class_name HMUndergroundDressing
extends Node3D
## Deterministic modular weathering pass on protected engineering collision.
## One low-poly faceted mesh per authored structural body, not hundreds of
## extra physics bodies. Never changes saved dismantling IDs or safe routes.
const ROCK_BASE: Color = Color("6d695d")
const CUT_BASE: Color = Color("807b6d")
const WOOD_BASE: Color = Color("5a4939")
var grain_texture: Texture2D
var dressed: int = 0
var light_count: int = 0

func decorate(underground: HMUndergroundSites) -> void:
    var nodes: Array[Node] = [underground]
    while not nodes.is_empty():
        var current: Node = nodes.pop_back()
        for child: Node in current.get_children():
            nodes.append(child)
        var body: StaticBody3D = current as StaticBody3D
        if body == null:
            continue
        # Runtime-created Godot children use auto-generated @MeshInstance3D@N
        # names, not a stable "MeshInstance3D" node path.
        var visual: MeshInstance3D
        for mesh_child: Node in body.get_children():
            var candidate: MeshInstance3D = mesh_child as MeshInstance3D
            if candidate != null and candidate.mesh is BoxMesh:
                visual = candidate
                break
        if visual == null:
            continue
        var size: Vector3 = (visual.mesh as BoxMesh).size
        # Keep authored collision unchanged while replacing every sterile
        # cube with a closed low-poly faceted mesh and uneven per-face tones.
        var material: StandardMaterial3D = visual.material_override as StandardMaterial3D
        var tone: Color = material.albedo_color if material != null else ROCK_BASE
        var replacement := MeshInstance3D.new()
        replacement.name = "WeatheredLowPolySkin"
        replacement.mesh = _facet_box(size, String(body.name).hash(), tone)
        var finish := StandardMaterial3D.new()
        finish.vertex_color_use_as_albedo = true
        finish.roughness = 0.94
        finish.metallic = 0.0
        finish.uv1_triplanar = true
        finish.uv1_scale = Vector3(0.34,0.34,0.34)
        finish.albedo_texture = _grain()
        finish.cull_mode = BaseMaterial3D.CULL_BACK
        replacement.material_override = finish
        visual.visible = false
        body.add_child(replacement)
        dressed += 1
    _well_stones(underground)
    _mine_fittings(underground)
    _undercroft_props(underground)
    _bell(underground)
    var overlay := HMUndergroundMasonry.new()
    overlay.name = "ArticulatedStoneCourses"
    add_child(overlay)
    var finish := StandardMaterial3D.new()
    finish.vertex_color_use_as_albedo = true
    finish.roughness = 0.95
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    finish.uv1_triplanar = true
    finish.uv1_scale = Vector3(0.42,0.42,0.42)
    finish.albedo_texture = _grain()
    overlay.build(underground, finish)
    set_meta("masonry_bodies",overlay.clad_bodies)
    set_meta("masonry_stones",overlay.stones)
    # Bespoke wall-margin supports, capped gallery ribs and tidal hand-work
    # detail. Separate noncolliding meshes preserve the tested floor/first-hit
    # physics and the 291 independently salvageable catalogue components.
    var architectural := HMUndergroundProductionArt.new()
    architectural.name = "ProtectedUndergroundArchitecturalFinish"
    add_child(architectural)
    architectural.build(underground)
    set_meta("production_beams",architectural.beam_count)
    set_meta("production_iron",architectural.iron_count)
    set_meta("production_stone",architectural.stone_count)

static func _facet_box(size: Vector3, seed: int, tone: Color) -> ArrayMesh:
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(seed) + 4513
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Each face is subdivided along its own axes, with small stone offsets.
    # Flat normals deliberately retain 1B angular facets and 1C chips.
    for face: int in range(6):
        var width: float = size.x if face < 2 else (size.z if face < 4 else size.x)
        var height: float = size.y if face < 4 else size.z
        var cols: int = clampi(ceili(width / 1.25), 1, 24)
        var rows: int = clampi(ceili(height / 0.95), 1, 14)
        for j: int in range(rows):
            for i: int in range(cols):
                var x0: float = float(i) / float(cols) - 0.5
                var x1: float = float(i+1) / float(cols) - 0.5
                var y0: float = float(j) / float(rows) - 0.5
                var y1: float = float(j+1) / float(rows) - 0.5
                var inset: float = rng.randf_range(-0.045,0.045)
                var p0: Vector3 = _face_point(face,size,x0,y0,inset)
                var p1: Vector3 = _face_point(face,size,x1,y0,inset)
                var p2: Vector3 = _face_point(face,size,x1,y1,inset + rng.randf_range(-0.08,0.08))
                var p3: Vector3 = _face_point(face,size,x0,y1,inset)
                var color: Color = tone * rng.randf_range(0.79,1.12)
                _tri(builder,p0,p1,p2,color)
                _tri(builder,p0,p2,p3,color.darkened(0.035))
    return builder.commit()

