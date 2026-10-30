class_name HMHarbourTerrainG1
extends RefCounted
## G1: continuous, authored harbour landform and a connected manual haul route.
## Geometry is a reproducible interim benchmark; final art requires owner review.
## No site ID, salvage owner, story marker, or economy data is changed.
const LOW_X0: float = -54.0
const LOW_X1: float = 50.0
const LOW_Z0: float = -47.0
const LOW_Z1: float = 47.0
const BLUFF_X0: float = 47.0
const BLUFF_X1: float = 65.5
const PATH_HALF_WIDTH: float = 1.8

static func lower_height(x: float, z: float) -> float:
	# Coastline wanders independently of the settlement grid. A continuous
	# shallow bank joins tidal rock to the retained 2m building datum.
	var tide_edge: float = -40.0 + 1.6 * sin(z * 0.09) + 0.8 * sin(z * 0.21 + 0.5)
	var terrace_lip: float = -29.3 + 1.1 * sin(z * 0.047 + 1.1)
	var t: float = clampf((x - tide_edge) / (terrace_lip - tide_edge), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var natural_bank: float = lerpf(-0.85, 2.0, t)
	# G1: the quay-to-warehouse walk is CUT INTO and SUPPORTED BY the
	# landform. Without this fill/cut the first path span hovered up to 2m
	# above the tidal bank. The gently graded approach is part of terrain,
	# not a decorative ribbon concealing a disconnected collision.
	var apron_start := Vector2(-38.0, 19.5)
	var apron_end := Vector2(-26.0, 27.0)
	var axis: Vector2 = apron_end - apron_start
	var point := Vector2(x,z)
	var u: float = clampf((point - apron_start).dot(axis) / axis.length_squared(),0.0,1.0)
	var nearest: Vector2 = apron_start + axis * u
	var edge_distance: float = point.distance_to(nearest)
	var mask: float = clampf(1.0 - edge_distance / 5.7,0.0,1.0)
	mask = mask * mask * (3.0 - 2.0 * mask)
	return lerpf(natural_bank,lerpf(1.29,2.0,u),mask)

static func bluff_height(x: float) -> float:
	var t: float = clampf((x - BLUFF_X0) / (BLUFF_X1 - BLUFF_X0), 0.0, 1.0)
	# The 6m upper-terrace rise is a real graded rock embankment outside
	# the existing central cart cutting, not a vertical rectangular wall.
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(2.0, 8.0, t)

static func create_lower_terrace() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LowerTerrace"
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("g1_coastal_topology", "sculpted_shoreline_and_terrace")
	var skin := MeshInstance3D.new()
	skin.name = "ContinuousCoastalLandform"
	skin.mesh = _lower_mesh(1.2)
	skin.material_override = _surface_material()
	body.add_child(skin)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.data = _lower_collision(2.0)
	collision.shape = shape
	body.add_child(collision)
	return body

static func create_bluff(name: String, z0: float, z1: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("g1_coastal_topology", "graded_upper_terrace_transition")
	var skin := MeshInstance3D.new()
	skin.name = "JoinedRockEmbankment"
	skin.mesh = _bluff_mesh(z0,z1,1.3)
	skin.material_override = _surface_material()
	body.add_child(skin)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.data = _bluff_collision(z0,z1,4.0)
	collision.shape = shape
	body.add_child(collision)
	return body

static func route_points() -> PackedVector2Array:
	# Quay boardwalk (x=-39) to inland warehouse frontage (18,37),
	# then east along the cottage approach. Avoids working shelter and walls.
	return PackedVector2Array([
		Vector2(-38.0,19.5), Vector2(-33.0,23.0),
		Vector2(-26.0,27.0), Vector2(-13.0,28.0),
		Vector2(1.0,37.0), Vector2(10.0,38.0),
		Vector2(18.0,37.0), Vector2(26.0,36.0),
		Vector2(28.0,31.0), Vector2(30.0,29.0)
	])

static func route_height(at: Vector2) -> float:
	# Pier walkway joins at 1.35m; inland stations retain the existing
	# floor datum, with no raised kerb or path-only collision obstacle.
	return maxf(1.43, lower_height(at.x,at.y) + 0.16)

static func create_haul_path() -> StaticBody3D:
	var path := StaticBody3D.new()
	path.name = "G1HaulPath"
	path.collision_layer = 1
	path.collision_mask = 2
	path.set_meta("manual_player_route", true)
	path.set_meta("not_salvage", true)
	var skin := MeshInstance3D.new()
	skin.name = "JoinedEarthAndStoneWalk"
	skin.mesh = _route_mesh()
	skin.material_override = _surface_material()
	path.add_child(skin)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.data = _route_collision()
	collision.shape = shape
	path.add_child(collision)
	return path

static func create_quay_revetment() -> MeshInstance3D:
	# Dry-stone facing sits below the already-existing quay deck.
	# The gap z=3..18 is the open pier access, not an invisible seawall.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for limits: Vector2 in [Vector2(-39.0,3.0),Vector2(18.0,39.0)]:
		var count: int = ceili((limits.y-limits.x)/1.6)
		for i: int in range(count):
			var z0: float = lerpf(limits.x,limits.y,float(i)/float(count))
			var z1: float = lerpf(limits.x,limits.y,float(i+1)/float(count))
			var x0: float = -40.4 + 0.48*sin(z0*0.117)
			var x1: float = -40.4 + 0.48*sin(z1*0.117)
			var top0 := Vector3(x0,1.31,z0)
			var top1 := Vector3(x1,1.31,z1)
			var foot0 := Vector3(x0-0.52,-0.63,z0)
			var foot1 := Vector3(x1-0.52,-0.63,z1)
			var shade := Color("696c61") * (0.88+0.11*sin(float(i)*1.7))
			_tri(st,foot0,top0,top1,shade)
			_tri(st,foot0,top1,foot1,shade.darkened(0.11))
	var art := MeshInstance3D.new()
	art.name = "QuayDryStoneRevetment"
	art.mesh = st.commit()
	art.material_override = _surface_material()
	art.set_meta("scenery_below_deck_no_collision",true)
	return art

static func _lower_mesh(step: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = ceili((LOW_X1-LOW_X0)/step)
	var nz: int = ceili((LOW_Z1-LOW_Z0)/step)
	for j: int in range(nz):
		for i: int in range(nx):
			var x0: float = lerpf(LOW_X0,LOW_X1,float(i)/float(nx))
			var x1: float = lerpf(LOW_X0,LOW_X1,float(i+1)/float(nx))
			var z0: float = lerpf(LOW_Z0,LOW_Z1,float(j)/float(nz))
			var z1: float = lerpf(LOW_Z0,LOW_Z1,float(j+1)/float(nz))
			var a := Vector3(x0,lower_height(x0,z0),z0)
			var b := Vector3(x1,lower_height(x1,z0),z0)
			var c := Vector3(x1,lower_height(x1,z1),z1)
			var d := Vector3(x0,lower_height(x0,z1),z1)
			var salt: float = 0.5+0.5*sin(float(i)*0.37+float(j)*0.19)
			var colour := Color("777867").lerp(Color("66705d"),salt*0.34)
			if x0 < -30.0:
				colour = colour.lerp(Color("5a625b"),0.42)
			_tri(st,a,d,b,colour)
			_tri(st,b,d,c,colour.darkened(0.045))
	return st.commit()

static func _lower_collision(step: float) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var nx: int = ceili((LOW_X1-LOW_X0)/step)
	var nz: int = ceili((LOW_Z1-LOW_Z0)/step)
	for j: int in range(nz):
		for i: int in range(nx):
			var x0: float = lerpf(LOW_X0,LOW_X1,float(i)/float(nx))
			var x1: float = lerpf(LOW_X0,LOW_X1,float(i+1)/float(nx))
			var z0: float = lerpf(LOW_Z0,LOW_Z1,float(j)/float(nz))
			var z1: float = lerpf(LOW_Z0,LOW_Z1,float(j+1)/float(nz))
			var a := Vector3(x0,lower_height(x0,z0),z0)
			var b := Vector3(x1,lower_height(x1,z0),z0)
			var c := Vector3(x1,lower_height(x1,z1),z1)
			var d := Vector3(x0,lower_height(x0,z1),z1)
			faces.append_array(PackedVector3Array([a,d,b,b,d,c]))
	return faces

static func _bluff_mesh(z0: float,z1: float, step: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = ceili((BLUFF_X1-BLUFF_X0)/step)
	var nz: int = ceili((z1-z0)/step)
	for j: int in range(nz):
		for i: int in range(nx):
			var x0: float = lerpf(BLUFF_X0,BLUFF_X1,float(i)/float(nx))
			var x1: float = lerpf(BLUFF_X0,BLUFF_X1,float(i+1)/float(nx))
			var a_z: float = lerpf(z0,z1,float(j)/float(nz))
			var b_z: float = lerpf(z0,z1,float(j+1)/float(nz))
			var a := Vector3(x0,bluff_height(x0)+0.012,a_z)
			var b := Vector3(x1,bluff_height(x1)+0.012,a_z)
			var c := Vector3(x1,bluff_height(x1)+0.012,b_z)
			var d := Vector3(x0,bluff_height(x0)+0.012,b_z)
			var shade := Color("6c705e")*(0.92+0.09*sin(float(i)*0.84+float(j)*0.35))
			_tri(st,a,d,b,shade)
			_tri(st,b,d,c,shade.darkened(0.07))
	return st.commit()

static func _bluff_collision(z0: float,z1: float,step: float) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var nx: int = ceili((BLUFF_X1-BLUFF_X0)/step)
	var nz: int = ceili((z1-z0)/step)
	for j: int in range(nz):
		for i: int in range(nx):
			var x0: float = lerpf(BLUFF_X0,BLUFF_X1,float(i)/float(nx))
			var x1: float = lerpf(BLUFF_X0,BLUFF_X1,float(i+1)/float(nx))
			var az: float = lerpf(z0,z1,float(j)/float(nz))
			var bz: float = lerpf(z0,z1,float(j+1)/float(nz))
			var a := Vector3(x0,bluff_height(x0),az)
			var b := Vector3(x1,bluff_height(x1),az)
			var c := Vector3(x1,bluff_height(x1),bz)
			var d := Vector3(x0,bluff_height(x0),bz)
			faces.append_array(PackedVector3Array([a,d,b,b,d,c]))
	return faces

static func _route_normal(points: PackedVector2Array,index: int) -> Vector2:
	var prev: Vector2 = points[maxi(0,index-1)]
	var next: Vector2 = points[mini(points.size()-1,index+1)]
	var axis: Vector2 = (next-prev).normalized()
	return Vector2(-axis.y,axis.x)

static func _route_vertex(points: PackedVector2Array,index: int,t: float,
		side: float, cosmetic: bool) -> Vector3:
	var a: Vector2 = points[index]
	var b: Vector2 = points[index+1]
	var normal: Vector2 = _route_normal(points,index).lerp(
		_route_normal(points,index+1),t).normalized()
	var p: Vector2 = a.lerp(b,t)+normal*side*PATH_HALF_WIDTH
	var h: float = lerpf(route_height(a),route_height(b),t)
	if cosmetic:
		h += 0.013 + 0.012*sin((float(index)+t)*5.2)
	return Vector3(p.x,h,p.y)

static func _route_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: PackedVector2Array = route_points()
	for i: int in range(points.size()-1):
		for s: int in range(4):
			var t0: float = float(s)/4.0
			var t1: float = float(s+1)/4.0
			var a := _route_vertex(points,i,t0,-1.0,true)
			var b := _route_vertex(points,i,t0,1.0,true)
			var c := _route_vertex(points,i,t1,1.0,true)
			var d := _route_vertex(points,i,t1,-1.0,true)
			var shade := Color("89806b") * (0.95+0.045*sin(float(i)*3.0+float(s)))
			_tri(st,a,b,c,shade)
			_tri(st,a,c,d,shade.darkened(0.035))
	return st.commit()

static func _route_collision() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var points: PackedVector2Array = route_points()
	# One pair of colliding triangles per route segment: no unwalkable
	# detailed cobble collision, while the rendered ribbon is subdivided.
	for i: int in range(points.size()-1):
		var a := _route_vertex(points,i,0.0,-1.0,false)
		var b := _route_vertex(points,i,0.0,1.0,false)
		var c := _route_vertex(points,i,1.0,1.0,false)
		var d := _route_vertex(points,i,1.0,-1.0,false)
		faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
	return faces

static func _surface_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.97
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		tint: Color) -> void:
	var n: Vector3 = (b-a).cross(c-a).normalized()
	for p: Vector3 in [a,b,c]:
		st.set_normal(n)
		st.set_color(tint)
		st.add_vertex(p)
