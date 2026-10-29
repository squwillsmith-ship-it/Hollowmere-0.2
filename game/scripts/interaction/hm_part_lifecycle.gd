class_name HMPartLifecycle
extends Node3D
## Reconcile saved authored part/output IDs to physical test-world geometry.
## No harvesting, collection, automatic release or support damage here.
var installed: Dictionary = {}
var recovered: Dictionary = {}
var scene_root: Node3D


func bind_stage(root: Node3D) -> void:
	scene_root = root
	installed.clear()
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var next: Node = queue.pop_front()
		if next is HMInspectTarget:
			var target: HMInspectTarget = next as HMInspectTarget
			assert(not installed.has(target.part_id), "Duplicate authored physical part ID")
			installed[target.part_id] = target
		for child: Node in next.get_children():
			queue.append(child)


func reconcile(state: Dictionary) -> void:
	if scene_root == null:
		return
	var world: Dictionary = state["world"]
	var parts: Dictionary = world["parts"]
	for part_id: Variant in installed:
		var body: HMInspectTarget = installed[part_id]
		var attached: bool = String(parts.get(part_id, {}).get("phase", "")) == "attached"
		body.visible = attached
		body.collision_layer = 1 if attached else 0
		body.collision_mask = 2 if attached else 0
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", not attached)
	var outputs: Dictionary = world["outputs"]
	for output_id: Variant in recovered.keys():
		if not outputs.has(output_id) or not ["world_released", "staged", "receiving_pad"].has(String(outputs[output_id].get("location", ""))):
			recovered[output_id].queue_free()
			recovered.erase(output_id)
	for output_id: Variant in outputs:
		var rec: Dictionary = outputs[output_id]
		if not ["world_released", "staged", "receiving_pad"].has(String(rec.get("location", ""))):
			continue
		if not recovered.has(output_id):
			recovered[output_id] = _spawn_output(rec)
		var item: HMRecoveredOutput = recovered[output_id]
		var saved_position: Array = rec.get("position", [0.0, 0.0, 0.0])
		item.position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))


func _spawn_output(rec: Dictionary) -> HMRecoveredOutput:
	var item := HMRecoveredOutput.new()
	item.name = "LooseOutput_" + String(rec["id"]).get_file()
	item.output_id = String(rec["id"])
	item.source_part_id = String(rec["source_part_id"])
	item.collision_layer = 1
	item.collision_mask = 2
	scene_root.add_child(item)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.29, 0.20, 0.27)
	var mat := StandardMaterial3D.new()
	var allocation: Dictionary = rec.get("allocation", {})
	if allocation.has("iron") or allocation.has("copper_bronze"):
		mat.albedo_color = Color("686a66")
	elif allocation.has("stone") or allocation.has("mineral_fill"):
		mat.albedo_color = Color("858579")
	elif allocation.has("fibres"):
		mat.albedo_color = Color("9b8964")
	else:
		mat.albedo_color = Color("795d43")
	mat.roughness = 0.86
	mesh.material = mat
	visual.mesh = mesh
	item.add_child(visual)
	var collider := CollisionShape3D.new()
	collider.name = "SolidCollision"
	var cube := BoxShape3D.new()
	cube.size = mesh.size
	collider.shape = cube
	item.add_child(collider)
	return item


func animate_work_impact(part_id: String) -> void:
	# Subcentimetre visual reaction only. Never move an authoritative collider,
	# part record or player camera while the work action is still in progress.
	var target: HMInspectTarget = installed.get(part_id, null) as HMInspectTarget
	if target == null or not target.visible:
		return
	var visual: MeshInstance3D
	var queue: Array[Node] = [target]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			visual = node as MeshInstance3D
			break
		for child: Node in node.get_children():
			queue.append(child)
	if visual == null or visual.has_meta("work_reaction_active"):
		return
	visual.set_meta("work_reaction_active", true)
	var original: Vector3 = visual.position
	var motion := visual.create_tween()
	motion.tween_property(visual, "position", original + Vector3(0, -0.018, 0), 0.055)
	motion.tween_property(visual, "position", original, 0.12)
	motion.tween_callback(func() -> void:
		if is_instance_valid(visual):
			visual.remove_meta("work_reaction_active"))


func animate_release(part_id: String) -> void:
	# A brief noncolliding projection of the actual removed member. The
	# existing transaction has already succeeded; the real part is hidden by
	# reconcile and only the canonical saved output becomes liftable.
	var target: HMInspectTarget = installed.get(part_id, null) as HMInspectTarget
	if target == null or not target.visible:
		return
	var ghost := Node3D.new()
	ghost.name = "TransientRelease_" + part_id.get_file()
	scene_root.add_child(ghost)
	ghost.global_transform = target.global_transform
	var body_inverse: Transform3D = target.global_transform.affine_inverse()
	var queue: Array[Node] = [target]
	var copied: int = 0
	while not queue.is_empty() and copied < 32:
		var node: Node = queue.pop_front()
		if node is MeshInstance3D:
			var original: MeshInstance3D = node as MeshInstance3D
			if original.visible and original.mesh != null:
				var piece := MeshInstance3D.new()
				piece.name = "VisualOnly_" + str(copied)
				piece.mesh = original.mesh
				piece.material_override = original.material_override
				piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				ghost.add_child(piece)
				piece.transform = body_inverse * original.global_transform
				copied += 1
		for child: Node in node.get_children():
			queue.append(child)
	if copied == 0:
		ghost.queue_free()
		return
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "position",
		ghost.position + Vector3(0.09, -0.18, 0.04), 0.30).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(ghost.queue_free)
