class_name HMMasonryRoofMeshes
extends RefCounted
## Step22: reusable procedural low-poly meshes. Metre scale, Y-up.
## One generated surface is tied to one independently dismantlable authored part.
## No automatic salvage, economy records, or implicit part IDs.

static func build(kind: String, size: Vector3, key: String) -> ArrayMesh:
	if kind == "irregular_stone":
		return stone(size, key)
	if kind == "slate_course":
		return roof_course(size, key)
	return null


static func stone(size: Vector3, key: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var phase: int = absi(key.hash()) % 7
	var outline: Array[Vector2] = [
		Vector2(-0.94, -0.91), Vector2(-0.32, -1.0), Vector2(0.62, -0.89),
		Vector2(1.0, -0.28), Vector2(0.87, 0.83), Vector2(0.15, 0.97),
		Vector2(-0.70, 0.84), Vector2(-1.0, 0.12)]
	var ytop: float = size.y * 0.49
	var ybottom: float = -size.y * 0.5
	for i: int in range(outline.size()):
		var j: int = (i + 1) % outline.size()
		var a := Vector3(outline[i].x * size.x * 0.5, ytop - float((i + phase) % 3) * size.y * 0.035, outline[i].y * size.z * 0.5)
		var b := Vector3(outline[j].x * size.x * 0.5, ytop - float((j + phase) % 3) * size.y * 0.035, outline[j].y * size.z * 0.5)
		var c := Vector3(a.x * 0.94, ybottom, a.z * 0.94)
		var d := Vector3(b.x * 0.94, ybottom, b.z * 0.94)
		var shade: float = 0.84 + 0.025 * float((phase + i * 3) % 6)
		var tint := Color(shade, shade * 0.99, shade * 0.96)
		_tri(surface, Vector3(0, ytop - size.y * 0.07, 0), b, a, tint)
		_tri(surface, a, b, c, tint)
		_tri(surface, b, d, c, tint)
		_tri(surface, Vector3(0, ybottom, 0), c, d, tint)
	surface.generate_normals()
	return surface.commit()


static func roof_course(size: Vector3, key: String) -> ArrayMesh:
	# Low-poly overlapping rows, each deterministic but visually nonuniform.
	# Individual roof tiles are geometry; the authored roof course is one logical lot.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var phase: int = absi(key.hash()) % 11
	var rows: int = maxi(3, roundi(size.z / 0.64))
	var columns: int = maxi(3, roundi(size.x / 0.65))
	var cell_x: float = size.x / float(columns)
	var cell_z: float = size.z / float(rows)
	for row: int in range(rows):
		for col: int in range(columns):
			var k: int = phase + row * 7 + col * 11
			var dx: float = (float(k % 5) - 2.0) * 0.014
			var x0: float = -size.x * 0.5 + float(col) * cell_x + dx
			var z0: float = -size.z * 0.5 + float(row) * cell_z
			var x1: float = minf(size.x * 0.5, x0 + cell_x * 1.025)
			var z1: float = minf(size.z * 0.5, z0 + cell_z * 1.17)
			var y: float = 0.018 * float(row % 2) + float(k % 4) * 0.006
			var tint: float = 0.77 + float(k % 7) * 0.026
			var color := Color(tint, tint * 0.99, tint * 0.96)
			var a := Vector3(x0, y, z0)
			var b := Vector3(x0, y + 0.01, z1)
			var c := Vector3(x1, y, z0)
			var d := Vector3(x1, y + 0.01, z1)
			_tri(surface, a, b, c, color)
			_tri(surface, c, b, d, color)
	surface.generate_normals()
	return surface.commit()


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_color(color)
		surface.set_uv(Vector2(point.x, point.z))
		surface.add_vertex(point)
