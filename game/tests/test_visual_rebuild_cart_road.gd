extends SceneTree
## Actual Godot physics proof that the undercroft-safe cart road is not a
## phantom visual: supported road surface and capsule clearance per waypoint.
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        problems.append(message)
        push_error("VISUAL_CART_ROUTE: " + message)

func _run() -> void:
    var village := HMBrinewickBlockout.new()
    village.spawn_exploration_player = false
    root.add_child(village)
    for i: int in range(6):
        await physics_frame
    var roads: Node3D = village.get_node("RoadsAndPaths") as Node3D
    _assert(roads.get_child_count() == 10, "Eight original road segments and two turning aprons")
    _assert(roads.get_node_or_null("UpperRampLowerTurn") != null, "Lower turn installed")
    _assert(roads.get_node_or_null("UpperRampHeadlandTurn") != null, "Headland return turn installed")
    var shelter: Node3D = village.district_sites.installation_nodes["service/boatyard_base"] as Node3D
    var left: StaticBody3D = shelter.get_node_or_null("CompanyWorkShelterRoofLeft") as StaticBody3D
    var right: StaticBody3D = shelter.get_node_or_null("CompanyWorkShelterRoofRight") as StaticBody3D
    _assert(left != null and right != null,"Boatyard has two real pitched roof bodies")
    _assert(shelter.get_node_or_null("CompanyWorkShelterRoof") == null,
        "Original large flat shelter roof is not left as invisible collision")
    if left != null and right != null:
        _assert(left.get_node_or_null("CollisionShape3D") != null and
            right.get_node_or_null("CollisionShape3D") != null,
            "Both pitched roof halves have matching collision geometry")
    var coords: Array[Vector2] = [Vector2(108,0),Vector2(108,3),Vector2(108,6),
        Vector2(108,9),Vector2(108,11),Vector2(113,11),Vector2(119,11),
        Vector2(125,11),Vector2(131,11),Vector2(137,11),Vector2(140,11),
        Vector2(140,7),Vector2(140,3),Vector2(140,0)]
    var space: PhysicsDirectSpaceState3D = village.get_world_3d().direct_space_state
    var person := CapsuleShape3D.new()
    person.radius = 0.34
    person.height = 1.8
    var previous_y: float = -100.0
    for spot: Vector2 in coords:
        var from: Vector3 = Vector3(spot.x,25.0,spot.y)
        var hit: Dictionary = space.intersect_ray(
            PhysicsRayQueryParameters3D.create(from,Vector3(spot.x,-3,spot.y),1))
        _assert(not hit.is_empty(), "Physical road ground at " + str(spot))
        if hit.is_empty():
            continue
        var support: Node = hit["collider"] as Node
        _assert(support.get_parent() == roads,
            "Road sample is actually held by a road collider at " + str(spot) + " hit=" + String(support.name))
        var floor_y: float = (hit["position"] as Vector3).y
        var space_query := PhysicsShapeQueryParameters3D.new()
        space_query.shape = person
        space_query.collision_mask = 1
        space_query.transform = Transform3D(Basis(),Vector3(spot.x,floor_y+1.02,spot.y))
        var intersected: Array[Dictionary] = space.intersect_shape(space_query,10)
        var blockers: Array[String] = []
        for col: Dictionary in intersected:
            blockers.append(String((col["collider"] as Node).name))
        _assert(blockers.is_empty(),
            "Player capsule has 1.8m clearance at "+str(spot)+" hits="+str(blockers))
        if previous_y > -90:
            _assert(absf(floor_y-previous_y) <= 1.5,
                "No abrupt >1.5m road drop between adjacent samples at "+str(spot))
        previous_y = floor_y
    village.queue_free()
    await process_frame
    if problems.is_empty():
        print("HOLLOWMERE_VISUAL_CART_ROUTE_OK samples="+str(coords.size()))
        quit(0)
    else:
        quit(1)
