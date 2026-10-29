extends SceneTree
## V03–V06 Godot contract test for the real visible candidate geometry.
## This test must run on the exact SHA; writing it is NOT engine acceptance.
var issues: Array[String] = []

func verify(condition: bool, detail: String) -> void:
    if not condition:
        issues.append(detail)
        push_error("PHASE_B_VISUAL: " + detail)

func _initialize() -> void:
    call_deferred("_check")

func _count_named(node: Node, prefix: String) -> int:
    var sum: int = 0
    for child: Node in node.get_children():
        if String(child.name).begins_with(prefix):
            sum += 1
        sum += _count_named(child,prefix)
    return sum

func _check() -> void:
    var cat := HMCatalog.new()
    verify(cat.load_all(),"Canonical catalogue loads")
    for profile: String in HMPhaseBMaterials.PROFILES:
        var mat: StandardMaterial3D = HMPhaseBMaterials.make_tinted(profile,Color.WHITE)
        verify(mat != null and mat.albedo_texture != null and mat.roughness_texture != null,
            "Both production surface textures loaded: " + profile)
        if mat.albedo_texture != null:
            verify(mat.albedo_texture.get_width() == 512, "512px face: " + profile)
    var manifest: Dictionary = HMBuildingPrefab.read_manifest(
        "res://data/v1/buildings/cottage_working_01.json")
    verify(HMBuildingPrefab.validate(manifest,cat).is_empty(),"Original nine cottage IDs valid")
    var cottage: Node3D = HMBuildingPrefab.build(manifest,cat)
    verify(cottage != null,"Production cottage builds")
    if cottage == null:
        quit(1)
        return
    var stage := Node3D.new()
    root.add_child(stage)
    stage.add_child(cottage)
    verify(_count_named(cottage,"GableRakeAndCollar") == 2,
        "Both gable trims are children of original infill parts")
    verify(_count_named(cottage,"WeatheredOakRake") == 4,
        "Existing gables expose four timber rakes")
    verify(_count_named(cottage,"Weatherboard_") >= 35,
        "Reference cottage has genuinely staggered short individual board sections")
    verify(_count_named(cottage,"IronFixingPeg_") >= 2,
        "Part-owned board ironwork remains subordinate to cladding")
    var life := HMPartLifecycle.new()
    stage.add_child(life)
    life.bind_stage(stage)
    verify(life.installed.size() == 9,"No new cottage salvage IDs created")
    var clean: Dictionary = HMSaveState.fresh(cat)
    verify(HMSaveState.validate(cat,clean).is_empty(),"Unchanged save format valid")
    life.reconcile(clean)
    verify(life.installed["fixture/house/front_infill"].visible,
        "Original attached gable shows its trim")
    var preview: Dictionary = clean.duplicate(true)
    preview["world"]["parts"]["fixture/house/front_infill"]["phase"] = "released"
    life.reconcile(preview)
    verify(not life.installed["fixture/house/front_infill"].visible,
        "Visual children disappear with existing released part")
    verify(life.recovered.is_empty(),"Visual removal cannot generate material lots")
    life.reconcile(clean)
    verify(life.installed["fixture/house/front_infill"].visible,
        "Attached component restores its entire trimmed appearance")
    var half_stripped: Dictionary = clean.duplicate(true)
    half_stripped["world"]["parts"]["fixture/house/cladding"]["phase"] = "released"
    life.reconcile(half_stripped)
    verify(not life.installed["fixture/house/cladding"].visible,
        "All stagger-jointed boards vanish with their original cladding owner")
    verify(life.installed["fixture/house/slate_patch"].visible,
        "Partially dismantled cottage retains separate roof assembly")
    verify(life.recovered.is_empty(), "Visual-only split planks never duplicate salvage")
    var heavily_stripped: Dictionary = half_stripped.duplicate(true)
    for detached_id: String in ["fixture/house/slate_patch", "fixture/house/front_infill",
        "fixture/house/shutters", "fixture/house/beam"]:
        heavily_stripped["world"]["parts"][detached_id]["phase"] = "released"
    life.reconcile(heavily_stripped)
    for detached_id: String in ["fixture/house/cladding", "fixture/house/slate_patch",
        "fixture/house/front_infill", "fixture/house/shutters", "fixture/house/beam"]:
        verify(not life.installed[detached_id].visible,
            "Heavy-strip hides entire target + its child visuals: " + detached_id)
    verify(life.installed["fixture/house/stone_block"].visible,
        "Heavy-strip retains correctly independent stone foundation")
    verify(life.recovered.is_empty(), "Cosmetic teardown cannot generate material lots")
    life.reconcile(clean)
    verify(life.installed["fixture/house/cladding"].visible,
        "Save/reentry restore brings back all stagger-jointed boards")
    var world := HMBrinewickBlockout.new()
    world.spawn_exploration_player = false
    stage.add_child(world)
    await physics_frame
    var district: HMBrinewickSites = world.district_sites
    var old_warehouse: Node3D = district.installation_nodes["district/old_warehouse"]
    verify(_count_named(old_warehouse,"CornerKnee") >= 2,
        "Warehouse structural bay details are owned by existing frame parts")
    var landmark: HMVillageLandmarkArt = world.get_node_or_null(
        "InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
    verify(landmark != null, "Inn and mine office loaded")
    if landmark != null:
        verify(landmark.created_bodies == 54, "54 original landmark IDs retained")
        verify(_count_named(landmark,"AttachedGableOakRake") == 4,
            "Inn and mine office gables have attached oak rakes")
        verify(_count_named(landmark,"OldInnSignBracket") == 1,
            "Inn facade details are owned by its lintel")
        verify(_count_named(landmark,"VacantToolHanger") == 3,
            "Mine office has purposeful tool rack dressing")
    stage.queue_free()
    await process_frame
    if issues.is_empty():
        print("HOLLOWMERE_PHASE_B_VISUAL_OK")
        quit(0)
    else:
        quit(1)
