class_name HMBuildingPrefab
extends RefCounted
## Step19 reusable, explicitly-authored modular building converter.
## Step20 uses fixture IDs already recognised by the versioned save schema.
## This script does NOT distribute outputs or advance salvage work.

const PALETTE: Dictionary = {
	"aged_timber": Color("7d6146"), "weathered_timber": Color("866a50"),
	"dark_timber": Color("554333"), "salt_grey_timber": Color("79716b"),
	"cream_infill": Color("c2b598"), "patched_infill": Color("c0b8a5"),
	"grey_slate": Color("676c6d"), "rough_stone": Color("868275"),
	"packed_earth": Color("776d5d"), "fibre": Color("9f9375")
}

static func read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func validate(manifest: Dictionary, catalog: HMCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (manifest.get("manifest_version", null) is int or manifest.get("manifest_version", null) is float) or int(manifest.get("manifest_version", 0)) != 1:
		errors.append("Unsupported prefab manifest revision")
	if String(manifest.get("id", "")).is_empty():
		errors.append("Building manifest has no stable ID")
	_validate_vector(manifest.get("origin", null), "Building origin", errors)
	var part_rows: Variant = manifest.get("parts", null)
	var scenery_rows: Variant = manifest.get("static_scenery", [])
	if not (part_rows is Array) or part_rows.is_empty():
		errors.append("Building parts must be a nonempty array")
		return errors
	if not (scenery_rows is Array):
		errors.append("Building scenery must be an array")
		return errors
	var found: Dictionary = {}
	for entry: Variant in part_rows:
		if not (entry is Dictionary):
			errors.append("Malformed part entry")
			continue
		var row: Dictionary = entry
		var id: String = String(row.get("id", ""))
		if id.is_empty() or found.has(id):
			errors.append("Missing or duplicate authored component: " + id)
		found[id] = true
		var authored: Dictionary = catalog.by_part_id(id)
		if authored.is_empty() or String(authored.get("building_id", "")) != String(manifest.get("building_id", "")) \
				or String(authored.get("site_id", "")) != String(manifest.get("site_id", "")):
			errors.append("Part ID not in original saved catalogue/building/site: " + id)
		var pieces: Variant = row.get("geometry", null)
		if not (pieces is Array) or pieces.is_empty():
			errors.append("Missing or malformed geometry for " + id)
			continue
		for geom: Variant in pieces:
			_validate_geometry(geom, errors)
	for geom: Variant in scenery_rows:
		_validate_geometry(geom, errors)
	return errors


static func _validate_vector(coords: Variant, label: String, errors: PackedStringArray,
		positive_size: bool = false) -> void:
	if not (coords is Array) or coords.size() != 3:
		errors.append(label + " must have exactly three numeric coordinates")
		return
	for n: Variant in coords:
		if not (n is float or n is int) or is_inf(float(n)) or is_nan(float(n)) \
				or absf(float(n)) > 100000.0 or (positive_size and float(n) <= 0.02):
			errors.append("Invalid " + label + " value")
			return


static func _validate_geometry(v: Variant, errors: PackedStringArray) -> void:
	if not (v is Dictionary):
		errors.append("Bad geometry entry")
		return
	var g: Dictionary = v
	if not ["box", "irregular_stone", "slate_course", "gable_panel"].has(String(g.get("shape", ""))):
		errors.append("Unknown geometry primitive")
	if not PALETTE.has(String(g.get("material", ""))):
		errors.append("Unregistered material surface")
	_validate_vector(g.get("size", null), "Geometry size", errors, true)
	_validate_vector(g.get("position", null), "Geometry position", errors)
	if g.has("rotation"):
		_validate_vector(g.get("rotation", null), "Geometry rotation", errors)

static func build(manifest: Dictionary, catalog: HMCatalog) -> Node3D:
	var problems: PackedStringArray = validate(manifest, catalog)
	if not problems.is_empty():
		push_error("Refusing invalid dismantling prefab: " + str(problems))
		return null
	var building := Node3D.new()
	building.name = String(manifest["id"]).replace("/", "_")
	var origin: Array = manifest["origin"]
	building.position = Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
	for row: Variant in manifest["parts"]:
		var part: Dictionary = row
		var body := HMInspectTarget.new()
		body.part_id = String(part["id"])
		body.name = body.part_id.get_file().to_pascal_case()
		body.collision_layer = 1
		body.collision_mask = 2
		building.add_child(body)
		for geom: Variant in part["geometry"]:
			_add_piece(body, geom)
		HMHeroBuildingSet.finish_cottage_part(body,body.part_id)
	# Scenery is deliberately not claimed as recoverable material. Remaining
	# environmental infill and floors need their own IDs in Step21–24.
	var scenery := Node3D.new()
	scenery.name = "NonSalvageableFixtureScenery"
	building.add_child(scenery)
	for geom: Variant in manifest.get("static_scenery", []):
		var holder := StaticBody3D.new()
		holder.name = String(geom.get("name", "Scenery"))
		holder.collision_layer = 1
		holder.collision_mask = 2
		scenery.add_child(holder)
		_add_piece(holder, geom)
	return building

static func _add_piece(body: StaticBody3D, geometry: Dictionary) -> void:
	var at: Array = geometry["position"]
	var dims: Array = geometry["size"]
	var size := Vector3(float(dims[0]), float(dims[1]), float(dims[2]))
	var offset := Vector3(float(at[0]), float(at[1]), float(at[2]))
	var rotations: Array = geometry.get("rotation", [0, 0, 0])
	var angle := Vector3(float(rotations[0]), float(rotations[1]), float(rotations[2]))
	var visual := MeshInstance3D.new()
	visual.name = String(geometry.get("name", "PartMesh"))
	var model: Mesh
	if String(geometry["shape"]) == "irregular_stone":
		model = HMMasonryRoofMeshes.build("irregular_stone", size, String(geometry.get("name", "stone")))
	elif String(geometry["shape"]) == "gable_panel":
		model = HMArchitecturalDetail.gable_mesh(size)
	elif String(geometry["shape"]) == "slate_course":
		model = HMMasonryRoofMeshes.build("slate_course", size, String(geometry.get("name", "roof")))
	else:
		var box := BoxMesh.new()
		box.size = size
		model = box
	var material: StandardMaterial3D = HMMaterialLibrary.get_shared(String(geometry["material"]))
	if material == null:
		# V03: palette-hued stone/slate faces get subtle neutral 1B/1C wear
		# overlays; existing Step21 timber/infill materials stay unchanged.
		var profile: String = "stone" if String(geometry["material"]) == "rough_stone" else ("slate" if String(geometry["material"]) == "grey_slate" else "")
		if not profile.is_empty():
			material = HMPhaseBMaterials.make_tinted(profile, PALETTE[String(geometry["material"])], String(geometry["shape"]) != "box")
		else:
			material = StandardMaterial3D.new()
			material.albedo_color = PALETTE[String(geometry["material"])]
			material.roughness = 0.94
	if String(geometry["shape"]) != "box":
		# Faceted materials can be viewed from either side while dismantling.
		material = material.duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if String(geometry["shape"]) != "gable_panel":
			material.vertex_color_use_as_albedo = true
	visual.material_override = material
	visual.mesh = model
	visual.position = offset
	visual.rotation_degrees = angle
	body.add_child(visual)
	# Gable rake and collar timbers belong to the existing infill salvage ID.
	# No freestanding visual pieces survive removal of their owning target.
	if String(geometry["shape"]) == "gable_panel":
		var rake := Node3D.new()
		rake.name = "GableRakeAndCollar"
		rake.position = offset
		rake.rotation_degrees = angle
		body.add_child(rake)
		HMArchitecturalDetail.gable_trim(rake, size, String(geometry.get("name", "Gable")))
	if geometry.has("detail_profile"):
		visual.visible = false
		var display := Node3D.new()
		display.name = "ArchitecturalDetail_" + visual.name
		display.position = offset
		display.rotation_degrees = angle
		body.add_child(display)
		HMArchitecturalDetail.decorate(display, size, PALETTE[String(geometry["material"])],
			String(geometry["detail_profile"]), visual.name)
	var collider := CollisionShape3D.new()
	collider.name = visual.name + "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = offset
	collider.rotation_degrees = angle
	body.add_child(collider)

static func _faceted_stone(size: Vector3) -> Mesh:
	# Eight planar sides, intentionally non-rectilinear silhouette; stable and
	# lightweight. UV-ready geometry; textured material pass belongs to Step22.
	var w: float = size.x * 0.5
	var h: float = size.y * 0.5
	var d: float = size.z * 0.5
	var corners: Array[Vector2] = [Vector2(-0.89 * w,-d),Vector2(0.36 * w,-0.97*d),
		Vector2(w,-0.80*d),Vector2(0.96*w,0.34*d),Vector2(0.77*w,d),
		Vector2(-0.25*w,0.90*d),Vector2(-w,0.65*d),Vector2(-0.95*w,-0.28*d)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(corners.size()):
		var next: int = (i + 1) % corners.size()
		var a := Vector3(corners[i].x, h, corners[i].y)
		var b := Vector3(corners[next].x, h, corners[next].y)
		var c := Vector3(corners[i].x,-h,corners[i].y)
		var e := Vector3(corners[next].x,-h,corners[next].y)
		_add_tri(surface, Vector3.ZERO + Vector3.UP*h, a, b)
		_add_tri(surface, a, c, e)
		_add_tri(surface, a, e, b)
		_add_tri(surface, Vector3.DOWN*h, e, c)
	surface.generate_normals()
	return surface.commit()

static func _add_tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v: Vector3 in [a, b, c]:
		surface.set_uv(Vector2(v.x, v.z))
		surface.add_vertex(v)