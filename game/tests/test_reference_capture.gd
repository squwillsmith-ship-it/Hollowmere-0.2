extends SceneTree
## Exact-engine Forward+/Vulkan reference imagery, not generative concept art.
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var where: String = OS.get_environment("HOLLOWMERE_REFERENCE_RENDER_DIR")
	if where.is_empty():
		push_error("HOLLOWMERE_REFERENCE_RENDER_DIR absent")
		quit(1)
		return
	var world := HMBrinewickBlockout.new()
	world.spawn_exploration_player = false
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 300.0
	camera.fov = 62.0
	world.add_child(camera)
	camera.current = true
	for key: String in ["cottage", "warehouse"]:
		var site_id: String = "brinewick/site_07" if key == "cottage" else "brinewick/site_04"
		var at: Vector3 = world.site_nodes[site_id].position
		camera.position = at + (Vector3(7.4, 5.8, 12) if key == "cottage" else Vector3(13, 9, 18))
		camera.look_at(at + (Vector3(0, 1.7, 0) if key == "cottage" else Vector3(0, 2.8, 0)), Vector3.UP)
		for tick: int in range(22):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.get_width() < 640:
			push_error("No rendered framebuffer for " + key)
			quit(1)
			return
		var unique: Dictionary = {}
		for x: int in range(3, 14):
			for y: int in range(2, 9):
				unique[frame.get_pixel(int(x*frame.get_width()/16),int(y*frame.get_height()/10)).to_html(false)] = true
		if unique.size() < 10:
			push_error("Reference rendering suspiciously uniform: "+key)
			quit(1)
			return
		var path: String = where.path_join("reference-"+key+".png")
		if frame.save_png(path) != OK:
			push_error("Cannot save actual reference render: "+path)
			quit(1)
			return
		print("HOLLOWMERE_REFERENCE_FRAME "+key+" "+str(frame.get_size()))
	world.free()
	print("HOLLOWMERE_REFERENCE_RENDER_OK")
	quit(0)
