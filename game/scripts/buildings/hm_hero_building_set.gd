class_name HMHeroBuildingSet
extends RefCounted
## G2 authored visual/physics treatment. Every architectural addition is a
## child of a pre-existing, saved HMInspectTarget assembly. No extra salvage,
## passive work or independently floating decorative building structure.

const OAK: Color = Color("67513d")
const SALT_OAK: Color = Color("766d5e")
const DARK_IRON: Color = Color("474742")

static func finish_warehouse_part(body: StaticBody3D,
		data: Dictionary) -> void:
	if not (body is HMInspectTarget):
		return
	var title: String = String(data.get("name",""))
	if title.begins_with("RoofLeft_Course") or title.begins_with("RoofRight_Course"):
		# Existing roof courses already have their 27-degree pitch and
		# matching colliders. Preserve verified geometry and salvage IDs.
		var left: bool = title.begins_with("RoofLeft_")
		var span: Vector3 = _vec(data["size"])
		var rafter := MeshInstance3D.new()
		rafter.name = "RafterUnderSalvagedRoofCourse"
		var beam := BoxMesh.new()
		beam.size = Vector3(span.x*0.94,0.17,maxf(0.13,span.z*0.25))
		rafter.mesh = beam
		rafter.material_override = _mat(OAK.darkened(0.13))
		rafter.position = Vector3(0,-0.22,0)
		body.add_child(rafter)
		var drip := MeshInstance3D.new()
		drip.name = "IrregularOakEaves"
		var edge := BoxMesh.new()
		edge.size = Vector3(0.17,0.16,span.z*0.95)
		drip.mesh = edge
		drip.position = Vector3(-span.x*0.47 if left else span.x*0.47,-0.13,0)
		drip.material_override = _mat(SALT_OAK)
		body.add_child(drip)
	elif title.begins_with("BackFrame_Section"):
		# Historically repaired planking closes the lower rear wall;
		# the upper framing stays legible, and the visible planks own their
		# physical collider. Front loading-door opening is left clear.
		var dims: Vector3 = _vec(data["size"])
		var r := RandomNumberGenerator.new()
		r.seed = absi(title.hash())+8916
		var board_count: int = 7
		var bottom: float = -dims.y*0.5+0.19
		var board_height: float = 2.58/float(board_count)
		for i: int in range(board_count):
			var wood := MeshInstance3D.new()
			wood.name = "RepairedBackPlank_%02d" % i
			var plank := BoxMesh.new()
			plank.size = Vector3(dims.x*0.88,board_height*0.94,0.17)
			wood.mesh = plank
			wood.position = Vector3(r.randf_range(-0.02,0.02),
				bottom+(float(i)+0.5)*board_height,0.045)
			wood.material_override = _mat(SALT_OAK *
				r.randf_range(0.82,1.06))
			body.add_child(wood)
		var cover := CollisionShape3D.new()
		cover.name = "RepairedBackBoardCollision"
		var shape := BoxShape3D.new()
		shape.size = Vector3(dims.x*0.88,2.58,0.17)
		cover.shape = shape
		cover.position = Vector3(0,bottom+1.29,0.045)
		body.add_child(cover)
	elif title.begins_with("PierDoorLeft") or title.begins_with("PierDoorRight"):
		var dims: Vector3 = _vec(data["size"])
		# Weathered upright construction joints are owned by the same door
		# wall section and cannot outlive its manual release.
		for sign: int in [-1,1]:
			_box(body,"PierFrameStile",Vector3(0.13,dims.y*0.98,0.31),
				Vector3(float(sign)*(dims.x*0.5-0.09),0,0),OAK)
		# Two individually removable lime-washed triangular upper panels
		# close the front gable without sealing the loading doorway.
		if title.ends_with("_Section_03"):
			_add_warehouse_gable(body,title.begins_with("PierDoorLeft"))

