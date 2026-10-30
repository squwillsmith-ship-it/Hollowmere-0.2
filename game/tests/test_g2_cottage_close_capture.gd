extends SceneTree
## Fixed real Forward+/Vulkan cottage art inspection poses.
## Visual evidence only, not proof of player motion or owner approval.
const VIEWS: Array[String] = [
    "front_eye","west_wall","roof_assembly"]
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var destination: String = OS.get_environment("HOLLOWMERE_G2_CLOSE_CAPTURE_DIR")
    if destination.is_empty():
        push_error("G2_CLOSE_CAPTURE: output folder not specified")
        quit(1)
        return
    var stage := HMBrinewickBlockout.new()
    stage.spawn_exploration_player = false
    root.add_child(stage)
    var camera := Camera3D.new()
    camera.far=155.0
    camera.fov=63.0
    stage.add_child(camera)
    camera.current=true
    var at: Vector3 = stage.site_nodes["brinewick/site_07"].global_position
    var offsets: Array[Vector3] = [
        Vector3(0.75,1.76,7.2),
        Vector3(-7.0,2.0,2.4),
        Vector3(5.0,6.3,5.9)]
    var targets: Array[Vector3] = [
        Vector3(0.0,1.8,0.0),Vector3(0.0,1.9,0.0),
        Vector3(0.0,3.35,0.0)]
    for index: int in range(VIEWS.size()):
        camera.global_position=at+offsets[index]
        camera.look_at(at+targets[index],Vector3.UP)
        for tick: int in range(21):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        if img == null or img.is_empty() or img.get_width()<640:
            errors.append("Missing actual render for "+VIEWS[index])
            continue
        var filename: String = destination.path_join("g2-cottage-"+VIEWS[index]+".png")
        if img.save_png(filename) != OK:
            errors.append("Could not save "+filename)
        else:
            print("G2_COTTAGE_CLOSE_FRAME "+VIEWS[index]+" pixels="+str(img.get_size()))
    stage.queue_free()
    await process_frame
    if errors.is_empty():
        print("HOLLOWMERE_G2_COTTAGE_CLOSE_RENDER_OK")
        quit(0)
    else:
        for error: String in errors:
            push_error("G2_CLOSE_CAPTURE: "+error)
        quit(1)
