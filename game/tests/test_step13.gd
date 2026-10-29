extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error("STEP13 FAILED: " + label)
func _run() -> void:
	var catalog := HMCatalog.new()
	check(catalog.load_all(), "Catalog loaded")
	var p := "fixture/shed/roof_patch"
	var intact: Dictionary = HMRules.make_outputs(catalog, p, "intact")[0]
	var damaged: Dictionary = HMRules.make_outputs(catalog, p, "damaged")[0]
	var a: Dictionary = HMLedger.quote(catalog, intact)
	var b: Dictionary = HMLedger.quote(catalog, damaged)
	check(int(a["base"]) == 12 and int(a["estimated_credits"]) == 12, "Timber 4 priced from catalog")
	check(int(b["base"]) == 12 and int(b["estimated_credits"]) == 7, "Binary damaged penalty rounds down")
	check(a["estimated_credits"] > b["estimated_credits"], "Intact material has higher estimate")
	check(bool(a["provisional"]) and bool(b["priced"]), "Rate explicitly provisional")
	var state: Dictionary = HMSaveState.fresh(catalog)
	check(int(state["economy"]["credits"]) == 0, "Estimates do not credit an account")
	check(HMSaveState.validate(catalog, state).is_empty(), "Valuation does not change saved schema")
	if failures.is_empty():
		print("HOLLOWMERE_STEP13_TEST_OK")
		quit(0)
	else:
		quit(1)
