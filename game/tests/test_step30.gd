extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("STEP30: " + message)
func run() -> void:
	var packed: PackedScene = load("res://scenes/brinewick_blockout.tscn") as PackedScene
	var level: HMBrinewickBlockout = packed.instantiate() as HMBrinewickBlockout
	root.add_child(level)
	var sites: HMBrinewickSites = level.district_sites
	check(sites.stage_counts.get(30,0) == 3, "Chapel, schoolroom and study groups present")
	for id: String in ["chapel/ordinary_hall","chapel/schoolroom_wing","chapel/aldren_study"]:
		var group: Node3D = sites.installation_nodes.get(id)
		check(group != null, "Protected story site geometry: "+id)
		if group != null:
			check(bool(group.get_meta("protected_story",false)), "Protected scene tagged: "+id)
			check(not bool(group.get_meta("ordinary_salvage",true)), "Story furnishing not sold as ordinary salvage")
			check(group.get_child_count() >= 8, "Distinct assembled meshes: "+id)
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog persists without editing approved story and part definitions")
	var state: Dictionary = HMSaveState.fresh(cat)
	check(HMSaveState.validate(cat,state).is_empty(), "No story flag/sale effects from entering chapel")
	check(state["world"]["outputs"].is_empty(), "Protected story scenery cannot spawn recoverable lots passively")
	check(sites.installation_nodes.size() == 15, "Cumulative structures from Steps26-30 maintained")
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP30_TEST_OK")
		quit(0)
	else:
		quit(1)
