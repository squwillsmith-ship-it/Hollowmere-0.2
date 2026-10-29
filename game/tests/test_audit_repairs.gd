extends SceneTree
## Guardrails on actual Godot 4.7.2: strict migration, pose and input denial.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_suite")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("AUDIT REPAIR FAILED: " + message)
func intent(id: String, op: String, extra: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {"transaction_id": id, "user_initiated": true, "op": op}
	payload.merge(extra)
	return payload
func clean_slot(slot: String) -> void:
	for tail: String in ["", ".writing", ".previous"]:
		var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json" + tail))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
func run_suite() -> void:
	var catalog := HMCatalog.new()
	check(catalog.load_all(), "Baseline catalogue loads")
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	check(HMBuildingPrefab.validate(manifest, catalog).is_empty(), "Original prefab valid")
	for wrong: Variant in [["bad", 0, 0], [0, INF, 2], [0, NAN, 2], [1, 2], [100001, 0, 0]]:
		var item: Dictionary = manifest.duplicate(true)
		item["origin"] = wrong
		check(not HMBuildingPrefab.validate(item, catalog).is_empty(), "Invalid origin rejected")
		item = manifest.duplicate(true)
		item["parts"][0]["geometry"][0]["rotation"] = wrong
		check(not HMBuildingPrefab.validate(item, catalog).is_empty(), "Invalid rotation rejected")
	for field: String in ["parts", "static_scenery"]:
		var wrong_kind: Dictionary = manifest.duplicate(true)
		wrong_kind[field] = "invalid array"
		check(not HMBuildingPrefab.validate(wrong_kind, catalog).is_empty(), "Reject bad " + field)
	var wrong_pieces: Dictionary = manifest.duplicate(true)
	wrong_pieces["parts"][0]["geometry"] = {}
	check(not HMBuildingPrefab.validate(wrong_pieces, catalog).is_empty(), "Reject bad geometry table")
	clean_slot("audit_additive")
	clean_slot("audit_incompatible")
	clean_slot("audit_pose")
	var old := HMSaveStore.new()
	check(old.open_slot(catalog, "audit_additive"), "Original slot opens")
	check(old.commit(intent("manual01", "partial_work", {"part_id": "fixture/shed/loose_rope", "cycles": 1})), "Manual work survives")
	check(old.commit(intent("manual02", "release", {"part_id": "fixture/shed/loose_rope", "spawn_origin": [0.0, 0.3, 0.0]})), "Manual release survives")
	check(old.save_now(), "Seal original v1 snapshot")
	var reference: Dictionary = old.snapshot()
	var expanded := HMCatalog.new()
	expanded.tables = catalog.tables.duplicate(true)
	var addition: Dictionary = expanded.tables["sample_parts"]["parts"][0].duplicate(true)
	addition["id"] = "fixture/audit/new_rope"
	expanded.tables["sample_parts"]["parts"].append(addition)
	var migrated := HMSaveStore.new()
	check(migrated.open_slot(expanded, "audit_additive"), "Append-only migration permitted")
	if not migrated.state.is_empty():
		check(HMSaveState.validate(expanded, migrated.state).is_empty(), "Migrated state valid")
		check(migrated.state["world"]["parts"][addition["id"]]["phase"] == "attached", "New part starts unworked")
		var previous_outputs: Dictionary = reference["world"]["outputs"]
		var migrated_outputs: Dictionary = migrated.state["world"]["outputs"]
		check(migrated_outputs.size() == previous_outputs.size(), "No historical output lost or duplicated")
		for output_id: Variant in previous_outputs:
			var expected: Dictionary = previous_outputs[output_id]
			var actual: Dictionary = migrated_outputs.get(output_id, {})
			check(not actual.is_empty(), "Preserved output ID")
			if not actual.is_empty():
				check(HMSchema.same_allocation(expected["allocation"], actual["allocation"]), "Preserved output quantity")
				for field: String in ["id", "source_part_id", "site_id", "condition", "location", "carrier_id", "processed", "registered", "sold"]:
					check(expected.get(field) == actual.get(field), "Preserved output field " + field)
		check(migrated.state["economy"] == reference["economy"], "Economy untouched")
		check(migrated.state["completed_transactions"] == reference["completed_transactions"], "Once-only receipt history untouched")
		check(migrated.commit(intent("pose_after_migrate", "set_player_pose", {"position": [2.0, 0.96, 7.0], "yaw": 1.1})), "New snapshot saves")
		var cold := HMSaveStore.new()
		check(cold.open_slot(expanded, "audit_additive"), "Reload migrated snapshot from disk")
		check(cold.state["world"]["carriers"]["player"]["position"] == [2.0, 0.96, 7.0], "Pose survived cold reload")
	var incompatible := HMSaveStore.new()
	check(incompatible.open_slot(catalog, "audit_incompatible"), "Second original slot")
	check(incompatible.save_now(), "Second original saved")
	var changed := HMCatalog.new()
	changed.tables = expanded.tables.duplicate(true)
	changed.tables["sample_parts"]["parts"][0]["work_units"] = 12
	var fail_closed := HMSaveStore.new()
	check(not fail_closed.open_slot(changed, "audit_incompatible"), "Changed historical part rejects migration")
	var changed_economy := HMCatalog.new()
	changed_economy.tables = expanded.tables.duplicate(true)
	changed_economy.tables["upgrades"]["upgrades"][0]["levels"][0]["price"] = 999
	check(not HMSaveStore.new().open_slot(changed_economy, "audit_incompatible"), "Changed price rejects migration")
	var belt := HMToolbelt.new()
	belt.initialize(catalog)
	var session := HMWorkSession.new()
	check(session.initialize(catalog, belt, true, "audit_pose"), "Persistent player session")
	check(not session.has_checkpointed_player_pose(), "Fresh placeholder is not persisted pose")
	check(session.checkpoint_player_pose({"position": [5.0, 0.96, 4.0], "yaw": 0.5}), "Manual movement checkpoint")
	check(session.has_checkpointed_player_pose(), "Actual pose checkpoint marker exists")
	var rev: int = int(belt.state["revision"])
	check(session.checkpoint_player_pose({"position": [5.0, 0.96, 4.0], "yaw": 0.5}), "Unchanged pose safe")
	check(int(belt.state["revision"]) == rev, "Unchanged pose makes no repeated transaction")
	var belt2 := HMToolbelt.new()
	belt2.initialize(catalog)
	var resumed := HMWorkSession.new()
	check(resumed.initialize(catalog, belt2, true, "audit_pose"), "Resume persisted session")
	check(resumed.has_checkpointed_player_pose(), "Real pose recognized")
	check(belt2.state["world"]["carriers"]["player"]["position"] == [5.0, 0.96, 4.0], "Checkpointed position restored")
	clean_slot("audit_additive")
	clean_slot("audit_incompatible")
	clean_slot("audit_pose")
	if failures.is_empty():
		print("HOLLOWMERE_AUDIT_REPAIRS_OK")
		quit(0)
	else:
		print("HOLLOWMERE_AUDIT_REPAIRS_FAILED " + str(failures))
		quit(1)
