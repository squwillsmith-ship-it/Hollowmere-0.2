extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("STEP15 FAILED: " + msg)
func _run() -> void:
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog")
	var belt := HMToolbelt.new()
	belt.initialize(cat)
	var session := HMWorkSession.new()
	check(session.initialize(cat, belt), "Session")
	var yard := HMYardService.new()
	yard.initialize(belt, session)
	var id := "fixture/shed/loose_rope"
	for e: Dictionary in [
		{"op":"partial_work","part_id":id,"cycles":1},
		{"op":"release","part_id":id}
	]:
		e["transaction_id"] = "yard/setup/" + String(e["op"])
		e["user_initiated"] = true
		var r: Dictionary = HMTransactions.apply(cat, belt.state, e)
		check(r.get("ok", false), "Work and release setup")
		if r.get("ok", false):
			belt.state = r["state"]
	var info := {"kind":"loose_output", "reachable":true, "output_id":id + "/out/rope"}
	check(yard.lift(info).get("ok", false), "Manual lift")
	check(not yard.unload(Vector3(0,0.96,0)).get("ok", false), "Remote unload blocked")
	check(not yard.register_lot(Vector3(0,0.96,0)).get("ok",false), "Remote registration blocked")
	check(yard.unload(HMYardService.PAD_CENTER).get("ok", false), "Pad unload")
	check(belt.state["economy"]["credits"] == 0, "Unloaded but not sold")
	check(yard.register_lot(HMYardService.PAD_CENTER).get("ok", false), "Register after delivery")
	check(belt.state["economy"]["credits"] == 0, "Registration does not pay")
	check(not yard.register_lot(HMYardService.PAD_CENTER).get("ok", false), "Duplicate registration blocked")
	check(yard.sell_lot(HMYardService.COUNTER_CENTER).get("ok", false), "Manual account sale")
	var paid: int = int(belt.state["economy"]["credits"])
	check(paid > 0, "Credits earned only from manual sale")
	check(not yard.sell_lot(HMYardService.COUNTER_CENTER).get("ok", false), "Cannot double sell")
	check(belt.state["economy"]["credits"] == paid, "No double payment")
	check(HMSaveState.validate(cat, belt.state).is_empty(), "Ledger and save invariant")
	if failures.is_empty():
		print("HOLLOWMERE_STEP15_TEST_OK")
		quit(0)
	else:
		quit(1)
