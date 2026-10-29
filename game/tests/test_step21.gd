extends SceneTree
## Pinned Windows + Linux Godot Step21 acceptance: texture import, shader
## mapping, prefab collider / stable ID unchanged, and existing save state.
var failures: Array[String] = []
func verify(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("STEP21 FAILED: " + detail)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var catalog := HMCatalog.new()
	verify(catalog.load_all(), "Catalog loads unchanged")
	for key: String in HMMaterialLibrary.MATERIALS:
		var material: StandardMaterial3D = HMMaterialLibrary.get_shared(key)
		verify(material != null, "Material exists: " + key)
		if material != null:
			verify(material.albedo_texture != null and material.roughness_texture != null, "Both maps present: " + key)
			verify(material.albedo_texture.get_width() == 512 and material.roughness_texture.get_height() == 512, "512px imported: " + key)
			verify(material.metallic == 0.0 and material.roughness > 0.8, "Matte nonmetal surface: " + key)
			verify(HMMaterialLibrary.get_shared(key) == material, "Reuses shared material: " + key)
	verify(HMMaterialLibrary.get_shared("rough_stone") == null, "Step22 stone still separate")
	var swatch: PackedScene = load("res://assets/materials/step21/step21_material_swatches.glb") as PackedScene
	verify(swatch != null, "GLB glTF material sample imports")
	if swatch != null:
		var sample: Node3D = swatch.instantiate() as Node3D
		verify(sample != null and sample.get_child_count() > 0, "GLB geometry available")
		sample.free()
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	var part_ids_before: Array[String] = []
	for row: Variant in manifest["parts"]:
		part_ids_before.append(String(row["id"]))
	verify(HMBuildingPrefab.validate(manifest, catalog).is_empty(), "Unchanged manifest remains valid")
	var built: Node3D = HMBuildingPrefab.build(manifest, catalog)
	verify(built != null, "Textured engineering cottage compiles")
	if built != null:
		root.add_child(built)
		var found: Dictionary = {}
		var bound: Dictionary = {}
		var collision_count: int = 0
		for body: Node in built.get_children():
			if body is HMInspectTarget:
				found[String(body.part_id)] = true
				for geom: Node in body.get_children():
					if geom is CollisionShape3D:
						collision_count += 1
					if geom is MeshInstance3D:
						var mat: StandardMaterial3D = geom.material_override as StandardMaterial3D
						verify(mat != null, "Every part mesh has a material")
						if mat != null and HMMaterialLibrary.supports(String(mat.resource_name).trim_prefix("HM21_")):
							bound[mat.resource_name] = true
		verify(found.size() == part_ids_before.size(), "All original and appended independent part IDs")
		for id: String in part_ids_before:
			verify(found.has(id), "Original authored ID preserved: " + id)
		verify(collision_count > 6, "Collision bodies remain separate")
		verify(bound.has("HM21_aged_timber") and bound.has("HM21_weathered_timber") and bound.has("HM21_dark_timber"), "Three timber materials visibly assigned")
		verify(bound.has("HM21_cream_infill"), "Cream plaster PBR now applied to removable infill")
		var scenery: Node = built.get_node_or_null("NonSalvageableFixtureScenery")
		verify(scenery != null and scenery.get_child_count() == 1, "Only non-salvage packed earth footprint remains")
		var old_state: Dictionary = HMSaveState.fresh(catalog)
		verify(HMSaveState.validate(catalog, old_state).is_empty(), "Old save schema still valid")
		built.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP21_TEST_OK")
		quit(0)
	else:
		quit(1)