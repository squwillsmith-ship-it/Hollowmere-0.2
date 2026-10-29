extends SceneTree
## Step44 transaction-level regression + full-catalogue conservation/budget gate.
## Does not certify renderer, player paths, licensed assets or final prices.
var failures: Array[String] = []
var cat: HMCatalog
var state: Dictionary
var serial: int = 0

func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error("STEP44: " + reason)

func action(event: Dictionary, expect_success: bool = true) -> bool:
	serial += 1
	event["transaction_id"] = "step44_explicit_" + str(serial)
	event["user_initiated"] = true
	var previous: Dictionary = state.duplicate(true)
	var result: Dictionary = HMTransactions.apply(cat, state, event)
	var ok: bool = bool(result.get("ok", false))
	check(ok == expect_success,
		String(event.get("op", "")) + " " + String(event.get("part_id", "")) +
		" expected=" + str(expect_success) + " reason=" + String(result.get("reason", "")))
	if ok:
		state = result["state"]
		check(HMSaveState.validate(cat, state).is_empty(), "Transaction conserves live snapshot")
	else:
		check(state == previous, "Refused transaction cannot mutate saved state")
	return ok

func recover(part_id: String) -> void:
	var part: Dictionary = cat.by_part_id(part_id)
	check(not part.is_empty(), "Original stable definition " + part_id)
	if part.is_empty():
		return
	check(not action({"op": "release", "part_id": part_id}, false),
		"Unworked salvage cannot be detached")
	action({"op": "partial_work", "part_id": part_id, "cycles": int(part["work_units"])})
	if not action({"op": "release", "part_id": part_id, "access_aids": [],
			"spawn_origin": [1.0, 0.4, 2.0]}):
		return
	for raw: Variant in HMRules.make_outputs(cat, part_id, "intact"):
		var oid: String = String(raw["id"])
		var lot: Dictionary = state["world"]["outputs"][oid]
		check(HMSchema.same_allocation(lot["allocation"], raw["allocation"]),
			"Every released child exactly conserves authored material " + oid)
		check(not bool(lot.get("registered", false)),
			"Release does not automatically register goods")
		check(HMLedger.quote(cat, lot)["estimated_credits"] >= 0,
			"Manual salvage has a nonnegative price quote")
		check(action({"op": "pickup", "output_id": oid, "carrier": "carried"}),
			"Explicit lift is available")
		check(action({"op": "unload", "output_id": oid, "receiving_pad_confirmed": true}),
			"Explicit unload at receiving pad")
		check(action({"op": "register", "output_id": oid}), "Manual yard registration")
		var before: int = int(state["economy"]["credits"])
		var expected: int = HMLedger.sale_price(cat, state["economy"]["registered"][oid])
		check(action({"op": "sell", "output_id": oid}), "One manual sale")
		check(int(state["economy"]["credits"]) == before + expected, "Exactly one quoted payout")
		check(not action({"op": "sell", "output_id": oid}, false),
			"Duplicate sale produces no extra credit")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	cat = HMCatalog.new()
	check(cat.load_all(), "Canonical 351-part catalogue loads")
	if not cat.errors.is_empty():
		quit(1)
		return
	check(HMSchema.validate(cat).is_empty(), "Complete production data validates")
	var parts: Array = cat.entries("sample_parts", "parts")
	check(parts.size() == 351, "Historical 297 plus 54 persistent landmark definitions")
	var valid_ids: Dictionary = {}
	var total: Dictionary = {}
	var largest_lot: int = 0
	var protected_parts: int = 0
	for entry: Variant in parts:
		var part: Dictionary = entry
		var pid: String = String(part["id"])
		check(not valid_ids.has(pid), "Stable part IDs are unique")
		valid_ids[pid] = true
		if bool(part.get("protected", false)):
			protected_parts += 1
			continue
		var rebuilt: Dictionary = HMSchema.sum_outputs(part["outputs"])
		check(HMSchema.same_allocation(part["allocation"], rebuilt),
			"No duplicated/lost salvage material " + pid)
		for material: Variant in rebuilt:
			total[material] = int(total.get(material, 0)) + int(rebuilt[material])
		for output: Variant in part["outputs"]:
			var mass: int = HMSalvageLogistics.units({"allocation": output["allocation"]})
			largest_lot = maxi(largest_lot, mass)
	check(protected_parts == 2, "Only two catalogue parts are unbreakable story fixtures")
	check(largest_lot == 8, "Largest physical output fits two existing pack upgrades")
	check(HMSchema.same_allocation(total,
		{"timber": 765, "stone": 326, "mineral_fill": 207, "fibres": 10, "iron": 3}),
		"Exact physical material units and family coverage remain conserved")
	state = HMSaveState.fresh(cat)
	check(not action({"op": "advance_act"}, false),
		"Cannot skip Act I requisition")
	check(not action({"op": "discover", "flag_id": "aldren_remains_found"}, false),
		"Act III evidence inaccessible in Act I")
	check(not bool(HMRules.can_use(cat, "fixture/house/beam", state["progress"]["tools"])),
		"Initial hands cannot saw a high-tier timber beam")
	recover("fixture/shed/loose_rope")
	recover("fixture/house/curtain")
	check(not HMRules.requisition_met(cat, "req_act_02", state["economy"],
		state["progress"]["tools"], []), "Act II cannot be skipped via Act I scrap")
	check(action({"op": "requisition", "requisition_id": "req_act_01"}),
		"Manual first requisition uses authentic stored material")
	check(action({"op": "advance_act"}), "Act II requires previously submitted requisition")
	check(action({"op": "find_tool", "tool_id": "claw_hammer",
		"source": "world_discovery"}), "Hammer discovered, not purchased")
	check(not action({"op": "purchase", "upgrade_id": "saw_teeth"}, false),
		"Upgrade cannot grant an undiscovered saw tier")
	recover("fixture/shed/roof_patch")
	recover("fixture/house/shutters")
	check(action({"op": "encounter", "flag_id": "bell_first_strike"}),
		"One-time auditory evidence discovered by manual action")
	check(action({"op": "requisition", "requisition_id": "req_act_02"}),
		"Second requisition uses at least two physical recovery sites")
	var prev_credits: int = int(state["economy"]["credits"])
	check(action({"op": "purchase", "upgrade_id": "pack_straps"}),
		"Earned credits buy a real capacity upgrade")
	check(int(state["economy"]["credits"]) == prev_credits - 12,
		"First engineering pack price deducted once")
	check(not state["progress"]["tools"].has("saw"),
		"Pack upgrade cannot silently skip the saw tier")
	check(not action({"op": "purchase", "upgrade_id": "saw_teeth"}, false),
		"Undiscovered tier enhancement remains forbidden after a purchase")
	var active: Array = ["fixture/house/beam"]
	var all_tools: Array = ["hands", "claw_hammer", "crowbar", "pickaxe", "saw"]
	check(not HMRules.inspect_release(cat, "fixture/house/beam", active, all_tools,
		[]).get("allowed", false), "Cottage beam requires deliberate sling rigging")
	check(bool(HMRules.inspect_release(cat, "fixture/house/beam", active, all_tools,
		["sling"]).get("allowed", false)), "Manual sling enables safe beam after saw discovery")
	var intact: Dictionary = HMRules.make_outputs(cat, "fixture/house/beam", "intact")[0]
	var damaged: Dictionary = HMRules.make_outputs(cat, "fixture/house/beam", "damaged")[0]
	check(HMSchema.same_allocation(intact["allocation"], damaged["allocation"]),
		"Structural damage never changes recovery quantity")
	check(HMLedger.sale_price(cat, damaged) < HMLedger.sale_price(cat, intact),
		"Damage applies only the binary sale-value penalty")
	check(HMSaveState.validate(cat, state).is_empty(), "Final saved campaign snapshot valid")
	if failures.is_empty():
		print("HOLLOWMERE_STEP44_TEST_OK")
		quit(0)
	else:
		quit(1)
