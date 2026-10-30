extends SceneTree
## G4 protected story-art pilot. Real Godot world and existing gameplay
## contracts; no fabricated entity, new narrative trigger, salvage, collision.
var failures: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool,description: String) -> void:
    if not ok:
        failures.append(description)
        push_error("G4_PROTECTED: "+description)
func _run() -> void:
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    for i: int in range(4):
        await physics_frame
    var protected: HMUndergroundSites=stage.underground_sites
    var layer: HMG4ProtectedComposition=stage.get_node_or_null(
        "G4ProtectedLandmarkComposition") as HMG4ProtectedComposition
    check(layer!=null,"G4 architectural layer exists in live world")
    if layer==null:
        quit(1)
        return
    check(layer.location_nodes.size()==7,"Seven original protected landmark locations")
    check(layer.detail_members>=40,"Material architectural supports actually installed")
    check(layer.practical_lights==3,"Subtle existing-context practical light only")
    for id: String in HMG4ProtectedComposition.ORDER:
        check(protected.locations.has(id),"Canonical protected site exists "+id)
        check(layer.location_nodes.has(id),"G4 landmark composed "+id)
        if not layer.location_nodes.has(id):
            continue
        var node: Node3D=layer.location_nodes[id]
        check(bool(node.get_meta("g4_visual_only_never_story_or_salvage",false)),
            "Visual only protected "+id)
        check(node.get_parent()==protected,"G4 landmark remains inside protected environment")
        check(node.get_child_count()>=2,"G4 architectural composition has rendered members "+id)
        for child: Node in node.get_children():
            check(child is MeshInstance3D or child is OmniLight3D,
                "G4 creates no new physics or narrative actors "+id)
    check(stage.campaign_sites.finale_nodes.size()==2,
        "Both established story endings intact")
    check(stage.campaign_sites.clue_nodes.size()>=10,
        "Original evidence record count unchanged")
    check(stage.underground_audio.ambience_players.size()>=4,
        "Existing location-based auditory horror preserved")
    check(stage.underground_audio.response_players.size()>=3,
        "One-shot responses remain in original audio layer")
    var lifecycle:=HMPartLifecycle.new()
    stage.add_child(lifecycle)
    lifecycle.bind_stage(stage)
    check(lifecycle.installed.size()==345,
        "G4 protected art introduces no additional manual salvage targets")
    check(stage.site_nodes.size()==21,"21 original site positions unchanged")
    check(stage.get_meta("g3_21_sites_covered",0)==21,
        "G3 original 21-site groundwork inherited")
    stage.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G4_PROTECTED_COMPOSITION_OK zones=7 endings=2 parts=345")
        quit(0)
    else:
        quit(1)
