extends SceneTree
## G3 actual authored GLB ownership in the existing live village.
## Does not pretend to be a human first-person/Windows visual acceptance test.
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, description: String) -> void:
    if not ok:
        failures.append(description)
        push_error("G3_KIT: " + description)
func _run() -> void:
    var world := HMBrinewickBlockout.new()
    world.spawn_exploration_player = false
    root.add_child(world)
    for i: int in range(4):
        await physics_frame
    var district: HMBrinewickSites = world.district_sites
    check(district != null, "Original village district stage persists")
    if district != null:
        var facades: HMG3TexturedStructureAssembly = district.get_node_or_null(
            "G3ModelTextureStructureAssembly") as HMG3TexturedStructureAssembly
        check(facades != null, "New authored G3 textured models assembled in the real world")
        if facades != null:
            check(facades.finished, "Structure assembly finished")
            check(facades.loaded_models.size() == 6, "Six reusable GLB variants loaded")
            check(facades.assembled_parts >= 35, "Multiple actual building parts replaced by authored facades")
            check(facades.removable_owners > 0, "Original removable part owners have textured model visuals")
            check(facades.static_owners > 0, "Protected static owners have distinct building models")
            check(facades.assembled_parts ==
                facades.removable_owners + facades.static_owners,
                "No independent model owner or new harvesting system")
            check(facades.installation_counts.size() == 10, "Ten established installations assessed")
            for key: String in facades.owner_names:
                var last_slash: int = key.rfind("/")
                var group_id: String = key.substr(0, last_slash)
                var part_name: String = key.substr(last_slash + 1)
                var group: Node3D = district.installation_nodes.get(group_id, null) as Node3D
                check(group != null, "Original building group still present")
                if group == null:
                    continue
                var body: StaticBody3D = group.get_node_or_null(part_name) as StaticBody3D
                check(body != null, "Original collider-backed piece still present")
                if body == null:
                    continue
                var model: Node3D = body.get_node_or_null("G3TexturedFacadeAssembly") as Node3D
                check(model != null and model.get_child_count() > 0,
                    "GLB render surfaces imported and attached to original owner")
                check(body.get_node_or_null("CollisionShape3D") != null,
                    "Previous physical collider retained for player work")
                if model == null:
                    continue
                check(bool(model.get_meta("g3_noncolliding", false)),
                    "Decorative model adds no physical obstruction")
                if body is HMInspectTarget:
                    check(String(model.get_meta("g3_saved_owner_part_id", "")) ==
                        (body as HMInspectTarget).part_id,
                        "Dismantling original owner removes decorative GLB with it")
                var path: String = String(model.get_meta("g3_model_source", ""))
                check(ResourceLoader.exists(path), "GLB asset comes from real project model library")
    var catalog := HMCatalog.new()
    check(catalog.load_all(), "Original gameplay catalogue still loads")
    var lifecycle := HMPartLifecycle.new()
    world.add_child(lifecycle)
    lifecycle.bind_stage(world)
    check(lifecycle.installed.size() == 345, "All 345 originally saved salvage IDs preserved")
    check(HMSaveState.validate(catalog, HMSaveState.fresh(catalog)).is_empty(),
        "Save, campaign and intact/damaged contract unchanged")
    world.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G3_MODEL_TEXTURE_STRUCTURE_OK owners_preserved=345 models=6")
        quit(0)
    else:
        quit(1)
