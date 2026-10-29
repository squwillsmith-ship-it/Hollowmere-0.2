extends SceneTree
## Real first-person camera/physics-to-ledger journey, without mock item IDs.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		push_error("STEP17 INTEGRATION FAILED: " + detail)
func _run() -> void:
	var game: PackedScene = load("res://scenes/main.tscn")
	var app: Node = game.instantiate()
	get_root().add_child(app)
	await process_frame
	app.call("show_stage")
	var actor: HMFirstPerson = app.get("player") as HMFirstPerson
	var inspector: HMInspector = app.get("inspector") as HMInspector
	var belt: HMToolbelt = app.get("toolbelt") as HMToolbelt
	var lifecycle: HMPartLifecycle = app.get("lifecycle") as HMPartLifecycle
	for i: int in range(5):
		await physics_frame
	check(inspector.probe().get("part_id", "") == "fixture/shed/loose_rope", "Real center ray hits intact fixture")
	check(app.call("perform_work_once").get("ok", false), "Mouse-equivalent work is manual")
	check(app.call("perform_release_once").get("ok", false), "R-equivalent release occurs after work")
	for i: int in range(5):
		await physics_frame
	var oid: String = "fixture/shed/loose_rope/out/rope"
	check(lifecycle.recovered.has(oid), "Physical output exists before collection")
	if lifecycle.recovered.has(oid):
		var output: HMRecoveredOutput = lifecycle.recovered[oid]
		var target: Vector3 = output.global_position
		var camera: Vector3 = actor.view_camera.global_position
		actor.head.rotation.x = -atan2(camera.y - target.y, camera.z - target.z)
	for i: int in range(6):
		await physics_frame
	check(inspector.probe().get("output_id", "") == oid, "Physical first-hit ray selects stable output")
	var got: Dictionary = app.call("manual_lift_or_place")
	check(got.get("ok", false), "C-equivalent physically lifts the visible output")
	check(belt.state["world"]["outputs"][oid]["location"] == "carried", "Held output state is carried")
	check(lifecycle.recovered.is_empty(), "Held output is no longer free salvage on ground")
	var credit: int = int(belt.state["economy"]["credits"])
	check(credit == 0, "Picking up cannot pay credits")
	check(not app.call("manual_register").get("ok",false), "No remote registration")
	check(not app.call("manual_sell").get("ok",false), "No remote sale")
	actor.global_position = HMYardService.PAD_CENTER
	for i: int in range(3):
		await physics_frame
	check(app.call("manual_unload").get("ok",false), "U unloads on pad")
	check(belt.state["world"]["outputs"][oid]["location"] == "receiving_pad", "Real receiving lot remains separate")
	check(int(belt.state["economy"]["credits"]) == 0, "Still no credits before sale")
	check(app.call("manual_register").get("ok",false), "N registers at yard")
	check(app.call("manual_sell").get("ok",false), "M sells after registration")
	check(int(belt.state["economy"]["credits"]) == 2, "Exactly one test-fibre sale credited")
	check(not app.call("manual_sell").get("ok",false), "No duplicate payout")
	check(not app.call("manual_purchase").get("ok",false), "Shop rejects insufficient funds")
	check(HMSaveState.validate(inspector.catalog,belt.state).is_empty(), "All transitions preserve authored invariants")
	app.call("pause_stage")
	check(not app.call("manual_lift_or_place").get("ok",false), "Pause disables collection")
	app.call("show_menu")
	app.free()
	if failures.is_empty():
		print("HOLLOWMERE_STEP17_INTEGRATION_OK")
		quit(0)
	else:
		quit(1)
