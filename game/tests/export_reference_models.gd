extends SceneTree
## Export exact visible in-engine architectural geometry, not concept artwork.
## Editable authoring source is the JSON profiles + typed Godot scripts; these
## GLBs are rebuildable interchange studies, not separate gameplay state.
func _initialize() -> void:
	call_deferred("_export")
func _collect_visible(node: Node, target: Node3D, inverse: Transform3D, visible_parent: bool = true) -> int:
	var visible_here: bool = visible_parent
	if node is Node3D:
		visible_here = visible_parent and (node as Node3D).visible
	if not visible_here:
		return 0
	var result: int = 0
	if node is MeshInstance3D:
		var original: MeshInstance3D = node as MeshInstance3D
		if original.mesh != null:
			var copy := MeshInstance3D.new()
			copy.name = "Mesh_" + str(target.get_child_count()).pad_zeros(4)
			copy.mesh = original.mesh
			copy.material_override = original.material_override
			target.add_child(copy)
			copy.transform = inverse * original.global_transform
			result += 1
	for child: Node in node.get_children():
		result += _collect_visible(child, target, inverse, visible_here)
	return result

func _export() -> void:
	var directory: String = OS.get_environment("HOLLOWMERE_REFERENCE_EXPORT_DIR")
	if directory.is_empty():
		push_error("Export directory must be explicit")
		quit(1)
		return
	var catalog := HMCatalog.new()
	if not catalog.load_all():
		quit(1)
		return
	var blueprint: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	var cottage: Node3D = HMBuildingPrefab.build(blueprint, catalog)
	if cottage == null:
		quit(1)
		return
	root.add_child(cottage)
	var village := HMBrinewickBlockout.new()
	village.spawn_exploration_player = false
	root.add_child(village)
	for key: String in ["cottage", "old_warehouse", "phase_ef_architecture", "chapel_finished_surfaces", "coastal_terrain", "inn_mine_landmarks"]:
		var source: Node3D
		match key:
			"cottage":
				source = cottage
			"old_warehouse":
				source = village.district_sites.installation_nodes["district/old_warehouse"] as Node3D
			"chapel_finished_surfaces":
				source = village.district_sites.installation_nodes["chapel/ordinary_hall"] as Node3D
			"coastal_terrain":
				source = village.get_node("Terraces") as Node3D
			"inn_mine_landmarks":
				source = village.get_node("InnAndMineOfficeArchitecture") as Node3D
			_:
				source = village.underground_sites.get_node(
					"FacetedUndergroundDetail/ProtectedUndergroundArchitecturalFinish") as Node3D
		if source == null:
			push_error("Missing source for reference asset: " + key)
			quit(1)
			return
		var study := Node3D.new()
		study.name = "HollowmereReference_" + key
		root.add_child(study)
		var meshes: int = _collect_visible(source, study, study.global_transform.affine_inverse())
		# Export complete authored reference groups, not only one sub-building
		# or the old terrain carrier; retain the original >=30 visible-mesh gate.
		if key == "chapel_finished_surfaces":
			for building_id: String in ["chapel/schoolroom_wing", "chapel/aldren_study"]:
				var chapel_part: Node3D = village.district_sites.installation_nodes[building_id] as Node3D
				meshes += _collect_visible(chapel_part, study, study.global_transform.affine_inverse())
		elif key == "coastal_terrain":
			for art_name: String in ["BrinewickFacetedGroundArt", "PhaseCGroundStratification", "BrinewickCoastalForeshore"]:
				var coastal_part: Node3D = village.get_node_or_null(art_name) as Node3D
				if coastal_part == null:
					push_error("Missing coastal artwork for reference export: " + art_name)
					quit(1)
					return
				meshes += _collect_visible(coastal_part, study, study.global_transform.affine_inverse())
		if meshes < 30:
			push_error("Reference GLB has too little authored source geometry: " + key)
			quit(1)
			return
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_scene(study, state) != OK:
			push_error("Godot glTF scene export failed: " + key)
			quit(1)
			return
		var output: String = directory.path_join("hollowmere-" + key + "-reference.glb")
		if document.write_to_filesystem(state, output) != OK:
			push_error("Godot GLB write failed: " + output)
			quit(1)
			return
		var file := FileAccess.open(output, FileAccess.READ)
		if file == null or file.get_length() < 2048:
			push_error("Godot GLB too small: " + output)
			quit(1)
			return
		if file.get_32() != 0x46546C67:
			push_error("Invalid glTF binary magic: " + output)
			quit(1)
			return
		var verify := GLTFState.new()
		if document.append_from_file(output, verify) != OK:
			push_error("GLB round-trip import failed: " + output)
			quit(1)
			return
		print("HOLLOWMERE_GLTF_REBUILT " + key + " " + str(meshes) + " meshes")
		study.free()
	cottage.free()
	village.free()
	print("HOLLOWMERE_REFERENCE_GLB_OK")
	quit(0)
