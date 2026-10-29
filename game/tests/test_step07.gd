extends SceneTree
## Executable Godot QA: catalogue, raycast, occlusion, range and pause isolation.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("STEP07 FAILED: " + detail)


func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene loads")
	if scene == null:
		quit(1)
		return
	var app: Node = scene.instantiate()
	get_root().add_child(app)
	await process_frame
	var actor: HMFirstPerson = app.get("player") as HMFirstPerson
	var inspector: HMInspector = app.get("inspector") as HMInspector
	check(actor != null and inspector != null, "Player and inspector exist")
	if actor == null or inspector == null:
		quit(1)
		return
	check(InputMap.has_action("hm_inspect"), "Inspection key mapped")
	check(inspector.current.is_empty(), "Menu has no inspection")
	var c: HMCatalog = inspector.catalog
	check(c != null, "Versioned catalog loaded")
	if c == null:
		quit(1)
		return
	var active: Array = inspector.active_ids
	var hands: Array = ["hands"]
	var hammer: Array = ["hands", "claw_hammer"]
	check(HMInspectionRules.describe(c, "fixture/shed/loose_rope", active, hands, [], true).get("read_only_actionable", false), "Hands can inspect loose scrap")
	check(String(HMInspectionRules.describe(c, "fixture/shed/roof_patch", active, hands, [], true).get("status", "")).contains("Claw hammer"), "Unknown tool gives a blocker")
	var loaded: Dictionary = HMInspectionRules.describe(c, "fixture/shed/posts", active, hammer, [], true)
	check(not loaded.get("read_only_actionable", true) and loaded.get("risks", []).size() > 0, "Loaded post warns")
	check(HMInspectionRules.describe(c, "fixture/shed/posts", ["fixture/shed/posts"], hammer, [], true).get("read_only_actionable", false), "Cleared supports allow theoretical work")
	check(HMInspectionRules.describe(c, "fixture/harbour/bell", active, ["hands", "saw"], [], true).get("protected", false), "Bell protected")
	check(not HMInspectionRules.describe(c, "fixture/shed/loose_rope", active, hands, [], false).get("read_only_actionable", true), "Too-far item not usable")
	check(HMInspectionRules.describe(c, "missing/id", active, hands, [], true).is_empty(), "Uncatalogued target yields nothing")
	app.call("show_stage")
	for i: int in range(5):
		await physics_frame
	var aimed: Dictionary = inspector.probe()
	check(aimed.get("part_id", "") == "fixture/shed/loose_rope" and aimed.get("reachable", false), "Camera ray strikes authored fixture within reach")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0, 1.55, 6.45)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	(app.get("stage") as Node3D).add_child(wall)
	await physics_frame
	check(inspector.probe().is_empty(), "Opaque wall blocks target ray")
	wall.queue_free()
	await physics_frame
	actor.global_position = Vector3(0, 0.96, 9.45)
	await physics_frame
	var distant: Dictionary = inspector.probe()
	check(distant.get("part_id", "") == "fixture/shed/loose_rope" and not distant.get("reachable", true), "Visible out-of-reach target not actionable")
	actor.global_position = Vector3(0, 0.96, 8)
	await physics_frame
	app.call("pause_stage")
	check(inspector.current.is_empty() and not inspector.enabled, "Pause immediately clears inspection")
	app.call("resume_stage")
	for i: int in range(5):
		await physics_frame
	var resumed: Dictionary = inspector.probe()
	check(inspector.enabled and resumed.get("part_id", "") == "fixture/shed/loose_rope", "Resume restores targeting: " + str(resumed))
	app.call("show_menu")
	check(inspector.current.is_empty(), "Title clears targeting")
	app.free()
	if failures.is_empty():
		print("HOLLOWMERE_STEP07_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP07_TEST_FAIL count=", failures.size())
		quit(1)
