class_name HMG4ProtectedComposition
extends Node3D
## G4 atmospheric composition at seven existing narrative landmarks.
## This is visual architecture and quiet practical light ONLY: no new story
## flags, salvage IDs, collision, gameplay trigger, spooky silhouette,
## automatic discovery, encounter, voice or visible underground entity.
const GRANITE: Color = Color("777264")
const MOSS_STONE: Color = Color("64675e")
const OAK: Color = Color("554639")
const IRON: Color = Color("484b47")
const SALT: Color = Color("847868")
const ORDER: Array[String] = [
    "well_listening", "mine_seal", "undercroft", "bell_house",
    "containment_machine", "tide_outfall", "escape_berth"
]
var location_nodes: Dictionary={}
var detail_members: int=0
var practical_lights: int=0

func build(underground: HMUndergroundSites) -> void:
    if not location_nodes.is_empty():
        return
    for id: String in ORDER:
        if not underground.locations.has(id):
            push_error("G4 expected original protected landmark "+id)
            continue
        var at: Vector3=underground.locations[id]
        var group := Node3D.new()
        group.name="G4_"+id
        group.position=at
        group.set_meta("g4_original_protected_location",id)
        group.set_meta("g4_visual_only_never_story_or_salvage",true)
        underground.add_child(group)
        match id:
            "well_listening":
                _well(group)
            "mine_seal":
                _mine(group)
            "undercroft":
                _crypt(group)
            "bell_house":
                _bell(group)
            "containment_machine":
                _counterweight(group)
            "tide_outfall":
                _outfall(group)
            "escape_berth":
                _berth(group)
        location_nodes[id]=group
    set_meta("G4_PILOT_PROTECTED_SEVEN_SITES",location_nodes.size())
    set_meta("no_entity_or_auto_actions",true)

func _well(group: Node3D) -> void:
    # Shallow structural veins at the gallery wall margin. NO light beam
    # or object crosses the existing 3.3m descending path or well rim.
    for side: int in [-1,1]:
        for i: int in range(4):
            _block(group,Vector3(float(side)*3.72,1.36,-3.7+float(i)*2.5),
                Vector3(.10,.24,.77),MOSS_STONE,i*2+side+10)
        _beam(group,Vector3(float(side)*3.58,.32,-4.15),
            Vector3(float(side)*3.58,2.06,-4.15),.12,OAK)
    _beam(group,Vector3(-3.38,2.80,-1.0),
        Vector3(3.38,2.80,-1.0),.14,OAK)
    _light(group,Vector3(3.35,1.48,-2.2),Color("bb9c78"),.18,8.0)

func _mine(group: Node3D) -> void:
    # Location is the original seal approach; no geometry or light inside
    # the impassable seal, and no humanoid/object embodiment of the voice.
    for i: int in range(3):
        var x: float=-20.0+float(i)*6.6
        for side: int in [-1,1]:
            _beam(group,Vector3(x,.20,float(side)*2.12),
                Vector3(x,2.90,float(side)*2.12),.16,OAK)
            _block(group,Vector3(x,2.68,float(side)*2.05),
                Vector3(.42,.18,.72),GRANITE,i+side+9)
        _beam(group,Vector3(x,2.95,-1.98),
            Vector3(x,2.95,1.98),.16,OAK)
    for side: int in [-1,1]:
        _block(group,Vector3(-.90,1.45,float(side)*2.18),
            Vector3(.35,2.0,.24),MOSS_STONE,5+side)
    _light(group,Vector3(-16.8,2.1,1.83),Color("99866f"),.10,7.0)

func _crypt(group: Node3D) -> void:
    # Under the actual vault, stone springer margins only; keep the
    # restored passage / real-player camera clearance from prior QA.
    for i: int in range(5):
        var z: float=-2.3+float(i)*1.1
        for side: int in [-1,1]:
            _block(group,Vector3(float(side)*4.27,1.22,z),
                Vector3(.13,.22,.76),GRANITE,i*3+side+9)
    _beam(group,Vector3(-4.07,2.18,2.38),
        Vector3(-4.07,2.18,-2.38),.10,OAK)
    _light(group,Vector3(-3.82,1.82,-2.0),Color("b79a71"),.16,7.2)

