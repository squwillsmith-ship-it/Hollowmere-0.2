class_name HMVillageLandmarkArt
extends Node3D
## Architectural replacements for the two remaining unoccupied village
## proxy volumes (inn and mine office). Their geometry has actual matching
## collision and usable doors; no unseen entity or new quest added.
## All authored structural pieces are individual stable-ID salvage nodes.
## Visual removal and saved state are reconciled by the existing lifecycle.
const STONE: Color = Color("716d60")
const OAK: Color = Color("67523e")
const LIME: Color = Color("b0a58e")
const SLATE: Color = Color("515857")
var created_bodies: int = 0
var rebuilt_sites: int = 0
var restored_openings: int = 0
var part_definitions: Array = []
const PART_SPEC: String = "res://data/v1/landmark_parts.json"

func build(sites: Dictionary) -> void:
    if rebuilt_sites > 0:
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PART_SPEC))
    if not (parsed is Dictionary) or not (parsed.get("parts", null) is Array):
        push_error("Missing stable landmark component manifest")
        return
    part_definitions = parsed["parts"]
    if part_definitions.size() != 54:
        push_error("Landmark part count changed without controlled migration")
        return
    _inn(sites["brinewick/site_10"])
    _mine_office(sites["brinewick/site_19"])
    var finish := HMSettlementProductionArt.new()
    finish.name = "LandmarkMaterialFinish"
    add_child(finish)
    var roots: Dictionary = {}
    for child: Node in get_children():
        if child != finish and child is Node3D:
            roots[String(child.name)] = child
    finish.build(roots)
    set_meta("collision_backed",true)
    set_meta("individual_salvage_count",created_bodies)
    assert(created_bodies == part_definitions.size(),
        "Every inn/mine office mesh must have one catalogue-backed removable ID")

func _replace_proxy(site: Node3D) -> Node3D:
    var raw: StaticBody3D = site.get_node_or_null("NonSalvageVolume") as StaticBody3D
    if raw != null:
        raw.visible = false
        raw.collision_layer = 0
        raw.collision_mask = 0
        var collider: CollisionShape3D = raw.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if collider != null:
            collider.set_deferred("disabled",true)
    var group := Node3D.new()
    group.name = "Architecture_"+String(site.get_meta("site_id")).get_file()
    group.position = site.position
    group.set_meta("catalogue_backed_individual_salvage",true)
    group.set_meta("production_architecture_geometry",true)
    add_child(group)
    rebuilt_sites += 1
    return group

func _inn(site: Node3D) -> void:
    var g: Node3D = _replace_proxy(site)
    _block(g,"InnStoneFooting",Vector3(9.0,0.50,7.5),
        Vector3(0,0.23,0),STONE)
    for side: float in [-1.0,1.0]:
        var x: float = side*4.15
        for z: float in [-3.15,0.0,3.15]:
            _block(g,"InnHewnPost",Vector3(0.33,4.0,0.32),
                Vector3(x,2.22,z),OAK)
        for z: float in [-2.3,1.85]:
            _block(g,"InnLimeInfill",Vector3(0.28,2.9,2.45),
                Vector3(x,2.45,z),LIME)
        _block(g,"InnOutsideEave",Vector3(0.26,0.21,7.7),
            Vector3(x,4.22,0),OAK)
        _block(g,"InnWindowShutter",Vector3(0.07,1.2,0.75),
            Vector3(x+side*0.18,2.6,-0.5),OAK)
    # Real doorway instead of a rendered dark rectangle backed by a solid
    # invisible collision box; 2.2m clear aperture is generous for player.
    for side: float in [-1.0,1.0]:
        _block(g,"InnFrontLimePier",Vector3(3.18,3.25,0.3),
            Vector3(side*2.8,2.15,3.5),LIME)
        _block(g,"InnRearLimePanel",Vector3(4.25,3.1,0.28),
            Vector3(side*2.2,2.15,-3.5),LIME)
        _block(g,"InnFrontTimberDoorPost",Vector3(0.22,2.95,0.42),
            Vector3(side*1.18,1.94,3.55),OAK)
        _block(g,"InnExteriorWindowSill",Vector3(1.3,0.14,0.25),
            Vector3(side*2.84,2.10,3.74),OAK)
    _block(g,"InnDoorLintel",Vector3(2.7,0.35,0.4),
        Vector3(0,3.65,3.5),OAK)
    _block(g,"InnFrontUpperPlaster",Vector3(8.6,0.65,0.35),
        Vector3(0,4.04,3.5),LIME)
    # Matched pitched collision sections, no impossible phantom flat roof.
    for side: float in [-1.0,1.0]:
        _block(g,"InnCantedSlateRoof",Vector3(5.0,0.24,8.1),
            Vector3(side*2.17,5.02,0),SLATE,
            Vector3(0,0,-side*31.0))
        _block(g,"InnTimberRoofPurlin",Vector3(0.21,0.19,8.2),
            Vector3(side*3.83,4.13,0),OAK)
    for z_end: float in [-3.52,3.52]:
        _gable(g,"InnHandLimeGable",4.25,4.22,6.18,z_end,LIME)
    _block(g,"InnRidgeBeam",Vector3(0.32,0.32,8.0),
        Vector3(0,6.2,0),OAK)
    _block(g,"InnCommonTable",Vector3(2.0,0.17,0.9),
        Vector3(1.0,1.18,-1.45),OAK)
    for side: float in [-1.0,1.0]:
        _block(g,"InnGatheringBench",Vector3(1.8,0.23,0.40),
            Vector3(1.0,0.70,-1.45+side*0.85),OAK)
    restored_openings += 1

