extends SceneTree
## Actual Godot CharacterBody3D slide/ground-following traversal on Phase E
## authored routes. Scripted inputs are a reproducible physics acceptance
## test, not a human-operated full campaign playthrough.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _walk(actor: HMFirstPerson, start_foot: Vector3, end_foot: Vector3,
		label: String) -> void:
	actor.enable_movement(false)
	actor.global_position = start_foot + Vector3(0,1.03,0)
	actor.velocity = Vector3.ZERO
	var floor_frames: int = 0
	var reached: bool = false
	for step: int in range(330):
		await physics_frame
		var horizontal := Vector3(end_foot.x-actor.global_position.x,0,
			end_foot.z-actor.global_position.z)
		if horizontal.length() < 0.8:
			reached = true
			break
		var dir: Vector3 = horizontal.normalized()
		var downward: float = maxf(-8.0, actor.velocity.y - actor.gravity_strength/60.0)
		actor.velocity = Vector3(dir.x*2.8, downward,dir.z*2.8)
		actor.move_and_slide()
		if actor.is_on_floor():
			floor_frames += 1
	if not reached:
		for collision_index: int in range(actor.get_slide_collision_count()):
			var hit: KinematicCollision3D = actor.get_slide_collision(collision_index)
			var collider_name: String = String((hit.get_collider() as Node).get_path()) if hit.get_collider() is Node else "unknown"
			print("HOLLOWMERE_BLOCKER ",label," collider=",collider_name,
				" normal=",hit.get_normal()," point=",hit.get_position())
		failures.append("Actual character did not finish " + label +
			" reached="+str(actor.global_position))
	if floor_frames < 65:
		failures.append("Actual character had insufficient grounded traversal on " +
			label + " grounded_frames="+str(floor_frames))
	if absf(actor.global_position.y-(end_foot.y+0.9)) > 1.45:
		failures.append("Character landed at incorrect level after " + label +
			" got="+str(actor.global_position.y)+" target="+str(end_foot.y+0.9))
	print("HOLLOWMERE_PHYSICAL_ROUTE ",label," reached=",reached,
		" floor_frames=",floor_frames," end=",actor.global_position)

func _run() -> void:
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	var actor: HMFirstPerson = load("res://scenes/player.tscn").instantiate()
	stage.add_child(actor)
	await physics_frame
	await _walk(actor,Vector3(79.0,8.3,-45.7),Vector3(79.0,4.14,-57.6),"well_listening")
	await _walk(actor,Vector3(176.6,12.95,-24.0),Vector3(188.4,6.9,-24.0),"mine_gallery")
	await _walk(actor,Vector3(128.5,13.08,-16.2),Vector3(128.5,11.9,-9.0),"chapel_undercroft")
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_PLAYER_ROUTE_MOTION_OK")
		quit(0)
	else:
		for line: String in failures:
			push_error("HOLLOWMERE_ROUTE_FAILURE: " + line)
		quit(1)
