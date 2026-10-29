extends SceneTree
## Explicit physical confirmation, bounded local damage and disk reload.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("STEP12 FAILED: " + message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var app: Node = packed.instantiate()
	get_root().add_child(app)
	await process_frame
	app.call("show_stage")
	var belt: HMToolbelt = app.get("toolbelt") as HMToolbelt
	var actor: HMFirstPerson = app.get("player") as HMFirstPerson
	var inspector: HMInspector = app.get("inspector") as HMInspector
	var lifecycle: HMPartLifecycle = app.get("lifecycle") as HMPartLifecycle
	check(InputMap.has_action("hm_risk_modifier"), "Risk modifier is explicitly mapped")
	check(belt.find_from_world("claw_hammer") and belt.select_tool("claw_hammer"), "World-discovered hammer explicitly equipped")
	app.call("_sync_tool_context")
	actor.global_position = Vector3(-3.8, 0.96, 8.0)
	for i: int in range(5):
		await physics_frame
	var rail: String = "fixture/shed/upper_rail"
	var patch: String = "fixture/shed/roof_patch"
	check(inspector.probe().get("part_id", "") == rail, "Physical camera sees loaded support")
	check(not app.call("perform_work_once").get("ok", false), "Normal working rejects loaded support")
	Input.action_press("hm_risk_modifier")
	check(app.call("perform_work_once").get("ok", false), "Explicit G-work accepts first manual cycle")
	check(app.call("perform_work_once").get("complete", false), "Second manual cycle completes loaded rail")
	check(not app.call("perform_release_once").get("ok", false), "Unmodified safe R still refuses load")
	var prior: int = int(belt.state["revision"])
	var armed: Dictionary = app.call("perform_risky_release_once")
	check(armed.get("armed", false) and int(belt.state["revision"]) == prior, "First G+R only arms, no transaction")
	var result: Dictionary = app.call("perform_risky_release_once")
	check(result.get("ok", false), "Second G+R commits deliberate risky release")
	Input.action_release("hm_risk_modifier")
	for i: int in range(4):
		await physics_frame
	var state: Dictionary = belt.state
	check(int(state["revision"]) == prior + 1, "Exactly one deliberate release transaction")
	check(state["world"]["parts"][rail]["phase"] == "released" and state["world"]["parts"][patch]["phase"] == "released", "Loaded dependent releases locally")
	check(state["world"]["outputs"][rail + "/out/wood"]["condition"] == "intact", "Removed support remains intact")
	check(state["world"]["outputs"][patch + "/out/boards"]["condition"] == "damaged", "Dependent material is binary damaged")
	check(state["world"]["outputs"][patch + "/out/fasteners"]["condition"] == "damaged", "All dependent child lots share damaged condition")
	check(state["world"]["outputs"][patch + "/out/boards"]["position"][0] < -2.0, "Failed part drops locally, not at world origin")
	check(lifecycle.recovered.size() == 3, "Three separate physical lots reconcile once")
	check(not lifecycle.installed[rail].visible and not lifecycle.installed[patch].visible, "Both affected installed meshes disappear")
	check(state["economy"]["credits"] == 0, "Risk cannot award credit or auto-collect")
	check(not app.call("perform_risky_release_once").get("ok", false), "Risk cannot repeat without modifier and target")
	app.call("pause_stage")
	Input.action_press("hm_risk_modifier")
	check(not app.call("perform_risky_release_once").get("ok", false), "Pause blocks risk confirmation")
	Input.action_release("hm_risk_modifier")
	app.call("show_menu")
	app.free()

	# Root post supports two attached levels; atomic engine save must preserve
	# the bounded, transitive damaged salvage after a cold reopen.
	var c := HMCatalog.new()
	check(c.load_all(), "Canonical authored catalog loads")
	var slot: String = "step12_damage_" + str(Time.get_ticks_usec())
	var store := HMSaveStore.new()
	check(store.open_slot(c, slot), "Independent crash-resistant slot opens")
	check(store.commit({"op":"find_tool","transaction_id":"risk/tool", "user_initiated":true,
		"tool_id":"claw_hammer", "source":"world_discovery"}), "Manual discovered tool saved")
	var posts: String = "fixture/shed/posts"
	check(store.commit({"op":"partial_work","transaction_id":"risk/preparation","user_initiated":true,
		"part_id":posts,"cycles":3}), "Three manually prepared work units saved")
	var before_release: int = int(store.snapshot()["revision"])
	check(not store.commit({"op":"release","transaction_id":"risk/blocked","user_initiated":true,
		"part_id":posts,"confirm_risk":false}), "Transaction rejects unconfirmed loaded support")
	check(int(store.snapshot()["revision"]) == before_release, "Denied risk does not mutate disk snapshot")
	check(store.commit({"op":"release","transaction_id":"risk/confirmed","user_initiated":true,
		"part_id":posts,"confirm_risk":true,"spawn_origin":[3.0,0.3,3.0]}), "Explicit bounded cascade commits atomically")
	var reopened := HMSaveStore.new()
	check(reopened.open_slot(c, slot), "Cold reopen after local failure succeeds")
	var snap: Dictionary = reopened.snapshot()
	for pid: String in [posts, rail, patch]:
		check(snap["world"]["parts"][pid]["phase"] == "released", "Affected part survives reload: " + pid)
	check(snap["world"]["outputs"][posts + "/out/wood"]["condition"] == "intact", "Root output stays intact after save")
	check(snap["world"]["outputs"][rail + "/out/wood"]["condition"] == "damaged", "Rail output stays damaged after save")
	check(snap["world"]["outputs"][patch + "/out/boards"]["condition"] == "damaged", "Patch output stays damaged after save")
	check(snap["world"]["outputs"].size() == 4, "No duplicated lots, allocations conserved")
	check(HMSaveState.validate(c, snap).is_empty(), "All material and provenance invariants pass after reload")
	check(snap["economy"]["credits"] == 0 and snap["progress"]["act"] == 1, "Neither economy nor narrative advanced")
	var prefix: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json"))
	for ext: String in ["", ".previous", ".writing"]:
		if FileAccess.file_exists(prefix + ext):
			DirAccess.remove_absolute(prefix + ext)
	if failures.is_empty():
		print("HOLLOWMERE_STEP12_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP12_TEST_FAIL count=", failures.size())
		quit(1)
