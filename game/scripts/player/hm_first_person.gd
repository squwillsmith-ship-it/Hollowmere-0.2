class_name HMFirstPerson
extends CharacterBody3D
## Step 6: player-driven first-person navigation only. No salvage/inspection automation.
## This actor owns the camera, but does not own economy, tools or save files.

@export_range(0.1, 12.0, 0.1) var walk_speed: float = 4.4
@export_range(0.1, 12.0, 0.1) var sprint_speed: float = 6.0
@export_range(0.1, 40.0, 0.1) var ground_acceleration: float = 20.0
@export_range(0.1, 40.0, 0.1) var ground_deceleration: float = 24.0
@export_range(0.1, 20.0, 0.1) var air_acceleration: float = 6.0
@export_range(0.1, 30.0, 0.1) var gravity_strength: float = 15.0
@export_range(0.1, 15.0, 0.1) var jump_velocity: float = 4.6
@export_range(0.0005, 0.008, 0.0001) var mouse_sensitivity: float = 0.0019
@export_range(30.0, 89.0, 1.0) var pitch_limit_degrees: float = 82.0

@onready var head: Node3D = $Head
@onready var view_camera: Camera3D = $Head/Camera3D

var movement_enabled: bool = false
var loaded_speed_multiplier: float = 1.0
var carrying_load: bool = false


func _ready() -> void:
	HMPlayerInput.ensure_defaults()
	view_camera.current = true


func enable_movement(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		apply_look_delta(motion.relative)


func apply_look_delta(relative_pixels: Vector2) -> void:
	# Yaw belongs to the collider; pitch belongs only to the child head.
	rotate_y(-relative_pixels.x * mouse_sensitivity)
	var limit: float = deg_to_rad(pitch_limit_degrees)
	head.rotation.x = clampf(head.rotation.x - relative_pixels.y * mouse_sensitivity, -limit, limit)


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		return
	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("hm_jump"):
			velocity.y = jump_velocity

	var axes: Vector2 = Input.get_vector("hm_left", "hm_right", "hm_forward", "hm_backward")
	var running: bool = Input.is_action_pressed("hm_sprint")
	var speed: float = sprint_speed if running else walk_speed
	if carrying_load:
		speed = walk_speed * minf(1.0, loaded_speed_multiplier)
	var desired: Vector3 = desired_velocity(axes, rotation.y, speed)
	var blend: float = ground_acceleration if is_on_floor() else air_acceleration
	if axes.is_zero_approx() and is_on_floor():
		blend = ground_deceleration
	velocity.x = move_toward(velocity.x, desired.x, blend * delta)
	velocity.z = move_toward(velocity.z, desired.z, blend * delta)
	move_and_slide()


static func desired_velocity(axes: Vector2, yaw_radians: float, speed: float) -> Vector3:
	# Normalises diagonal inputs; never gives extra movement speed for W+D.
	var flat: Vector3 = Vector3(axes.x, 0.0, axes.y)
	if flat.length_squared() > 1.0:
		flat = flat.normalized()
	return Basis(Vector3.UP, yaw_radians) * flat * maxf(0.0, speed)


func read_pose() -> Dictionary:
	# Fits Step 5's player carrier save schema. The act of saving remains
	# an explicit user transaction in a later integration step.
	return {"position": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y}


func restore_pose(pose: Dictionary) -> bool:
	var raw_position: Variant = pose.get("position", null)
	var raw_yaw: Variant = pose.get("yaw", null)
	if not (raw_position is Array) or raw_position.size() != 3:
		return false
	if not (raw_yaw is int or raw_yaw is float):
		return false
	var coords: Array = raw_position
	for value: Variant in coords:
		if not (value is float or value is int):
			return false
		if is_inf(float(value)) or is_nan(float(value)):
			return false
	var yaw: float = float(raw_yaw)
	if is_inf(yaw) or is_nan(yaw):
		return false
	global_position = Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
	rotation.y = yaw
	velocity = Vector3.ZERO
	return true
