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
	for name: String in ["UpperCartRampEarthworks","LowerNorthShore","LowerSouthShore",
		"UpperNorthScarp","UpperSouthScarp"]:
		var foundation: StaticBody3D = village.get_node_or_null("Terraces/"+name) as StaticBody3D
		_require(foundation != null,"Physical continuous terrain repair: "+name)
		if foundation != null:
			var geometry: CollisionShape3D = foundation.get_node_or_null("CollisionShape3D") as CollisionShape3D
			_require(geometry != null and geometry.shape is ConcavePolygonShape3D,
				"Lower resolution collision on seam repair: "+name)
	for sample_z: float in [-38.0,-16.2,-12.0,-8.0,8.0,12.0,16.2,38.0]:
		var low: float = HMHarbourTerrainG1.lower_height(50.0,sample_z)
		var upper: float = HMHarbourTerrainG1.bluff_height_at(50.0,sample_z)
		_require(absf(low-upper)<0.01,"No lower/upper ground gap z="+str(sample_z))
	for sample_z: float in [-8.0,-5.0,0.0,5.0,8.0]:
		_require(absf(HMHarbourTerrainG1.lower_height(50.0,sample_z)-
			HMHarbourTerrainG1.ramp_cut_height(50.0,sample_z))<0.01,
			"No unsupported road cutting at z="+str(sample_z))
	for sample_x: float in [-40.0,-10.0,25.0,50.0]:
		for side: float in [-1.0,1.0]:
			_require(absf(HMHarbourTerrainG1.edge_height(sample_x,47.0*side,false)-
				HMHarbourTerrainG1.lower_height(sample_x,47.0*side))<0.01,
				"Lower outer shoreline has closed seam")
	for sample_x: float in [50.0,57.0,65.5,95.0,120.0]:
		for side: float in [-1.0,1.0]:
			var inner: float = HMHarbourTerrainG1.bluff_height_at(sample_x,46.0) if sample_x<=65.5 else 8.0
			_require(absf(HMHarbourTerrainG1.edge_height(sample_x,46.0*side,true)-
				inner)<0.01,"Upper coastal scarp closes old cliff edge")
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
	# Confirm that route geometry is supported by actual underlying soil,
	# not a hovering ribbon over the old tidal bank.
	for i: int in range(points.size()-1):
		for step: int in range(9):
			var fraction: float = float(step)/8.0
			var check_at: Vector2 = points[i].lerp(points[i+1],fraction)
			var expected_floor: float = lerpf(HMHarbourTerrainG1.route_height(points[i]),
				HMHarbourTerrainG1.route_height(points[i+1]),fraction)
			var terrain_floor: float = HMHarbourTerrainG1.lower_height(check_at.x,check_at.y)
			_require(expected_floor-terrain_floor >= 0.085 and expected_floor-terrain_floor <= 0.25,
				"Haul route has small visible, grounded soil thickness at "+str(check_at))
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
		Vector3(56,4.0,38),Vector3(69,8.0,-30)]:
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
