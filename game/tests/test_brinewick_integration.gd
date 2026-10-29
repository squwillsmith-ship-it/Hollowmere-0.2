extends SceneTree
## Engine-checked production integration; scripted transactions are NOT a GUI playtest.
var failures: Array[String] = []
func check(good: bool, reason: String) -> void:
	if not good:
		failures.append(reason)
		push_error("BRINEWICK: " + reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var app: Variant = packed.instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	check(app.use_brinewick and app.stage is HMBrinewickBlockout, "Main controller enters Brinewick")
	check(app.player.get_parent() == app.stage, "One controller-owned player")
	check(app.lifecycle.installed.size() == 345, "Original 291 assemblies plus 54 inn/office parts")
	check(app.yard_service.belt == app.toolbelt, "Existing manual carrying/economy service connected")
	check(app.yard_service.pad_center == app.stage.district_sites.get_yard_station_positions()["pad"], "Real village receiving pad selected")
	check(app.yard_service.additional_benches.size() == 1, "Tomas workbench selected")
	check(app.work_ready, "Existing work session initialized")
	check(not app.toolbelt.is_owned("claw_hammer"), "Tools not granted automatically")
	var pickup: HMToolPickup = app.stage.district_sites.installation_nodes["discovery/workshop_hammer"].get_node_or_null("ManualDiscovery_claw_hammer") as HMToolPickup
	check(pickup != null, "Workshop hammer remains an explicit physical pickup")
	var pid: String = "village/06/net_store/net_rack"
	check(app.lifecycle.installed.has(pid), "New hand-tier net rack has physical target")
	var state: Dictionary = app.toolbelt.state.duplicate(true)
	check(HMSaveState.validate(app.inspector.catalog,state).is_empty(), "Integrated state is valid")
	app.show_stage()
	check(app.inspector.enabled and app.player.movement_enabled, "Player can enter active world")
	var work: Dictionary = HMTransactions.apply(app.inspector.catalog, state, {"op":"partial_work",
		"part_id":pid,"cycles":1,"user_initiated":true,"transaction_id":"village/work/net"})
	check(bool(work.get("ok",false)), "Manual work rules accept village authored part")
	if bool(work.get("ok",false)):
		state = work["state"]
		var released: Dictionary = HMTransactions.apply(app.inspector.catalog, state, {"op":"release",
			"part_id":pid,"access_aids":[],"spawn_origin":[1.0,2.3,1.0],
			"user_initiated":true,"transaction_id":"village/release/net"})
		check(bool(released.get("ok",false)), "Manual release creates conserved output")
		if bool(released.get("ok",false)):
			state = released["state"]
			app.lifecycle.reconcile(state)
			check(not app.lifecycle.installed[pid].visible, "Removed part visual disabled")
			check(state["world"]["outputs"].size() == 1, "One recovered lot")
			var oid: String = String(state["world"]["outputs"].keys()[0])
			for operation: String in ["pickup","unload","register","sell"]:
				var transaction: Dictionary = {"op":operation,"output_id":oid,"user_initiated":true,
					"transaction_id":"village/"+operation+"/net"}
				if operation == "pickup": transaction["carrier"] = "carried"
				if operation == "unload": transaction["receiving_pad_confirmed"] = true
				var result: Dictionary = HMTransactions.apply(app.inspector.catalog,state,transaction)
				check(bool(result.get("ok",false)), "Manual logistics " + operation)
				if bool(result.get("ok",false)): state=result["state"]
			check(int(state["economy"]["credits"]) > 0, "Manual sale earns credits")
			check(HMSaveState.validate(app.inspector.catalog,state).is_empty(), "Ledgers conserved")
			var slot := HMSaveStore.new()
			check(slot.open_slot(app.inspector.catalog,"brinewick_integration_test"),"Isolated disk-backed slot")
			slot.state=state.duplicate(true)
			check(slot.save_now(),"Integrated scene snapshot written")
			var cold := HMSaveStore.new()
			check(cold.open_slot(app.inspector.catalog,"brinewick_integration_test"),"Cold reload")
			check(cold.snapshot()["world"]["parts"][pid]["phase"]=="released","Release persists")
			for ext: String in ["", ".previous", ".writing"]:
				var path: String = ProjectSettings.globalize_path(
					HMSaveStore.SAVE_DIRECTORY.path_join("brinewick_integration_test.hmsave.json"+ext))
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app.show_menu()
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_BRINEWICK_INTEGRATION_OK")
		quit(0)
	else:
		quit(1)
