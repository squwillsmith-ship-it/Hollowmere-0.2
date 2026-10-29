extends SceneTree
## Step45 preflight: actual disk-backed failure/recovery paths, not a human
## campaign or Windows acceptance test. Uses disposable namespaced slots ONLY.
const SLOT: String = "step45_disposable_recovery"
const STAGE_SLOT: String = "step45_disposable_staged"
const TAMPER_SLOT: String = "step45_disposable_tamper"
var failures: Array[String] = []
var catalog: HMCatalog

func _initialize() -> void:
	call_deferred("run")

func check(good: bool, note: String) -> void:
	if not good:
		failures.append(note)
		push_error("STEP45 SAVE RECOVERY: " + note)

func event(id: String, op: String, more: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"transaction_id": id, "op": op, "user_initiated": true}
	result.merge(more)
	return result

func path(slot_name: String, suffix: String = "") -> String:
	return ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(
		slot_name + ".hmsave.json" + suffix))

func cleanup() -> void:
	for name: String in [SLOT, STAGE_SLOT, TAMPER_SLOT]:
		for suffix: String in ["", ".previous", ".writing"]:
			var file: String = path(name, suffix)
			if FileAccess.file_exists(file):
				check(DirAccess.remove_absolute(file) == OK, "Remove disposable fixture " + file)

func write_text(destination: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func run() -> void:
	catalog = HMCatalog.new()
	check(catalog.load_all(), "Canonical content loads")
	if not catalog.errors.is_empty():
		quit(1)
		return
	cleanup()
	var forbidden := HMSaveStore.new()
	check(not forbidden.open_slot(catalog, "../real_save"), "Path traversal is rejected")
	check(not forbidden.open_slot(catalog, ""), "Empty save slot rejected")
	var writer := HMSaveStore.new()
	check(writer.open_slot(catalog, SLOT), "Disposable slot opens clean")
	check(writer.commit(event("45-find-hammer", "find_tool",
		{"tool_id": "claw_hammer", "source": "world_discovery"})),
		"Player-discovered tool is committed")
	var part_id: String = "fixture/house/shutters"
	check(writer.commit(event("45-work-1", "partial_work",
		{"part_id": part_id, "cycles": 1})), "First manual work cycle committed")
	var revision: int = int(writer.state["revision"])
	var before_denial: Dictionary = writer.snapshot()
	check(not writer.commit(event("45-work-1", "partial_work",
		{"part_id": part_id, "cycles": 1})), "Replay of transaction ID is refused")
	check(writer.snapshot() == before_denial, "Refused replay does not change memory")
	var passive: Dictionary = event("45-auto", "partial_work",
		{"part_id": part_id, "cycles": 1})
	passive["user_initiated"] = false
	check(not writer.commit(passive), "Automatic harvest cannot persist")
	check(writer.snapshot() == before_denial, "Refused passive operation does not change memory")
	check(writer.save_now(), "Explicit first checkpoint safely written")
	var cold := HMSaveStore.new()
	check(cold.open_slot(catalog, SLOT), "First checkpoint cold-opens")
	check(int(cold.state.get("revision", -1)) == revision,
		"Cold restart retains exact transaction count")
	check(cold.state["world"]["parts"][part_id]["work"] == 1,
		"Cold restart retains partial work")
	check(cold.commit(event("45-work-2", "partial_work",
		{"part_id": part_id, "cycles": 1})), "Second cycle creates newer primary")
	var latest_revision: int = int(cold.state["revision"])
	check(FileAccess.file_exists(path(SLOT, ".previous")), "Good previous save retained")
	check(write_text(path(SLOT), "{ truncated power-loss JSON"),
		"Simulate torn primary save")
	var recovered := HMSaveStore.new()
	check(recovered.open_slot(catalog, SLOT), "Corrupt primary loads valid previous")
	check(recovered.recovered_previous, "Recovery is explicitly flagged to player/UI")
	check(int(recovered.state["revision"]) == revision and latest_revision > revision,
		"Recovery restores the last valid backup, not corrupt latest progress")
	check(recovered.state["world"]["parts"][part_id]["work"] == 1,
		"Recovered manual work remains exact")
	check(recovered.save_now(), "Recovered checkpoint can safely replace corrupt primary")
	var post_recovery := HMSaveStore.new()
	check(post_recovery.open_slot(catalog, SLOT) and not post_recovery.recovered_previous,
		"New primary reopens without fallback")
	check(HMSaveState.validate(catalog, post_recovery.state).is_empty(),
		"Recovered state still obeys salvage, story and economy invariants")
	# A valid staged file must not override a committed primary. Only .hmsave
	# and .previous are recovery sources; .writing represents an uncommitted transaction.
	var staged := HMSaveStore.new()
	check(staged.open_slot(catalog, STAGE_SLOT), "Staging fixture opens")
	check(staged.commit(event("45-staged-only", "find_tool",
		{"tool_id": "claw_hammer", "source": "world_discovery"})),
		"Staging fixture writes committed primary")
	var committed: Dictionary = staged.snapshot()
	check(write_text(path(STAGE_SLOT, ".writing"), "{uncommitted-and-invalid"),
		"Simulate interrupted temporary write")
	var stage_reader := HMSaveStore.new()
	check(stage_reader.open_slot(catalog, STAGE_SLOT), "Interrupted temp does not block good primary")
	check(stage_reader.state == committed, "Uncommitted .writing file cannot override saved progress")
	# Signed envelope tampering must be rejected even when payload is valid JSON.
	var tamper := HMSaveStore.new()
	check(tamper.open_slot(catalog, TAMPER_SLOT), "Tamper fixture opens")
	check(tamper.commit(event("45-tamper-tool", "find_tool",
		{"tool_id": "claw_hammer", "source": "world_discovery"})),
		"Tamper fixture writes known good primary")
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(TAMPER_SLOT)))
	if stored is Dictionary:
		stored["payload_sha256"] = "invalid_payload_digest"
		check(write_text(path(TAMPER_SLOT), JSON.stringify(stored)), "Corrupt signed payload digest")
	else:
		check(false, "Known-good save envelope parses")
	var invalid := HMSaveStore.new()
	check(not invalid.open_slot(catalog, TAMPER_SLOT),
		"Tampered primary with no valid backup refuses silent reset")
	check(invalid.state.is_empty(), "No fresh state is fabricated after corrupt lone save")
	# Destroy both known save copies and verify no missing-progress reset.
	check(write_text(path(SLOT), "bad-primary"), "Damage primary")
	check(write_text(path(SLOT, ".previous"), "bad-backup"), "Damage previous")
	var no_recovery := HMSaveStore.new()
	check(not no_recovery.open_slot(catalog, SLOT),
		"Double corruption must fail rather than overwrite a previous playthrough")
	check(no_recovery.state.is_empty(), "Double corruption never masquerades as a new game")
	cleanup()
	if failures.is_empty():
		print("HOLLOWMERE_STEP45_RECOVERY_OK")
		quit(0)
	else:
		quit(1)