func _bell(group: Node3D) -> void:
    # Damaged, open bell house must NOT get an enclosing new roof.
    for side: int in [-1,1]:
        _block(group,Vector3(float(side)*3.29,4.83,-3.27),
            Vector3(.91,.12,.57),GRANITE,side+9)
        _beam(group,Vector3(float(side)*2.98,4.76,-2.84),
            Vector3(float(side)*2.98,4.89,-.62),.11,OAK)

func _counterweight(group: Node3D) -> void:
    # Protected mechanism remains manually operated through original
    # task targets. Brackets do not add an interactable new gear.
    for side: int in [-1,1]:
        _beam(group,Vector3(float(side)*2.30,.15,-1.03),
            Vector3(float(side)*2.30,1.68,-1.03),.13,OAK)
        _block(group,Vector3(float(side)*2.29,1.64,-1.03),
            Vector3(.4,.13,.44),IRON,side+11)

func _outfall(group: Node3D) -> void:
    for side: int in [-1,1]:
        _block(group,Vector3(float(side)*4.17,.82,-1.68),
            Vector3(.62,.34,1.8),GRANITE,side+5)
        _block(group,Vector3(float(side)*4.04,1.13,-1.8),
            Vector3(.87,.14,1.1),MOSS_STONE,side+7)

func _berth(group: Node3D) -> void:
    # Open berth and cut rope should remain ambiguous evidence, not proof
    # of Mara's fate. Do not obscure boat, entry or any ending work target.
    for side: int in [-1,1]:
        _beam(group,Vector3(float(side)*4.28,.15,-2.70),
            Vector3(float(side)*4.28,1.23,-2.70),.13,OAK)
        _beam(group,Vector3(float(side)*4.28,1.22,-2.70),
            Vector3(float(side)*4.28,1.22,-1.53),.095,SALT)

func _block(parent: Node3D,pos: Vector3,size: Vector3,
        tint: Color,seed: int) -> void:
    var mesh:=MeshInstance3D.new()
    mesh.name="G4ArchitecturalFacet"
    var shape:=BoxMesh.new()
    shape.size=size
    mesh.mesh=shape
    mesh.position=pos
    mesh.rotation_degrees=Vector3(0,float((seed*17)%13-6),0)
    var surface:=StandardMaterial3D.new()
    surface.albedo_color=tint*(.92+.015*float(seed%7))
    surface.roughness=.97
    mesh.material_override=surface
    mesh.set_meta("noncolliding_visual_only",true)
    parent.add_child(mesh)
    detail_members+=1

func _beam(parent: Node3D,a: Vector3,b: Vector3,
        thickness: float,tint: Color) -> void:
    var mesh:=MeshInstance3D.new()
    mesh.name="G4ProtectedTimberJoinery"
    var length: float=(b-a).length()
    var shape:=BoxMesh.new()
    shape.size=Vector3(thickness,length,thickness*.86)
    mesh.mesh=shape
    mesh.position=(a+b)*.5
    mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    var finish:=StandardMaterial3D.new()
    finish.albedo_color=tint
    finish.roughness=.96
    mesh.material_override=finish
    mesh.set_meta("noncolliding_visual_only",true)
    parent.add_child(mesh)
    detail_members+=1

func _light(parent: Node3D,at: Vector3,tint: Color,
        energy: float,range_m: float) -> void:
    var lamp:=OmniLight3D.new()
    lamp.name="G4IndirectPracticalBounce"
    lamp.position=at
    lamp.light_color=tint
    lamp.light_energy=energy
    lamp.omni_range=range_m
    lamp.shadow_enabled=false
    lamp.set_meta("visual_only_no_story_gate",true)
    parent.add_child(lamp)
    practical_lights+=1
