extends SceneTree
## Phase C Godot regression — AUTHORING ONLY until executed in pinned 4.7.2.
var issues: Array[String] = []

func check(ok: bool, detail: String) -> void:
    if not ok:
        issues.append(detail)
        push_error("PHASE_C_VISUAL: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _count_type(node: Node, type_name: String) -> int:
    var total: int = 0
    if type_name == "static" and node is StaticBody3D:
        total += 1
    if type_name == "target" and node is HMInspectTarget:
        total += 1
    for child: Node in node.get_children():
        total += _count_type(child, type_name)
    return total

func _run() -> void:
    var cat := HMCatalog.new()
    check(cat.load_all(),"Original catalogue still parses")
    var stage := Node3D.new()
    root.add_child(stage)
    var world := HMBrinewickBlockout.new()
    world.spawn_exploration_player = false
    stage.add_child(world)
    await physics_frame
    var district: HMBrinewickSites = world.district_sites
    var architecture: HMPhaseCSurfaceDetail = district.get_node_or_null("PhaseCDistrictJoinery") as HMPhaseCSurfaceDetail
    check(architecture != null,"Phase C architecture attached")
    if architecture != null:
        check(architecture.treated_parts > 75,"Existing district bodies carry batched detail")
        check(_count_type(architecture,"static") == 0,"No new architecture colliders")
        check(_count_type(architecture,"target") == 0,"No invented salvage IDs")
    var terrain: HMPhaseCGroundDetail = world.get_node_or_null("PhaseCGroundStratification") as HMPhaseCGroundDetail
    check(terrain != null,"Road and cliff refinements attached")
    if terrain != null:
        check(terrain.treated_roads == 10,"All eight original road segments plus two undercroft-safe turning aprons dressed")
        check(terrain.treated_cliffs == 6,"Six upper rock masses retain legacy art; the real lower coast needs no box dressing")
        check(_count_type(terrain,"static") == 0,"Ground detail is visual-only")
    var harbour: HMPhaseCHarbourDressing = world.get_node_or_null("PhaseCHarbourHistory") as HMPhaseCHarbourDressing
    check(harbour != null,"Harbour details attached")
    if harbour != null:
        check(harbour.quay_batches == 1 and harbour.fishing_batches == 1,"Both harbour zones dressed")
        check(_count_type(harbour,"static") == 0,"Harbour dressing cannot block manual shipping")
    var underground: HMPhaseCUndergroundDetail = world.underground_sites.get_node_or_null("PhaseCProtectedStonesAndTimber") as HMPhaseCUndergroundDetail
    check(underground != null,"Protected underground details attached")
    if underground != null:
        check(underground.zones_dressed == 4,"Four protected spaces receive stone and timber")
        check(_count_type(underground,"target") == 0,"Protected work cannot become ordinary salvage")
    var scatter: HMPhaseCVillageDressing = world.get_node_or_null("PhaseCSettlementVegetation") as HMPhaseCVillageDressing
    check(scatter != null,"Settlement foliage attached")
    if scatter != null:
        check(scatter.covered_sites == 21,"All established 21 site markers inventoried")
        check(scatter.clump_count > 100,"Perimeter vegetation seeded")
        check(_count_type(scatter,"static") == 0,"No invisible scatter collision")
    var landmark: HMVillageLandmarkArt = world.get_node_or_null("InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
    check(landmark != null and landmark.created_bodies == 54,"Phase B landmark source unchanged")
    check(district.cottage != null,"Existing cottage preserved")
    stage.queue_free()
    await process_frame
    if issues.is_empty():
        print("HOLLOWMERE_PHASE_C_VISUAL_OK")
        quit(0)
    else:
        quit(1)
