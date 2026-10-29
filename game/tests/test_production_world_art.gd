extends SceneTree
## Production environment authoring contract. It does not replace human
## graphical acceptance; it prevents ornate visual-only geometry concealing
## missing physics, merged salvage IDs or blocked fundamental doorways.
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("PRODUCTION_WORLD_ART: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var app: Node = load("res://scenes/main.tscn").instantiate()
    app.force_brinewick_for_tests = true
    root.add_child(app)
    await physics_frame
    await physics_frame
    var village: HMBrinewickBlockout = app.stage as HMBrinewickBlockout
    check(village != null, "Existing integrated player world loaded")
    if village != null:
        var land: HMVillageLandmarkArt = village.get_node_or_null(
            "InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
        check(land != null, "Inn and mine office are no longer blockout volumes")
        if land != null:
            check(land.rebuilt_sites == 2, "Both placeholder landmarks replaced")
            check(land.created_bodies >= 42, "Landmarks use individually colliding wall/roof members")
            check(land.restored_openings == 2, "Two real doorway approaches")
        var shoreline: HMCoastalForeshoreArt = village.get_node_or_null(
            "BrinewickCoastalForeshore") as HMCoastalForeshoreArt
        check(shoreline != null, "Coastal stone and surf asset groups integrated")
        if shoreline != null:
            check(shoreline.wash_bands == 12 and shoreline.shore_rocks == 94,
                "Muted low-poly shoreline is deterministic")
            for child: Node in shoreline.get_children():
                check(child is MeshInstance3D, "No hidden shoreline collision blockers")
        var ground: HMCoastalGroundArt = village.get_node_or_null(
            "BrinewickFacetedGroundArt") as HMCoastalGroundArt
        check(ground != null, "Coastal terrain skin exists")
        if ground != null:
            check(ground.dressed_landforms >= 6 and ground.dressed_paths >= 7,
                "Every established cliff and roadway uses a real mesh")
        var district: HMBrinewickSites = village.district_sites
        var surface: HMSettlementProductionArt = district.get_node_or_null(
            "BrinewickAuthoredArchitecture") as HMSettlementProductionArt
        check(surface != null, "All original districts received material-specific asset pass")
        if surface != null:
            check(surface.finished_bodies >= 20, "Replace raw masonry, roofing, timber and plaster boxes")
            check(surface.finished_roofs >= 2, "Roof tile mesh profiles actually render")
            check(surface.original_visible_boxes == surface.finished_bodies,
                "Untextured raw render blocks were concealed after replacement")
            check(bool(surface.get_meta("visual_only_preserves_colliders",false)),
                "Existing production part collision remains source of truth")
        # New art-ownership regression: scenery spanning removable supports
        # must belong to real physical bodies, not immortal district roots.
        # Visibility must follow the owner's removal/reload lifecycle.
        var bracing_count: int = 0
        for member: Node in district.find_children("*","MeshInstance3D",true,false):
            var title: String = String(member.name)
            if title.begins_with("LandingFender_") or title.begins_with("ShelterKneeBrace_") or title.begins_with("ChapelWeatheredFascia_") or title.begins_with("LightWindBrace_"):
                bracing_count += 1
                var host: StaticBody3D = member.get_parent() as StaticBody3D
                check(host != null,"Scenic structural brace must be child-owned by a physical part: "+title)
                if host != null:
                    var was_visible: bool = host.visible
                    host.visible = false
                    check(not (member as MeshInstance3D).is_visible_in_tree(),
                        "Part-owned brace must disappear with owner: "+title)
                    host.visible = was_visible
        check(bracing_count >= 10,
            "Original landing, boatyard, chapel and navigation braces are retained with correct ownership")
        for site_id: String in ["brinewick/site_10","brinewick/site_19"]:
            var proxy: StaticBody3D = village.site_nodes[site_id].get_node("NonSalvageVolume")
            check(proxy.collision_layer == 0 and not proxy.visible,
                "Old solid proxy does not invisibly occlude the actual entrance " + site_id)
        await physics_frame
        # Player eye-height sightline through both physical entrances, not a
        # fictitious door textured onto a still-solid blockout collider.
        var space: PhysicsDirectSpaceState3D = village.get_world_3d().direct_space_state
        for case: Dictionary in [
            {"name":"inn", "start":Vector3(70,9.53,30.3),
                "end":Vector3(70,9.53,25.5)},
            {"name":"mine_office", "start":Vector3(157,14.5,-5.2),
                "end":Vector3(157,14.5,-10.4)}]:
            var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
                case["start"],case["end"],1))
            check(hit.is_empty(), "Real entrance line of sight remains unblocked " + String(case["name"]))
        check(app.lifecycle.installed.size() == 345,
            "291 prior targets plus 54 individually dismantlable landmarks with stable IDs")
    app.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_PRODUCTION_WORLD_ART_OK")
        quit(0)
    else:
        quit(1)
