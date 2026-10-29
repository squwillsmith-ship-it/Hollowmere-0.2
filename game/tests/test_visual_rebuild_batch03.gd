extends SceneTree
## Pinned Godot 4.7.2 scene checks. Not a graphical visual-acceptance test.
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, reason: String) -> void:
    if not ok:
        problems.append(reason)
        push_error("BATCH03: " + reason)

func _count_colliders(source: Node) -> int:
    var n: int = 1 if source is CollisionShape3D else 0
    for child: Node in source.get_children():
        n += _count_colliders(child)
    return n

func _run() -> void:
    var village := HMBrinewickBlockout.new()
    village.spawn_exploration_player = false
    root.add_child(village)
    for n: int in range(6):
        await physics_frame
    var roads: Node3D = village.get_node("RoadsAndPaths") as Node3D
    var finish: HMCoastalRoadWear = village.get_node_or_null(
        "GroundedCartRoadWear") as HMCoastalRoadWear
    verify(finish != null,"Road detailing instantiated into actual Brinewick stage")
    if finish != null:
        verify(finish.dressed_roads == 8,"Eight actual cart-road segment skins installed")
        verify(finish.surface_patches > 60,"Worn wheel tracks and mineral inclusions authored")
        verify(_count_colliders(finish) == 0,"No new physics bodies in road detailing")
    for title: String in HMCoastalRoadWear.CART_ROADS:
        var body: StaticBody3D = roads.get_node_or_null(title) as StaticBody3D
        verify(body != null,"Existing physical road survives "+title)
        if body == null:
            continue
        var physical: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        var skin: MeshInstance3D = body.get_node_or_null("GroundedCartRutsAndAggregate") as MeshInstance3D
        verify(physical != null and physical.shape is BoxShape3D,
            "Original road box still carries collisions at "+title)
        verify(skin != null and skin.mesh is ArrayMesh and skin.get_child_count() == 0,
            "New road accents only use rendered triangles at "+title)
    var history: HMPhaseCHarbourDressing = village.get_node_or_null(
        "PhaseCHarbourHistory") as HMPhaseCHarbourDressing
    verify(history != null,"Existing harbour art layer still connected")
    if history != null:
        verify(history.hull_planks == 48,"Clinker boat has 48 staggered hull panels")
        verify(_count_colliders(history) == 0,"Boat and quay weathering cannot obstruct cargo")
        verify(history.get_node_or_null("OutboardMooringsAndClinker") is MeshInstance3D,
            "Hull, moorings and revetment remain in draw-batched source geometry")
    verify(village.site_nodes.size() == 21,"All original 21 site markers retained")
    verify(village.district_sites.cottage != null,"Removable reference cottage retained")
    village.queue_free()
    await process_frame
    if problems.is_empty():
        print("HOLLOWMERE_VISUAL_BATCH03_OK")
        quit(0)
    else:
        quit(1)
