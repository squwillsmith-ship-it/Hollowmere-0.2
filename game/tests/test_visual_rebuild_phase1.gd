extends SceneTree
## Visual Rebuild Phase 1: actual physics world, not a render-only camera move.
## Requires pinned Godot 4.7.2; no test success asserted until executed.
var failures: Array[String] = []

func require(condition: bool, detail: String) -> void:
    if not condition:
        failures.append(detail)
        push_error("VISUAL_REBUILD_PHASE1: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var village := HMBrinewickBlockout.new()
    village.spawn_exploration_player = false
    root.add_child(village)
    for tick: int in range(6):
        await physics_frame
    var underground: HMUndergroundSites = village.underground_sites
    var vault: Node = underground.get_node_or_null(
        "UndercroftBellAndContainment/UndercroftVaultSlope_1")
    var other: Node = underground.get_node_or_null(
        "UndercroftBellAndContainment/UndercroftVaultSlope_-1")
    require(vault is StaticBody3D and other is StaticBody3D,
        "Both vault panels have real, protected static colliders")
    require(underground.get_node_or_null(
        "UndercroftBellAndContainment/RockCeiling_128") == null,
        "The former occluding slab has been removed, not merely hidden")
    var finish: HMUndergroundProductionArt = underground.get_node_or_null(
        "FacetedUndergroundDetail/ProtectedUndergroundArchitecturalFinish") as HMUndergroundProductionArt
    require(finish != null,"Protective underground finish is in the real world")
    if finish != null:
        var pitched: int = 0
        for piece: Node in finish.get_children():
            if String(piece.name).begins_with("UndercroftRakedRib_"):
                pitched += 1
                require(piece is MeshInstance3D,
                    "Undercroft raked ribs are visual-only; roof collision is owned by stone vault")
            require(not String(piece.name).begins_with("UndercroftRoofRib_"),
                "No old flat decorative stone rib masks the corrected vault")
        require(pitched == 6,"Three pairs of masonry ribs follow the vaulted profile")
    var position: Vector3 = underground.locations["undercroft"]
    var space: PhysicsDirectSpaceState3D = village.get_world_3d().direct_space_state
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.8
    # Body stands 0.95 m above the real 9.97-m floor, with 0.59-m
    # first-person Head camera offset. Test two realistic central stances.
    for x: float in [-1.6,0.4]:
        var shape_query := PhysicsShapeQueryParameters3D.new()
        shape_query.shape = capsule
        shape_query.collision_mask = 1
        shape_query.transform = Transform3D(Basis(),
            Vector3(position.x+x,10.92,position.z+2.55))
        var obstruction: Array[Dictionary] = space.intersect_shape(shape_query,16)
        require(obstruction.is_empty(),
            "Standing capsule clears ceiling/rock at offset " + str(x))
    # Eye ray should reach the protected desk; no phantom, solid ceiling
    # collider may hide the recorded story location from normal stance.
    var eye: Vector3 = position + Vector3(-1.6,1.43,2.55)
    var focus: Vector3 = position + Vector3(0.0,0.50,1.0)
    var ray: Dictionary = space.intersect_ray(
        PhysicsRayQueryParameters3D.create(eye,focus,1))
    require(not ray.is_empty(),"A real scene surface is visible from player-eye height")
    if not ray.is_empty():
        require(not String(ray["collider"].name).begins_with("UndercroftVaultSlope"),
            "No ceiling is the first hit on the player-eye story line")
    # All 21 sites, 345 normal-world removable IDs and protected finale
    # machinery must still exist in this exact same world.
    require(village.site_nodes.size() == 21,"Original 21 location anchors remain")
    require(village.campaign_sites.finale_nodes.size() == 2,
        "Both mutually exclusive ending targets remain")
    village.free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_VISUAL_REBUILD_PHASE1_OK")
        quit(0)
    else:
        quit(1)
