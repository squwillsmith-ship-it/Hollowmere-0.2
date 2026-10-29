extends SceneTree
## Step23: actual disk-backed snapshots + physical authoring reconciliation.
## Test actions below are scripted substitutes for manual inputs, not autoplay code.
var issues: Array[String] = []
func _initialize() -> void:
	call_deferred("test")
func check(ok: bool, message: String) -> void:
	if not ok:
		issues.append(message)
		push_error("STEP23 FAILED: " + message)
func event(key: String, op: String, detail: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"transaction_id": key, "op": op, "user_initiated": true}
	e.merge(detail)
	return e
func clean() -> void:
	for ext: String in ["", ".previous", ".writing"]:
		var p: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join("step23_roundtrip.hmsave.json" + ext))
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
func test() -> void:
	clean()
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog loads")
	var initial := HMSaveStore.new()
	check(initial.open_slot(cat, "step23_roundtrip"), "Open new slot")
	check(initial.commit(event("23/tool", "find_tool", {"tool_id": "claw_hammer", "source": "world_discovery"})), "Discovered hammer stored")
	var id: String = "fixture/house/shutters"
	check(initial.commit(event("23/work1", "partial_work", {"part_id": id, "cycles": 1})), "One manual partial work cycle")
	check(initial.state["world"]["parts"][id]["work"] == 1, "Progress is incomplete")
	check(initial.save_now(), "Persist first checkpoint")
	var reopened := HMSaveStore.new()
	check(reopened.open_slot(cat, "step23_roundtrip"), "Cold read first checkpoint")
	check(reopened.state["world"]["parts"][id]["phase"] == "attached" and reopened.state["world"]["parts"][id]["work"] == 1, "Partial work survives cold restart")
	check(reopened.state["progress"]["tools"].has("claw_hammer"), "Discovered tool survives restart")
	var prefab: Node3D = HMBuildingPrefab.build(HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json"), cat)
	check(prefab != null, "Cottage compiles for reload")
	var stage := Node3D.new()
	root.add_child(stage)
	if prefab != null:
		stage.add_child(prefab)
	var lifecycle := HMPartLifecycle.new()
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	lifecycle.reconcile(reopened.snapshot())
	check(lifecycle.installed.has(id) and lifecycle.installed[id].visible, "Part is still visibly attached during partial work")
	check(reopened.commit(event("23/work2", "partial_work", {"part_id": id, "cycles": 2})), "Complete manual work")
	check(reopened.commit(event("23/release", "release", {"part_id": id, "spawn_origin": [-8.0, 0.35, -3.0]})), "Release once creates physical output")
	var once: int = reopened.state["world"]["outputs"].size()
	check(once == 1, "One authored shutter lot recovered")
	check(not reopened.commit(event("23/release-again", "release", {"part_id": id})), "Releasing same part twice denied")
	lifecycle.reconcile(reopened.snapshot())
	check(not lifecycle.installed[id].visible and lifecycle.recovered.size() == once, "Physical part disappears and lot appears")
	var disk := HMSaveStore.new()
	check(disk.open_slot(cat, "step23_roundtrip"), "Cold read after release")
	check(disk.state["world"]["outputs"].size() == once and disk.state["world"]["parts"][id]["phase"] == "released", "No duplication or resurrection after reload")
	var oid: String = id + "/out/shutters"
	check(disk.state["world"]["outputs"].has(oid), "Deterministic recoverable lot ID survives")
	check(disk.commit(event("23/pick", "pickup", {"output_id": oid, "carrier": "carried"})), "Physical lot manually lifted after reload")
	check(disk.commit(event("23/place", "place", {"output_id": oid, "position": [-7.5, 0.4, -2.8]})), "Physical lot manually staged")
	var last := HMSaveStore.new()
	check(last.open_slot(cat, "step23_roundtrip"), "Cold read staged lot")
	check(last.state["world"]["outputs"][oid]["location"] == "staged", "Staged salvage and position survive")
	check(last.state["world"]["outputs"][oid]["position"] == [-7.5, 0.4, -2.8], "Staged salvage position round trips")
	lifecycle.reconcile(last.snapshot())
	check(lifecycle.recovered.size() == 1, "One settled physical lot reconstructed")
	check(HMSaveState.validate(cat, last.state).is_empty(), "No material or transaction corruption")
	stage.queue_free()
	await process_frame
	clean()
	if issues.is_empty():
		print("HOLLOWMERE_STEP23_TEST_OK")
		quit(0)
	else:
		quit(1)