static func finish_cottage_part(body: HMInspectTarget, part_id: String) -> void:
	if part_id == "fixture/house/front_infill":
		# Behind the removable lime panels: hand-hewn vertical oak posts,
		# not freestanding columns when the underlying front is removed.
		for x: float in [-2.23,2.23]:
			_box(body,"FacadeCornerOakPost",Vector3(0.18,2.63,0.22),
				Vector3(x,1.48,2.2),OAK.darkened(0.08))
		_box(body,"OakOverDoorLintel",Vector3(1.45,0.20,0.24),
			Vector3(0,2.51,2.24),SALT_OAK.darkened(0.22))
	elif part_id == "fixture/house/slate_patch":
		# Removable barge/drip edges keep the two actual roof sections
		# legible in the intact, half-stripped and empty states.
		for x: float in [-2.36,2.36]:
			_box(body,"RoofCourseDripBatten",Vector3(0.10,0.09,4.85),
				Vector3(x,2.67,0),OAK.darkened(0.15))
	elif part_id == "fixture/house/curtain":
		# The original single beige rectangle becomes a salt-stiff cloth with
		# uneven hanging folds. Its original ray collision and hands-only salvage
		# identity remain exactly the same.
		var old_cloth: MeshInstance3D = body.get_node_or_null("DoorCloth") as MeshInstance3D
		if old_cloth != null:
			old_cloth.visible = false
		var fabric := SurfaceTool.new()
		fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(10):
			var x0: float = -0.45+0.9*float(i)/10.0
			var x1: float = -0.45+0.9*float(i+1)/10.0
			var hem0: float = 0.45+0.046*sin(float(i)*2.7)
			var hem1: float = 0.45+0.046*sin(float(i+1)*2.7)
			var fold0: float = 2.20+0.047*sin(float(i)*1.65)
			var fold1: float = 2.20+0.047*sin(float(i+1)*1.65)
			var shade: Color = Color("aaa08b")*(0.90+0.07*float(i%3))
			_tri(fabric,Vector3(x0,2.05,2.19),Vector3(x0,hem0,fold0),
				Vector3(x1,2.05,2.19),shade)
			_tri(fabric,Vector3(x1,2.05,2.19),Vector3(x0,hem0,fold0),
				Vector3(x1,hem1,fold1),shade.darkened(0.06))
		var cloth_mesh := MeshInstance3D.new()
		cloth_mesh.name = "SaltStiffHangingDoorTextile"
		cloth_mesh.mesh = fabric.commit()
		var cloth_finish := _mat(Color.WHITE)
		cloth_finish.vertex_color_use_as_albedo = true
		cloth_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth_mesh.material_override = cloth_finish
		body.add_child(cloth_mesh)
	elif part_id == "fixture/house/beam":
		# Adds historically plausible pegged joints without changing the
		# original saw tier, support relationships, or load distribution.
		for x: float in [-1.92,1.92]:
			_box(body,"OakPeggedFrameJoint",Vector3(0.18,0.26,0.31),
				Vector3(x,2.68,2.2),DARK_IRON)

static func _mat(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.94
	return material

static func _vec(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))

static func _box(parent: Node3D, title: String, size: Vector3,
		at: Vector3, tint: Color) -> void:
	var detail := MeshInstance3D.new()
	detail.name = title
	var geometry := BoxMesh.new()
	geometry.size = size
	detail.mesh = geometry
	detail.position = at
	detail.material_override = _mat(tint)
	parent.add_child(detail)

static func _add_warehouse_gable(body: StaticBody3D,left: bool) -> void:
	# Front wall section centre is (+/-3.125, 4.0667, 4.0).
	# Local triangular halves span from upper 4.8m wall to the 27-degree
	# ridge at approximately 6.42m; shared centre seam is intentionally open
	# only when its owning panel is manually dismantled.
	var low: float = 0.73
	var high: float = 2.35
	var begin_x: float = -0.05 if left else -3.125
	var end_x: float = 3.125 if left else 0.05
	var peak_x: float = 3.125 if left else -3.125
	var a := Vector3(begin_x,low,0.09)
	var b := Vector3(end_x,low,0.09)
	var c := Vector3(peak_x,high,0.09)
	var depth := Vector3(0,0,0.17)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var infill := Color("b8ac91")
	_tri(st,a,b,c,infill)
	_tri(st,c+depth,b+depth,a+depth,infill.darkened(0.15))
	_tri(st,a,a+depth,b,infill.darkened(0.08))
	_tri(st,b,a+depth,b+depth,infill.darkened(0.10))
	_tri(st,b,b+depth,c,infill.darkened(0.12))
	_tri(st,c,b+depth,c+depth,infill.darkened(0.11))
	_tri(st,c,c+depth,a,infill.darkened(0.08))
	_tri(st,a,c+depth,a+depth,infill.darkened(0.08))
	var face := MeshInstance3D.new()
	face.name = "OwnedLimeWashedFrontGableHalf"
	face.mesh = st.commit()
	var plaster := _mat(Color.WHITE)
	plaster.vertex_color_use_as_albedo = true
	plaster.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = plaster
	body.add_child(face)
	var solid := CollisionShape3D.new()
	solid.name = "OwnedFrontGablePanelCollision"
	var prism := ConvexPolygonShape3D.new()
	prism.points = PackedVector3Array([a,b,c,a+depth,b+depth,c+depth])
	solid.shape = prism
	body.add_child(solid)
	# Continuous bargeboard follows the rake; it is not an orphaned extra
	# salvage component after the enclosing wall section disappears.
	var trim := MeshInstance3D.new()
	trim.name = "OakRakingGableTrim"
	var timber := BoxMesh.new()
	timber.size = Vector3(3.55,0.13,0.21)
	trim.mesh = timber
	trim.position = Vector3((begin_x+end_x)*0.5,1.52,0.21)
	trim.rotation_degrees.z = 27.0 if left else -27.0
	trim.material_override = _mat(OAK.darkened(0.09))
	body.add_child(trim)

static func _tri(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,
		shade: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for p: Vector3 in [a,b,c]:
		st.set_normal(normal)
		st.set_color(shade)
		st.add_vertex(p)