static func _face_point(face: int, size: Vector3, u: float, v: float, offset: float) -> Vector3:
    match face:
        0: return Vector3(u*size.x, v*size.y, size.z*0.5 + offset)
        1: return Vector3(-u*size.x, v*size.y, -size.z*0.5 - offset)
        2: return Vector3(size.x*0.5 + offset, v*size.y, -u*size.z)
        3: return Vector3(-size.x*0.5 - offset, v*size.y, u*size.z)
        4: return Vector3(u*size.x, size.y*0.5 + offset, -v*size.z)
        _: return Vector3(u*size.x, -size.y*0.5 - offset, v*size.z)

static func _tri(tool: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,shade: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for point: Vector3 in [a,b,c]:
        tool.set_color(shade)
        tool.set_normal(normal)
        tool.add_vertex(point)

func _decorative_box(parent: Node3D,title: String,size:Vector3,at:Vector3,tone:Color) -> void:
    var geometry := MeshInstance3D.new()
    geometry.name = title
    geometry.mesh = _facet_box(size, title.hash(), tone)
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.95
    geometry.material_override = material
    geometry.position = at
    parent.add_child(geometry)

func _lantern(parent: Node3D, at: Vector3, warmth: float = 1.0,
        reach: float = 11.0, unique_name: String = "ShieldedOilLantern") -> void:
    var lamp := OmniLight3D.new()
    lamp.name = unique_name
    lamp.position = at
    lamp.light_color = Color("efbd79")
    lamp.light_energy = 3.1 * warmth
    lamp.omni_range = reach
    lamp.shadow_enabled = false
    parent.add_child(lamp)
    var cover := MeshInstance3D.new()
    var glass := SphereMesh.new()
    glass.radius = 0.11
    glass.height = 0.20
    cover.mesh = glass
    cover.position = at
    var soot := StandardMaterial3D.new()
    soot.albedo_color = Color("bc8a50")
    soot.emission_enabled = true
    soot.emission = Color("77512d")
    soot.emission_energy_multiplier = 0.9
    cover.material_override = soot
    parent.add_child(cover)
    light_count += 1

func _grain() -> Texture2D:
    if grain_texture != null:
        return grain_texture
    var noise := FastNoiseLite.new()
    noise.seed = 4185
    noise.frequency = 0.11
    noise.fractal_octaves = 3
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    var img := Image.create_empty(128,128,false,Image.FORMAT_RGB8)
    for y: int in range(128):
        for x: int in range(128):
            var r: float = clampf(0.93 + noise.get_noise_2d(float(x),float(y))*0.075,0.85,0.99)
            img.set_pixel(x,y,Color(r,r*0.993,r*0.970))
    grain_texture = ImageTexture.create_from_image(img)
    return grain_texture

func _well_stones(underground: HMUndergroundSites) -> void:
    var parent: Node3D = underground.get_node("WellAndListeningGallery")
    var point: Vector3 = underground.locations["well"]
    # Unequal stone coping, oak windlass and a chain/rope with no vertical drop.
    for n: int in range(14):
        var angle: float = TAU * float(n)/14.0
        var at: Vector3 = point + Vector3(cos(angle)*1.55,1.17,sin(angle)*1.55)
        _decorative_box(parent,"ChippedCoping_%d"%n, Vector3(0.65,0.18,0.40),at,CUT_BASE)
    _decorative_box(parent,"WellWinchDrum",Vector3(2.75,0.28,0.3),
        point+Vector3(0,2.25,0),WOOD_BASE)
    for t: int in range(15):
        var z: float = -59.5 - float(t)*0.52
        var jitter: float = sin(float(t)*2.13)*0.34
        _decorative_box(parent,"Gravel_%d"%t,Vector3(0.35,0.09,0.42),
            Vector3(point.x+jitter,4.22,z),ROCK_BASE)
    _lantern(parent,underground.locations["well_listening"]+Vector3(-2.7,2.0,-1.7),0.7)

func _mine_fittings(underground: HMUndergroundSites) -> void:
    var parent: Node3D = underground.get_node("MineApproachOfficeAndSealedGallery")
    var seal: Vector3 = underground.locations["mine_seal"]
    # Sleepers and separated track iron clarify depth without inviting sale.
    for n: int in range(20):
        var x: float = 188.3 + float(n)*1.55
        _decorative_box(parent,"OakSleeper_%02d"%n,Vector3(0.23,0.10,2.75),
            Vector3(x,6.2,seal.z),WOOD_BASE)
    for side: float in [-0.72,0.72]:
        _decorative_box(parent,"RailHead",Vector3(30,0.10,0.10),
            Vector3(202.0,6.30,seal.z+side),Color("57584f"))
    for index: int in range(5):
        var x: float = 190.0 + float(index)*6.2
        _decorative_box(parent,"WedgeTop_%d"%index,
            Vector3(0.32,0.30,4.0),Vector3(x,9.45,seal.z),WOOD_BASE)
    _lantern(parent,Vector3(seal.x-14,8.2,seal.z+1.4),0.55)
    _lantern(parent,Vector3(seal.x-25,8.2,seal.z-1.0),0.45)

func _undercroft_props(underground: HMUndergroundSites) -> void:
    var parent: Node3D = underground.get_node("UndercroftBellAndContainment")
    var middle: Vector3 = underground.locations["undercroft"]
    for index: int in range(8):
        _decorative_box(parent,"ScatteredStone_%02d"%index,
            Vector3(0.43+float(index%3)*0.12,0.14,0.32),
            middle+Vector3(cos(float(index)*1.57)*3.3,0.16,sin(float(index)*1.6)*2.4),ROCK_BASE)
    # Previously one nominal "wall rib" stood at x=-0.55, inside the
    # player's central sightline. Keep visible articulation at the real
    # wall margins instead of camouflaging the obstruction with camera tricks.
    for side: float in [-1.0,1.0]:
        for bay: int in range(2):
            _decorative_box(parent,"UndercroftWallRib_%d_%d"%[int(side),bay],
                Vector3(0.20,1.65,0.30),
                middle+Vector3(side*4.16,0.96,-2.2+float(bay)*3.0),
                CUT_BASE.darkened(0.13))
    _lantern(parent,middle+Vector3(0.7,2.12,0.3),0.65)

func _bell(underground: HMUndergroundSites) -> void:
    var parent: Node3D = underground.get_node("UndercroftBellAndContainment")
    var at: Vector3 = underground.locations["bell_house"]+Vector3(0,3.52,0)
    var bell := MeshInstance3D.new()
    bell.name = "CastBellBody"
    var cast := CylinderMesh.new()
    cast.top_radius = 0.52
    cast.bottom_radius = 0.85
    cast.height = 1.3
    cast.radial_segments = 13
    bell.mesh = cast
    bell.position = at
    var bronze := StandardMaterial3D.new()
    # Tarnished bronze: a bell should read as a solid dark silhouette
    # against pale stone, not as another yellow floodlit ceiling fragment.
    bronze.albedo_color = Color("665941")
    bronze.roughness = 0.76
    bronze.metallic = 0.35
    bell.material_override = bronze
    parent.add_child(bell)
    _decorative_box(parent,"SaltEncrustedBellYoke",Vector3(1.75,0.23,0.35),
        at+Vector3(0,0.88,0),WOOD_BASE)
    # Legible small clapper below the casting; non-colliding protected art.
    var clapper := MeshInstance3D.new()
    clapper.name = "CastBellClapper"
    var iron := SphereMesh.new()
    iron.radius = 0.17
    iron.height = 0.32
    clapper.mesh = iron
    clapper.position = at + Vector3(0,-0.73,0)
    var iron_finish := StandardMaterial3D.new()
    iron_finish.albedo_color = Color("484843")
    iron_finish.metallic = 0.24
    iron_finish.roughness = 0.82
    clapper.material_override = iron_finish
    parent.add_child(clapper)
    # Small grounded wall sconce instead of a large high yellow wash.
    # Light source is visibly mounted at the side, away from the bell.
    _decorative_box(parent,"BellLanternWallBracket",Vector3(0.43,0.10,0.24),
        at+Vector3(2.78,-0.97,2.40),WOOD_BASE.darkened(0.18))
    _lantern(parent,at+Vector3(2.96,-0.90,2.40),0.26,6.5,
        "BellHouseWallSconce")
