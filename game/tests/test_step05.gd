extends SceneTree
## Godot 4.7.2 acceptance test; must be run in the exact pinned engine.
## godot --headless --path game --script res://tests/test_step05.gd

var failures: Array[String] = []
var checks: int = 0


func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("STEP05 FAILED: " + label)


func event(id: String, op: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"transaction_id": id, "user_initiated": true, "op": op}
	result.merge(extra)
	return result


func _initialize() -> void:
	call_deferred("run_suite")


func run_suite() -> void:
	var catalog := HMCatalog.new()
	verify(catalog.load_all(), "Step04 catalogs load")
	verify(HMSchema.validate(catalog).is_empty(), "Step04 content schema")
	var state: Dictionary = HMSaveState.fresh(catalog)
	verify(HMSaveState.validate(catalog, state).is_empty(), "Initial state valid")
	var found: Dictionary = HMTransactions.apply(catalog, state, event("find_hammer", "find_tool", {"tool_id": "claw_hammer", "source": "world_discovery"}))
	verify(found.get("ok", false), "Hammer must be manually discovered before Tier 2 work")
	if not found.get("ok", false):
		quit(1)
		return
	state = found["state"]
	var denied: Dictionary = HMTransactions.apply(catalog, state, event("bad1", "release", {"part_id": "fixture/shed/roof_patch"}))
	verify(not denied["ok"], "Unworked item cannot be released")
	var auto: Dictionary = HMTransactions.apply(catalog, state, {"transaction_id": "bad2", "op": "partial_work", "part_id": "fixture/shed/roof_patch", "cycles": 2})
	verify(not auto["ok"], "No passive work transactions")
	var worked: Dictionary = HMTransactions.apply(catalog, state, event("work01", "partial_work", {"part_id": "fixture/shed/roof_patch", "cycles": 2}))
	verify(worked.get("ok", false), "Manual partial work accepted")
	if not worked.get("ok", false):
		quit(1)
		return
	state = worked["state"]
	var released: Dictionary = HMTransactions.apply(catalog, state, event("release01", "release", {"part_id": "fixture/shed/roof_patch"}))
	verify(released.get("ok", false), "Explicit release creates outputs")
	if not released.get("ok", false):
		quit(1)
		return
	state = released["state"]
	verify(state["world"]["parts"]["fixture/shed/roof_patch"]["phase"] == "released" and state["world"]["outputs"].size() == 2, "Parent/output atomic state")
	var repeat: Dictionary = HMTransactions.apply(catalog, state, event("release01", "release", {"part_id": "fixture/shed/roof_patch"}))
	verify(not repeat["ok"], "Transaction ID cannot repeat")
	var child: String = "fixture/shed/roof_patch/out/boards"
	var distant: Dictionary = HMTransactions.apply(catalog, state, event("register_invalid", "register", {"output_id": child}))
	verify(not distant["ok"], "Remote registration refused")
	for transaction: Dictionary in [
		event("pickup01", "pickup", {"output_id": child, "carrier": "carried"}),
		event("unload01", "unload", {"output_id": child, "receiving_pad_confirmed": true}),
		event("register01", "register", {"output_id": child}),
		event("sell01", "sell", {"output_id": child})
	]:
		var result: Dictionary = HMTransactions.apply(catalog, state, transaction)
		verify(result["ok"], "Manual yard action " + String(transaction["op"]))
		if not result["ok"]:
			break
		state = result["state"]
	verify(state["economy"]["registered"].size() == 1 and state["economy"]["sold"].size() == 1, "Sale and delivery counted independently")
	verify(HMLedger.recovered_units(state["economy"]) == 4, "Original recovery units remain after sale")
	verify(not HMTransactions.apply(catalog, state, event("sell_again", "sell", {"output_id": child}))["ok"], "Cannot sell twice")
	verify(HMSaveState.validate(catalog, state).is_empty(), "Live reference state still valid")

	var location: String = "step05_engine_test"
	var manager := HMSaveStore.new()
	# Test isolation: only clean this explicitly reserved test slot.
	for ending: String in ["", ".writing", ".previous"]:
		var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(location + ".hmsave.json" + ending))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	verify(manager.open_slot(catalog, location), "Create empty isolated test slot")
	verify(manager.save_now(), "Write initial durable save")
	verify(manager.commit(event("save_found_hammer", "find_tool", {"tool_id": "claw_hammer", "source": "world_discovery"})), "Tool discovery persisted before Tier 2 work")
	verify(manager.commit(event("save_work01", "partial_work", {"part_id": "fixture/shed/roof_patch", "cycles": 1})), "Commit state only after durable write")
	var expected: Dictionary = manager.snapshot()
	verify(manager.commit(event("save_work02", "partial_work", {"part_id": "fixture/shed/roof_patch", "cycles": 1})), "Rotate prior save before second write")
	var reopened := HMSaveStore.new()
	verify(reopened.open_slot(catalog, location), "Reload primary save")
	verify(int(reopened.state["revision"]) == 3, "Reload preserves revision and partial work")
	var primary: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(location + ".hmsave.json"))
	var corrupt: FileAccess = FileAccess.open(primary, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("this file was deliberately interrupted")
		corrupt.close()
	var recovered := HMSaveStore.new()
	verify(recovered.open_slot(catalog, location) and recovered.recovered_previous, "Corrupt primary falls back to valid previous")
	verify(int(recovered.state.get("revision", -1)) == int(expected["revision"]), "Recovery restores last fully committed snapshot")
	verify(not recovered.commit(event("save_work01", "partial_work", {"part_id": "fixture/shed/roof_patch", "cycles": 1})), "Replayed transaction is rejected after reload")
	verify(recovered.commit(event("save_work03", "partial_work", {"part_id": "fixture/shed/roof_patch", "cycles": 1})), "Recovered slot can resume without discarding backup")
	if failures.is_empty():
		print("HOLLOWMERE_STEP05_TESTS_OK checks=" + str(checks))
		quit(0)
	else:
		print("HOLLOWMERE_STEP05_TESTS_FAIL checks=" + str(checks) + " failures=" + str(failures))
		quit(1)
