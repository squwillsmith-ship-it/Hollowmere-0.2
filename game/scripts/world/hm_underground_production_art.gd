class_name HMUndergroundProductionArt
extends Node3D
## Phase E/F visual architecture over established protected collision.
## No physical/interactive targets, part IDs, save fields or road grades change.
## Details occupy the wall margins and high timber spans; paths remain authored
## in HMUndergroundSites. Godot engine tests inspect counts and physics.
var beam_count: int = 0
var iron_count: int = 0
var stone_count: int = 0
var finish_material: StandardMaterial3D

func build(underground: HMUndergroundSites) -> void:
    if finish_material != null:
        return
    finish_material = StandardMaterial3D.new()
    finish_material.vertex_color_use_as_albedo = true
    finish_material.roughness = 0.94
    finish_material.metallic = 0.0
    finish_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _listening_gallery(underground.locations["well_listening"])
    _mine_gallery(underground.locations["mine_seal"])
    _undercroft(underground.locations["undercroft"])
    _bell_frame(underground.locations["bell_house"])
    _tidal_work(underground.locations["containment_machine"],
        underground.locations["tide_outfall"], underground.locations["escape_berth"])
    set_meta("art_noncolliding", true)
    set_meta("authored_phase_e_beams", beam_count)
    set_meta("authored_phase_e_iron", iron_count)
    set_meta("authored_phase_e_stone", stone_count)

func _timber(title: String, a: Vector3, b: Vector3, width: float,
        thickness: float, variation: int = 0) -> void:
    _piece(title, a, b, width, thickness,
        variation, "timber")

func _metal(title: String, a: Vector3, b: Vector3, width: float,
        thickness: float, variation: int = 0) -> void:
    _piece(title, a, b, width, thickness,
        variation, "iron")

func _stone(title: String, a: Vector3, b: Vector3, width: float,
        thickness: float, variation: int = 0) -> void:
    _piece(title, a, b, width, thickness,
        variation, "stone")

func _piece(title: String, a: Vector3, b: Vector3, width: float,
        thickness: float, variation: int, kind: String) -> void:
    var direction: Vector3 = b - a
    var length: float = direction.length()
    if length < 0.05:
        return
    var item := MeshInstance3D.new()
    item.name = title
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.UP, direction / length)
    item.mesh = _octagonal_beam(length, width, thickness, title.hash()+variation,
        Color("574736") if kind == "timber" else
        (Color("4b514e") if kind == "iron" else Color("777163")))
    item.material_override = finish_material
    item.set_meta("protected_non_salveable_art", true)
    add_child(item)
    match kind:
        "timber": beam_count += 1
        "iron": iron_count += 1
        "stone": stone_count += 1

static func _octagonal_beam(length: float, width: float, depth: float,
        seed: int, tint: Color) -> ArrayMesh:
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(seed) + 17031
    var hx: float = width * 0.5
    var hz: float = depth * 0.5
    var bevel: float = minf(width, depth) * rng.randf_range(0.12, 0.24)
    # Uneven octagonal grain catches side light with 1B facets. The optional
    # stone/iron/wood material tone is in the vertex data, not a box texture.
    var profile: Array[Vector2] = [
        Vector2(-hx + bevel, -hz), Vector2(hx - bevel, -hz),
        Vector2(hx, -hz + bevel), Vector2(hx, hz - bevel),
        Vector2(hx - bevel, hz), Vector2(-hx + bevel, hz),
        Vector2(-hx, hz - bevel), Vector2(-hx, -hz + bevel)]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j: int in range(8):
        var k: int = (j+1)%8
        var low_a := Vector3(profile[j].x, -length*0.5, profile[j].y)
        var low_b := Vector3(profile[k].x, -length*0.5, profile[k].y)
        var top_a := Vector3(profile[j].x, length*0.5, profile[j].y)
        var top_b := Vector3(profile[k].x, length*0.5, profile[k].y)
        var tone: Color = tint * rng.randf_range(0.82, 1.08)
        _triangle(st,low_a,top_a,top_b,tone)
        _triangle(st,low_a,top_b,low_b,tone.darkened(0.025))
        _triangle(st,Vector3(0,length*0.5,0),top_a,top_b,tint.lightened(0.08))
        _triangle(st,Vector3(0,-length*0.5,0),low_b,low_a,tint.darkened(0.18))
    return st.commit()

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        tint: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for vertex: Vector3 in [a,b,c]:
        st.set_color(tint)
        st.set_normal(normal)
        st.add_vertex(vertex)

func _listening_gallery(at: Vector3) -> void:
    # Each braced threshold has a real opening; timber stays at existing
    # collision wall margins, not across the traversable floor.
    for n: int in range(3):
        var z: float = at.z + 4.2 - float(n)*4.0
        for side: float in [-1.0,1.0]:
            var x: float = at.x + side*3.68
            _timber("ListeningOakPost_%d_%d"%[n,int(side)],
                Vector3(x,4.25,z),Vector3(x,7.55,z),0.31,0.25,n)
            _timber("ListeningKneeBrace_%d_%d"%[n,int(side)],
                Vector3(x,6.50,z),Vector3(x-side*0.95,7.63,z),
                0.15,0.16,n)
            _stone("SaltWornPilaster_%d_%d"%[n,int(side)],
                Vector3(at.x+side*3.82,5.1,z-0.37),
                Vector3(at.x+side*3.82,6.72,z-0.37),0.20,0.12,n)
        _timber("ListeningCeilingTie_%d"%n,
            Vector3(at.x-3.69,7.66,z),Vector3(at.x+3.69,7.66,z),
            0.30,0.28,n)
    # Cold iron lamps are unlit here; auditory evidence leads instead.
    for n: int in range(3):
        _metal("UnlitListeningBracket_%d"%n,
            Vector3(at.x-3.55,5.65,at.z+2.0-float(n)*2.8),
            Vector3(at.x-3.18,5.65,at.z+2.0-float(n)*2.8),
            0.09,0.09,n)

