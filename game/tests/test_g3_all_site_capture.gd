extends SceneTree
## Real 21-site production-gate panorama frames. Includes 2 atmospheric
## variants. All sites are the canonical coordinates; no camera teleport
## represents gameplay traversal or human-controlled salvage.
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func _shot(directory: String,label: String) -> void:
    for frame: int in range(8):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image==null or image.is_empty() or image.get_width()<640:
        failures.append("Empty actual renderer frame "+label)
        return
    if image.save_png(directory.path_join("g3-site-"+label+".png"))!=OK:
        failures.append("PNG save failed "+label)
    else:
        print("G3_VULKAN_SITE_FRAME "+label)

func _run() -> void:
    var directory: String=OS.get_environment("HOLLOWMERE_G3_21_RENDER_DIR")
    if directory.is_empty():
        push_error("G3 21-site capture needs HOLLOWMERE_G3_21_RENDER_DIR")
        quit(1)
        return
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    var camera:=Camera3D.new()
    camera.current=true
    camera.fov=64.0
    camera.far=270.0
    stage.add_child(camera)
    var ids: Array=stage.site_nodes.keys()
    ids.sort()
    if ids.size()!=21:
        failures.append("Need original 21 village markers")
    for item: Variant in ids:
        var site_id: String=String(item)
        var no: int=int(site_id.get_file().trim_prefix("site_"))
        var site: Node3D=stage.site_nodes[site_id]
        var focus: Vector3=site.global_position+Vector3(0,2.2,0)
        var angle: float=float((no*37)%180)*PI/180.0
        var offset:=Vector3(12.5*cos(angle),7.2,14.5*sin(angle))
        # Human-eye and slightly elevated long views without spawning a
        # camera inside neighbour walls, mining seal or high rock.
        if no==3 or no==4:
            offset=Vector3(-13,6,12)
        if no==13:
            offset=Vector3(-17,8.4,18)
            focus=site.global_position+Vector3(0,4.8,0)
        if no==14:
            offset=Vector3(-14,6.2,12)
        if no==16:
            offset=Vector3(17,12.0,21)
            focus=site.global_position+Vector3(0,7.0,0)
        if no==18 or no==19:
            offset=Vector3(-17,7.0,12)
        camera.global_position=site.global_position+offset
        camera.look_at(focus,Vector3.UP)
        await _shot(directory,"%02d"%no)
    var env: WorldEnvironment=stage.get_node("CoastalEnvironment") as WorldEnvironment
    var sun: DirectionalLight3D=stage.get_node("OvercastCoastalSun") as DirectionalLight3D
    if env==null or sun==null:
        failures.append("Real weather lighting objects absent")
    else:
        var original: Environment=env.environment
        var dark: Environment=original.duplicate() as Environment
        dark.background_color=Color("303943")
        dark.ambient_light_energy=.12
        dark.fog_density=original.fog_density*1.20
        env.environment=dark
        sun.light_energy=.14
        camera.global_position=stage.site_nodes["brinewick/site_13"].global_position+Vector3(-17,8.4,18)
        camera.look_at(stage.site_nodes["brinewick/site_13"].global_position+Vector3(0,4.8,0),Vector3.UP)
        await _shot(directory,"13-night-study")
        var mist: Environment=original.duplicate() as Environment
        mist.fog_density=original.fog_density*2.0
        env.environment=mist
        sun.light_energy=1.02
        camera.global_position=stage.site_nodes["brinewick/site_03"].global_position+Vector3(-13,6,12)
        camera.look_at(stage.site_nodes["brinewick/site_03"].global_position+Vector3(0,2.2,0),Vector3.UP)
        await _shot(directory,"03-heavy-fog")
        env.environment=original
    stage.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G3_TWENTY_ONE_SITES_VULKAN_OK sites=21 atmosphere=2")
        quit(0)
    else:
        for reason: String in failures:
            push_error("G3_SITE_QA "+reason)
        quit(1)
