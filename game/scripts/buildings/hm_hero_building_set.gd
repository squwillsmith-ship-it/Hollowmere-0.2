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
		# Each previously flat warehouse half-course now climbs toward a
		# common ridge. Rotate BOTH its art AND original physical collision.
		var left: bool = title.begins_with("RoofLeft_")
		body.rotation_degrees.z = 20.0 if left else -20.0
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
		for x: float in [-2.48,2.48]:
			_box(body,"RoofCourseDripBatten",Vector3(0.11,0.10,4.85),
				Vector3(x,2.88,0),OAK.darkened(0.15))
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
