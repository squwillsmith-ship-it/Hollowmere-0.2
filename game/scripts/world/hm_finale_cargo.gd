class_name HMFinaleCargo
extends Node3D
## Visual, non-autonomous heavy hauling sledge. Always moves with player input.
## The durable haul state belongs to save.progress.finale_actions, not this node.
var bell_mesh: MeshInstance3D

func _ready() -> void:
    name = "HandDrawnBellSledge"
    position = Vector3(0.0, -0.92, -2.05)
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color("62503a")
    wood.roughness = 0.93
    var bronze := StandardMaterial3D.new()
    bronze.albedo_color = Color("625841")
    bronze.metallic = 0.62
    bronze.roughness = 0.49
    for side: float in [-0.8, 0.8]:
        _box("Runner", Vector3(0.18,0.22,2.1), Vector3(side,-0.5,0), wood)
    for z: float in [-0.65,0.7]:
        _box("CrossTie", Vector3(1.95,0.20,0.20), Vector3(0,-0.36,z), wood)
    bell_mesh = MeshInstance3D.new()
    bell_mesh.name = "CradledHarbourBell"
    var bell := CylinderMesh.new()
    bell.top_radius = 0.42
    bell.bottom_radius = 0.73
    bell.height = 0.98
    bell.radial_segments = 12
    bell_mesh.mesh = bell
    bell_mesh.position = Vector3(0,0.17,0)
    bell_mesh.material_override = bronze
    add_child(bell_mesh)
    _box("PaddedHarness", Vector3(1.6,0.11,0.14), Vector3(0,0.43,0),wood)
    visible = false

func _box(title: String, dims: Vector3, at: Vector3, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = title
    var box := BoxMesh.new()
    box.size = dims
    mesh.mesh = box
    mesh.position = at
    mesh.material_override = material
    add_child(mesh)
