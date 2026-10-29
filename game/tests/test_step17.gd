extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func ck(x: bool, name: String) -> void:
	if not x:
		errors.append(name)
		push_error("STEP17 FAILED: " + name)
func event(tx: String, operation: String, extra: Dictionary) -> Dictionary:
	var d := {"transaction_id":tx,"op":operation,"user_initiated":true}
	d.merge(extra)
	return d
func _run() -> void:
	var cat := HMCatalog.new()
	ck(cat.load_all(),"Catalog loads")
	var s: Dictionary = HMSaveState.fresh(cat)
	var pid: String = "fixture/shed/loose_rope"
	for action: Dictionary in [event("17-work","partial_work",{"part_id":pid,"cycles":1}),
			event("17-release","release",{"part_id":pid}),
			event("17-lift","pickup",{"output_id":pid+"/out/rope","carrier":"carried"}),
			event("17-place","place",{"output_id":pid+"/out/rope","position":[6.4,0.3,8.0]})]:
		var r: Dictionary = HMTransactions.apply(cat,s,action)
		ck(r.get("ok",false),"Manual prerequisite "+String(action["op"]))
		if r.get("ok",false): s = r["state"]
	var oid: String = pid+"/out/rope"
	var original: Dictionary = s["world"]["outputs"][oid].duplicate(true)
	ck(not HMTransactions.apply(cat,s,event("no-bench","process",{"output_id":oid})).get("ok",false), "Remote process refused")
	var done := HMTransactions.apply(cat,s,event("17-process","process",{"output_id":oid,"bench_confirmed":true}))
	ck(done.get("ok",false),"Manual sort accepted once")
	if done.get("ok",false): s = done["state"]
	ck(bool(s["world"]["outputs"][oid]["processed"]), "Immutable marker set")
	ck(s["world"]["outputs"][oid]["allocation"] == original["allocation"],"No duplication or material modification")
	ck(s["world"]["outputs"][oid]["condition"] == original["condition"], "Condition remains binary")
	ck(not HMTransactions.apply(cat,s,event("17-repeat","process",{"output_id":oid,"bench_confirmed":true})).get("ok",false), "Second processing refused")
	ck(HMLedger.sale_price(cat,s["world"]["outputs"][oid]) > HMLedger.sale_price(cat,original),"One-time optional sorting premium")
	for op: String in ["pickup","unload","register","sell"]:
		var options: Dictionary = {"output_id":oid}
		if op == "pickup":options["carrier"]="carried"
		if op == "unload":options["receiving_pad_confirmed"]=true
		var res := HMTransactions.apply(cat,s,event("17/"+op,op,options))
		ck(res.get("ok",false),"After processing "+op)
		if res.get("ok",false):s=res["state"]
	ck(HMSaveState.validate(cat,s).is_empty(),"Sale receipt reconciles processed premium")
	ck(s["economy"]["registered"][oid]["processed"],"Registered snapshot persists processing")
	# Repeat the actual sequence through staged filesystem writes and reopen.
	var slot: String = "step17_sale_" + str(Time.get_ticks_usec())
	var persisted := HMSaveStore.new()
	ck(persisted.open_slot(cat, slot), "Independent durable slot starts")
	for action: Dictionary in [
		event("save17-work","partial_work",{"part_id":pid,"cycles":1}),
		event("save17-release","release",{"part_id":pid}),
		event("save17-pick","pickup",{"output_id":oid,"carrier":"carried"}),
		event("save17-stage","place",{"output_id":oid,"position":[6.4,0.3,8.0]}),
		event("save17-sort","process",{"output_id":oid,"bench_confirmed":true}),
		event("save17-carry","pickup",{"output_id":oid,"carrier":"carried"}),
		event("save17-pad","unload",{"output_id":oid,"receiving_pad_confirmed":true,
			"position":[8.0,0.3,8.0]}),
		event("save17-register","register",{"output_id":oid}),
		event("save17-sell","sell",{"output_id":oid})
	]:
		ck(persisted.commit(action), "Durable manual action " + String(action["op"]))
	var reopened := HMSaveStore.new()
	ck(reopened.open_slot(cat, slot), "Processed sale file cold-reopens")
	var saved: Dictionary = reopened.snapshot()
	ck(bool(saved["economy"]["registered"][oid]["processed"]), "Registered sort retained after reload")
	ck(int(saved["economy"]["credits"]) == 3, "Saved processed fibre sale paid once")
	ck(saved["world"]["outputs"][oid]["location"] == "sold", "No loose sold output reappears")
	ck(HMSaveState.validate(cat,saved).is_empty(), "Rehydrated economy/source invariants")
	var path: String = ProjectSettings.globalize_path(
		HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json"))
	for ext: String in ["", ".previous", ".writing"]:
		if FileAccess.file_exists(path + ext):
			DirAccess.remove_absolute(path + ext)
	if errors.is_empty():
		print("HOLLOWMERE_STEP17_TEST_OK")
		quit(0)
	else:
		quit(1)
