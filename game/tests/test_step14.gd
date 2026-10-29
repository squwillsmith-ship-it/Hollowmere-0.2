extends SceneTree
var bad: Array[String] = []
func _initialize() -> void:
	call_deferred("_go")
func check(yes: bool, why: String) -> void:
	if not yes:
		bad.append(why)
		push_error("STEP14 FAILED: " + why)
func _evt(code: String, op: String, extras: Dictionary) -> Dictionary:
	var e := {"transaction_id": code, "op": op, "user_initiated": true}
	e.merge(extras)
	return e
func _go() -> void:
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog loads")
	var state := HMSaveState.fresh(cat)
	var pid := "fixture/shed/loose_rope"
	var work := HMTransactions.apply(cat, state, _evt("14-work", "partial_work", {"part_id": pid, "cycles": 1}))
	check(work.get("ok", false), "Explicit manual work")
	if work.get("ok", false):
		state = work["state"]
	var release := HMTransactions.apply(cat, state, _evt("14-release", "release", {"part_id": pid}))
	check(release.get("ok", false), "Manual component release")
	if release.get("ok", false):
		state = release["state"]
	var oid: String = pid + "/out/rope"
	check(HMSalvageLogistics.can_lift(state["world"], state["economy"], oid), "Small scrap fits pack")
	var lift := HMTransactions.apply(cat, state, _evt("14-pick", "pickup", {"output_id": oid, "carrier": "carried"}))
	check(lift.get("ok", false), "Explicit pickup accepted")
	if lift.get("ok", false):
		state = lift["state"]
	check(not HMSalvageLogistics.can_lift(state["world"], state["economy"], oid), "Occupied pack blocks duplicate pickup")
	var place := HMTransactions.apply(cat, state, _evt("14-place", "place", {"output_id":oid, "position":[3.0,0.3,3.0]}))
	check(place.get("ok", false), "Manual stage")
	if place.get("ok", false):
		state = place["state"]
	check(state["world"]["outputs"][oid]["location"] == "staged", "Staged is not delivered")
	check(state["economy"]["credits"] == 0, "No passive credits")
	check(HMSaveState.validate(cat, state).is_empty(), "State remains valid")
	if bad.is_empty():
		print("HOLLOWMERE_STEP14_TEST_OK")
		quit(0)
	else:
		quit(1)
