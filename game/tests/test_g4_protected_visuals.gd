extends SceneTree
## G4 protected-zone composition: no actor, new story action, removal ID
## or collision. The entity must remain unseen and audible only.
var failures: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func test(ok: bool,why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("G4_STORY_VISUALS: "+why)
func _run() -> void:
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    for i: int in range(4):
        await physics_frame
    var underground: HMUndergroundSites=stage.underground_sites
    var g4: HMG4ProtectedStoryVisuals=underground.get_node_or_null(
        "G4ProtectedStoryArchitecture") as HMG4ProtectedStoryVisuals
    test(g4!=null,"Actual G4 art installed in canonical protected passage world")
    if g4==null:
        quit(1)
        return
    test(g4.zones.size()==4,"All four original well, mine, undercroft/bell and tidal zones have visual treatment")
    test(g4.owners_dressed>=20,"G4 has real owner-attached material joints in each story zone")
    test(g4.pieces>=20,"G4 adds actual renderable low-poly architectural pieces")
    test(bool(g4.get_meta("g4_entity_never_visualized",false)),
        "No entity visualization, fantasy light or encounter added")
    var inspected: int=0
    for group: Node in underground.get_children():
        for owner: Node in group.get_children():
            var holder: Node3D=owner.get_node_or_null("G4StorySurfaceJoinery") as Node3D
            if holder==null:
                continue
            test(owner is StaticBody3D,"G4 artwork belongs to an already colliding protected owner")
            test(holder.get_child_count()>0,"Actual art geometry generated")
            test(bool(holder.get_meta("g4_visual_only",false)),"No G4 gameplay collision added")
            for child: Node in holder.get_children():
                test(child is MeshInstance3D and (child as MeshInstance3D).mesh!=null,
                    "New pieces are actual render meshes, no colliders")
                test(not (child is CollisionShape3D),"No extra physics")
            inspected+=1
    test(inspected==g4.owners_dressed,"All G4 art owners found on the old protected bodies")
    var audio: HMUndergroundAudio=stage.underground_audio
    test(audio!=null,"Original spatial audio preserved")
    if audio!=null:
        test(audio.ambience_players.size()>=4,"Audio-first story beds remain present")
        test(audio.response_players.size()>=2,"Narrative responses remain audio, not apparition")
    test(stage.campaign_sites.finale_nodes.size()==2,"Both original endings unchanged")
    test(stage.site_nodes.size()==21,"All original Brinewick sites unchanged")
    var life:=HMPartLifecycle.new()
    stage.add_child(life)
    life.bind_stage(stage)
    test(life.installed.size()==345,"No changes to 345 original salvages")
    var cat:=HMCatalog.new()
    test(cat.load_all(),"Canonical manual catalogue preserved")
    var state: Dictionary=HMSaveState.fresh(cat)
    test(HMSaveState.validate(cat,state).is_empty(),"Save schema unaffected by protected visuals")
    stage.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G4_PROTECTED_VISUALS_OK zones=4 no_new_salvage_or_ending")
        quit(0)
    else:
        quit(1)