func _mine_gallery(seal: Vector3) -> void:
    var z: float = seal.z
    for n: int in range(5):
        var x: float = 191.8+float(n)*5.5
        # The existing fully colliding rock shell remains untouched. Frames
        # are close to the shell with a 3.5m player-clear central passage.
        for side: float in [-1.0,1.0]:
            var wall_z: float = z+side*1.94
            _timber("GalleryStanchion_%d_%d"%[n,int(side)],
                Vector3(x,6.28,wall_z),Vector3(x,9.25,wall_z),
                0.32,0.30,n)
            _timber("GalleryHaunch_%d_%d"%[n,int(side)],
                Vector3(x,8.12,wall_z),Vector3(x,9.35,z+side*1.05),
                0.20,0.22,n)
            _metal("OxidisedStrap_%d_%d"%[n,int(side)],
                Vector3(x,8.83,wall_z-side*0.13),
                Vector3(x,9.12,wall_z-side*0.13),
                0.035,0.08,n)
        _timber("GalleryHewnTie_%d"%n,Vector3(x,9.35,z-1.94),
            Vector3(x,9.35,z+1.94),0.32,0.29,n)
    for n: int in range(9):
        var x: float = 191.2+float(n)*3.15+0.17*sin(float(n)*2.31)
        # Bare mining face, not regular laid masonry.
        for side: float in [-1.0,1.0]:
            _stone("GalleryToolScars_%d_%d"%[n,int(side)],
                Vector3(x,7.9,z+side*1.95),
                Vector3(x+0.30+0.07*float(n%3),8.36,z+side*1.95),
                0.10,0.045,n)

func _undercroft(at: Vector3) -> void:
    for n: int in range(3):
        var z: float = at.z-2.6+float(n)*2.6
        for side: float in [-1.0,1.0]:
            var x: float = at.x+side*4.05
            _stone("UndercroftPier_%d_%d"%[n,int(side)],
                Vector3(x,10.1,z),Vector3(x,11.87,z),0.32,0.33,n)
            _stone("UndercroftSpringer_%d_%d"%[n,int(side)],
                Vector3(x,11.63,z),Vector3(x-side*0.72,12.02,z),
                0.29,0.26,n)
        # Ribs follow the same two-piece pitch as the *physical* vault.
        # A previous full-width straight tie sat visibly across the crown,
        # creating a false low beam even when the collision roof was fixed.
        for side: int in [-1,1]:
            _stone("UndercroftRakedRib_%d_%d"%[n,side],
                Vector3(at.x+float(side)*3.92,11.74,z),
                Vector3(at.x,12.43,z),0.17,0.15,n)
    # Suggest an intentionally emptied book chest, not an invented person.
    _timber("StudyChestLid",at+Vector3(-3.15,0.4,1.8),
        at+Vector3(-2.08,0.4,1.8),0.12,0.56)
    _metal("StudyChestCatch",at+Vector3(-2.6,0.37,1.6),
        at+Vector3(-2.6,0.55,1.6),0.08,0.10)

func _bell_frame(at: Vector3) -> void:
    # Architectural braces remain outside the central lowering mechanism.
    for side: float in [-1.0,1.0]:
        var x: float = at.x+side*3.12
        _timber("SeaWeatheredBellStrut_%d"%int(side),
            Vector3(x,2.5,at.z-3.05),
            Vector3(x-side*1.0,4.42,at.z-3.05),0.24,0.21)
        _metal("BellYokeClamp_%d"%int(side),
            Vector3(at.x+side*1.52,5.15,at.z),
            Vector3(at.x+side*1.52,5.52,at.z),0.10,0.12)

func _tidal_work(machine: Vector3, outlet: Vector3, berth: Vector3) -> void:
    for n: int in range(6):
        var a: float = TAU*float(n)/6.0
        _timber("RatchetSpoke_%d"%n,
            machine+Vector3(0,1.52,1.0),
            machine+Vector3(cos(a)*0.84,1.52,1.0+sin(a)*0.84),
            0.15,0.15,n)
    _metal("CounterweightChain",machine+Vector3(0,0.8,-0.65),
        machine+Vector3(0,2.3,-0.65),0.07,0.08)
    for n: int in range(5):
        var x: float = outlet.x-2.8+float(n)*1.15
        _stone("OutfallRoughBed_%d"%n,
            Vector3(x,outlet.y+0.92,outlet.z-1.8),
            Vector3(x+0.32,outlet.y+1.02,outlet.z-1.8),
            0.27,0.16,n)
    # Visible cut-rope evidence, with no unapproved confirmation of Mara.
    _timber("BerthManualMooring",berth+Vector3(-2.9,1.10,2.2),
        berth+Vector3(-2.9,2.35,2.2),0.26,0.25)
    _metal("BerthOarlock",berth+Vector3(3.9,1.55,0.7),
        berth+Vector3(4.08,1.76,0.7),0.10,0.10)
