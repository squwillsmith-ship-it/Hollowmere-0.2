extends SceneTree
## Physical first-person route check: actual raycast through two inhabited
## structure entrances, with door curtain manually removed before entry.
var failures: Array[String] = []
func demand(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error("REFERENCE ACCESS: " + reason)
func _initialize() -> void:
	call_deferred("_run")
func _cast(world: Node3D, a: Vector3, b: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(a,b)
	params.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_ray(params)
func _run() -> void:
	var catalog := HMCatalog.new()
	demand(catalog.load_all(), "catalog loads")
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	for tick: int in range(4):
		await physics_frame
	var warehouse: Vector3 = stage.site_nodes["brinewick/site_04"].position
	var a: Vector3 = warehouse + Vector3(0,1.7,5.4)
	var b: Vector3 = warehouse + Vector3(0,1.7,1.0)
	demand(_cast(stage,a,b).is_empty(), "warehouse loading doorway is traversable, no invisible wall collider")
	var cottage: Vector3 = stage.site_nodes["brinewick/site_07"].position
	var front: Vector3 = cottage + Vector3(0,1.5,3.25)
	var rear: Vector3 = cottage + Vector3(0,1.5,1.1)
	var blocked: Dictionary = _cast(stage, front, rear)
	demand(blocked.get("collider") is HMInspectTarget, "cottage cloth is an actual obstructing target")
	var cloth: HMInspectTarget = blocked.get("collider") as HMInspectTarget
	demand(cloth != null and cloth.part_id == "fixture/house/curtain", "cottage entrance only blocked by removable cloth")
	var state: Dictionary = HMSaveState.fresh(catalog)
	var work: Dictionary = HMTransactions.apply(catalog,state,{
		"transaction_id":"reference_cottage_manual/01","op":"partial_work",
		"part_id":"fixture/house/curtain","cycles":1,"user_initiated":true})
	demand(bool(work.get("ok",false)), "hand removal work")
	if bool(work.get("ok",false)):
		state=work["state"]
		var done: Dictionary = HMTransactions.apply(catalog,state,{
			"transaction_id":"reference_cottage_manual/02","op":"release",
			"part_id":"fixture/house/curtain","access_aids":[],
			"spawn_origin":[cottage.x, cottage.y+0.7, cottage.z+3.2],"user_initiated":true})
		demand(bool(done.get("ok",false)), "safe manual removal of hanging doorway cloth")
		if bool(done.get("ok",false)): state=done["state"]
	var life := HMPartLifecycle.new()
	stage.add_child(life)
	life.bind_stage(stage)
	life.reconcile(state)
	for tick: int in range(3):
		await physics_frame
	demand(_cast(stage,front,rear).is_empty(), "first-person path into cottage opens after actual manual removal")
	demand(HMSaveState.validate(catalog,state).is_empty(), "clue/entrance removal conserves all salvage")
	stage.free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_REFERENCE_ACCESS_OK")
		quit(0)
	else:
		quit(1)
