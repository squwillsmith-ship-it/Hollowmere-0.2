extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok:
		errors.append(why)
		push_error("STEP29: " + why)
func run() -> void:
	var level: HMBrinewickBlockout = (load("res://scenes/brinewick_blockout.tscn") as PackedScene).instantiate() as HMBrinewickBlockout
	root.add_child(level)
	var sites: HMBrinewickSites = level.district_sites
	check(sites.stage_counts.get(29,0) == 3, "Three harbour working groups placed")
	for id: String in ["harbour/office","harbour/net_store","harbour/navigation_light"]:
		var group: Node3D = sites.installation_nodes.get(id)
		check(group != null, "Physical harbour construction: " + id)
		if group != null:
			check(group.get_child_count() > 3, "Individually assembled geometry: " + id)
	var light: Node3D = sites.installation_nodes.get("harbour/navigation_light")
	check(light != null and light.get_node_or_null("PracticalHarbourNavigationLamp") is OmniLight3D,
		"Navigation light distinct from protected harbour bell mechanism")
	var cat := HMCatalog.new()
	check(cat.load_all(), "Original catalogue loaded")
	var state: Dictionary = HMSaveState.fresh(cat)
	check(HMSaveState.validate(cat,state).is_empty(), "No passive salvage state changes")
	check(cat.by_part_id("fixture/harbour/bell").get("protected",false), "Bell remains protected")
	level.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_STEP29_TEST_OK")
		quit(0)
	else:
		quit(1)
