extends SceneTree
## Actual Godot 4.7.2 fixed-camera G1 evidence. Use the SAME poses
## to capture baseline eddeaef2 and the G1 candidate; never fake frames.
## Export HOLLOWMERE_G1_CAPTURE_DIR to a writable directory.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder: String = OS.get_environment("HOLLOWMERE_G1_CAPTURE_DIR")
	if folder.is_empty():
		push_error("HOLLOWMERE_G1_CAPTURE_DIR is required")
		quit(1)
		return
	var stage: HMBrinewickBlockout = load("res://scenes/brinewick_blockout.tscn").instantiate() as HMBrinewickBlockout
	stage.spawn_exploration_player = false
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.name = "G1FixedCamera"
	camera.current = true
	camera.far = 340.0
	camera.fov = 72.0
	stage.add_child(camera)
	var scenes: Array[Dictionary] = [
		{"name":"01_quay_eye","eye":Vector3(-43,3.1,19),"look":Vector3(-23,2.0,23)},
		{"name":"02_warehouse_eye","eye":Vector3(8,3.6,43),"look":Vector3(19,3.3,30)},
		{"name":"03_cottage_eye","eye":Vector3(26,3.8,41),"look":Vector3(35,3.7,24)},
		{"name":"04_embankment_eye","eye":Vector3(42,4.0,43),"look":Vector3(59,6.5,30)},
		{"name":"05_coastal_wide","eye":Vector3(-60,14,69),"look":Vector3(1,3.5,18)}
	]
	for pose: Dictionary in scenes:
		camera.global_position = pose["eye"]
		camera.look_at(pose["look"],Vector3.UP)
		for tick: int in range(22):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.get_width() < 640:
			push_error("G1 framebuffer failed at "+String(pose["name"]))
			quit(1)
			return
		var samples: Dictionary = {}
		for ix: int in range(2,14):
			for iz: int in range(2,8):
				samples[frame.get_pixel(int(ix*frame.get_width()/16),
					int(iz*frame.get_height()/10)).to_html(false)] = true
		if samples.size() < 10:
			push_error("G1 image near uniform at "+String(pose["name"]))
			quit(1)
			return
		var target: String = folder.path_join("g1-"+String(pose["name"])+".png")
		if frame.save_png(target) != OK:
			push_error("Could not save G1 real image: "+target)
			quit(1)
			return
		print("G1_FRAME "+String(pose["name"])+" "+str(frame.get_size()))
	stage.queue_free()
	await process_frame
	print("HOLLOWMERE_G1_CAPTURE_OK")
	quit(0)
