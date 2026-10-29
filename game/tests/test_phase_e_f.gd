extends SceneTree
## Exact-engine Phase E/F contract: protected physical sites, persistence,
## manual gated narrative events and mutually exclusive endings.
var issues: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		issues.append(label)
		push_error("PHASE E/F: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	await physics_frame
	await physics_frame
	var village: HMBrinewickBlockout = app.stage
	check(village != null, "Production stage remains Brinewick")
	check(village.underground_sites != null, "Phase E built in normal world")
	check(village.campaign_sites != null, "Phase F evidence built in normal world")
	var ground_art: HMCoastalGroundArt = village.get_node_or_null(
		"BrinewickFacetedGroundArt") as HMCoastalGroundArt
	check(ground_art != null,"Brinewick procedural mineral ground visuals are integrated")
	if ground_art != null:
		check(ground_art.dressed_landforms >= 6,"Six or more protected coastal landforms have visible faceted skins")
		check(ground_art.dressed_paths >= 7,"Hand-shaped road surfaces keep physical paths distinct")

	check(village.underground_audio != null, "Spatial underground audio integrated")
	check(village.underground_audio.ambience_players.size() == 6, "Four established ambience sources plus two quiet coastal soundbeds")
	check(village.underground_audio.response_players.size() == 4, "Four gated one-time authored responses")
	var ground: HMUndergroundSites = village.underground_sites
	check(ground.stage_counts.has(31), "Step31 well and listening path")
	check(ground.stage_counts.has(32), "Step32 mine and inner seal")
	check(ground.stage_counts.has(33), "Step33 undercroft and protected bell")
	var dressing: Node3D = ground.get_node_or_null("FacetedUndergroundDetail") as Node3D
	check(dressing != null,"Masonry-dressed protected underground scene exists")
	if dressing != null:
		print("HOLLOWMERE_STONE_METRICS bodies=",dressing.get_meta("masonry_bodies",-1),
			" stones=",dressing.get_meta("masonry_stones",-1))
		check(int(dressing.get_meta("masonry_bodies",0)) >= 12,
			"Distinct physical masonry colliders have visual stone courses")
		check(int(dressing.get_meta("masonry_stones",0)) >= 100,
			"Procedural irregular stone courses are actually built")

	# Distinct player-clear architecture is built during normal world load.
	# No extra StaticBody3D/CollisionShape3D may be hidden in the art layer.
	var production_art: HMUndergroundProductionArt
	if dressing != null:
		production_art = dressing.get_node_or_null(
			"ProtectedUndergroundArchitecturalFinish") as HMUndergroundProductionArt
	check(production_art != null, "Phase E/F architectural geometry integrated")
	if production_art != null:
		check(production_art.beam_count >= 48, "Distinct faceted structural timber pieces")
		check(production_art.stone_count >= 30, "Distinct irregular protected stone pieces")
		check(production_art.iron_count >= 17, "Restrained oxidised iron details")
		for art_mesh: Node in production_art.get_children():
			check(art_mesh is MeshInstance3D,
				"Finish pieces are visual meshes, never invisible physics blockers")
		check(bool(production_art.get_meta("art_noncolliding",false)),
			"Architectural finish does not change structural collision")
	check(ground.locations.size() >= 6, "Underground landmarks have stable scene positions")
	check(ground.get_node_or_null("MineApproachOfficeAndSealedGallery/PermanentInnerSeal") != null,
		"Permanent inner mine seal remains collision-backed")
	check(app.lifecycle.installed.size() == 345,
		"Original 291 physical targets retained, with 54 new landmark components")
	check(village.campaign_sites.clue_nodes.size() == 10,
		"Ten additional one-time village records supplement two existing events")
	check(village.campaign_sites.finale_nodes.size() == 2,
		"Exactly two physical finale documents are present")
	var catalog: HMCatalog = app.inspector.catalog
	check(catalog.by_id("story", "discoveries", "aldren_remains_found").size() > 0,
		"Aldren's death evidence is in approved story data")
	var state: Dictionary = HMSaveState.fresh(catalog)
	var no_gesture: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "encounter", "flag_id": "bell_first_strike",
		"transaction_id": "test-no-gesture", "user_initiated": false})
	check(not no_gesture.get("ok", false), "Story evidence cannot be collected automatically")
	var first: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "encounter", "flag_id": "bell_first_strike",
		"transaction_id": "test-physical-event", "user_initiated": true})
	check(bool(first.get("ok", false)), "Explicit story transaction persists")
	if first.get("ok", false):
		state = first["state"]
		check(HMSaveState.validate(catalog, state).is_empty(), "Story flag keeps save valid")
		check(not HMTransactions.apply(catalog, state, {
			"op": "encounter", "flag_id": "bell_first_strike",
			"transaction_id": "test-repeat-event", "user_initiated": true}).get("ok", false),
			"Evidence cannot be duplicated")
	var early: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "ending", "ending_id": "bell_delivery", "explicit_confirmation": true,
		"finale_validated": true, "finale_site": "brinewick/site_15",
		"transaction_id": "test-early-finale", "user_initiated": true})
	check(not early.get("ok", false), "Cannot skip four-act contract by touching a finale")
	# Construct a synthetic fully-cleared state for negative/positive atomic
	# end-condition tests. This does NOT claim gameplay earned the requisitions.
	state["progress"]["act"] = 4
	state["progress"]["requisition_flags"] = ["req_act_01", "req_act_02", "req_act_03", "req_act_04"]
	state["progress"]["tools"] = ["hands", "claw_hammer", "crowbar", "pickaxe", "saw"]
	state["progress"]["discoveries"] = ["mine_voice_heard",
		"aldren_remains_found", "containment_understood", "mara_escape_clues"]
	check(HMSaveState.validate(catalog, state).is_empty(), "Synthetic test fixture is schema valid")
	var first_step: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "finale_action", "action_id": "float_reset", "world_target_validated": true,
		"site_id": "brinewick/site_20", "selected_tool_id": "hands",
		"transaction_id": "test-first-repair", "user_initiated": true})
	check(bool(first_step.get("ok", false)), "Manual float step is an atomic saved action")
	if first_step.get("ok", false):
		state = first_step["state"]
		check(not HMTransactions.apply(catalog, state, {
			"op": "finale_action", "action_id": "ratchet_align", "world_target_validated": true,
			"site_id": "brinewick/site_17", "selected_tool_id": "claw_hammer",
			"transaction_id": "test-skip-physical-work", "user_initiated": true}).get("ok", false),
			"Repair chain cannot skip a physical task")
		check(not HMTransactions.apply(catalog, state, {
			"op": "finale_action", "action_id": "bell_clamps", "world_target_validated": true,
			"site_id": "brinewick/site_15", "selected_tool_id": "crowbar",
			"transaction_id": "test-cross-branch", "user_initiated": true}).get("ok", false),
			"No contradictory delivery after beginning containment repair")
	var remaining: Array[String] = HMCampaignRules.REPAIR.slice(1)
	for action_id: String in remaining:
		var task: Dictionary = HMCampaignRules.TASKS[action_id]
		var response: Dictionary = HMTransactions.apply(catalog, state, {
			"op": "finale_action", "action_id": action_id, "world_target_validated": true,
			"site_id": task["site"], "selected_tool_id": task["tool"],
			"transaction_id": "test-repair-" + action_id, "user_initiated": true})
		check(bool(response.get("ok", false)), "Required repair operation " + action_id)
		if response.get("ok", false):
			state = response["state"]
	check(HMSaveState.validate(catalog, state).is_empty(), "Every physical repair step keeps the save valid")
	var wrong_place: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "ending", "ending_id": "repair_escape", "explicit_confirmation": true,
		"finale_validated": true, "finale_site": "brinewick/site_15",
		"transaction_id": "test-wrong-site", "user_initiated": true})
	check(not wrong_place.get("ok", false), "Repair ending rejects bell-house site")
	var no_confirm: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "ending", "ending_id": "repair_escape", "explicit_confirmation": false,
		"finale_validated": true, "finale_site": "brinewick/site_21",
		"transaction_id": "test-no-confirm", "user_initiated": true})
	check(not no_confirm.get("ok", false), "Repair ending requires explicit confirmation")
	var approved: Dictionary = HMTransactions.apply(catalog, state, {
		"op": "ending", "ending_id": "repair_escape", "explicit_confirmation": true,
		"finale_validated": true, "finale_site": "brinewick/site_21",
		"transaction_id": "test-real-finale", "user_initiated": true})
	check(bool(approved.get("ok", false)), "Prepared repair outcome is atomic and durable")
	if approved.get("ok", false):
		var completed: Dictionary = approved["state"]
		check(String(completed["progress"]["ending"]) == "repair_escape",
			"Only chosen ending stored")
		check(HMSaveState.validate(catalog, completed).is_empty(),
			"Ending round trip remains compatible with save schema")
		check(not HMTransactions.apply(catalog, completed, {
			"op": "ending", "ending_id": "bell_delivery", "explicit_confirmation": true,
			"finale_validated": true, "finale_site": "brinewick/site_15",
			"transaction_id": "test-second-ending", "user_initiated": true}).get("ok", false),
			"Both endings cannot be obtained in a single save")
	# Migration: a legitimately finished pre-upgrade save had no final action
	# list; it must remain loadable rather than being treated as corruption.
	var historical: Dictionary = HMSaveState.fresh(catalog)
	historical["progress"].erase("finale_actions")
	historical["progress"]["act"] = 4
	historical["progress"]["ending"] = "bell_delivery"
	historical["progress"]["discoveries"] = ["containment_understood"]
	check(HMSaveState.validate(catalog,historical).is_empty(),
		"Previously completed narrative saves stay compatible")
	app.queue_free()
	if issues.is_empty():
		print("HOLLOWMERE_PHASE_E_F_TEST_OK")
		quit(0)
	else:
		quit(1)
