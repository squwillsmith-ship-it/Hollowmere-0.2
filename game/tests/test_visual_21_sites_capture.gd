extends SceneTree
## Visual diagnostics only: 21 site functions, two real framebuffer camera probes
## each. "Wide" is an elevated establishing camera; "near" is a closer
## camera probe and does NOT establish safe player-capsule placement.
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var directory: String = OS.get_environment("HOLLOWMERE_SITE_RENDER_DIR")
    if directory.is_empty():
        push_error("Missing HOLLOWMERE_SITE_RENDER_DIR")
        quit(1)
        return
    var village := HMBrinewickBlockout.new()
    village.spawn_exploration_player = false
    root.add_child(village)
    var camera := Camera3D.new()
    camera.far = 320.0
    camera.fov = 65.0
    village.add_child(camera)
    camera.current = true
    for warmup: int in range(5):
        await process_frame
        await RenderingServer.frame_post_draw
    var registry := HMCatalog.new()
    if not registry.load_all():
        push_error("Cannot load original 21-site registry")
        quit(1)
        return
    var count: int = 0
    for entry: Variant in registry.entries("locations", "sites"):
        var id: String = String(entry["id"])
        if not village.site_nodes.has(id):
            errors.append("Site not installed: " + id)
            continue
        var marker: Node3D = village.site_nodes[id] as Node3D
        var focus: Vector3 = marker.global_position + Vector3(0.0, 1.55, 0.0)
        for pose: String in ["wide", "near"]:
            if pose == "wide":
                camera.position = focus + Vector3(13.0, 7.5, 18.5)
            else:
                camera.position = focus + Vector3(5.5, 1.1, 7.5)
            camera.look_at(focus, Vector3.UP)
            for tick: int in range(9):
                await process_frame
                await RenderingServer.frame_post_draw
            var frame: Image = root.get_texture().get_image()
            if frame == null or frame.is_empty() or frame.get_width() < 640:
                errors.append("Missing framebuffer for " + id + "/" + pose)
                continue
            var colors: Dictionary = {}
            for x: int in range(3, 14):
                for y: int in range(2, 9):
                    colors[frame.get_pixel(int(x * frame.get_width() / 16), int(y * frame.get_height() / 10)).to_html(false)] = true
            if colors.size() < 6:
                errors.append("Uniform frame for " + id + "/" + pose)
                continue
            var output: String = directory.path_join("site-" + id.get_file() + "-" + pose + ".png")
            if frame.save_png(output) != OK:
                errors.append("Failed writing " + output)
            else:
                count += 1
                print("HOLLOWMERE_SITE_FRAME ", id, " ", pose, " ", frame.get_size())
    village.queue_free()
    await process_frame
    if errors.is_empty() and count == 42:
        print("HOLLOWMERE_SITE_CAPTURE_OK count=42")
        quit(0)
    else:
        for issue: String in errors:
            push_error(issue)
        push_error("Captured " + str(count) + " of expected 42 frames")
        quit(1)
