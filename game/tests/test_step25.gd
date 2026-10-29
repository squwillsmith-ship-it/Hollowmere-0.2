extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("test")
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error("STEP25: " + reason)
func test() -> void:
	var packed: PackedScene = load("res://scenes/brinewick_blockout.tscn") as PackedScene
	check(packed != null, "Runnable blockout scene imported")
	if packed == null:
		quit(1)
		return
	var level: HMBrinewickBlockout = packed.instantiate() as HMBrinewickBlockout
	check(level != null, "Brinewick level has authored blockout controller")
	root.add_child(level)
	check(level.site_nodes.size() == 21, "All 21 established site functions indexed without fixed building counts")
	var cat := HMCatalog.new()
	check(cat.load_all(), "Read canonical site catalogue")
	for site: Variant in cat.entries("locations","sites"):
		check(level.site_nodes.has(String(site["id"])), "Every location has provisional marker: " + String(site["id"]))
	check(level.get_node_or_null("Terraces/LowerTerrace") != null, "Lower terrace created")
	check(level.get_node_or_null("Terraces/UpperNorth") != null, "Upper terrace created")
	check(level.get_node_or_null("Terraces/HeadlandNorth") != null, "Headland heights and chapel/mining area created")
	check(level.get_node_or_null("RoadsAndPaths/LowerToUpperRamp") != null, "Connected lower-to-upper cart ramp authored")
	check(level.get_node_or_null("RoadsAndPaths/UpperToHeadlandRamp") != null, "Headland approach ramp authored")
	check(level.get_node_or_null("NonCollidableSeaStudy") != null, "Coastline present")
	# Verify collisions are active for separate road and terrace pieces, not
	# visually convincing but non-walkable boxes.
	await physics_frame
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	for point: Vector3 in [Vector3(1,16,12),Vector3(81,22,0),Vector3(153,24,0)]:
		var result: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 40))
		check(not result.is_empty(), "Walkable physics floor at world " + str(point))
	var baseline: Dictionary = HMSaveState.fresh(cat)
	check(baseline["world"]["outputs"].is_empty(), "World blockout does not create salvage or currency")
	check(HMSaveState.validate(cat, baseline).is_empty(), "Existing save schema unaffected by blockout")
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP25_TEST_OK")
		quit(0)
	else:
		quit(1)
