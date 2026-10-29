extends SceneTree
## Run: godot --headless --path game --script res://tests/test_step04.gd
var failures: Array[String] = []
var count: int = 0


func check(value: bool, description: String) -> void:
	count += 1
	if not value:
		failures.append(description)
		push_error("STEP04 TEST FAILED: " + description)


func _initialize() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var c := HMCatalog.new()
	check(c.load_all(), "All version 1 catalogs load")
	if not c.errors.is_empty():
		for err: String in c.errors:
			push_error(err)
		quit(1)
		return
	var errors := HMSchema.validate(c)
	check(errors.is_empty(), "Static schema validates: " + str(errors))
	var tools: Array = ["hands", "claw_hammer"]
	check(HMRules.can_use(c, "fixture/shed/posts", tools), "Tier 2 can complete light shelter")
	check(not HMRules.can_use(c, "fixture/house/beam", tools), "Hammer cannot cut structural frame")
	check(not HMRules.can_use(c, "fixture/harbour/bell", ["hands", "saw"]), "Bell blocked from ordinary work")
	var active: Array = ["fixture/shed/roof_patch", "fixture/shed/upper_rail", "fixture/shed/posts"]
	var warned: Dictionary = HMRules.inspect_release(c, "fixture/shed/posts", active, tools, [])
	check(not warned.get("allowed", false) and warned.get("warning", false), "Loaded support warns before commit")
	var confirmed: Dictionary = HMRules.inspect_release(c, "fixture/shed/posts", active, tools, [], true)
	check(confirmed.get("allowed", false) and confirmed.get("damaged_dependents", []).size() == 2, "Transitive cascade remains locally bounded and explicit")
	var safe: Dictionary = HMRules.inspect_release(c, "fixture/shed/roof_patch", active, tools, [])
	check(safe.get("allowed", false), "Unloaded roof patch is removable")
	var outputs: Array = HMRules.make_outputs(c, "fixture/shed/roof_patch", "intact")
	check(outputs.size() == 2, "Mixed material outputs keep stable child IDs")
	check(HMSchema.same_allocation(c.by_part_id("fixture/shed/roof_patch")["allocation"], HMSchema.sum_outputs(outputs)), "Output material conserved")
	var ledger := HMLedger.fresh()
	var first: Dictionary = outputs[0]
	check(not HMLedger.register_unloaded(c, ledger, first, true), "Staged outside pad pays nothing")
	first["location"] = "receiving_pad"
	check(HMLedger.register_unloaded(c, ledger, first, true), "First player unload registers once")
	check(not HMLedger.register_unloaded(c, ledger, first, true), "Duplicate register forbidden")
	check(HMLedger.sell_registered(c, ledger, String(first["id"])), "Registered salvage sells once")
	var before: int = int(ledger["credits"])
	check(not HMLedger.sell_registered(c, ledger, String(first["id"])) and int(ledger["credits"]) == before, "Duplicate sale adds no credits")
	check(HMLedger.recovered_units(ledger) == 4, "Sale leaves recovered units intact")
	ledger["credits"] = 30
	check(HMLedger.purchase(c, ledger, "pack_straps", tools), "Affordable carry upgrade purchased")
	check(HMLedger.recovered_units(ledger) == 4, "Spending never alters recovery")
	check(not HMLedger.purchase(c, ledger, "saw_teeth", tools), "Not-owned saw cannot be refined")
	var damaged: Dictionary = first.duplicate(true)
	damaged["condition"] = "damaged"
	check(HMLedger.sale_price(c, damaged) < HMLedger.sale_price(c, first), "Damaged changes price not quantity")
	if failures.is_empty():
		print("HOLLOWMERE_STEP04_TESTS_OK count=" + str(count))
		quit(0)
	else:
		print("HOLLOWMERE_STEP04_TESTS_FAIL count=" + str(count) + " errors=" + str(failures))
		quit(1)
