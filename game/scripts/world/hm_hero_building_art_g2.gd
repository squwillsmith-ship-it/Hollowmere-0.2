class_name HMHeroBuildingArtG2
extends Node3D
## G2 hero architecture: individually owned, part-state-aware authored facets.
## This is render-only detail on EXISTING HMInspectTarget parts. Never adds an
## independent salvage ID, collision proxy, output or automatic work action.
const OAK: Color = Color("685541")
const WEATHERED: Color = Color("786754")
const IRON: Color = Color("414540")
var cottage_owners: int = 0
var warehouse_owners: int = 0
var batched_meshes: int = 0

func build(cottage: Node3D, installations: Dictionary) -> void:
	if batched_meshes > 0:
		return
	if cottage != null:
		for candidate: Node in cottage.get_children():
			if not (candidate is HMInspectTarget):
				continue
			var part := candidate as HMInspectTarget
			if bool(part.get_meta("g2_assembled",false)):
				continue
			if part.part_id == "fixture/house/front_infill":
				_facade(part)
			elif part.part_id == "fixture/house/beam":
				_interior(part)
	for key: String in ["district/old_warehouse","district/expanded_warehouse"]:
		var group: Node3D = installations.get(key,null) as Node3D
		if group == null:
			continue
		for candidate: Node in group.get_children():
			if not (candidate is HMInspectTarget):
				continue
			var part := candidate as HMInspectTarget
			var collider := part.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collider == null or not (collider.shape is BoxShape3D):
				continue
			var bounds: Vector3 = (collider.shape as BoxShape3D).size
			if part.name.begins_with("BackFrame"):
				_warehouse_bent(part,bounds)
			elif part.name.begins_with("RoofLeft") or part.name.begins_with("RoofRight"):
				_warehouse_slate_edge(part,bounds)

func _facade(part: HMInspectTarget) -> void:
	# Form a distinctive half-timber/gable hierarchy without covering door
	# or window apertures. All members vanish on front-infill release.
	var st := _begin()
	for x: float in [-2.25,2.25]:
		_beam(st,Vector3(x,0.38,2.30),Vector3(x,2.77,2.30),0.18,0.16,OAK)
	for x: float in [-0.53,0.53]:
		_beam(st,Vector3(x,0.48,2.31),Vector3(x,2.59,2.31),0.10,0.10,WEATHERED)
	_beam(st,Vector3(-2.36,2.78,2.31),Vector3(2.36,2.78,2.31),0.16,0.16,OAK)
	_beam(st,Vector3(-2.34,2.80,2.31),Vector3(0,4.08,2.31),0.17,0.15,OAK)
	_beam(st,Vector3(0,4.08,2.31),Vector3(2.34,2.80,2.31),0.17,0.15,OAK)
	_beam(st,Vector3(0,2.79,2.32),Vector3(0,3.92,2.32),0.11,0.11,WEATHERED)
	_beam(st,Vector3(-0.63,2.46,2.32),Vector3(0.63,2.46,2.32),0.14,0.12,OAK)
	for x: float in [-2.22,2.22]:
		_beam(st,Vector3(x,2.77,2.46),Vector3(x,2.77,2.30),0.06,0.075,IRON)
	_finish(part,st,"G2OwnerFrontGable",Vector3.ONE)
	cottage_owners += 1

func _interior(part: HMInspectTarget) -> void:
	# Small pitched ceiling and collar joinery, all owned by ridge/tie ID.
	var st := _begin()
	for x: float in [-1.52,1.52]:
		_beam(st,Vector3(x,3.19,-2.02),Vector3(x,3.19,2.02),0.19,0.17,OAK)
		for z: float in [-1.96,1.96]:
			_beam(st,Vector3(x,3.18,z),Vector3(x*0.70,3.75,z),0.13,0.12,WEATHERED)
	_beam(st,Vector3(-2.27,2.76,0),Vector3(2.27,2.76,0),0.18,0.15,OAK)
	_finish(part,st,"G2OwnerInternalCollars",Vector3.ONE)
	cottage_owners += 1