func _mine_office(site: Node3D) -> void:
    var g: Node3D = _replace_proxy(site)
    _block(g,"MiningOfficeFooting",Vector3(7.2,0.36,6.25),
        Vector3(0,0.17,0),STONE)
    for side: float in [-1.0,1.0]:
        _block(g,"OfficeHewnCornerPost",Vector3(0.30,3.2,0.3),
            Vector3(side*3.3,1.83,-2.6),OAK)
        _block(g,"OfficeHewnCornerPost",Vector3(0.30,3.2,0.3),
            Vector3(side*3.3,1.83,2.6),OAK)
        _block(g,"OfficeWattleLimeSide",Vector3(0.25,2.85,5.4),
            Vector3(side*3.27,1.75,0),LIME)
        _block(g,"OfficeFrontHalf",Vector3(2.25,2.9,0.33),
            Vector3(side*2.4,1.78,2.79),STONE)
        _block(g,"OfficeRearMasonry",Vector3(3.35,3.0,0.34),
            Vector3(side*1.78,1.80,-2.79),STONE)
    _block(g,"OfficeFrontLintel",Vector3(2.0,0.32,0.4),
        Vector3(0,3.23,2.79),OAK)
    for side: float in [-1.0,1.0]:
        _block(g,"OfficeUnevenSlateSlope",Vector3(4.15,0.22,6.7),
            Vector3(side*1.77,4.05,0),SLATE,
            Vector3(0,0,-side*28.0))
    for z_end: float in [-2.80,2.80]:
        _gable(g,"MineOfficeLimeGable",3.35,3.35,5.02,z_end,LIME)
    _block(g,"MineOfficeRidge",Vector3(0.3,0.27,6.7),
        Vector3(0,5.0,0),OAK)
    _block(g,"MiningRecordsTable",Vector3(1.4,0.16,0.7),
        Vector3(1.1,0.95,-1.4),OAK)
    _block(g,"MiningToolRack",Vector3(0.22,1.65,2.0),
        Vector3(-2.9,1.25,-0.5),OAK)
    restored_openings += 1

func _part_body(parent: Node3D, title: String) -> HMInspectTarget:
    assert(created_bodies < part_definitions.size(), "No stable component definition")
    var definition: Dictionary = part_definitions[created_bodies]
    assert(int(definition.get("body_index", -1)) == created_bodies
        and String(definition.get("title", "")) == title, "Landmark geometry/catalogue mismatch")
    var body := HMInspectTarget.new()
    body.name = title + "_" + str(created_bodies)
    body.part_id = String(definition["id"])
    body.collision_layer = 1
    body.collision_mask = 2
    body.set_meta("landmark_material", String(definition.get("allocation", {}).keys()[0]))
    parent.add_child(body)
    return body


