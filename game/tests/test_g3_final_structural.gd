extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func expect(ok: bool,why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("G3_FINAL: "+why)
func _run() -> void:
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    for k: int in range(4):
        await physics_frame
    var terrain: HMG3GeologicalFoundation=stage.get_node_or_null("G3SculptedPlateauAndHeadland")
    expect(terrain!=null,"Terrain generator attached")
    if terrain!=null:
        expect(terrain.complete and terrain.reshaped==6,"Six real original terrain volumes replaced")
        expect(terrain.triangles>1500,"Geometric topography is not box skin")
        for id: String in terrain.original_bodies:
            var body: StaticBody3D=terrain.original_bodies[id]
            var shape: CollisionShape3D=body.get_node_or_null("CollisionShape3D")
            expect(shape!=null and shape.shape is ConcavePolygonShape3D,
                "Physically colliding sculpted ground "+id)
            expect(body.get_node_or_null("G3MatchedSculptedTopography")!=null,
                "Genuine rendered landform "+id)
    var district: HMBrinewickSites=stage.district_sites
    expect(district!=null,"Original district remains")
    if district!=null:
        var roofs: HMG3RoofSectionRebuild=district.get_node_or_null("G3FullOwnedRoofSections")
        expect(roofs!=null,"New roof assembly available")
        if roofs!=null:
            expect(roofs.finished and roofs.replaced==64,"64 original roofs modelled")
            expect(roofs.original_removable>=60,"Manual dismantling parts own roof cladding")
            expect(roofs.tessellated_triangles>1000,"New real slate geometry")
    var lifecycle:=HMPartLifecycle.new()
    stage.add_child(lifecycle)
    lifecycle.bind_stage(stage)
    expect(lifecycle.installed.size()==345,"All 345 salvages preserved")
    var space: PhysicsDirectSpaceState3D=root.world_3d.direct_space_state
    for origin: Vector3 in [Vector3(80,22,-25),Vector3(95,22,27),
            Vector3(150,28,32),Vector3(80,22,0)]:
        var hit: Dictionary=space.intersect_ray(
            PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*48))
        expect(not hit.is_empty(),"Walkable terrain/road "+str(origin))
    stage.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G3_LAST_CHANCE_OK terrain=6 roofs=64 targets=345")
        quit(0)
    else:
        quit(1)
