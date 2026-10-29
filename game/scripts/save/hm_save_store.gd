class_name HMSaveStore
extends RefCounted
## Durable snapshot store. Saves a clone only after an explicit player transaction.
## Uses a staged write and retains previous valid snapshot; never silently wipes
## a corrupt save or treats an uncommitted state change as successful.
## Permits verified append-only part IDs and one explicitly pinned Act III
## eligibility correction. Never silently accepts other changed historical values.

const SAVE_DIRECTORY: String = "user://saves"

var catalog: HMCatalog
var slot: String = ""
var state: Dictionary = {}
var last_error: String = ""
var recovered_previous: bool = false


func open_slot(source_catalog: HMCatalog, slot_id: String) -> bool:
	catalog = source_catalog
	last_error = ""
	recovered_previous = false
	if not _slot_safe(slot_id):
		last_error = "Unsafe or empty save slot name"
		return false
	slot = slot_id
	var folder: String = ProjectSettings.globalize_path(SAVE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		last_error = "Unable to create local save directory"
		return false
	var primary: String = _path("")
	var previous: String = _path(".previous")
	if not FileAccess.file_exists(primary) and not FileAccess.file_exists(previous):
		state = HMSaveState.fresh(catalog)
		return HMSaveState.validate(catalog, state).is_empty()
	var loaded: Dictionary = _read_checked(primary)
	if loaded.is_empty():
		loaded = _read_checked(previous)
		if loaded.is_empty():
			last_error = "Both primary and previous saves are missing or invalid; refusing to reset progress"
			return false
		recovered_previous = true
	state = loaded
	return true


func commit(event: Dictionary) -> bool:
	if state.is_empty():
		last_error = "No open save state"
		return false
	var result: Dictionary = HMTransactions.apply(catalog, state, event)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("reason", "Transaction refused"))
		return false
	if not _write_snapshot(result["state"]):
		return false
	state = result["state"]
	last_error = ""
	return true


func save_now() -> bool:
	if state.is_empty():
		last_error = "No open save"
		return false
	return _write_snapshot(state)


func snapshot() -> Dictionary:
	return state.duplicate(true)


func _write_snapshot(data: Dictionary) -> bool:
	var mistakes: PackedStringArray = HMSaveState.validate(catalog, data)
	if not mistakes.is_empty():
		last_error = "Refusing invalid save: " + mistakes[0]
		return false
	var json: String = JSON.stringify(data, "", true)
	var envelope: Dictionary = {
		"format": "hollowmere_save_v1",
		"content_sha256": _content_hash(),
		"payload_sha256": json.sha256_text(),
		"payload_json": json
	}
	var temp: String = _path(".writing")
	var main: String = _path("")
	var previous: String = _path(".previous")
	var handle: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if handle == null:
		last_error = "Could not open staged save file"
		return false
	handle.store_string(JSON.stringify(envelope, "", true))
	handle.flush()
	var write_error: Error = handle.get_error()
	handle.close()
	if write_error != OK:
		last_error = "Staged write failed: " + str(write_error)
		return false
	if _read_checked(temp).is_empty():
		last_error = "Staged save did not verify"
		return false
	# Rotate only when main is a known good save. If main was corrupt and we
	# recovered previous, leave that valid previous intact until the new main exists.
	if FileAccess.file_exists(main):
		var old_good: bool = not _read_checked(main).is_empty()
		if old_good:
			if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous) != OK:
				last_error = "Unable to retire old previous save"
				return false
			if DirAccess.rename_absolute(main, previous) != OK:
				last_error = "Unable to rotate previous save"
				return false
		else:
			if DirAccess.remove_absolute(main) != OK:
				last_error = "Unable to replace corrupt primary safely"
				return false
	var swap_result: Error = DirAccess.rename_absolute(temp, main)
	if swap_result != OK:
		# After an interrupted rotation the valid previous remains available.
		if not FileAccess.file_exists(main) and FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, main)
		last_error = "Unable to commit staged save: " + str(swap_result)
		return false
	recovered_previous = false
	return true


