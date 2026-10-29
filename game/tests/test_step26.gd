extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func require(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("STEP26: " + msg)
func run() -> void:
	var scene: PackedScene = load("res://scenes/brinewick_blockout.tscn") as PackedScene
	var level: HMBrinewickBlockout = scene.instantiate() as HMBrinewickBlockout
	root.add_child(level)
	var sites: HMBrinewickSites = level.district_sites
	require(sites != null, "District builder installed")
	if sites == null:
		quit(1)
		return
	require(sites.stage_counts.get(26,0) == 2, "Landing and base independent placed structures")
	require(sites.installation_nodes.has("service/landing_pier"), "Quay landing exists")
	require(sites.installation_nodes.has("service/boatyard_base"), "Boatyard installed")
	var yard := HMYardService.new()
	require(yard.configure_stations(sites.get_yard_station_positions()), "Real yard service accepts relocated village stations")
	var pos: Dictionary = sites.get_yard_station_positions()
	require(yard.pad_center != HMYardService.PAD_CENTER, "Village and legacy yard separated")
	require(not yard.configure_stations({"pad":Vector3.ZERO}), "Incomplete service config denied")
	var cat := HMCatalog.new()
	require(cat.load_all(), "Canonical catalogue survives construction")
	var state: Dictionary = HMSaveState.fresh(cat)
	require(state["world"]["outputs"].size() == 0, "World construction produces no passive salvage")
	require(HMSaveState.validate(cat,state).is_empty(), "Save schema unchanged")
	await physics_frame
	var physics: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var test_ray: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(
		pos["pad"] + Vector3.UP*5, pos["pad"] + Vector3.DOWN*4))
	require(not test_ray.is_empty(), "Boatyard receives physical pad collision")
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP26_TEST_OK")
		quit(0)
	else:
		quit(1)
