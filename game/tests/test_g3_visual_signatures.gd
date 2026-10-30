extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool,label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("G3_VISUAL "+label)
func _run() -> void:
    var scene:=HMBrinewickBlockout.new()
    scene.spawn_exploration_player=false
    root.add_child(scene)
    for i: int in range(4):
        await physics_frame
    check(scene.site_nodes.size()==21,"All village sites preserved")
    var district: HMBrinewickSites=scene.district_sites
    var finish: HMG3ArchitecturalSignature=district.get_node_or_null(
        "G3OwnedSilhouetteSignatures") as HMG3ArchitecturalSignature
    check(finish!=null,"Real owner-bound G3 signature exists")
    if finish!=null:
        check(finish.finished,"Signature pass executed")
        check(finish.group_counts.size()==8,"Eight original building groups")
        check(finish.decorated_faces>=25,"Original facade pieces refined")
        check(finish.roof_rakes>=6,"Original roofs have new rakes")
        check(finish.removable_faces>=12,"Saved removable parts own finishes")
        var count: int=0
        for key: String in finish.group_counts:
            var group: Node3D=district.installation_nodes.get(key,null) as Node3D
            check(group!=null,"Original installation "+key)
            if group==null:
                continue
            for node: Node in group.get_children():
                var body: StaticBody3D=node as StaticBody3D
                if body==null:
                    continue
                var skin: MeshInstance3D=body.get_node_or_null(
                    "G3ArchitecturalSignature") as MeshInstance3D
                if skin==null:
                    continue
                count+=1
                check(skin.mesh!=null,"Real faceted visual mesh")
                check(bool(skin.get_meta("g3_noncolliding",false)),
                    "No new physical obstacles")
                check(body.get_node_or_null("CollisionShape3D")!=null,
                    "Retained old physical collider")
                if body is HMInspectTarget:
                    check(String(skin.get_meta("g3_saved_owner_part_id",""))==
                        (body as HMInspectTarget).part_id,
                        "Old saved part still owns its repair")
        check(count==finish.decorated_faces,"No detached facade props")
    var env: WorldEnvironment=scene.get_node_or_null("CoastalEnvironment")
    var sun: DirectionalLight3D=scene.get_node_or_null("OvercastCoastalSun")
    check(env!=null and sun!=null,"Original weather nodes")
    if env!=null and sun!=null:
        check(env.environment.fog_enabled,"Coastal fog retained")
        check(env.environment.ambient_light_energy<.33,"Contrast refined")
        check(sun.light_energy>1.02,"Directional relief refined")
    var lifecycle:=HMPartLifecycle.new()
    scene.add_child(lifecycle)
    lifecycle.bind_stage(scene)
    check(lifecycle.installed.size()==345,"345 existing removable parts intact")
    scene.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G3_VISUAL_SIGNATURES_OK")
        quit(0)
    else:
        quit(1)
