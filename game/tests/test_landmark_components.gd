extends SceneTree
## New deterministic physical salvage plus append-only save regression.
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("LANDMARKS FAIL: " + label)

func remove_slot() -> void:
	var slot: String = "landmark_additive_replay"
	for ext: String in ["", ".previous", ".writing"]:
		var path: String = ProjectSettings.globalize_path(
			HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json" + ext))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func run() -> void:
	var cat := HMCatalog.new()
	check(cat.load_all(), "Complete catalogue loads")
	check(HMSchema.validate(cat).is_empty(), "Tool, support and salvage contracts validate")
	var definitions: Array = cat.entries("sample_parts", "parts")
	check(definitions.size() == 351, "297 original + 54 new part definitions")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/v1/landmark_parts.json"))
	check(raw is Dictionary and raw.get("parts", []).size() == 54,
		"Exactly 54 uniquely named building pieces")
	var prior_ids: Dictionary = {}
	for part: Variant in definitions.slice(0, 297):
		prior_ids[String(part["id"])] = true
	var all_ids: Dictionary = {}
	for part: Variant in definitions:
		check(not all_ids.has(String(part["id"])), "No duplicate component ID")
		all_ids[String(part["id"])] = true
	for part: Variant in raw["parts"]:
		var pid: String = String(part["id"])
		check(not prior_ids.has(pid), "Existing salvage IDs never overwritten")
		check(not bool(part["protected"]), "Ordinary architecture may be dismantled")
		check(HMSalvageLogistics.units({"allocation": part["allocation"]}) <= 6,
			"Each recovered component fits initial carrying capacity")
		for dependent: String in part["supports"]:
			check(all_ids.has(dependent), "All structural dependents have persisted IDs")
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	await physics_frame
	await physics_frame
	check(app.lifecycle.installed.size() == 345, "All original and new physical targets installed")
	var group: HMVillageLandmarkArt = (app.stage as HMBrinewickBlockout).get_node_or_null(
		"InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
	check(group != null and group.created_bodies == 54, "Both normal buildings authored")
	var world: Dictionary = app.toolbelt.state
	for part: Variant in raw["parts"]:
		var pid: String = String(part["id"])
		check(app.lifecycle.installed.has(pid), "Scene part corresponds to saved ID: " + pid)
		check(world["world"]["parts"].has(pid), "Fresh save knows physical part: " + pid)
	var state: Dictionary = HMSaveState.fresh(cat)
	var footing: Dictionary = HMSupportGraph.release_diagnostic(cat,
		String(raw["parts"][0]["id"]), state["world"]["parts"].keys())
	check(not bool(footing.get("allowed_safe", true)), "Inn footing must retain supported walls until removal")
	var found: Dictionary = HMTransactions.apply(cat, state, {
		"op": "find_tool", "tool_id": "claw_hammer", "source": "world_discovery",
		"transaction_id": "landmark/manual_find_hammer", "user_initiated": true})
	check(bool(found.get("ok", false)), "Manually discover hammer capability before furniture work")
	if bool(found.get("ok", false)):
		state = found["state"]
	var bench: String = String(raw["parts"][33]["id"])
	var part: Dictionary = cat.by_part_id(bench)
	var work: Dictionary = HMTransactions.apply(cat, state, {
		"op": "partial_work", "part_id": bench, "cycles": int(part["work_units"]),
		"transaction_id": "landmark/manual_bench_work", "user_initiated": true})
	check(bool(work.get("ok", false)), "Deliberate hammer work can finish real inn furniture")
	if bool(work.get("ok", false)):
		state = work["state"]
		var release: Dictionary = HMTransactions.apply(cat, state, {
			"op": "release", "part_id": bench, "access_aids": [],
			"spawn_origin": [70.0, 9.0, 26.0], "transaction_id": "landmark/manual_bench_release",
			"user_initiated": true})
		check(bool(release.get("ok", false)), "Manual release produces recoverable furniture")
		if bool(release.get("ok", false)):
			state = release["state"]
			check(state["economy"]["credits"] == 0, "Dismantling does not auto-sell")
			app.lifecycle.reconcile(state)
			check(not app.lifecycle.installed[bench].visible, "Released bench disappears from world")
			check(HMSaveState.validate(cat, state).is_empty(), "Recovery remains save-valid")
	# Signed old-save simulation (297 known definitions): migrate only append-only.
	remove_slot()
	var previous := HMCatalog.new()
	previous.tables = cat.tables.duplicate(true)
	previous.tables["sample_parts"]["parts"] = definitions.slice(0, 297)
	var before := HMSaveStore.new()
	check(before.open_slot(previous, "landmark_additive_replay"), "Prior 297-ID save opens")
	var old: Dictionary = before.snapshot()
	old["world"]["parts"]["village/06/net_store/net_rack"]["work"] = 1
	before.state = old
	check(before.save_now(), "Prior signed snapshot written")
	var migrated := HMSaveStore.new()
	check(migrated.open_slot(cat, "landmark_additive_replay"),
		"New parts append with no deletion of old progress")
	if not migrated.state.is_empty():
		check(migrated.state["world"]["parts"].size() == 351,
			"Migration appends exactly 54 landmark IDs")
		check(int(migrated.state["world"]["parts"]["village/06/net_store/net_rack"]["work"]) == 1,
			"Previously worked panels retain partial progress")
		check(HMSaveState.validate(cat, migrated.state).is_empty(), "Migrated save validates")
	remove_slot()
	app.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_LANDMARK_COMPONENTS_OK")
		quit(0)
	else:
		quit(1)
