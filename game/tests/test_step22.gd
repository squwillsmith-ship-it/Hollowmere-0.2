extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_test")
func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error("STEP22: " + reason)
func run_test() -> void:
	var catalog := HMCatalog.new()
	check(catalog.load_all(), "Catalog loads")
	var a: ArrayMesh = HMMasonryRoofMeshes.stone(Vector3(1.5, 0.6, 0.7), "stone-a")
	var b: ArrayMesh = HMMasonryRoofMeshes.roof_course(Vector3(2.6, 0.15, 5.0), "roof-a")
	check(a != null and a.get_surface_count() == 1, "Faceted stone mesh is generated")
	check(b != null and b.get_surface_count() == 1, "Overlapped slate roof mesh is generated")
	if a != null and b != null:
		check(a.surface_get_array_len(0) >= 48, "Masonry contains independently faceted sides")
		check(b.surface_get_array_len(0) >= 150, "Roof contains individually shaped tiles")
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	check(HMBuildingPrefab.validate(manifest, catalog).is_empty(), "Asset shapes pass strict manifest validation")
	var built: Node3D = HMBuildingPrefab.build(manifest, catalog)
	check(built != null, "Cottage imports new stone/roof meshes")
	if built != null:
		root.add_child(built)
		for body: Node in built.get_children():
			if body is HMInspectTarget:
				for child: Node in body.get_children():
					if child is MeshInstance3D and (String(child.name).begins_with("WestRoof") or String(child.name).begins_with("Foundation")):
						check(child.mesh is ArrayMesh, "Nonuniform roof and masonry actually used by prefab")
						check(child.material_override != null, "Facet colours have a material")
		built.queue_free()
		await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP22_TEST_OK")
		quit(0)
	else:
		quit(1)
