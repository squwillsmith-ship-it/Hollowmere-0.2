class_name HMToolViewModel
extends Node3D
## Camera-space low-poly physical tools. PURE visual feedback: not a work timer,
## interaction ray or tool unlock. Player's input remains the only authority.
const WOOD: Color = Color("67523f")
const IRON: Color = Color("777773")
const STEEL: Color = Color("858985")
const CLOTH: Color = Color("a89d83")
var models: Dictionary = {}
var equipped: String = "hands"
var swing_tween: Tween
var base_pose: Vector3 = Vector3(0.39, -0.31, -0.67)

func _ready() -> void:
	name = "FirstPersonPhysicalTool"
	position = base_pose
	for id: String in ["hands", "claw_hammer", "crowbar", "pickaxe", "saw"]:
		var model := Node3D.new()
		model.name = id
		add_child(model)
		models[id] = model
		_build_tool(model, id)
	select_tool("hands")

func _part(root: Node3D, label: String, size: Vector3, at: Vector3,
		color: Color, angle: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var primitive := BoxMesh.new()
	primitive.size = size
	mesh.mesh = primitive
	mesh.position = at
	mesh.rotation_degrees = angle
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.91
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)

func _build_tool(model: Node3D, id: String) -> void:
	# A gloved hand and a distinct real tool silhouette for each capability.
	_part(model, "Sleeve", Vector3(0.18, 0.28, 0.23),
		Vector3(0.11, -0.20, 0.16), WOOD, Vector3(12, 0, 28))
	_part(model, "Palm", Vector3(0.14, 0.15, 0.17),
		Vector3(0.06, -0.04, 0.07), CLOTH)
	match id:
		"claw_hammer":
			_part(model, "Handle", Vector3(0.085, 0.66, 0.075),
				Vector3(0, 0.22, 0), WOOD, Vector3(0, 0, -16))
			_part(model, "ClawHammerHead", Vector3(0.42, 0.105, 0.12),
				Vector3(-0.09, 0.51, 0), IRON, Vector3(0, 0, -16))
			_part(model, "Claw", Vector3(0.15, 0.065, 0.08),
				Vector3(-0.33, 0.55, 0), STEEL, Vector3(0, 0, -26))
		"crowbar":
			_part(model, "ForgedBar", Vector3(0.085, 0.81, 0.08),
				Vector3(0, 0.23, 0), IRON, Vector3(0, 0, -22))
			_part(model, "PryingFoot", Vector3(0.25, 0.07, 0.12),
				Vector3(-0.13, 0.59, 0), IRON, Vector3(0, 0, -16))
		"pickaxe":
			_part(model, "PickShaft", Vector3(0.085, 0.85, 0.08),
				Vector3(0, 0.29, 0), WOOD, Vector3(0, 0, 12))
			_part(model, "Pickhead", Vector3(0.64, 0.10, 0.13),
				Vector3(0, 0.65, 0), IRON, Vector3(0, 0, 12))
			_part(model, "PickPoint", Vector3(0.23, 0.055, 0.08),
				Vector3(0.40, 0.67, 0), STEEL, Vector3(0, 0, -9))
		"saw":
			_part(model, "SawGrip", Vector3(0.14, 0.37, 0.18),
				Vector3(-0.02, 0.11, 0), WOOD, Vector3(0, 0, -17))
			_part(model, "SawBlade", Vector3(0.63, 0.27, 0.045),
				Vector3(0.29, 0.32, 0), STEEL, Vector3(0, 0, 11))
			for i: int in range(9):
				_part(model, "Tooth_" + str(i), Vector3(0.045, 0.065, 0.05),
					Vector3(float(i) * 0.07 + 0.015, 0.17, 0), IRON)
		_:
			_part(model, "Fingers", Vector3(0.15, 0.11, 0.16),
				Vector3(0.04, 0.04, -0.055), CLOTH)

func select_tool(id: String) -> void:
	if not models.has(id):
		return
	equipped = id
	for name: String in models:
		(models[name] as Node3D).visible = name == id
	position = base_pose
	rotation = Vector3.ZERO

func play_action(kind: String, success: bool) -> void:
	if swing_tween != null and swing_tween.is_running():
		swing_tween.kill()
	position = base_pose
	rotation = Vector3.ZERO
	var duration: float = 0.20 if kind != "saw" else 0.32
	var pitch: float = 0.15 if success else 0.035
	var direction: float = -1.0 if kind == "crowbar" else 1.0
	swing_tween = create_tween()
	swing_tween.tween_property(self, "rotation:x", direction * pitch, duration * 0.44)
	swing_tween.parallel().tween_property(self, "position:z", base_pose.z - 0.055, duration * 0.44)
	swing_tween.tween_property(self, "rotation:x", 0.0, duration * 0.56)
	swing_tween.parallel().tween_property(self, "position", base_pose, duration * 0.56)
