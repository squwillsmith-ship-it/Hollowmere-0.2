extends SceneTree
## Actual Godot Forward+/Vulkan viewport frames with fixed player-height
## camera poses. Saved-state stripping is a synthetic diagnostic, never a
## claim of player-completed dismantling or art approval.
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _shot(stage: Node3D, camera: Camera3D, folder: String,
		title: String, at: Vector3, focus: Vector3) -> void:
	camera.position = at
	camera.look_at(focus,Vector3.UP)
	for frame: int in range(22):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.get_width() < 640:
		problems.append("Missing actual rendered framebuffer " + title)
		return
	var path: String = folder.path_join("benchmark-" + title + ".png")
	if image.save_png(path) != OK:
		problems.append("Cannot save " + path)
	else:
		print("HOLLOWMERE_BENCHMARK_FRAME ", title, " pixels=", image.get_size())

func _run() -> void:
	var folder: String = OS.get_environment("HOLLOWMERE_BENCHMARK_RENDER_DIR")
	if folder.is_empty():
		push_error("HOLLOWMERE_BENCHMARK_RENDER_DIR missing")
		quit(1)
		return
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.fov = 67.0
	camera.near = 0.065
	camera.far = 230.0
	stage.add_child(camera)
	camera.current = true
	var cat := HMCatalog.new()
	if not cat.load_all():
		quit(1)
		return
	var life := HMPartLifecycle.new()
	stage.add_child(life)
	life.bind_stage(stage)
	var pristine: Dictionary = HMSaveState.fresh(cat)
	life.reconcile(pristine)
	await _shot(stage,camera,folder,"01-quay-eye",
		Vector3(-39.5,3.95,14.5),Vector3(-15.0,4.1,16.0))
	await _shot(stage,camera,folder,"02-haul-eye",
		Vector3(-5.0,3.72,11.2),Vector3(25.0,3.8,23.0))
	await _shot(stage,camera,folder,"03-warehouse-eye",
		Vector3(18.5,3.72,42.0),Vector3(18.0,4.1,29.0))
	await _shot(stage,camera,folder,"04-cottage-eye",
		Vector3(38.2,3.7,34.7),Vector3(35.0,3.8,24.0))
	var stripped: Dictionary = pristine.duplicate(true)
	for part_id: Variant in life.installed.keys():
		var id: String = String(part_id)
		if id.begins_with("village/04/old_warehouse/"):
			if id.contains("roof") or id.contains("back_frame"):
				stripped["world"]["parts"][id]["phase"] = "released"
	life.reconcile(stripped)
	await _shot(stage,camera,folder,"05-warehouse-synthetic-stripped",
		Vector3(18.5,3.72,42.0),Vector3(18.0,4.1,29.0))
	life.reconcile(pristine)
	stage.queue_free()
	await process_frame
	if problems.is_empty():
		print("HOLLOWMERE_HARBOUR_BENCHMARK_RENDER_OK")
		quit(0)
	else:
		for problem: String in problems:
			push_error(problem)
		quit(1)
