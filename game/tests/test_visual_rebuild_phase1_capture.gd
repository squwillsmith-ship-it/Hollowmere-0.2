extends SceneTree
## Phase 1 matched-pose visual inspection on the *actual* Brinewick world.
## These are framebuffer frames, NOT approval or a substitute for player QA.
## Run in Godot 4.7.2 windowed Forward+/Vulkan with a real framebuffer:
## HOLLOWMERE_PHASE1_RENDER_DIR=/absolute/output/folder
## Run with a real window/display, e.g. Godot --path game --rendering-method gl_compatibility
## --script res://tests/test_visual_rebuild_phase1_capture.gd for DIAGNOSTIC OpenGL.
## The required primary art acceptance is Forward+/Vulkan (renderer selector: gl_compatibility
## must NOT be used for that run). Pin exact source SHA and record backend separately.
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var folder: String = OS.get_environment("HOLLOWMERE_PHASE1_RENDER_DIR")
    if folder.is_empty():
        push_error("HOLLOWMERE_PHASE1_RENDER_DIR not set; fail closed")
        quit(1)
        return
    var village := HMBrinewickBlockout.new()
    village.spawn_exploration_player = false
    root.add_child(village)
    var camera := Camera3D.new()
    camera.far = 380.0
    camera.fov = 68.0
    village.add_child(camera)
    camera.current = true
    for tick: int in range(6):
        await process_frame
    var u: Vector3 = village.underground_sites.locations["undercroft"]
    var bell: Vector3 = village.underground_sites.locations["bell_house"]
    # First two EXACTLY repeat the previous main Phase E camera targets;
    # the second two record additional normal-height first-person contexts.
    var poses: Array[Dictionary] = [
        {"name":"undercroft-matched",
            "eye":u+Vector3(-1.6,1.43,2.8),
            "focus":u+Vector3(-0.3,0.8,-0.5)},
        {"name":"bell-matched",
            "eye":bell+Vector3(5.0,6.7,6.0),
            "focus":bell+Vector3(0.0,1.0,0.0)},
        {"name":"undercroft-central-eye",
            "eye":u+Vector3(0.4,1.43,2.55),
            "focus":u+Vector3(0.0,0.5,1.0)},
        {"name":"bell-standing-eye",
            "eye":bell+Vector3(0.0,1.60,6.0),
            "focus":bell+Vector3(0.0,4.45,0.0)}
    ]
    for pose: Dictionary in poses:
        camera.position = pose["eye"]
        camera.look_at(pose["focus"],Vector3.UP)
        for frame: int in range(10):
            await process_frame
        await RenderingServer.frame_post_draw
        var pixels: Image = root.get_texture().get_image()
        if pixels == null or pixels.is_empty() or pixels.get_width() < 640:
            push_error("No real Phase 1 framebuffer: " + String(pose["name"]))
            village.queue_free()
            quit(1)
            return
        var save_to: String = folder.path_join(
            "phase1-" + String(pose["name"]) + ".png")
        if pixels.save_png(save_to) != OK:
            push_error("Could not save Phase 1 framebuffer: " + save_to)
            village.queue_free()
            quit(1)
            return
        print("HOLLOWMERE_PHASE1_FRAME ",pose["name"]," ",pixels.get_size())
    village.queue_free()
    await process_frame
    print("HOLLOWMERE_PHASE1_MATCHED_CAPTURE_OK")
    quit(0)
