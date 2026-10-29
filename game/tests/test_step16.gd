extends SceneTree
var bad: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, name: String) -> void:
	if not ok:
		bad.append(name)
		push_error("STEP16 FAILED: " + name)
func event(name: String, op: String, extra: Dictionary) -> Dictionary:
	var e := {"transaction_id":name,"op":op,"user_initiated":true}
	e.merge(extra)
	return e
func _run() -> void:
	var c := HMCatalog.new()
	check(c.load_all(), "Catalog loads")
	var s := HMSaveState.fresh(c)
	var pid: String = "fixture/shed/roof_patch"
	var hammer := HMTransactions.apply(c,s,event("tool","find_tool",{"tool_id":"claw_hammer","source":"world_discovery"}))
	check(hammer.get("ok",false), "Discovery manual")
	if hammer.get("ok", false):
		s = hammer["state"]
	var work := HMTransactions.apply(c,s,event("work","partial_work",{"part_id":pid,"cycles":2}))
	check(work.get("ok",false), "Work manual")
	if work.get("ok", false):
		s = work["state"]
	var release := HMTransactions.apply(c,s,event("release","release",{"part_id":pid}))
	check(release.get("ok",false), "Release")
	if release.get("ok", false):
		s = release["state"]
	for suffix: String in ["boards","fasteners"]:
		var oid: String = pid + "/out/" + suffix
		for op: String in ["pickup","unload","register","sell"]:
			var extra: Dictionary = {"output_id":oid}
			if op == "pickup": extra["carrier"] = "carried"
			if op == "unload": extra["receiving_pad_confirmed"] = true
			var r: Dictionary = HMTransactions.apply(c,s,event(suffix+op,op,extra))
			check(r.get("ok",false), "Manual sequence " + suffix + op)
			if r.get("ok",false): s = r["state"]
	var initial: int = int(s["economy"]["credits"])
	check(initial >= 12, "Enough genuine delivered sales for fixture upgrade")
	var bought := HMTransactions.apply(c,s,event("buy1","purchase",{"upgrade_id":"pack_straps"}))
	check(bought.get("ok",false), "Straps purchased from sold credits")
	if bought.get("ok",false): s = bought["state"]
	check(int(s["economy"]["credits"]) == initial - 12, "Debited exactly once")
	check(HMSalvageLogistics.capacity(s["economy"]) == 7, "Carrying capacity improves")
	check(s["progress"]["tools"] == ["hands","claw_hammer"], "Upgrade cannot grant a higher tier")
	check(not HMTransactions.apply(c,s,event("buy-unknown","purchase",{"upgrade_id":"missing"})).get("ok",false), "Forged item refused")
	check(HMUpgradeEffects.work_interval(c,s["economy"],"claw_hammer") == 0.42, "No free hammer upgrade")
	check(HMSaveState.validate(c,s).is_empty(), "Saved credits reconcile purchases")
	if bad.is_empty():
		print("HOLLOWMERE_STEP16_TEST_OK")
		quit(0)
	else:
		quit(1)
