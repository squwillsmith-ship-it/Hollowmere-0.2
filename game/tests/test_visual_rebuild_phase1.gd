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
    # Regression for the observed central undercroft occluder: visual
    # "wall" ribs must now live against physical walls, not at desk height.
    var protected_room: Node3D = underground.get_node_or_null(
        "UndercroftBellAndContainment") as Node3D
    require(protected_room != null,"Undercroft and bell share protected world group")
    if protected_room != null:
        var wall_ribs: int = 0
        var bell_lamps: int = 0
        var bell_at: Vector3 = underground.locations["bell_house"]
        for detail: Node in protected_room.get_children():
            if String(detail.name).begins_with("UndercroftWallRib_"):
                wall_ribs += 1
                require(detail is MeshInstance3D,
                    "Wall rib is visual-only, never new opaque interaction collision")
                if detail is MeshInstance3D:
                    var world_x: float = (detail as MeshInstance3D).position.x
                    require(absf(world_x-position.x) >= 3.9,
                        "Undercroft rib stays outside central player sightline")
            if detail is OmniLight3D and String(detail.name) == "BellHouseWallSconce":
                var lamp: OmniLight3D = detail as OmniLight3D
                if lamp.position.distance_to(bell_at) < 7.0:
                    bell_lamps += 1
                    require(lamp.light_energy <= 0.9 and lamp.omni_range <= 7.0,
                        "Bell side lamp no longer floods the entire overhead frame")
        require(wall_ribs == 4,"Four restrained wall-margin undercroft ribs")
        require(bell_lamps == 1,"One local protected bell sconce is present")
        require(protected_room.get_node_or_null("CastBellClapper") is MeshInstance3D,
            "Protected bell has an actual visible clapper")
        var mount: StaticBody3D = protected_room.get_node_or_null("BellMount") as StaticBody3D
        require(mount != null and mount.collision_layer == 1,
            "Original protected physical bell mount still exists")
        # The centre of the open square is unobstructed by the eaves and
        # piers when looking to the mounted protected bell from normal height.
        var bell_ray: Dictionary = space.intersect_ray(
            PhysicsRayQueryParameters3D.create(
                bell_at+Vector3(0,1.60,6.0),
                bell_at+Vector3(0,4.45,0),1))
        require(not bell_ray.is_empty(),"Protected bell mount is ray-visible from square")
        if not bell_ray.is_empty():
            require(bell_ray.get("collider") == mount,
                "No front lintel, roof slab or hidden collider masks the bell mount")
    village.free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_VISUAL_REBUILD_PHASE1_OK")
        quit(0)
    else:
        quit(1)
