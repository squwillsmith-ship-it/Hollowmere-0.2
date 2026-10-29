extends SceneTree
## Real GPU/software-rendered framebuffer capture; cannot pass under dummy --headless.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("Render QA scene missing")
		quit(1)
		return
	var app: Node = scene.instantiate()
	get_root().add_child(app)
	await process_frame
	app.call("show_stage")
	for i: int in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture_path: String = OS.get_environment("HOLLOWMERE_SCREENSHOT")
	if capture_path.is_empty():
		push_error("Render QA requires HOLLOWMERE_SCREENSHOT")
		quit(1)
		return
	var frame: Image = get_root().get_texture().get_image()
	if frame == null or frame.is_empty() or frame.get_width() < 640 or frame.get_height() < 360:
		push_error("No real framebuffer available")
		quit(1)
		return
	# Reject empty/solid-colour framebuffer: mere existence of a PNG is not rendering proof.
	var sampled: Dictionary = {}
	for gx: int in range(2, 15):
		for gy: int in range(2, 9):
			var px: int = int(float(gx) / 16.0 * frame.get_width())
			var py: int = int(float(gy) / 10.0 * frame.get_height())
			sampled[frame.get_pixel(px, py).to_html(false)] = true
	if sampled.size() < 3:
		push_error("Framebuffer is visually uniform, not a usable yard render")
		quit(1)
		return
	if frame.save_png(capture_path) != OK:
		push_error("Framebuffer capture was not written")
		quit(1)
		return
	print("HOLLOWMERE_STEP06_RENDER_OK size=" + str(frame.get_size()))
	app.free()
	quit(0)
