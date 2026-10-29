extends SceneTree
## Production-scene contract, not a substitute for graphical playtest.
var errors: Array[String] = []
func require(ok: bool, reason: String) -> void:
	if not ok:
		errors.append(reason)
		push_error("BRINEWICK PRIORITIES: " + reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	require(app.lifecycle.installed.size() == 345, "All cottage and village sections have physical targets")
	var sites: HMBrinewickSites = app.stage.district_sites
	var finds: Dictionary = {}
	var clues: Dictionary = {}
	for child: Node in sites.get_children():
		if child is HMToolPickup:
			var tool: HMToolPickup = child as HMToolPickup
			finds[tool.tool_id] = tool
		elif child is HMStoryClue:
			var clue: HMStoryClue = child as HMStoryClue
			clues[clue.flag_id] = clue
	require(finds.size() == 3 and finds.has("crowbar") and finds.has("pickaxe") and finds.has("saw"), "Three world tool locations")
	require(clues.size() == 2 and clues.has("bell_first_strike") and clues.has("mine_voice_heard"), "Story one-time interaction props")
	require(finds["crowbar"].minimum_act == 2 and finds["pickaxe"].minimum_act == 2 and finds["saw"].minimum_act == 3, "Tool pickup act gates")
	require(app.toolbelt.owned_ids() == ["hands"], "No passive tool unlock")
	require(app.toolbelt.state["world"]["outputs"].is_empty(), "No passive materials")
	app.show_stage()
	require(not bool(app._story_clue_action(clues["mine_voice_heard"]).get("ok",false)), "Premature clue blocked")
	var state: Dictionary = app.toolbelt.state.duplicate(true)
	var sequence: int = 0
	for pid: String in ["village/02/yard_scrap/looseropecoil", "village/02/yard_scrap/stormthrownplanka"]:
		require(app.lifecycle.installed.has(pid), "Tier1 starter prop physical: "+pid)
		for op: String in ["partial_work","release"]:
			sequence += 1
			var event: Dictionary = {"op":op,"part_id":pid,"transaction_id":"priority/"+str(sequence),"user_initiated":true}
			if op == "partial_work": event["cycles"] = 1
			if op == "release":
				event["spawn_origin"] = [-18.0,2.3,18.0]
				event["access_aids"] = []
			var result: Dictionary = HMTransactions.apply(app.inspector.catalog,state,event)
			require(bool(result.get("ok",false)), "Manual part action " + op + ": " + String(result.get("reason","")))
			if bool(result.get("ok",false)): state = result["state"]
		for op: String in ["pickup","unload","register"]:
			sequence += 1
			var event: Dictionary = {"op":op,"output_id":pid+"/out/lot","transaction_id":"priority/"+str(sequence),"user_initiated":true}
			if op == "pickup": event["carrier"] = "carried"
			if op == "unload": event["receiving_pad_confirmed"] = true
			var result: Dictionary = HMTransactions.apply(app.inspector.catalog,state,event)
			require(bool(result.get("ok",false)), "Manual transport " + op + ": " + String(result.get("reason","")))
			if bool(result.get("ok",false)): state = result["state"]
	app.toolbelt.state = state
	app._sync_tool_context()
	app.player.global_position = app.yard_service.counter_center
	require(bool(app.manual_requisition().get("ok",false)), "Manual requisition accepts actual registered lots")
	require(int(app.toolbelt.state["progress"]["act"]) == 1, "Contract submission does not auto-advance")
	require(bool(app.manual_requisition().get("ok",false)), "Second explicit action advances act")
	require(int(app.toolbelt.state["progress"]["act"]) == 2, "Act II active")
	require(not app.toolbelt.is_owned("crowbar"), "Act progression does not grant tools")
	require(bool(app._story_clue_action(clues["mine_voice_heard"]).get("ok",false)), "Act II clue can be deliberately examined")
	require(not bool(app._story_clue_action(clues["mine_voice_heard"]).get("ok",false)), "Cannot repeat one-time clue")
	require(app.toolbelt.find_from_world("crowbar"), "Manual world tool transaction unlocks crowbar")
	app._sync_tool_context()
	require(HMSaveState.validate(app.inspector.catalog,app.toolbelt.state).is_empty(), "Post-progression state conserves source")
	app.show_menu()
	app.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_BRINEWICK_PRIORITIES_OK")
		quit(0)
	else:
		quit(1)
