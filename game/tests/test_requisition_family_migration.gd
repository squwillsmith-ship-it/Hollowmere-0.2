extends SceneTree
## Strict signed-save migration test for removing unavailable fired_clay from Act III.
const SLOTS: Array[String] = ["act3_legacy_full", "act3_legacy_297", "act3_legacy_75", "act3_invalid_quota"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func ensure(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		push_error("ACT III MIGRATION: " + note)

func cleanup() -> void:
	for slot: String in SLOTS:
		for suffix: String in ["", ".previous", ".writing"]:
			var path: String = ProjectSettings.globalize_path(
				HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json" + suffix))
			if FileAccess.file_exists(path):
				ensure(DirAccess.remove_absolute(path) == OK, "Clean disposable slot " + slot)

func legacy(current: HMCatalog, count: int, altered: bool = false) -> HMCatalog:
	var old := HMCatalog.new()
	old.tables = current.tables.duplicate(true)
	old.tables["requisitions"]["requisitions"][2]["families"] = ["timber", "stone", "fired_clay"]
	if altered:
		old.tables["requisitions"]["requisitions"][2]["min_registered_units"] = 26
	if count < 351:
		var parts: Array = old.tables["sample_parts"]["parts"]
		old.tables["sample_parts"]["parts"] = parts.slice(0, count)
	return old

func check_migration(current: HMCatalog, slot: String, count: int) -> void:
	var prior: HMCatalog = legacy(current, count)
	var writer := HMSaveStore.new()
	ensure(writer.open_slot(prior, slot), "Open old signed slot " + slot)
	if writer.state.is_empty():
		return
	var original: Dictionary = writer.snapshot()
	original["world"]["parts"]["village/06/net_store/net_rack"]["work"] = 1
	writer.state = original
	ensure(writer.save_now(), "Persist old work " + slot)
	var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json"))
	var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	ensure(before is Dictionary, "Original envelope parses " + slot)
	var reader := HMSaveStore.new()
	ensure(reader.open_slot(current, slot), "Exact historical content hash migrates " + slot)
	if reader.state.is_empty():
		return
	ensure(reader.state["world"]["parts"].size() == 351, "Part IDs preserved " + slot)
	ensure(int(reader.state["world"]["parts"]["village/06/net_store/net_rack"]["work"]) == 1,
		"Original partial work preserved " + slot)
	ensure(HMSaveState.validate(current, reader.state).is_empty(), "State remains valid " + slot)
	ensure(reader.save_now(), "Resign migrated save " + slot)
	var after: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if before is Dictionary and after is Dictionary:
		ensure(before["content_sha256"] != after["content_sha256"], "Content hash advanced " + slot)
	var cold := HMSaveStore.new()
	ensure(cold.open_slot(current, slot), "Cold reopened migrated save " + slot)

func run() -> void:
	var current := HMCatalog.new()
	ensure(current.load_all(), "Current catalogue loads")
	if not current.errors.is_empty():
		quit(1)
		return
	ensure(current.by_id("requisitions", "requisitions", "req_act_03").get("families", []) ==
		["timber", "stone"], "Act III has no unavailable material")
	cleanup()
	check_migration(current, SLOTS[0], 351)
	check_migration(current, SLOTS[1], 297)
	check_migration(current, SLOTS[2], 75)
	var wrong := HMSaveStore.new()
	ensure(wrong.open_slot(legacy(current, 351, true), SLOTS[3]), "Create altered signed quota")
	ensure(wrong.save_now(), "Write altered quota fixture")
	var blocked := HMSaveStore.new()
	ensure(not blocked.open_slot(current, SLOTS[3]), "Refuse unrelated quota migration")
	ensure(blocked.state.is_empty(), "No silent save reset")
	cleanup()
	if failures.is_empty():
		print("HOLLOWMERE_ACT_III_MATERIAL_MIGRATION_OK")
		quit(0)
	else:
		quit(1)