func _gable(parent: Node3D, title: String, half_width: float,
        bottom: float, apex: float, z: float, tint: Color) -> void:
    # Closed triangular prism, with matching convex physical collision:
    # the roof is not floating over a large impossible solid placeholder.
    var body: HMInspectTarget = _part_body(parent,title)
    var front: float = z - 0.12
    var back: float = z + 0.12
    var points := PackedVector3Array([
        Vector3(-half_width,bottom,front),Vector3(half_width,bottom,front),
        Vector3(0,apex,front),Vector3(-half_width,bottom,back),
        Vector3(half_width,bottom,back),Vector3(0,apex,back)])
    var shape := ConvexPolygonShape3D.new()
    shape.points = points
    var collision := CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a: Vector3 = points[0]
    var b: Vector3 = points[1]
    var c: Vector3 = points[2]
    var d: Vector3 = points[3]
    var e: Vector3 = points[4]
    var f: Vector3 = points[5]
    _triangle(st,a,b,c,tint)
    _triangle(st,f,e,d,tint.darkened(0.09))
    _triangle(st,a,c,f,tint.darkened(0.16))
    _triangle(st,a,f,d,tint.darkened(0.16))
    _triangle(st,c,b,e,tint.darkened(0.13))
    _triangle(st,c,e,f,tint.darkened(0.13))
    _triangle(st,a,d,e,tint.darkened(0.24))
    _triangle(st,a,e,b,tint.darkened(0.24))
    var visual := MeshInstance3D.new()
    visual.name = "ClosedStoneAndLimeGable"
    visual.mesh = st.commit()
    var finish := StandardMaterial3D.new()
    finish.vertex_color_use_as_albedo = true
    finish.roughness = 0.95
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    visual.material_override = finish
    body.add_child(visual)
    # V06: exposed rake and collar are real children of the original gable
    # salvage target. They cannot outlive its manual release or save reload.
    var timber_rake := Node3D.new()
    timber_rake.name = "AttachedGableOakRake"
    timber_rake.position = Vector3(0,(bottom+apex)*0.5,z)
    body.add_child(timber_rake)
    HMArchitecturalDetail.gable_trim(timber_rake,
        Vector3(half_width*2.0,apex-bottom,0.24),title)
    created_bodies += 1

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, color: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(color)
        st.add_vertex(p)

func _block(parent: Node3D, title: String, size: Vector3,
        offset: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> void:
    var solid: HMInspectTarget = _part_body(parent,title)
    solid.position = offset
    solid.rotation_degrees = angles
    var mesh := MeshInstance3D.new()
    var block := BoxMesh.new()
    block.size = size
    mesh.mesh = block
    var surface := StandardMaterial3D.new()
    surface.albedo_color = color
    surface.roughness = 0.96
    mesh.material_override = surface
    solid.add_child(mesh)
    var collision := CollisionShape3D.new()
    var prism := BoxShape3D.new()
    prism.size = size
    collision.shape = prism
    solid.add_child(collision)
    # These are restrained, non-colliding trim pieces belonging to exactly
    # one catalogue-backed manual release. None is a permanent facade proxy.
    if title == "InnDoorLintel":
        _trim(solid,"OldInnSignBracket",Vector3(0.05,0.28,0.40),
            Vector3(0,-0.26,size.z*0.48),Color("4a4841"))
        _trim(solid,"BlankInnHangingBoard",Vector3(0.70,0.18,0.065),
            Vector3(0,-0.31,size.z*0.52),OAK.darkened(0.09))
    elif title == "OfficeFrontLintel":
        _trim(solid,"MineLedgerLintelPeg",Vector3(0.35,0.075,0.07),
            Vector3(0,-0.13,size.z*0.51),Color("4c4a40"))
    elif title == "MiningToolRack":
        for row: int in range(3):
            _trim(solid,"VacantToolHanger_%d" % row,Vector3(0.09,0.09,0.32),
                Vector3(0,-size.y*0.33+float(row)*0.43,
                    -size.z*0.35),Color("514c3e"))
    elif title == "InnWindowShutter":
        for row: int in [-1,1]:
            _trim(solid,"WindowHingeIron",Vector3(size.x*1.25,0.040,0.12),
                Vector3(0,float(row)*size.y*0.28,0),Color("494942"))
    elif title == "InnFrontLimePier":
        for edge: int in [-1,1]:
            _trim(solid,"LimePierTimberBatten",Vector3(0.12,size.y*0.86,0.10),
                Vector3(float(edge)*size.x*0.43,0,size.z*0.52),OAK)
    elif title == "OfficeWattleLimeSide":
        for edge: int in [-1,1]:
            _trim(solid,"WattleOuterLath",Vector3(0.085,size.y*0.87,0.13),
                Vector3(size.x*0.54,0,float(edge)*size.z*0.39),OAK)
    created_bodies += 1

static func _trim(owner: Node3D, title: String, size: Vector3,
        at: Vector3, color: Color) -> void:
    var visual := MeshInstance3D.new()
    visual.name = title
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.position = at
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.96
    visual.material_override = mat
    owner.add_child(visual)