func _read_checked(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	# Invalid primary saves are expected during recovery tests. Parse without
	# emitting engine-level errors for deliberately malformed JSON.
	var envelope_reader := JSON.new()
	if envelope_reader.parse(raw) != OK:
		return {}
	var result: Variant = envelope_reader.data
	if not (result is Dictionary):
		return {}
	var wrapped: Dictionary = result
	if String(wrapped.get("format", "")) != "hollowmere_save_v1":
		return {}
	var payload_json: String = String(wrapped.get("payload_json", ""))
	if payload_json.sha256_text() != String(wrapped.get("payload_sha256", "")):
		return {}
	var payload_reader := JSON.new()
	if payload_reader.parse(payload_json) != OK:
		return {}
	var parsed: Variant = payload_reader.data
	if not (parsed is Dictionary):
		return {}
	var state_data: Dictionary = parsed
	_normalize_numbers(state_data)
	var recorded_hash: String = String(wrapped.get("content_sha256", ""))
	if recorded_hash != _content_hash():
		state_data = _migrate_additive_parts(state_data, recorded_hash)
		if state_data.is_empty():
			return {}
	if not HMSaveState.validate(catalog, state_data).is_empty():
		return {}
	return state_data


func _migrate_additive_parts(old_save: Dictionary, previous_hash: String) -> Dictionary:
	# Strictly reconstruct the original signed catalogue before migrating.
	# Historical additive part migrations remain supported. The ONLY non-additive
	# exception is removing the unavailable fired_clay option from Act III.
	# Recreate exactly the old eligibility array and check its original hash;
	# never allow altered quotas, tool gates, material values or other changes.
	if not (old_save.get("world", null) is Dictionary):
		return {}
	var saved: Variant = old_save["world"].get("parts", null)
	if not (saved is Dictionary) or saved.is_empty():
		return {}
	var all_definitions: Variant = catalog.tables.get("sample_parts", {}).get("parts", null)
	if not (all_definitions is Array):
		return {}
	var previous_parts: Array = []
	var new_ids: Array[String] = []
	for entry: Variant in all_definitions:
		if not (entry is Dictionary) or not entry.has("id"):
			return {}
		var id: String = String(entry["id"])
		if saved.has(id):
			previous_parts.append(entry)
		else:
			new_ids.append(id)
	if previous_parts.size() != saved.size():
		return {}
	# Try exactly two historical catalogue shapes: normal append-only content,
	# then the precise old Act III accepted-family list. Both require a match
	# against the existing signed content_sha256 before any state is converted.
	for legacy_act_iii: bool in [false, true]:
		if new_ids.is_empty() and not legacy_act_iii:
			continue
		var old_tables: Dictionary = catalog.tables.duplicate(true)
		old_tables["sample_parts"]["parts"] = previous_parts
		if legacy_act_iii:
			var reqs: Array = old_tables.get("requisitions", {}).get("requisitions", [])
			if reqs.size() != 4:
				return {}
			var act_iii: Dictionary = reqs[2]
			if String(act_iii.get("id", "")) != "req_act_03" or \
					act_iii.get("families", []) != ["timber", "stone"]:
				return {}
			act_iii["families"] = ["timber", "stone", "fired_clay"]
		if JSON.stringify(old_tables, "", true).sha256_text() != previous_hash:
			continue
		var prior_catalog := HMCatalog.new()
		prior_catalog.tables = old_tables
		if not HMSaveState.validate(prior_catalog, old_save).is_empty():
			return {}
		var migrated: Dictionary = old_save.duplicate(true)
		for id: String in new_ids:
			migrated["world"]["parts"][id] = {"phase": "attached", "work": 0}
		if not HMSaveState.validate(catalog, migrated).is_empty():
			return {}
		return migrated
	return {}

func _normalize_numbers(save: Dictionary) -> void:
	# Godot JSON converts numeric tokens to floats; the typed state uses integer
	# counters, units, levels and credits. Rehydrate these after digest verification.
	for key: String in ["revision", "save_schema_version", "data_schema_version"]:
		save[key] = int(save.get(key, -1))
	var econ: Dictionary = save.get("economy", {})
	for key: String in ["credits", "schema_version"]:
		econ[key] = int(econ.get(key, -1))
	for key: Variant in econ.get("sold", {}):
		econ["sold"][key] = int(econ["sold"][key])
	for key: Variant in econ.get("upgrades", {}):
		econ["upgrades"][key] = int(econ["upgrades"][key])
	for key: Variant in econ.get("registered", {}):
		_normalize_allocation(econ["registered"][key])
	for key: Variant in save.get("completed_transactions", {}):
		save["completed_transactions"][key] = int(save["completed_transactions"][key])
	var world: Dictionary = save.get("world", {})
	for key: Variant in world.get("parts", {}):
		world["parts"][key]["work"] = int(world["parts"][key].get("work", -1))
	for key: Variant in world.get("outputs", {}):
		_normalize_allocation(world["outputs"][key])
	var progress: Dictionary = save.get("progress", {})
	progress["act"] = int(progress.get("act", -1))


static func _normalize_allocation(lot: Dictionary) -> void:
	var allocation: Dictionary = lot.get("allocation", {})
	for family: Variant in allocation:
		allocation[family] = int(allocation[family])


func _content_hash() -> String:
	# Freeze authored data across save load; future schema migrations must
	# explicitly convert an old snapshot before changing this contract.
	return JSON.stringify(catalog.tables, "", true).sha256_text()


func _path(extension: String) -> String:
	return ProjectSettings.globalize_path(SAVE_DIRECTORY.path_join(slot + ".hmsave.json" + extension))


static func _slot_safe(id: String) -> bool:
	var pattern := RegEx.new()
	if pattern.compile("^[A-Za-z0-9_-]{1,40}$") != OK:
		return false
	return pattern.search(id) != null
