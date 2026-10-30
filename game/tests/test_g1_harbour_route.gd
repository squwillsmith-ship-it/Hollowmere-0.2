extends SceneTree
## G1 physical route and terrain regression. Run using Godot 4.7.2.
## This does not constitute owner aesthetic acceptance or a human walk.
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("G1_HARBOUR: " + label)

func _run() -> void:
	var village := HMBrinewickBlockout.new()
	village.spawn_exploration_player = false
	root.add_child(village)
	for i: int in range(6):
		await physics_frame
	_require(village.site_nodes.size() == 21,"All canonical site markers preserved")
	_require(village.district_sites.cottage != null,"Original cottage prefab remains installed")
	_require(village.campaign_sites != null,"Story evidence remains installed")
	var shore: StaticBody3D = village.get_node_or_null("Terraces/LowerTerrace") as StaticBody3D
	_require(shore != null,"Sculpted lower terrace exists")
	if shore != null:
		var shape: CollisionShape3D = shore.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_require(shape != null and shape.shape is ConcavePolygonShape3D,
			"Lower coast has real continuous terrain collision, not old BoxShape3D")
		var skin: MeshInstance3D = shore.get_node_or_null("ContinuousCoastalLandform") as MeshInstance3D
		_require(skin != null and skin.mesh is ArrayMesh,"Lower terrace is authored mesh")
	for name: String in ["UpperNorthTransition","UpperSouthTransition"]:
		var bluff: StaticBody3D = village.get_node_or_null("Terraces/" + name) as StaticBody3D
		_require(bluff != null,"Graded upper-level transition: "+name)
		if bluff != null:
			var collision: CollisionShape3D = bluff.get_node_or_null("CollisionShape3D") as CollisionShape3D
			_require(collision != null and collision.shape is ConcavePolygonShape3D,
				"Transition collision is actual faceted slope: "+name)
	var haul: StaticBody3D = village.get_node_or_null("HarbourG1Route/G1HaulPath") as StaticBody3D
	_require(haul != null,"Actual physical route beside older road network")
	_require(village.get_node_or_null("HarbourG1Route/QuayDryStoneRevetment") is MeshInstance3D,
		"Quay edge has deliberate stone facing and an open pier slot")
	_require(village.get_node_or_null("RoadsAndPaths/QuayWalk") != null,
		"Original quay boardwalk retains permanent collision")
	_require(village.get_node_or_null("RoadsAndPaths/LowerToUpperRamp") != null,
		"Existing multi-terrace cart ramp retained")
	if haul == null:
		village.queue_free()
		quit(1)
		return
	var route_shape: CollisionShape3D = haul.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_require(route_shape != null and route_shape.shape is ConcavePolygonShape3D,
		"Haul route has its own simplified physics surface")
	var points: PackedVector2Array = HMHarbourTerrainG1.route_points()
	_require(points.size() >= 8,"Continuous route has meaningful turning stations")
	var space: PhysicsDirectSpaceState3D = village.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	var last_y: float = -999.0
	for i: int in range(points.size()-1):
		for j: int in range(5):
			var t: float = float(j)/4.0
			var at: Vector2 = points[i].lerp(points[i+1],t)
			var y: float = lerpf(HMHarbourTerrainG1.route_height(points[i]),
				HMHarbourTerrainG1.route_height(points[i+1]),t)
			var start := Vector3(at.x,y+0.8,at.y)
			var finish := Vector3(at.x,y-0.4,at.y)
			var hit: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(start,finish,1))
			_require(not hit.is_empty(),"Route supported at "+str(at))
			if not hit.is_empty():
				_require(hit.get("collider") == haul,
					"First foot collider is authored route at "+str(at))
				var ground: float = (hit["position"] as Vector3).y
				_require(absf(ground-y) < 0.11,"No floating walk surface at "+str(at))
				if last_y > -900.0:
					_require(absf(ground-last_y) < 0.7,"No sudden route drop "+str(at))
				last_y = ground
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 1
				query.transform = Transform3D(Basis(),Vector3(at.x,ground+0.99,at.y))
				var occupants: Array[Dictionary] = space.intersect_shape(query,16)
				_require(occupants.is_empty(),
					"Unobstructed 1.75m player stance at "+str(at)+" hits="+str(occupants.size()))
	# Sample actual coastal collider at tidal bank, level district and both
	# graded transition zones. No invisible old lower terrace box is allowed.
	for sample: Vector3 in [Vector3(-47,-0.85,-18),Vector3(-24,2.0,5),
		Vector3(41,2.0,42),Vector3(51,2.2,-38),
		Vector3(56,4.9,38),Vector3(69,8.0,-30)]:
		var from: Vector3 = Vector3(sample.x,sample.y+2.4,sample.z)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			from,Vector3(sample.x,sample.y-2.2,sample.z),1))
		_require(not hit.is_empty(),"Landform physics ray at "+str(sample))
		if not hit.is_empty():
			var foot: float = (hit["position"] as Vector3).y
			_require(absf(foot-sample.y) < 0.55,"Terrain grade near specified elevation "+str(sample))
	village.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_G1_HARBOUR_ROUTE_OK stations="+str(points.size()))
		quit(0)
	else:
		quit(1)
