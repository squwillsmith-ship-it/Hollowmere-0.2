extends SceneTree
## Complete *engineering* cottage transaction + physical part rehearsal.
## This is not an automated in-game harvesting feature or real user playtest.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("rehearse")
func check(good: bool, reason: String) -> void:
	if not good:
		failures.append(reason)
		push_error("STEP24 FAILED: " + reason)
func transact(catalog: HMCatalog, state: Dictionary, op: String, tid: String, extra: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {"transaction_id": tid, "op": op, "user_initiated": true}
	event.merge(extra)
	var result: Dictionary = HMTransactions.apply(catalog, state, event)
	check(bool(result.get("ok", false)), op + " " + tid + " " + String(result.get("reason", "")))
	return result.get("state", state)
func remove_slot() -> void:
	for ext: String in ["", ".previous", ".writing"]:
		var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join("step24_cottage.hmsave.json" + ext))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
func rehearse() -> void:
	remove_slot()
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalogue loads")
	var blueprint: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	check(HMBuildingPrefab.validate(blueprint, cat).is_empty(), "Cottage authoring valid")
	var built: Node3D = HMBuildingPrefab.build(blueprint, cat)
	check(built != null, "Physical cottage builds")
	if built == null:
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(built)
	var life := HMPartLifecycle.new()
	stage.add_child(life)
	life.bind_stage(stage)
	check(life.installed.size() == blueprint["parts"].size(), "Every authored cottage part has a unique target/collider")
	var state: Dictionary = HMSaveState.fresh(cat)
	for tool: String in ["claw_hammer", "crowbar", "pickaxe", "saw"]:
		state = transact(cat, state, "find_tool", "24/find/"+tool, {"tool_id":tool, "source":"world_discovery"})
	var phase: int = 0
	for row: Variant in blueprint["parts"]:
		var pid: String = String(row["id"])
		var part: Dictionary = cat.by_part_id(pid)
		check(not part.is_empty(), "Real catalogue definition: " + pid)
		state = transact(cat, state, "partial_work", "24/work/"+pid, {"part_id":pid, "cycles":int(part["work_units"])})
		var access: Array = part.get("requires_access_aids", [])
		state = transact(cat, state, "release", "24/release/"+pid,
			{"part_id":pid, "access_aids":access, "spawn_origin":[-8.0+float(phase)*0.5, 0.4, -3.0]})
		phase += 1
		if phase == 4:
			life.reconcile(state)
			check(life.recovered.size() >= 4, "Visible recovered parts after first cottage pass")
		check(HMSaveState.validate(cat,state).is_empty(), "Conservation after "+pid)
	life.reconcile(state)
	var retained: int = 0
	for row: Variant in blueprint["parts"]:
		var pid: String = String(row["id"])
		check(state["world"]["parts"][pid]["phase"] == "released", "Every original part removed: "+pid)
		check(not life.installed[pid].visible, "No invisible blocker/ghost visual: "+pid)
		retained += HMRules.make_outputs(cat,pid,"intact").size()
	check(life.recovered.size() == retained, "Every authored recovery lot spawned once")
	check(built.get_node("NonSalvageableFixtureScenery").get_child_count() == 1, "Only terrain footprint remains")
	# Manually register and sell small salvage before purchasing the physical
	# load upgrade needed for the heavy frame. Neither release nor collision pays.
	var lot_keys: Array = state["world"]["outputs"].keys()
	lot_keys.sort()
	var heavy: Array[String] = []
	for key: Variant in lot_keys:
		var oid: String = String(key)
		if HMSalvageLogistics.units(state["world"]["outputs"][oid]) > 6:
			heavy.append(oid)
			continue
		state = transact(cat,state,"pickup","24/pick/"+oid,{"output_id":oid,"carrier":"carried"})
		state = transact(cat,state,"unload","24/unload/"+oid,{"output_id":oid,"receiving_pad_confirmed":true})
		state = transact(cat,state,"register","24/register/"+oid,{"output_id":oid})
		state = transact(cat,state,"sell","24/sell/"+oid,{"output_id":oid})
	check(int(state["economy"]["credits"]) >= 44, "Player earns enough credits from physically handled small lots")
	state = transact(cat,state,"purchase","24/pack1",{"upgrade_id":"pack_straps"})
	state = transact(cat,state,"purchase","24/pack2",{"upgrade_id":"pack_straps"})
	for oid: String in heavy:
		check(HMSalvageLogistics.can_lift(state["world"],state["economy"],oid),"Upgraded manual capacity can lift beam")
		state = transact(cat,state,"pickup","24/pick/"+oid,{"output_id":oid,"carrier":"carried"})
		state = transact(cat,state,"unload","24/unload/"+oid,{"output_id":oid,"receiving_pad_confirmed":true})
		state = transact(cat,state,"register","24/register/"+oid,{"output_id":oid})
		state = transact(cat,state,"sell","24/sell/"+oid,{"output_id":oid})
	check(state["world"]["outputs"].size() == state["economy"]["sold"].size(), "Every lot manually registered and sold once")
	check(HMSaveState.validate(cat, state).is_empty(), "Complete cottage conserves materials and credits")
	# Test an actual cold save/reopen at the end of the physical rehearsal.
	var store := HMSaveStore.new()
	check(store.open_slot(cat,"step24_cottage"),"New physical replay save slot")
	store.state=state.duplicate(true)
	check(store.save_now(),"Full cottage snapshot written")
	var cold := HMSaveStore.new()
	check(cold.open_slot(cat,"step24_cottage"),"Full cottage snapshot cold-reloaded")
	check(cold.state["world"]["outputs"].size() == retained, "All recovered child IDs survive reload")
	life.reconcile(cold.snapshot())
	check(life.recovered.is_empty(), "Sold lots do not respawn after reload")
	for id: Variant in life.installed:
		check(not life.installed[id].visible, "Dismantled cottage stays dismantled after reload")
	remove_slot()
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP24_TEST_OK")
		quit(0)
	else:
		quit(1)
