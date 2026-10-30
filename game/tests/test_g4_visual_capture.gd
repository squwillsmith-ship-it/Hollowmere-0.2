extends SceneTree
const IDS: Array[String]=["well_listening","mine_seal","undercroft","bell_house"]
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var folder: String=OS.get_environment("HOLLOWMERE_G4_RENDER_DIR")
    if folder.is_empty():
        quit(1)
        return
    var world:=HMBrinewickBlockout.new()
    world.spawn_exploration_player=false
    root.add_child(world)
    var camera:=Camera3D.new()
    camera.current=true
    camera.fov=68.0
    world.add_child(camera)
    var failures: int=0
    for key: String in IDS:
        var p: Vector3=world.underground_sites.locations[key]
        var camera_offset: Vector3=Vector3(0,1.4,0)
        var look_offset: Vector3=Vector3(2,1.6,2)
        match key:
            "well_listening":
                camera_offset=Vector3(-2.1,1.3,-2.0)
                look_offset=Vector3(2.0,1.4,3.0)
            "mine_seal":
                # The corridor approaches the barrier from smaller X,
                # not beyond the closed permanent seal.
                camera_offset=Vector3(-8.5,1.1,0)
                look_offset=Vector3(0,1.5,0)
            "undercroft":
                camera_offset=Vector3(-1.8,1.1,-1.5)
                look_offset=Vector3(2.0,1.6,2.0)
            "bell_house":
                camera_offset=Vector3(7.0,5.1,9.5)
                look_offset=Vector3(0,2.8,0)
        camera.global_position=p+camera_offset
        camera.look_at(p+look_offset,Vector3.UP)
        for tick: int in range(16):
            await process_frame
        await RenderingServer.frame_post_draw
        var picture: Image=root.get_texture().get_image()
        if picture==null or picture.is_empty() or picture.get_width()<640:
            failures+=1
            continue
        if picture.save_png(folder.path_join("g4-"+key+".png"))!=OK:
            failures+=1
    world.queue_free()
    await process_frame
    if failures==0:
        print("HOLLOWMERE_G4_FOUR_VULKAN_SCENES_OK")
        quit(0)
    else:
        quit(1)
