extends SceneTree
## Programmatic production reference validity: geometry/colliders in the actual
## first-person world. Art approval and Windows GUI remain separately deferred.
var errors: Array[String] = []
func demand(ok: bool, why: String) -> void:
	if not ok:
		errors.append(why)
		push_error("REFERENCE ARCHITECTURE: " + why)
func _initialize() -> void:
	call_deferred("_check")
func _detail_meshes(node: Node) -> int:
	var total: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			total += 1
		total += _detail_meshes(child)
	return total
func _check() -> void:
	var cat := HMCatalog.new()
	demand(cat.load_all(), "catalog loads")
	var data: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	demand(HMBuildingPrefab.validate(data, cat).is_empty(), "reference cottage authentic parts")
	var building: Node3D = HMBuildingPrefab.build(data, cat)
	demand(building != null, "reference cottage instantiates")
	if building == null:
		quit(1)
		return
	root.add_child(building)
	var front: HMInspectTarget = null
	var roof: HMInspectTarget = null
	for child: Node in building.get_children():
		if child is HMInspectTarget:
			var target: HMInspectTarget = child as HMInspectTarget
			if target.part_id == "fixture/house/front_infill": front = target
			if target.part_id == "fixture/house/slate_patch": roof = target
	demand(front != null and roof != null, "original interactive IDs preserved")
	if front != null:
		var hitboxes: int = 0
		for child: Node in front.get_children():
			if child is CollisionShape3D: hitboxes += 1
		demand(hitboxes == 9, "two real window openings and triangular end gable")
		demand(_detail_meshes(front) >= 20, "wall infill is not a single solid box")
	if roof != null:
		demand(_detail_meshes(roof) >= 4, "roof is meshed as slate and battens")
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	await physics_frame
	var district: HMBrinewickSites = stage.district_sites
	for group_id: String in ["district/old_warehouse", "district/expanded_warehouse"]:
		var group: Node3D = district.installation_nodes.get(group_id) as Node3D
		demand(group != null, "physical warehouse: "+group_id)
		if group == null: continue
		var detailed: int = 0
		var roofs: int = 0
		for child: Node in group.get_children():
			if child is HMInspectTarget:
				var part: HMInspectTarget = child as HMInspectTarget
				if part.get_node_or_null("ArchitecturalDetail") != null: detailed += 1
				if part.name.begins_with("Roof"):
					roofs += 1
					demand(absf(absf(part.rotation_degrees.z) - 27.0) < 0.15, "actual pitched roof")
		demand(detailed >= 40 and roofs >= 16, "warehouse has many detailed removable assemblies")
		for child: Node in group.get_children():
			if child is HMInspectTarget and child.name.begins_with("BackFrame"):
				var source: CollisionShape3D = child.get_node_or_null("CollisionShape3D") as CollisionShape3D
				demand(source != null and source.disabled, "frame no longer blocks visual openings")
				var members: int = 0
				for element: Node in child.get_children():
					if element is CollisionShape3D and element != source: members += 1
				demand(members == 4, "structural frame colliders match visible posts and rails")
				break
	# A new material detail node may not create extra salvageable IDs or outputs.
	var lifecycle := HMPartLifecycle.new()
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	demand(lifecycle.installed.size() == 345, "original 291 parts retained plus 54 catalogue-backed architectural members")
	var state: Dictionary = HMSaveState.fresh(cat)
	demand(state["world"]["outputs"].is_empty(), "architectural detailing does not auto-harvest")
	lifecycle.reconcile(state)
	demand(HMSaveState.validate(cat,state).is_empty(), "pre-existing save format remains valid")
	building.free()
	stage.free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_REFERENCE_ARCHITECTURE_OK")
		quit(0)
	else:
		quit(1)
