class_name HMArchitecturalDetail
extends RefCounted
## Deterministic 1B/1C production-reference geometry, owned by a real removable
## HMInspectTarget. Visual detail NEVER registers independent salvage targets:
## the authoring manifest specifies the independently releasable assembly.
## No collision or item ledger changes happen here.

static func decorate(parent: Node3D, size: Vector3, base: Color, profile: String, key: String) -> void:
	match profile:
		"weatherboards":
			_boards(parent, size, base, key)
		"framed_bay":
			_framed_bay(parent, size, base, key)
		"rough_beam":
			# The central hewn member and restrained darker iron pegs move and
			# disappear together with the ORIGINAL authoring part ID.
			_add_box(parent, "HandHewnSolid", size * Vector3(0.98, 0.98, 0.98),
				Vector3.ZERO, _shade(base,key,1))
			_beam_ends(parent,size,base,key)
		"patch_plaster":
			_plaster(parent, size, base, key)
		"shutter":
			_shutter(parent, size, base, key)
		"slate":
			_slate(parent, size, base, key)
		"stonework":
			_stonework(parent, size, base, key)
		_:
			_add_box(parent, "SimplePanel", size, Vector3.ZERO, base)

static func _mat(color: Color, rough: float = 0.94) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

static func _add_box(parent: Node3D, name: String, size: Vector3, at: Vector3, tint: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _mat(tint)
	parent.add_child(mesh)

static func _axis_is_x(size: Vector3) -> bool:
	return size.x >= size.z

static func _shade(base: Color, key: String, index: int) -> Color:
	var phase: int = absi(key.hash()) % 13
	var v: float = 0.90 + float((index * 7 + phase) % 11) * 0.017
	return Color(base.r * v, base.g * v, base.b * v)

static func _boards(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	# Wall planks are actual short stagger-jointed sections, rather than
	# repeated full-length horizontal ribbons. Every section is a *child*
	# of the original manually removable wall/fitment target, with no extra
	# collision, ID or salvage allocation. Joint spacing is deterministic.
	var along_x: bool = _axis_is_x(size)
	var span: float = size.x if along_x else size.z
	var rows: int = maxi(2, ceili(size.y / 0.26))
	var height: float = size.y / float(rows)
	var r := RandomNumberGenerator.new()
	r.seed = absi(key.hash()) + 84219
	for row: int in range(rows):
		var y: float = -size.y * 0.5 + (float(row) + 0.5) * height
		var offset: float = r.randf_range(-0.009, 0.009)
		var pieces: int = clampi(ceili(span / 1.35), 2, 6) if span > 1.75 else 1
		var base_width: float = span / float(pieces)
		# An alternating offset makes running joints, rather than stacked
		# vertical seams. End caps are shortened to the actual wall envelope.
		var running_joint: float = base_width * (0.35 if row % 2 == 1 else 0.0)
		for section: int in range(pieces + 1):
			var from: float = maxf(-span * 0.5,
				-span * 0.5 + float(section) * base_width - running_joint)
			var to: float = minf(span * 0.5,
				-span * 0.5 + float(section + 1) * base_width - running_joint)
			if to - from < 0.045:
				continue
			var width: float = to - from
			var gap: float = minf(0.015, width * 0.10)
			var section_size: Vector3 = Vector3(width - gap, height * 0.955, size.z * 0.96) if along_x else Vector3(size.x * 0.96, height * 0.955, width - gap)
			var at: Vector3 = Vector3((from + to) * 0.5, y, offset) if along_x else Vector3(offset, y, (from + to) * 0.5)
			_add_box(parent, "Weatherboard_%02d_%02d" % [row, section], section_size,
				at, _shade(base, key, row * 17 + section).lerp(Color("817263"), 0.035))
	# All metal fasteners remain part-owned, noncolliding presentation.
	if size.y > 1.0:
		var face: float = size.z * 0.52 if along_x else size.x * 0.52
		for index: int in range(2):
			var t: float = -0.3 + float(index) * 0.6
			var peg_at := Vector3(t * size.x, size.y * 0.23, face) if along_x else Vector3(face, size.y * 0.23, t * size.z)
			var peg_sz := Vector3(0.042, 0.038, 0.024) if along_x else Vector3(0.024, 0.038, 0.042)
			_add_box(parent,"IronFixingPeg_%02d" % index,peg_sz,peg_at,Color("48443d"))
	# Visible cut timber battens at the existing wall ends only; dismantling
	# the owner removes the entire assembly including these narrow trims.
	var timber: Color = base.darkened(0.24)
	if along_x:
		for signum: int in [-1, 1]:
			_add_box(parent, "EdgeBatten_%d" % signum,
				Vector3(0.10, size.y, size.z * 1.16),
				Vector3(float(signum) * (size.x * 0.5 - 0.05), 0, 0), timber)
	else:
		for signum: int in [-1, 1]:
			_add_box(parent, "EdgeBatten_%d" % signum,
				Vector3(size.x * 1.16, size.y, 0.10),
				Vector3(0, 0, float(signum) * (size.z * 0.5 - 0.05)), timber)

static func _framed_bay(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	# Structural bay, not a solid painted wall: open between vertical posts.
	var along_x: bool = _axis_is_x(size)
	var dark: Color = base.darkened(0.24)
	if along_x:
		for signum: int in [-1, 1]:
			_add_box(parent, "Upright", Vector3(0.20, size.y, maxf(size.z, 0.22)),
				Vector3(float(signum) * (size.x * 0.5 - 0.1), 0, 0), _shade(dark,key,signum+2))
		for y: float in [-0.5, 0.5]:
			_add_box(parent, "HorizontalRail", Vector3(size.x, 0.18, maxf(size.z,0.22)),
				Vector3(0, y * (size.y - 0.18), 0), dark)
	else:
		for signum: int in [-1, 1]:
			_add_box(parent, "Upright", Vector3(maxf(size.x,0.22), size.y, 0.20),
				Vector3(0, 0, float(signum) * (size.z * 0.5 - 0.1)), _shade(dark,key,signum+2))
		for y: float in [-0.5, 0.5]:
			_add_box(parent, "HorizontalRail", Vector3(maxf(size.x,0.22), 0.18, size.z),
				Vector3(0, y * (size.y - 0.18), 0), dark)
	# Visual-only short corner knee braces stay near posts, never cross the
	# player-sized opening or add a hidden collision barrier.
	if size.y > 1.4:
		for signum: int in [-1,1]:
			if along_x:
				var x: float = float(signum) * (size.x * 0.5 - 0.12)
				_brace(parent,"CornerKnee",Vector3(x,size.y*0.5-0.16,0),
					Vector3(x-float(signum)*minf(0.33,size.x*0.18),size.y*0.5-0.49,0),0.085,dark)
			else:
				var z: float = float(signum) * (size.z * 0.5 - 0.12)
				_brace(parent,"CornerKnee",Vector3(0,size.y*0.5-0.16,z),
					Vector3(0,size.y*0.5-0.49,z-float(signum)*minf(0.33,size.z*0.18)),0.085,dark)

static func _plaster(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	_add_box(parent, "NaturalLimeInfill", size * Vector3(0.95, 0.99, 0.95), Vector3.ZERO,
		_shade(base, key, 0))
	var timber := Color("62503d")
	if _axis_is_x(size):
		_add_box(parent, "InfillHead", Vector3(size.x, 0.10, size.z * 1.15),
			Vector3(0, size.y * 0.5 - 0.05, 0), timber)
		_add_box(parent, "InfillSill", Vector3(size.x, 0.09, size.z * 1.15),
			Vector3(0, -size.y * 0.5 + 0.05, 0), timber)
	else:
		_add_box(parent, "InfillHead", Vector3(size.x * 1.15, 0.10, size.z),
			Vector3(0, size.y * 0.5 - 0.05, 0), timber)
		_add_box(parent, "InfillSill", Vector3(size.x * 1.15, 0.09, size.z),
			Vector3(0, -size.y * 0.5 + 0.05, 0), timber)

static func _shutter(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	var boards: int = maxi(2, ceili(size.x / 0.13))
	for i: int in range(boards):
		var width: float = size.x / float(boards)
		_add_box(parent, "ShutterSlat", Vector3(width * 0.94, size.y, size.z),
			Vector3(-size.x * 0.5 + (float(i) + 0.5) * width, 0, 0), _shade(base,key,i))
	for y: float in [-0.28, 0.28]:
		_add_box(parent, "ShutterCrossbar", Vector3(size.x, 0.075, size.z * 1.35),
			Vector3(0, y * size.y, size.z * 0.28), base.darkened(0.22))
	# A few narrow black-iron hinge straps, never blue painted wood.
	for y: float in [-0.28,0.28]:
		_add_box(parent,"IronHingeStrap",Vector3(minf(size.x*0.5,0.26),0.043,0.020),
			Vector3(-size.x*0.23,y*size.y,size.z*0.53),Color("484942"))

static func _slate(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "OverlappedUnevenSlate"
	mesh.mesh = HMMasonryRoofMeshes.build("slate_course", size, key)
	var material: StandardMaterial3D = HMPhaseBMaterials.make_tinted("slate",base,true)
	mesh.material_override = material
	parent.add_child(mesh)
	# A proper opaque roof plane remains visible regardless of slate tile
	# winding and camera angle. It belongs to the SAME removable course ID.
	_add_box(parent, "ContinuousSlateBacking", Vector3(size.x, 0.07, size.z),
		Vector3(0, -0.085, 0), base.darkened(0.15))
	# A thin timber batten visible at each course's bottom edge.
	_add_box(parent, "RoofBatten", Vector3(size.x * 0.96, 0.05, 0.10),
		Vector3(0, -0.055, -size.z * 0.48), Color("55483b"))

static func _stonework(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	var along_x: bool = _axis_is_x(size)
	var rows: int = clampi(ceili(size.y / 0.34), 1, 6)
	var columns: int = clampi(ceili((size.x if along_x else size.z) / 0.72), 2, 14)
	var span: float = size.x if along_x else size.z
	for row: int in range(rows):
		# Hand-laid bond: alternating courses have offset joints and occasional
		# shorter terminal stones. Keep the underlying part collider unchanged.
		var stagger: float = 0.5 if row % 2 == 1 else 0.0
		for col: int in range(columns + 1):
			var unit: float = span / float(columns)
			var a: float = maxf(-span*0.5,-span*0.5+(float(col)-stagger)*unit)
			var b: float = minf(span*0.5,-span*0.5+(float(col+1)-stagger)*unit)
			if b-a < unit*0.20:
				continue
			var h: float = size.y / float(rows)
			var variation: float = 0.88 + float((col*5+row*7+absi(key.hash())%11)%9)*0.025
			var stone_size := Vector3((b-a)*0.965 if along_x else size.x*0.95,
				h*0.94, size.z*0.95 if along_x else (b-a)*0.965)
			var at := Vector3((a+b)*0.5 if along_x else 0.0,
				-size.y*0.5+(float(row)+0.5)*h,
				0.0 if along_x else (a+b)*0.5)
			var visual := MeshInstance3D.new()
			visual.name = "BondedStone_%d_%d" % [row,col]
			visual.mesh = HMMasonryRoofMeshes.build("irregular_stone",stone_size,key+":"+str(row)+":"+str(col))
			visual.material_override = HMPhaseBMaterials.make_tinted("stone",_shade(base,key,row*columns+col)*variation,true)
			visual.position = at
			parent.add_child(visual)

static func _brace(parent: Node3D, title: String, a: Vector3, b: Vector3,
		thickness: float, tint: Color) -> void:
	var vec: Vector3 = b-a
	if vec.length() < 0.05:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var wood := BoxMesh.new()
	wood.size = Vector3(thickness, vec.length(), thickness * 0.82)
	mesh.mesh = wood
	mesh.position = (a+b)*0.5
	mesh.quaternion = Quaternion(Vector3.UP,vec.normalized())
	mesh.material_override = _mat(tint)
	parent.add_child(mesh)

static func _beam_ends(parent: Node3D, size: Vector3, base: Color, key: String) -> void:
	# Iron pegging is a tiny noncolliding embellishment on the ONE parent beam.
	if maxf(size.x,maxf(size.y,size.z)) < 0.7:
		return
	var long_z: bool = size.z > size.x and size.z >= size.y
	for end_index: int in [-1,1]:
		var at: Vector3 = Vector3(0,0,float(end_index)*size.z*0.43) if long_z else Vector3(float(end_index)*size.x*0.43,0,0)
		var dims: Vector3 = Vector3(size.x*0.50,0.025,0.035) if long_z else Vector3(0.035,0.025,size.z*0.5)
		_add_box(parent,"HewnBeamIronPeg",dims,at,Color("484941"))

static func gable_trim(parent: Node3D, size: Vector3, key: String) -> void:
	# Pitched oak rake battens follow the lime panel. They are children of
	# the original removable infill body, NOT new salvage or support objects.
	var half_width: float = size.x*0.5
	var low_y: float = -size.y*0.5 + 0.07
	var peak_y: float = size.y*0.5 - 0.045
	for side: int in [-1,1]:
		var x: float = float(side)*half_width*0.94
		_brace(parent,"WeatheredOakRake_%d" % side,Vector3(x,low_y,size.z*0.56),
			Vector3(0.0,peak_y,size.z*0.56),0.12,Color("64503d"))
	_add_box(parent,"GableCollar",Vector3(size.x*0.83,0.10,0.10),
		Vector3(0,-size.y*0.18,size.z*0.58),Color("594837"))

static func add_frame_colliders(body: StaticBody3D, size: Vector3) -> void:
	# Visual openings must NOT remain occupied by an invisible solid wall.
	# Each physical timber member has a corresponding collision member.
	var along_x: bool = _axis_is_x(size)
	for signum: int in [-1, 1]:
		var half_pos: float = (size.x if along_x else size.z) * 0.5 - 0.10
		var at := Vector3(float(signum) * half_pos, 0, 0) if along_x else Vector3(0, 0, float(signum) * half_pos)
		var dims := Vector3(0.20, size.y, maxf(size.z, 0.22)) if along_x else Vector3(maxf(size.x,0.22),size.y,0.20)
		_add_collision(body, "TimberUprightCollision", dims, at)
	for y: float in [-0.5,0.5]:
		var dims := Vector3(size.x, 0.18, maxf(size.z,0.22)) if along_x else Vector3(maxf(size.x,0.22),0.18,size.z)
		_add_collision(body, "TimberRailCollision", dims, Vector3(0, y * (size.y - 0.18), 0))

static func _add_collision(body: StaticBody3D, name: String, size: Vector3, at: Vector3) -> void:
	var member := CollisionShape3D.new()
	member.name = name
	var collision := BoxShape3D.new()
	collision.size = size
	member.shape = collision
	member.position = at
	body.add_child(member)

static func gable_mesh(size: Vector3) -> ArrayMesh:
	# Triangular infill at the pitched end of a medieval gable.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = size.x * 0.5
	var h: float = size.y * 0.5
	var z: float = size.z * 0.5
	var a := Vector3(-w, -h, z)
	var b := Vector3(w, -h, z)
	var c := Vector3(0, h, z)
	var d := Vector3(-w, -h, -z)
	var e := Vector3(w, -h, -z)
	var f := Vector3(0, h, -z)
	_gable_triangle(surface, a, b, c)
	_gable_triangle(surface, e, d, f)
	_gable_triangle(surface, a, d, e)
	_gable_triangle(surface, a, e, b)
	_gable_triangle(surface, a, c, f)
	_gable_triangle(surface, a, f, d)
	_gable_triangle(surface, c, b, e)
	_gable_triangle(surface, c, e, f)
	surface.generate_normals()
	return surface.commit()

static func _gable_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v: Vector3 in [a,b,c]:
		surface.set_uv(Vector2(v.x, v.y))
		surface.add_vertex(v)
