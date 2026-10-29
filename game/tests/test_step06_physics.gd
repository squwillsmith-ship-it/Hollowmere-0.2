extends SceneTree
## Executable physics integration test: actual movement, floor collision and pause.
## Only counts if run by pinned Godot; Python cannot execute these assertions.

var failed: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed.append(description)
		push_error("STEP06 PHYSICS FAILED: " + description)


func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Scene loads")
	if scene == null:
		quit(1)
		return
	var app: Node = scene.instantiate()
	get_root().add_child(app)
	await process_frame
	var player: HMFirstPerson = app.get("player") as HMFirstPerson
	_check(player != null, "Player exists")
	if player == null:
		quit(1)
		return
	var initial: Vector3 = player.global_position
	for i: int in range(12):
		await physics_frame
	_check(initial.distance_to(player.global_position) < 0.01, "Player remains stopped in title")
	app.call("show_stage")
	for i: int in range(15):
		await physics_frame
	Input.action_press("hm_forward")
	var before: Vector3 = player.global_position
	for i: int in range(65):
		await physics_frame
	Input.action_release("hm_forward")
	_check(player.global_position.z < before.z - 1.5, "Holding W moves forward through physics")
	_check(absf(player.global_position.y - 0.9) < 0.3, "Capsule rests on collision ground")
	app.call("pause_stage")
	var paused: Vector3 = player.global_position
	for i: int in range(10):
		await physics_frame
	_check(paused.distance_to(player.global_position) < 0.02, "Paused actor cannot drift")
	app.call("resume_stage")
	Input.action_press("hm_jump")
	for i: int in range(6):
		await physics_frame
	Input.action_release("hm_jump")
	_check(player.global_position.y > paused.y + 0.01, "Space produces a physical jump")
	app.call("show_menu")
	app.free()
	if failed.is_empty():
		print("HOLLOWMERE_STEP06_PHYSICS_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP06_PHYSICS_FAIL " + str(failed))
		quit(1)
