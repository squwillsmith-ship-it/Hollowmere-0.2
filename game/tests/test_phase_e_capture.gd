extends SceneTree
## Captures actual Forward+/Vulkan frames of authored Phase E architecture.
## These images are engineering scenes, not concept art or final production art.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var directory: String = OS.get_environment("HOLLOWMERE_UNDERGROUND_RENDER_DIR")
	if directory.is_empty():
		push_error("HOLLOWMERE_UNDERGROUND_RENDER_DIR absent")
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
	var locations: Dictionary = village.underground_sites.locations
	for label: String in ["well", "mine", "undercroft", "bell", "harbour", "headland", "inn", "mine_office", "chapel", "shore"]:
		var point: Vector3
		match label:
			"well":
				point = locations["well_listening"]
				camera.position = point + Vector3(-0.8, 1.75, 4.7)
			"mine":
				point = locations["mine_seal"]
				camera.position = point + Vector3(-10.7, 2.05, 0.1)
			"undercroft":
				point = locations["undercroft"]
				# Match a standing player camera, not an artificially lowered
				# beauty-shot pose (player capsule 1.8 m; Head is +0.59 m).
				camera.position = point + Vector3(-1.6, 1.43, 2.8)
			"harbour":
				point = Vector3(-24.0,2.6,13.0)
				camera.position = point + Vector3(8.0,4.0,15.5)
			"headland":
				point = Vector3(128.5,12.6,-13.5)
				camera.position = point + Vector3(-13.0,6.4,-18.0)
			"inn":
				point = Vector3(70.0,10.3,24.0)
				camera.position = Vector3(59.5,13.3,38.6)
			"mine_office":
				point = Vector3(157.0,14.6,-9.0)
				camera.position = Vector3(147.7,17.7,3.8)
			"chapel":
				point = Vector3(139.0,16.4,-25.0)
				camera.position = Vector3(124.0,21.6,-43.2)
			"shore":
				point = Vector3(-38.8,0.4,10.3)
				camera.position = Vector3(-61.0,8.5,29.0)
			_:
				point = locations["bell_house"]
				camera.position = point + Vector3(5.0, 6.7, 6.0)
		camera.look_at(point + (Vector3(-0.3, 0.8, -0.5) if label == "undercroft" else Vector3(0, 1.0, 0)), Vector3.UP)
		for frame_num: int in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.get_width() < 640:
			push_error("Missing real underground framebuffer " + label)
			quit(1)
			return
		var colors: Dictionary = {}
		for x: int in range(3, 14):
			for y: int in range(2, 9):
				colors[frame.get_pixel(int(x*frame.get_width()/16),int(y*frame.get_height()/10)).to_html(false)] = true
		if colors.size() < 6:
			push_error("Uniform or blank Phase E frame " + label)
			quit(1)
			return
		var path: String = directory.path_join("phase-e-" + label + ".png")
		if frame.save_png(path) != OK:
			push_error("Unable to save exact-render frame " + label)
			quit(1)
			return
		print("PHASE_E_FRAME " + label + " " + str(frame.get_size()))
		# A separately named comparison at the *original* pre-rebuild pose.
		# This is NEVER an acceptance frame or substitute for standing-eye QA;
		# it isolates geometric changes from the revised main camera position.
		if label == "undercroft":
			camera.position = point + Vector3(-1.6, 0.84, 2.8)
			camera.look_at(point + Vector3(-0.3, 0.8, -0.5), Vector3.UP)
			for old_frame: int in range(10):
				await process_frame
			await RenderingServer.frame_post_draw
			var parity_image: Image = root.get_texture().get_image()
			if parity_image == null or parity_image.is_empty() or parity_image.get_width() < 640:
				push_error("Missing legacy-pose comparison frame")
				quit(1)
				return
			var parity_path: String = directory.path_join("phase-e-undercroft-legacy-pose.png")
			if parity_image.save_png(parity_path) != OK:
				push_error("Unable to save same-pose undercroft comparison")
				quit(1)
				return
			print("HOLLOWMERE_BEFORE_POSE_PARITY_ONLY " + parity_path)
	village.free()
	print("HOLLOWMERE_PHASE_E_RENDER_OK")
	quit(0)
