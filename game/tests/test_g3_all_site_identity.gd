extends SceneTree
## G3 all-site art coverage, no duplicate inn/mine landmark ownership.
var errors: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func demand(value: bool, label: String) -> void:
    if not value:
        errors.append(label)
        push_error("G3_ALL_SITE: "+label)
func _run() -> void:
    var scene:=HMBrinewickBlockout.new()
    scene.spawn_exploration_player=false
    root.add_child(scene)
    for frame: int in range(4):
        await physics_frame
    demand(scene.site_nodes.size()==21,"All 21 original fixed Brinewick site markers")
    var identity: HMG3SiteIdentity=scene.get_node_or_null("G3VillageWideSiteIdentity") as HMG3SiteIdentity
    demand(identity!=null,"Actual G3 all-site art included in world")
    if identity!=null:
        demand(identity.site_profiles.size()==21,"Every canonical site has coastal/civic/upland/industrial differentiation")
        demand(identity.visual_members>=84,"Each of twenty-one sites has real small low-poly approach meshes")
        for id: String in scene.site_nodes:
            var root_node: Node3D=scene.site_nodes[id]
            var cue: Node3D=root_node.get_node_or_null("G3SiteApproachIdentity") as Node3D
            demand(cue!=null,"G3 original site physical visual coverage: "+id)
            if cue!=null:
                demand(cue.get_child_count()>=4,"No empty site visual proxy "+id)
                demand(String(cue.get_meta("site_id",""))==id,
                    "Site identity stored against existing site ID")
                for part: Node in cue.get_children():
                    demand(part is MeshInstance3D,"Site approach has real geometry")
    var inn: HMVillageLandmarkArt=scene.get_node_or_null("InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
    demand(inn!=null,"Preserved original inn and mine office authoring")
    if inn!=null:
        demand(inn.rebuilt_sites==2,"Two actually built former massing sites")
        demand(inn.created_bodies==54,"Original 54 manually removable inn and mine-office part targets")
    var catalog:=HMCatalog.new()
    demand(catalog.load_all(),"Canonical game catalogue intact")
    var lifecycle:=HMPartLifecycle.new()
    scene.add_child(lifecycle)
    lifecycle.bind_stage(scene)
    demand(lifecycle.installed.size()==345,"G3 has not deleted or duplicated the 345 salvage parts")
    var fresh: Dictionary=HMSaveState.fresh(catalog)
    demand(HMSaveState.validate(catalog,fresh).is_empty(),
        "Original four-act two-ending save state still valid")
    scene.queue_free()
    await process_frame
    if errors.is_empty():
        print("HOLLOWMERE_G3_ALL_SITE_IDENTITY_OK original_sites=21 salvage=345 landmark_owners=54")
        quit(0)
    else:
        quit(1)
