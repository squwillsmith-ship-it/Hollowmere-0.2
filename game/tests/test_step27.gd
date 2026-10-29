extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error("STEP27: " + reason)
func run() -> void:
	var packed: PackedScene = load("res://scenes/brinewick_blockout.tscn") as PackedScene
	var level: HMBrinewickBlockout = packed.instantiate() as HMBrinewickBlockout
	root.add_child(level)
	var group: HMBrinewickSites = level.district_sites
	check(group.stage_counts.get(26,0) == 2, "Step26 base retained")
	check(group.stage_counts.get(27,0) == 5, "Five Step27 working groups installed")
	check(group.cottage != null, "Existing nine-part cottage reused in village")
	var cat := HMCatalog.new()
	check(cat.load_all(), "Saved catalogue unchanged")
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	check(HMBuildingPrefab.validate(manifest,cat).is_empty(), "Original proven cottage unchanged")
	var ids: Dictionary = {}
	for child: Node in group.cottage.get_children():
		var part: HMInspectTarget = child as HMInspectTarget
		if part != null:
			check(not ids.has(part.part_id), "No duplicate physical cottage IDs")
			ids[part.part_id] = true
	check(ids.size() == 9, "All nine existing cottage targets physically present")
	check(group.cottage.position == level.site_nodes["brinewick/site_07"].position,
		"Cottage placed within provisional lower-terrace function")
	var state: Dictionary = HMSaveState.fresh(cat)
	var first: String = "fixture/house/curtain"
	var step: Dictionary = HMTransactions.apply(cat,state,{"op":"partial_work",
		"part_id":first,"cycles":1,"user_initiated":true,"transaction_id":"27/work/curtain"})
	check(bool(step.get("ok",false)), "Manual transaction works with existing cottage ID")
	if bool(step.get("ok",false)):
		state=step["state"]
		var released: Dictionary = HMTransactions.apply(cat,state,{"op":"release",
			"part_id":first,"access_aids":[],"spawn_origin":[35.0,2.4,24.0],
			"user_initiated":true,"transaction_id":"27/release/curtain"})
		check(bool(released.get("ok",false)), "Catalogue-backed cottage part releases one conserved physical lot")
		if bool(released.get("ok",false)):
			check(HMSaveState.validate(cat,released["state"]).is_empty(), "Village stage part keeps save invariant")
	var others: Array[String] = ["district/old_warehouse", "district/expanded_warehouse",
		"district/mara_home", "district/upper_cottage_cluster_study"]
	for id: String in others:
		check(group.installation_nodes.has(id), "Physical scene massing: "+id)
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP27_TEST_OK")
		quit(0)
	else:
		quit(1)
