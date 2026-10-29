extends SceneTree
## Actual Godot 4.7.2 Forward+/Vulkan Step25 scene render capture.
## Tests *visualized prototype geometry*, not finished-game scenery.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var directory: String = OS.get_environment("HOLLOWMERE_BLOCKOUT_RENDER_DIR")
	if directory.is_empty():
		push_error("Set HOLLOWMERE_BLOCKOUT_RENDER_DIR")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/brinewick_blockout.tscn") as PackedScene
	if packed == null:
		push_error("Step25 Brinewick scene missing")
		quit(1)
		return
	var stage: Node3D = packed.instantiate() as Node3D
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.name = "TestCaptureCamera"
	camera.far = 550.0
	stage.add_child(camera)
	camera.current = true
	for view_name: String in ["aerial", "harbour"]:
		if view_name == "aerial":
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 139.0
			camera.position = Vector3(60, 154, 154)
			camera.look_at(Vector3(57, 1, 0), Vector3.UP)
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 72.0
			camera.position = Vector3(-45, 38, 70)
			camera.look_at(Vector3(70, 5, 0), Vector3.UP)
		for tick: int in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.get_width() < 640:
			push_error("Missing Step25 real rendered framebuffer")
			quit(1)
			return
		var samples: Dictionary = {}
		for x: int in range(2, 14):
			for y: int in range(2, 8):
				samples[frame.get_pixel(int(x * frame.get_width() / 16), int(y * frame.get_height() / 10)).to_html(false)] = true
		if samples.size() < 5:
			push_error("Step25 image is visually uniform, not a usable render")
			quit(1)
			return
		var name: String = "step25-brinewick-" + view_name + ".png"
		var path: String = directory.path_join(name)
		if frame.save_png(path) != OK:
			push_error("Could not save Step25 framebuffer " + path)
			quit(1)
			return
		print("STEP25_RENDER_CAPTURED " + view_name + " " + str(frame.get_size()))
	stage.free()
	print("HOLLOWMERE_STEP25_RENDER_OK")
	quit(0)
