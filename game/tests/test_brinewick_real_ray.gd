extends SceneTree
## End-to-end physical first-hit Brinewick run; not a native Windows GUI playtest.
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BRINEWICK RAY: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	await process_frame
	app.show_stage()
	var actor: HMFirstPerson = app.player
	var inspector: HMInspector = app.inspector
	var belt: HMToolbelt = app.toolbelt
	var part_id: String = "village/02/yard_scrap/looseropecoil"
	var part: HMInspectTarget = app.lifecycle.installed.get(part_id) as HMInspectTarget
	check(part != null, "Physical hand scrap collider exists")
	var point: Vector3 = part.global_position
	actor.global_position = point + Vector3(0, 0.10, 2.1)
	actor.rotation.y = 0.0
	actor.velocity = Vector3.ZERO
	var origin: Vector3 = actor.view_camera.global_position
	actor.head.rotation.x = -atan2(origin.y - point.y, origin.z - point.z)
	for i: int in range(6):
		await physics_frame
	var target: Dictionary = inspector.probe()
	check(String(target.get("part_id","")) == part_id, "Actual first-blocking camera physics ray hits Brinewick starter part")
	if String(target.get("part_id","")) == part_id:
		check(bool(app.perform_work_once().get("ok",false)), "Manual first-person work acts on physical target")
		check(bool(app.perform_release_once().get("ok",false)), "Manual release removes exact target")
		check(not part.visible and part.collision_layer == 0, "Physical model and collision removed")
		var oid: String = part_id+"/out/lot"
		for i: int in range(4):
			await physics_frame
		check(app.lifecycle.recovered.has(oid), "Recovered material exists as ray-hittable lot")
		if app.lifecycle.recovered.has(oid):
			var loose: HMRecoveredOutput = app.lifecycle.recovered[oid]
			point = loose.global_position
			origin = actor.view_camera.global_position
			actor.head.rotation.x = -atan2(origin.y - point.y, origin.z - point.z)
			for i: int in range(5):
				await physics_frame
			check(String(inspector.probe().get("output_id","")) == oid, "Player first-hit ray sees recovered salvage")
			check(bool(app.manual_lift_or_place().get("ok",false)), "Player lift confirms physical lot")
			check(belt.state["world"]["outputs"][oid]["location"] == "carried", "Material physically carried")
			check(not bool(app.manual_register().get("ok",false)), "Cannot register remotely")
			actor.global_position = app.yard_service.pad_center
			for i: int in range(3):
				await physics_frame
			check(bool(app.manual_unload().get("ok",false)), "Manual receiving at physical pad")
			check(bool(app.manual_register().get("ok",false)), "Manually registers recovered lot")
			actor.global_position = app.yard_service.counter_center
			for i: int in range(3):
				await physics_frame
			check(bool(app.manual_sell().get("ok",false)), "Manually sells registered lot")
			check(int(belt.state["economy"]["credits"]) > 0, "Credits only on manual sale")
			check(HMSaveState.validate(inspector.catalog,belt.state).is_empty(), "Whole player-led physics journey conserved")
	app.show_menu()
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_BRINEWICK_REAL_RAY_OK")
		quit(0)
	else:
		quit(1)
