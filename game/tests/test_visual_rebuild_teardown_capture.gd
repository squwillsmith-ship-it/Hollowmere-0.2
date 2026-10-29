extends SceneTree
## QA-only actual world framebuffer capture of saved-part presentation states.
## The staged state edits are synthetic diagnostics, NOT a human-operated teardown.
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_capture")

func _fail(message: String) -> void:
    errors.append(message)
    push_error("VISUAL_TEARDOWN: " + message)

func _capture() -> void:
    var destination: String = OS.get_environment("HOLLOWMERE_TEARDOWN_RENDER_DIR")
    if destination.is_empty():
        _fail("Output folder not configured")
        quit(1)
        return
    var cat := HMCatalog.new()
    if not cat.load_all():
        _fail("Canonical 351-part catalogue absent")
        quit(1)
        return
    var stage := HMBrinewickBlockout.new()
    stage.spawn_exploration_player = false
    root.add_child(stage)
    var life := HMPartLifecycle.new()
    life.name = "TeardownVisualStateLifecycle"
    stage.add_child(life)
    life.bind_stage(stage)
    var camera := Camera3D.new()
    camera.far = 210.0
    camera.fov = 64.0
    stage.add_child(camera)
    camera.current = true
    var pristine: Dictionary = HMSaveState.fresh(cat)
    for building: String in ["cottage", "warehouse"]:
        var site_id: String = "brinewick/site_07" if building == "cottage" else "brinewick/site_04"
        var pos: Vector3 = stage.site_nodes[site_id].global_position
        camera.position = pos + (Vector3(7.4, 5.8, 12.0) if building == "cottage" else Vector3(13.0, 9.0, 18.0))
        camera.look_at(pos + (Vector3(0,1.7,0) if building == "cottage" else Vector3(0,2.8,0)),Vector3.UP)
        var targets: Array[String] = []
        for key: Variant in life.installed.keys():
            var id: String = String(key)
            if (building == "cottage" and id.begins_with("fixture/house/")) or (building == "warehouse" and id.begins_with("village/04/old_warehouse/")):
                targets.append(id)
        targets.sort()
        if targets.size() != (9 if building == "cottage" else 42):
            _fail("Unexpected authoring ID count for " + building + ": " + str(targets.size()))
            continue
        for condition: String in ["intact", "half", "heavy"]:
            var snapshot: Dictionary = pristine.duplicate(true)
            var cleared: int = 0
            for index: int in range(targets.size()):
                var id: String = targets[index]
                var remove: bool = false
                if building == "cottage":
                    remove = (condition == "half" and id in ["fixture/house/cladding", "fixture/house/shutters", "fixture/house/slate_patch", "fixture/house/front_infill"]) or (condition == "heavy" and id not in ["fixture/house/stone_block", "fixture/house/footing"])
                else:
                    # Distribute removals over roof, joinery and wall sections.
                    remove = (condition == "half" and index % 2 == 0) or (condition == "heavy" and index % 5 != 0)
                if remove:
                    snapshot["world"]["parts"][id]["phase"] = "released"
                    cleared += 1
            life.reconcile(snapshot)
            for id: String in targets:
                var removed: bool = String(snapshot["world"]["parts"][id]["phase"]) == "released"
                var part: HMInspectTarget = life.installed[id]
                if part.visible == removed or (removed and part.collision_layer != 0):
                    _fail("Wrong visibility/collision after release: " + id)
                # Visual subtree remains parent-owned, no independent free-floating children.
                if removed and not (part.get_parent() is Node3D):
                    _fail("Lost assembly ownership: " + id)
            for frame: int in range(15):
                await process_frame
            await RenderingServer.frame_post_draw
            var shot: Image = root.get_texture().get_image()
            if shot == null or shot.is_empty() or shot.get_width() < 640:
                _fail("Missing actual rendered frame: " + building + " " + condition)
                continue
            var dest: String = destination.path_join("teardown-" + building + "-" + condition + ".png")
            if shot.save_png(dest) != OK:
                _fail("Cannot save " + dest)
            else:
                print("HOLLOWMERE_TEARDOWN_FRAME ",building," ",condition," released=",cleared,"/",targets.size()," pixels=",shot.get_size())
    stage.queue_free()
    await process_frame
    if errors.is_empty():
        print("HOLLOWMERE_VISUAL_TEARDOWN_RENDER_OK")
        quit(0)
    else:
        quit(1)
