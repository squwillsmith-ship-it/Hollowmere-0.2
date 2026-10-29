class_name HMUndergroundMasonry
extends Node3D
## Art-pass masonry only. Every course is generated into one ArrayMesh per
## pre-existing protected collider; neither salvage IDs nor physics change.
## Staggered courses and broken faces retain the approved 1B faceted style,
## with subtle 1C salt-weathering rather than regular brick wallpaper.
var clad_bodies: int = 0
var stones: int = 0

func build(underground: HMUndergroundSites, material: Material) -> void:
	if clad_bodies != 0:
		return
	for section: Node in underground.get_children():
		if not section is Node3D or section == self:
			continue
		for child: Node in section.get_children():
			var body: StaticBody3D = child as StaticBody3D
			if body == null or not _needs_masonry(String(body.name)):
				continue
			var original: MeshInstance3D
			for mesh_child: Node in body.get_children():
				var candidate: MeshInstance3D = mesh_child as MeshInstance3D
				if candidate != null and candidate.mesh is BoxMesh:
					original = candidate
					break
			if original == null:
				continue
			var dimensions: Vector3 = (original.mesh as BoxMesh).size
			if dimensions.y < 0.52 or maxf(dimensions.x, dimensions.z) < 0.45:
				continue
			var source_material: StandardMaterial3D = original.material_override as StandardMaterial3D
			var local_stone: Color = source_material.albedo_color if source_material != null else Color("7a766a")
			var mesh: ArrayMesh = _build_courses(dimensions, String(body.name), local_stone)
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var cladding := MeshInstance3D.new()
			cladding.name = "IrregularSaltWeatheredStoneCourses"
			cladding.mesh = mesh
			cladding.material_override = material
			body.add_child(cladding)
			clad_bodies += 1

static func _needs_masonry(name: String) -> bool:
	# Rough mine and listening-gallery rock is *not* course-laid masonry.
	return (name.begins_with("WellStone_") or name.begins_with("BellHouseWeatheredPier_")
		or name.begins_with("BellHouseBrokenCap_")
		or name.begins_with("BellHouseSideLintel_")
		or name.begins_with("BellHouseRearLintel")
		or name.begins_with("PermanentInnerSeal")
		or name.begins_with("StoneCounterweightBed")
		or name.begins_with("DrainageWingWall_")
		or name.begins_with("LowStoneListeningAperture"))

func _build_courses(dims: Vector3, name: String, stone_tone: Color) -> ArrayMesh:
	var along_x: bool = dims.x >= dims.z
	var surface_width: float = dims.x if along_x else dims.z
	var surface_height: float = dims.y
	var columns: int = clampi(ceili(surface_width / 1.16), 1, 48)
	var rows: int = clampi(ceili(surface_height / 0.72), 1, 16)
	var cell_w: float = surface_width / float(columns)
	var cell_h: float = surface_height / float(rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(name.hash()) + 8442
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1, 1]:
		for row: int in range(rows):
			# Half-course offsets imitate short, hand-dressed irregular stones.
			var course_offset: float = -0.5 * cell_w if row % 2 == 1 else 0.0
			for col: int in range(columns + 1):
				var left: float = -surface_width * 0.5 + float(col) * cell_w + course_offset
				var right: float = minf(left + cell_w, surface_width * 0.5)
				left = maxf(left, -surface_width * 0.5)
				if right - left < cell_w * 0.22:
					continue
				var bottom: float = -surface_height * 0.5 + float(row) * cell_h
				var top: float = bottom + cell_h
				var mortar: float = minf(0.036,cell_h * 0.11)
				var w: float = rng.randf_range(0.010,0.055)
				var h: float = rng.randf_range(0.006,0.034)
				var u0: float = left + mortar + w
				var u1: float = right - mortar - w * 0.35
				var v0: float = bottom + mortar + h * 0.5
				var v1: float = top - mortar - h
				if u1 <= u0 or v1 <= v0:
					continue
				var elevation: float = rng.randf_range(0.018,0.055)
				var panel: float = (dims.z if along_x else dims.x) * 0.5
				var back: float = float(side) * (panel + 0.005)
				var front: float = float(side) * (panel + elevation)
				var shade: float = rng.randf_range(0.75, 1.07)
				var tint: Color = stone_tone * Color(shade,shade * rng.randf_range(0.982,1.008),
					shade * rng.randf_range(0.956,0.99))
				# Uneven lower/top edges break the artificial mathematical grid.
				var a: Vector3 = _point(along_x, u0, v0, front, side)
				var b: Vector3 = _point(along_x, u1, v0 + h, front + float(side)*0.018, side)
				var c: Vector3 = _point(along_x, u1 - w*0.3, v1, front, side)
				var d: Vector3 = _point(along_x, u0 + w*0.4, v1 - h*0.5, front, side)
				var centre := (a + b + c + d) * 0.25
				centre += Vector3(0,float(row % 3)*0.003,0)
				_emit(tool,a,b,centre,tint)
				_emit(tool,b,c,centre,tint.darkened(0.05))
				_emit(tool,c,d,centre,tint)
				_emit(tool,d,a,centre,tint.darkened(0.035))
				var aa: Vector3 = _point(along_x, u0, v0, back, side)
				var bb: Vector3 = _point(along_x, u1, v0 + h, back, side)
				var cc: Vector3 = _point(along_x, u1 - w*0.3, v1, back, side)
				var dd: Vector3 = _point(along_x, u0 + w*0.4, v1 - h*0.5, back, side)
				_emit(tool,aa,a,b,tint.darkened(0.16))
				_emit(tool,aa,b,bb,tint.darkened(0.16))
				_emit(tool,bb,b,c,tint.darkened(0.20))
				_emit(tool,bb,c,cc,tint.darkened(0.20))
				_emit(tool,cc,c,d,tint.darkened(0.11))
				_emit(tool,cc,d,dd,tint.darkened(0.11))
				_emit(tool,dd,d,a,tint.darkened(0.19))
				_emit(tool,dd,a,aa,tint.darkened(0.19))
				stones += 1
	return tool.commit()

static func _point(along_x: bool, u: float, v: float,
		depth: float, side: int) -> Vector3:
	# Winding is normalized by the material's double-sided culling; no 3D
	# collision exists on this decorative geometry.
	return Vector3(u, v, depth) if along_x else Vector3(depth, v, u)

static func _emit(tool: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, tint: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for position: Vector3 in [a,b,c]:
		tool.set_color(tint)
		tool.set_normal(normal)
		tool.add_vertex(position)