func _warehouse_bent(part: HMInspectTarget,bounds: Vector3) -> void:
	# Authored per existing bay: a timber skeleton and joined knee braces.
	# Normalized geometry scales to the pre-existing collision envelope.
	var st := _begin()
	for signum: float in [-1.0,1.0]:
		_beam(st,Vector3(signum*0.43,-0.46,0.035),
			Vector3(signum*0.43,0.46,0.035),0.09,0.55,OAK)
		_beam(st,Vector3(signum*0.43,0.39,0.04),
			Vector3(signum*0.13,0.16,0.04),0.075,0.44,WEATHERED)
		_beam(st,Vector3(signum*0.43,-0.40,0.04),
			Vector3(signum*0.18,-0.20,0.04),0.07,0.40,WEATHERED)
		_beam(st,Vector3(signum*0.43,0.36,0.24),
			Vector3(signum*0.43,0.47,0.24),0.045,0.21,IRON)
	_beam(st,Vector3(-0.47,0.44,0.035),Vector3(0.47,0.44,0.035),0.095,0.55,OAK)
	_finish(part,st,"G2OwnerWarehouseBent",bounds)
	warehouse_owners += 1

func _warehouse_slate_edge(part: HMInspectTarget,bounds: Vector3) -> void:
	# Under-slate purlin ends are stripped with their own roof course,
	# rather than persisting as floating decorative braces.
	var st := _begin()
	_beam(st,Vector3(-0.49,0.35,-0.43),Vector3(0.49,0.35,-0.43),0.15,0.60,WEATHERED)
	_beam(st,Vector3(-0.49,0.34,0.43),Vector3(0.49,0.34,0.43),0.11,0.50,OAK)
	for x: float in [-0.42,0.42]:
		_beam(st,Vector3(x,-0.17,-0.43),Vector3(x,-0.17,0.43),0.10,0.40,OAK)
	_finish(part,st,"G2OwnerRoofUnderlay",bounds)
	warehouse_owners += 1

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _finish(owner_part: HMInspectTarget,st: SurfaceTool,label: String,scale_by: Vector3) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = st.commit()
	visual.scale = scale_by
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat
	visual.set_meta("g2_owner_part_id",owner_part.part_id)
	visual.set_meta("noncolliding_visual_only",true)
	owner_part.add_child(visual)
	batched_meshes += 1

func _beam(st: SurfaceTool,a: Vector3,b: Vector3,width: float,
		depth: float,tint: Color) -> void:
	var axis: Vector3 = (b-a).normalized()
	if axis.is_zero_approx():
		return
	var guide: Vector3 = Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var tangent: Vector3 = axis.cross(guide).normalized()
	var binormal: Vector3 = tangent.cross(axis).normalized()
	var middle: Vector3 = (a+b)*0.5
	var half_length: float = (b-a).length()*0.5
	var hw: float = width*0.5
	var hd: float = depth*0.5
	var v: Array[Vector3] = []
	for corner: Vector3 in [
		Vector3(-hw,-half_length,-hd),Vector3(hw,-half_length,-hd),
		Vector3(hw,half_length,-hd),Vector3(-hw,half_length,-hd),
		Vector3(-hw,-half_length,hd),Vector3(hw,-half_length,hd),
		Vector3(hw,half_length,hd),Vector3(-hw,half_length,hd)]:
		v.append(middle+tangent*corner.x+axis*corner.y+binormal*corner.z)
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0,1,2,3]),PackedInt32Array([5,4,7,6]),
		PackedInt32Array([4,0,3,7]),PackedInt32Array([1,5,6,2]),
		PackedInt32Array([3,2,6,7]),PackedInt32Array([4,5,1,0])]
	for i: int in range(faces.size()):
		var face: PackedInt32Array = faces[i]
		var shade: Color = tint*(0.81+0.037*float(i))
		_triangle(st,v[face[0]],v[face[1]],v[face[2]],shade)
		_triangle(st,v[face[0]],v[face[2]],v[face[3]],shade.darkened(0.038))

func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	var n: Vector3 = (b-a).cross(c-a).normalized()
	for point: Vector3 in [a,b,c]:
		st.set_normal(n)
		st.set_color(tint)
		st.add_vertex(point)
