class_name HMHarbourBenchmarkCoast
extends RefCounted
## G1: one continuous, physics-backed lower coast and grounded cart-track
## spine. Coordinates preserve the established 21 sites and service stations.
## This is editable Godot geometry, not a visual-only cover over a box collider.

const COAST_X_MIN: float = -52.0
const COAST_X_MAX: float = 50.0
const COAST_Z_MIN: float = -47.0
const COAST_Z_MAX: float = 47.0
const COAST_COLS: int = 76
const COAST_ROWS: int = 68
const QUAY_TO_YARD: Array[Vector2] = [
	Vector2(-35.0,10.0), Vector2(-29.0,10.0),
	Vector2(-21.0,9.5), Vector2(-16.0,9.0)
]
const YARD_TO_COTTAGE: Array[Vector2] = [
	Vector2(-16.0,9.0), Vector2(-4.0,9.0),
	Vector2(10.0,11.0), Vector2(23.0,14.0),
	Vector2(26.5,19.0), Vector2(26.5,29.5),
	Vector2(35.0,30.0)
]
const WAREHOUSE_SPUR: Array[Vector2] = [
	Vector2(26.5,29.5), Vector2(26.5,38.0),
	Vector2(18.0,38.0)
]

static func shore_at(z: float) -> float:
	return -38.1 + sin(z * 0.105) * 2.25 + sin(z * 0.285 + 0.7) * 1.2

static func ground_height(x: float, z: float) -> float:
	# A graded tidal shingle-to-earth shoulder. The service district and
	# salvage building footprints stay nearly level at the established y=2.
	var shore: float = shore_at(z)
	var t: float = clampf((x-shore) / 11.5, 0.0, 1.0)
	t = t*t*(3.0-2.0*t)
	var land: float = lerpf(-0.67,1.965,t)
	var exposed: float = 1.0 - smoothstep(-28.0,-20.0,x)
	land += exposed * 0.065 * sin(z*0.27+x*0.21)
	return land

static func install_terrace(parent: Node3D) -> StaticBody3D:
	var terrain := StaticBody3D.new()
	terrain.name = "LowerTerrace"
	terrain.collision_layer = 1
	terrain.collision_mask = 2
	terrain.set_meta("authored_continuous_coast",true)
	parent.add_child(terrain)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(COAST_ROWS):
		var z0: float = lerpf(COAST_Z_MIN,COAST_Z_MAX,float(row)/float(COAST_ROWS))
		var z1: float = lerpf(COAST_Z_MIN,COAST_Z_MAX,float(row+1)/float(COAST_ROWS))
		for col: int in range(COAST_COLS):
			var x0: float = lerpf(COAST_X_MIN,COAST_X_MAX,float(col)/float(COAST_COLS))
			var x1: float = lerpf(COAST_X_MIN,COAST_X_MAX,float(col+1)/float(COAST_COLS))
			var a := Vector3(x0,ground_height(x0,z0),z0)
			var b := Vector3(x1,ground_height(x1,z0),z0)
			var c := Vector3(x1,ground_height(x1,z1),z1)
			var d := Vector3(x0,ground_height(x0,z1),z1)
			var centre: Vector2 = Vector2((x0+x1)*0.5,(z0+z1)*0.5)
			var shore_distance: float = centre.x - shore_at(centre.y)
			var stone: Color = Color("777970").lerp(Color("6b6c5d"),
				clampf((shore_distance+4.0)/20.0,0.0,1.0))
			stone = stone.lerp(Color("8a826e"),
				0.10+0.11*absf(sin(centre.x*0.14+centre.y*0.11)))
			var shade: float = 0.96+0.035*sin(centre.x*0.24+centre.y*0.36)
			_triangle(st,a,d,b,stone*shade)
			_triangle(st,b,d,c,stone.darkened(0.035)*shade)
	# Inland face terminates below the upper ramp and adjoining terraces;
	# no exposed full-height perfectly vertical block is left at the shore.
	for row: int in range(COAST_ROWS):
		var z0: float = lerpf(COAST_Z_MIN,COAST_Z_MAX,float(row)/float(COAST_ROWS))
		var z1: float = lerpf(COAST_Z_MIN,COAST_Z_MAX,float(row+1)/float(COAST_ROWS))
		var a := Vector3(COAST_X_MAX,ground_height(COAST_X_MAX,z0),z0)
		var b := Vector3(COAST_X_MAX,ground_height(COAST_X_MAX,z1),z1)
		var c := Vector3(COAST_X_MAX,-1.25,z1)
		var d := Vector3(COAST_X_MAX,-1.25,z0)
		_triangle(st,a,b,d,Color("5b6056"))
		_triangle(st,d,b,c,Color("565b52"))
	var mesh: ArrayMesh = st.commit()
	_install_mesh_and_collision(terrain,mesh,"AuthoredTidalBankAndLowerStreet")
	return terrain

static func install_haul_routes(parent: Node3D) -> void:
	# Three connected segments: dock ramp, street spine, warehouse branch.
	# Every rendered strip has exactly the same simplified static collision.
	_route(parent,"LandingApproach",QUAY_TO_YARD,3.25)
	_route(parent,"WarehouseCottageHaulTrack",YARD_TO_COTTAGE,3.2)
	_route(parent,"WarehouseDoorSpur",WAREHOUSE_SPUR,2.65)

static func _route(parent: Node3D, title: String,
		points: Array[Vector2], width: float) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("authored_haul_route",true)
	parent.add_child(body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(points.size()-1):
		var start: Vector2 = points[i]
		var finish: Vector2 = points[i+1]
		var segment: Vector2 = finish-start
		var divisions: int = maxi(2,ceili(segment.length()/1.05))
		var normal: Vector2 = Vector2(-segment.y,segment.x).normalized()
		for j: int in range(divisions):
			var t0: float = float(j)/float(divisions)
			var t1: float = float(j+1)/float(divisions)
			var p0: Vector2 = start.lerp(finish,t0)
			var p1: Vector2 = start.lerp(finish,t1)
			var half: float = width*0.5
			var a := _route_vertex(p0+normal*half)
			var b := _route_vertex(p0-normal*half)
			var c := _route_vertex(p1-normal*half)
			var d := _route_vertex(p1+normal*half)
			var tone: Color = Color("877d69").lerp(Color("726c5e"),
				0.16+0.10*sin(float(i)*1.8+float(j)*0.4))
			_triangle(st,a,b,d,tone)
			_triangle(st,b,c,d,tone.darkened(0.055))
	var mesh: ArrayMesh = st.commit()
	_install_mesh_and_collision(body,mesh,"RuttedStoneAndPackedEarth")

static func _route_vertex(p: Vector2) -> Vector3:
	# At the quay the real strip joins the old low waterfront deck. The
	# rising approach then meets the inland terrace without a floating slab.
	return Vector3(p.x,ground_height(p.x,p.y)+0.13,p.y)

static func _install_mesh_and_collision(body: StaticBody3D,
		mesh: ArrayMesh, mesh_name: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = mesh_name
	visual.mesh = mesh
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.97
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = finish
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = mesh.create_trimesh_shape()
	body.add_child(collider)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, tint: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for point: Vector3 in [a,b,c]:
		tool.set_color(tint)
		tool.set_normal(normal)
		tool.add_vertex(point)
