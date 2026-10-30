extends SceneTree
## Seven authentic Godot Vulkan protected landmark camera frames.
const LABELS: Array[String] = [
    "well_listening","mine_seal","undercroft","bell_house",
    "containment_machine","tide_outfall","escape_berth"]
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var path: String=OS.get_environment("HOLLOWMERE_G4_CAPTURE_DIR")
    if path.is_empty():
        push_error("G4 screenshot directory not provided")
        quit(1)
        return
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    var camera:=Camera3D.new()
    camera.current=true
    camera.fov=65.0
    camera.far=180.0
    stage.add_child(camera)
    var fail: int=0
    for id: String in LABELS:
        var origin: Vector3=stage.underground_sites.locations[id]
        var offset: Vector3=Vector3(-8.0,2.6,8.2)
        var target: Vector3=origin+Vector3(0,1.3,0)
        match id:
            "well_listening":
                offset=Vector3(2.5,2.3,6.2)
            "mine_seal":
                offset=Vector3(-9.0,2.2,1.3)
                target=origin+Vector3(.1,1.2,0)
            "undercroft":
                offset=Vector3(-4.3,1.7,4.6)
            "bell_house":
                offset=Vector3(7.3,4.2,9.8)
                target=origin+Vector3(0,3,0)
            "containment_machine":
                offset=Vector3(7.0,4.7,8.6)
            "tide_outfall":
                offset=Vector3(-7.6,3.0,7.7)
            "escape_berth":
                offset=Vector3(-6.1,4.4,10.0)
        camera.global_position=origin+offset
        camera.look_at(target,Vector3.UP)
        for frame: int in range(9):
            await process_frame
        await RenderingServer.frame_post_draw
        var image: Image=root.get_texture().get_image()
        if image==null or image.is_empty() or image.get_width()<640:
            fail+=1
            continue
        if image.save_png(path.path_join("g4-"+id+".png"))!=OK:
            fail+=1
    stage.queue_free()
    await process_frame
    if fail==0:
        print("HOLLOWMERE_G4_SEVEN_VULKAN_PROTECTED_FRAMES_OK")
        quit(0)
    else:
        quit(1)
