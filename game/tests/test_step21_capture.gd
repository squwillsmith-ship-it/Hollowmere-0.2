extends SceneTree
## Captures neutral and maritime-coastal software framebuffer of real Godot
## StandardMaterial3D PBR surfaces. This is NOT a GPU/Windows GUI playtest.
func _initialize() -> void:
	call_deferred("run_capture")
func run_capture() -> void:
	var target_dir: String = OS.get_environment("HOLLOWMERE_MATERIAL_RENDER_DIR")
	if target_dir.is_empty():
		push_error("Must supply output directory")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c3c6c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f1ebe2")
	env.ambient_light_energy = 0.55
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-28,0)
	sun.light_energy = 0.85
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0,0,4.0)
	stage.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var mat_keys: Array[String] = HMMaterialLibrary.MATERIALS
	for i: int in range(mat_keys.size()):
		var tile := MeshInstance3D.new()
		tile.name = mat_keys[i]
		var geometry := BoxMesh.new()
		geometry.size = Vector3(1.65,1.65,0.15)
		tile.mesh = geometry
		tile.material_override = HMMaterialLibrary.get_shared(mat_keys[i])
		tile.position = Vector3(float(i % 3 - 1)*2.1, (0.5 - float(i / 3))*2.1, 0)
		stage.add_child(tile)
	for mode: String in ["neutral", "coastal"]:
		if mode == "coastal":
			env.background_color = Color("929ca5")
			env.ambient_light_color = Color("aab8c5")
			env.ambient_light_energy = 0.50
			sun.light_color = Color("d1d9de")
			sun.light_energy = 0.63
		for j: int in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.get_width() < 640:
			push_error("Missing Godot render " + mode)
			quit(1)
			return
		var path: String = target_dir.path_join("step21-materials-" + mode + ".png")
		if frame.save_png(path) != OK:
			push_error("Could not write " + path)
			quit(1)
			return
		print("STEP21_RENDER_CAPTURED " + mode + " " + str(frame.get_size()))
	stage.queue_free()
	print("HOLLOWMERE_STEP21_RENDER_OK")
	quit(0)