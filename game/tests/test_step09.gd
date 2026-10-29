extends SceneTree
## End-to-end physics, repeated manual input, atomic work and disk reload.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("STEP09 FAILED: " + detail)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "Stage loads")
	if packed == null:
		quit(1)
		return
	var app: Node = packed.instantiate()
	get_root().add_child(app)
	await process_frame
	var actor: HMFirstPerson = app.get("player") as HMFirstPerson
	var inspector: HMInspector = app.get("inspector") as HMInspector
	var belt: HMToolbelt = app.get("toolbelt") as HMToolbelt
	var work: HMWorkSession = app.get("work_session") as HMWorkSession
	check(actor != null and inspector != null and belt != null and work != null, "Step08 systems and work session are connected")
	check(InputMap.has_action("hm_work"), "Left-button manual work action registered")
	app.call("show_stage")
	for i: int in range(4):
		await physics_frame
	check(inspector.probe().get("part_id", "") == "fixture/shed/loose_rope", "Real first-hit ray targets loose scrap")
	var first: Dictionary = app.call("perform_work_once")
	check(first.get("ok", false) and first.get("complete", false), "Single physical hands action completes one-unit fixture")
	check(int(belt.state["world"]["parts"]["fixture/shed/loose_rope"]["work"]) == 1, "Partial progress recorded exactly once")
	check(String(belt.state["world"]["parts"]["fixture/shed/loose_rope"]["phase"]) == "attached", "Work completion does NOT release a component")
	check(belt.state["world"]["outputs"].is_empty(), "Work never generates or auto-collects salvage")
	var repeat: Dictionary = app.call("perform_work_once")
	check(not repeat.get("ok", true), "Fully worked target cannot farm more transactions")
	var revision: int = int(belt.state["revision"])
	app.call("pause_stage")
	check(not app.call("perform_work_once").get("ok", true), "Paused direct work is rejected")
	Input.action_press("hm_work")
	for i: int in range(8):
		await physics_frame
	check(int(belt.state["revision"]) == revision, "Holding input while paused does no work")
	Input.action_release("hm_work")
	app.call("resume_stage")
	await physics_frame
	var before_missing: int = int(belt.state["revision"])
	actor.global_position = Vector3(-2.6, 0.96, 8.0)
	for i: int in range(5):
		await physics_frame
	check(inspector.probe().get("part_id", "") == "fixture/shed/roof_patch", "Ray physically hits authored two-unit work panel")
	check(not app.call("perform_work_once").get("ok", true) and int(belt.state["revision"]) == before_missing, "Missing discovered hammer blocks manual work")
	check(belt.find_from_world("claw_hammer"), "Manual discovery transaction creates hammer permission")
	check(belt.select_tool("claw_hammer"), "Can manually equip known hammer")
	app.call("_sync_tool_context")
	# Holding through a pause/resume must not start work without a fresh press.
	app.call("pause_stage")
	Input.action_press("hm_work")
	for i: int in range(4):
		await physics_frame
	app.call("resume_stage")
	for i: int in range(26):
		await physics_frame
	check(int(belt.state["world"]["parts"]["fixture/shed/roof_patch"]["work"]) == 0, "Resume rejects an already held work button")
	Input.action_release("hm_work")
	for i: int in range(3):
		await physics_frame
	Input.action_press("hm_work")
	for i: int in range(64):
		await physics_frame
	Input.action_release("hm_work")
	for i: int in range(3):
		await physics_frame
	var done: Dictionary = belt.state["world"]["parts"]["fixture/shed/roof_patch"]
	check(int(done["work"]) == 2 and done["phase"] == "attached", "Sustained aim gives precisely two work units; component remains installed")
	check(belt.state["world"]["outputs"].is_empty(), "No material outputs before separate release system")
	var after_work: int = int(belt.state["revision"])
	Input.action_press("hm_work")
	for i: int in range(12):
		await physics_frame
	Input.action_release("hm_work")
	check(int(belt.state["revision"]) == after_work, "Work capped and holding completed panel cannot farm revisions")
	app.call("show_menu")
	check(not app.call("perform_work_once").get("ok", true), "Title never advances work")
	app.free()

	# True Step05 staged-disk persistence: separate isolated slot, then reopen.
	var catalog := HMCatalog.new()
	check(catalog.load_all(), "Fresh canonical catalog for persistence case")
	var slot_id: String = "qa_step09_" + str(Time.get_ticks_usec())
	var belt_a := HMToolbelt.new()
	belt_a.initialize(catalog)
	var session_a := HMWorkSession.new()
	check(session_a.initialize(catalog, belt_a, true, slot_id), "Step09 session creates a valid disk slot")
	check(belt_a.find_from_world("claw_hammer") and belt_a.select_tool("claw_hammer"), "Tool discovery persists through same store")
	var info: Dictionary = {"part_id": "fixture/shed/roof_patch", "reachable": true}
	check(not session_a.work_once(info, false).get("ok", true), "Passive transaction blocked")
	var saved: Dictionary = session_a.work_once(info, true)
	check(saved.get("ok", false) and saved.get("work", -1) == 1, "One engaged action atomically saved")
	var belt_b := HMToolbelt.new()
	belt_b.initialize(catalog)
	var session_b := HMWorkSession.new()
	check(session_b.initialize(catalog, belt_b, true, slot_id), "New independent session loads disk state")
	check(belt_b.is_owned("claw_hammer") and int(belt_b.state["world"]["parts"]["fixture/shed/roof_patch"]["work"]) == 1, "Persisted tool and fractional work survive reload")
	check(belt_b.select_tool("claw_hammer"), "Loaded discovered tool can be equipped")
	var resumed: Dictionary = session_b.work_once(info, true)
	check(resumed.get("ok", false) and resumed.get("complete", false), "Work resumes after file reload")
	check(not session_b.work_once(info, true).get("ok", true), "Fully worked part is idempotently capped")
	var belt_c := HMToolbelt.new()
	belt_c.initialize(catalog)
	var session_c := HMWorkSession.new()
	check(session_c.initialize(catalog, belt_c, true, slot_id), "Completed work reloads")
	check(int(belt_c.state["world"]["parts"]["fixture/shed/roof_patch"]["work"]) == 2, "Full progress retained on disk")
	check(belt_c.state["world"]["outputs"].is_empty(), "No hidden release or economy transitions in persisted state")
	var disk_prefix: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot_id + ".hmsave.json"))
	for extension: String in ["", ".previous", ".writing"]:
		if FileAccess.file_exists(disk_prefix + extension):
			DirAccess.remove_absolute(disk_prefix + extension)
	if failures.is_empty():
		print("HOLLOWMERE_STEP09_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP09_TEST_FAIL count=", failures.size())
		quit(1)
