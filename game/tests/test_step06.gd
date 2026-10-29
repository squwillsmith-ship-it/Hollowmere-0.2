extends SceneTree
## Run: godot --headless --path game --script res://tests/test_step06.gd
## Godot runtime integration checks; MUST actually run before claiming engine success.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _check(truth: bool, message: String) -> void:
	if not truth:
		failures.append(message)
		push_error("STEP06 TEST FAILED: " + message)


func _run_all() -> void:
	var app_scene: PackedScene = load("res://scenes/main.tscn")
	_check(app_scene != null, "Main scene loads")
	if app_scene == null:
		quit(1)
		return
	var app: Node = app_scene.instantiate()
	get_root().add_child(app)
	await process_frame
	var controller: HMFirstPerson = app.get("player") as HMFirstPerson
	_check(controller != null, "Player controller created")
	if controller == null:
		quit(1)
		return
	_check(controller.get_node_or_null("Head/Camera3D") is Camera3D, "Eye camera exists")
	_check(controller.get_node_or_null("BodyCollision") is CollisionShape3D, "Capsule collision exists")
	_check(app.get("current_view") == 0 and not controller.movement_enabled, "Starts in title menu")
	for name: String in ["hm_forward", "hm_backward", "hm_left", "hm_right", "hm_sprint", "hm_jump"]:
		_check(InputMap.has_action(name), "Input action exists: " + name)

	var plain: Vector3 = HMFirstPerson.desired_velocity(Vector2(0.0, -1.0), 0.0, 4.0)
	_check(plain.is_equal_approx(Vector3(0.0, 0.0, -4.0)), "Forward faces -Z")
	var diagonal: Vector3 = HMFirstPerson.desired_velocity(Vector2(1.0, -1.0), 0.0, 4.4)
	_check(is_equal_approx(diagonal.length(), 4.4), "Diagonal movement stays at declared speed")
	var turned: Vector3 = HMFirstPerson.desired_velocity(Vector2(0.0, -1.0), PI / 2.0, 4.0)
	_check(turned.is_equal_approx(Vector3(-4.0, 0.0, 0.0)), "Yaw rotates forward movement")

	controller.apply_look_delta(Vector2(0.0, -100000.0))
	_check(is_equal_approx(controller.head.rotation.x, deg_to_rad(controller.pitch_limit_degrees)), "Upward pitch is clamped")
	controller.apply_look_delta(Vector2(0.0, 100000.0))
	_check(is_equal_approx(controller.head.rotation.x, -deg_to_rad(controller.pitch_limit_degrees)), "Downward pitch is clamped")
	var initial_pose: Dictionary = controller.read_pose()
	_check(controller.restore_pose(initial_pose), "Accepts own save-compatible pose")
	_check(not controller.restore_pose({"position": [0.0, 1.0], "yaw": 0.0}), "Rejects incomplete position")
	_check(not controller.restore_pose({"position": [INF, 1.0, 0.0], "yaw": 0.0}), "Rejects invalid position")

	app.call("show_stage")
	_check(app.get("current_view") == 1 and controller.movement_enabled, "Entering gameplay activates movement")
	app.call("pause_stage")
	_check(app.get("current_view") == 2 and not controller.movement_enabled, "Pause stops movement")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause releases cursor")
	app.call("resume_stage")
	_check(app.get("current_view") == 1 and controller.movement_enabled, "Resume reactivates movement")
	app.call("show_menu")
	_check(app.get("current_view") == 0 and not controller.movement_enabled, "Return to title disables controller")

	var solid_count: int = 0
	var yard: Node3D = app.get("stage") as Node3D
	for child: Node in yard.get_children():
		if child is StaticBody3D:
			solid_count += 1
			_check(child.get_node_or_null("SolidCollision") is CollisionShape3D, "Static visual includes collider")
	_check(solid_count >= 15, "Test yard contains physical floor and obstacles")
	app.free()
	if failures.is_empty():
		print("HOLLOWMERE_STEP06_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP06_TEST_FAILED count=", failures.size())
		quit(1)
