extends SceneTree
## Real physics and disk tests for explicit release and child output reconciliation.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)
		push_error("STEP10 FAILED: " + reason)


func _verify() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "Main stage loads")
	if packed == null:
		quit(1)
		return
	var app: Node = packed.instantiate()
	get_root().add_child(app)
	await process_frame
	var inspector: HMInspector = app.get("inspector") as HMInspector
	var belt: HMToolbelt = app.get("toolbelt") as HMToolbelt
	var lifecycle: HMPartLifecycle = app.get("lifecycle") as HMPartLifecycle
	check(inspector != null and belt != null and lifecycle != null, "Work and physical lifecycle connected")
	check(InputMap.has_action("hm_release"), "Separate release input registered")
	app.call("show_stage")
	for i: int in range(4):
		await physics_frame
	check(inspector.probe().get("part_id", "") == "fixture/shed/loose_rope", "Physical ray hits installed rope")
	check(not app.call("perform_release_once").get("ok", false), "Unworked part cannot release")
	check(app.call("perform_work_once").get("complete", false), "Explicit hands action prepares rope")
	var before: int = int(belt.state["revision"])
	app.call("request_release")
	for i: int in range(5):
		await physics_frame
	check(int(belt.state["revision"]) == before + 1, "R input performs exactly one release")
	var world: Dictionary = belt.state["world"]
	check(world["parts"]["fixture/shed/loose_rope"]["phase"] == "released", "Part changed to released")
	check(world["outputs"].size() == 1, "One authored output exists")
	var rope: Dictionary = world["outputs"].get("fixture/shed/loose_rope/out/rope", {})
	check(rope.get("condition", "") == "intact" and rope.get("allocation", {}).get("fibres", -1) == 2,
		"Rope materials conserved and quality intact")
	check(rope.get("location", "") == "world_released" and not rope.get("registered", true),
		"Output stays in world with no automatic registration")
	check(belt.state["economy"]["credits"] == 0 and belt.state["economy"]["registered"].is_empty(),
		"No proceeds or yard delivery from release")
	check(not lifecycle.installed["fixture/shed/loose_rope"].visible and lifecycle.installed["fixture/shed/loose_rope"].collision_layer == 0,
		"Removed parent is no longer rendered or collidable")
	check(lifecycle.recovered.has("fixture/shed/loose_rope/out/rope") and lifecycle.recovered.size() == 1,
		"One physical recovered output exists with stable ID")
	lifecycle.reconcile(belt.state)
	check(lifecycle.recovered.size() == 1, "Reconcile cannot duplicate children")
	check(not app.call("perform_release_once").get("ok", false) and int(belt.state["revision"]) == before + 1,
		"Repeat release cannot farm transactions")
	app.call("pause_stage")
	app.call("request_release")
	for i: int in range(3):
		await physics_frame
	check(int(belt.state["revision"]) == before + 1, "Pause prevents release")
	app.call("show_menu")
	app.free()

	var catalog := HMCatalog.new()
	check(catalog.load_all(), "Catalog loads independently")
	var slot: String = "qa_step10_" + str(Time.get_ticks_usec())
	var a := HMToolbelt.new()
	a.initialize(catalog)
	var work_a := HMWorkSession.new()
	check(work_a.initialize(catalog, a, true, slot), "Durable save slot opened")
	check(a.find_from_world("claw_hammer") and a.select_tool("claw_hammer"), "Explicit discovery and selection")
	var info: Dictionary = {"part_id": "fixture/shed/roof_patch", "reachable": true,
		"hit_position": [2.0, 0.35, 5.5]}
	check(work_a.work_once(info).get("ok", false) and work_a.work_once(info).get("complete", false),
		"Two independent manual work units finish panel")
	check(not work_a.release_once(info, false).get("ok", false), "Passive release refused")
	var rel: Dictionary = work_a.release_once(info)
	check(rel.get("ok", false) and rel.get("output_ids", []).size() == 2,
		"Release atomically writes two separate child groups")
	check(not work_a.release_once(info).get("ok", false), "Duplicate release refused")
	var totals: Dictionary = {}
	for raw: Variant in a.state["world"]["outputs"].values():
		var child: Dictionary = raw
		check(child["location"] == "world_released" and child["source_part_id"] == "fixture/shed/roof_patch",
			"Child remains physical and tied to original part")
		for family: Variant in child["allocation"]:
			totals[family] = int(totals.get(family, 0)) + int(child["allocation"][family])
	check(totals == {"timber": 4, "iron": 1}, "All material quantities conserved")
	var b := HMToolbelt.new()
	b.initialize(catalog)
	var work_b := HMWorkSession.new()
	check(work_b.initialize(catalog, b, true, slot), "New session reloads disk snapshot")
	check(b.state["world"]["parts"]["fixture/shed/roof_patch"]["phase"] == "released" and b.state["world"]["outputs"].size() == 2,
		"Released parent and two children survive disk reload")
	check(HMSaveState.validate(catalog, b.state).is_empty(), "Reload meets authoritative state invariants")
	var container := Node3D.new()
	get_root().add_child(container)
	var rebuild := HMPartLifecycle.new()
	container.add_child(rebuild)
	rebuild.bind_stage(container)
	rebuild.reconcile(b.state)
	check(rebuild.recovered.size() == 2, "Physical children recreated exactly from save")
	rebuild.reconcile(b.state)
	check(rebuild.recovered.size() == 2, "Rehydration is idempotent")
	container.free()
	var c := HMToolbelt.new()
	c.initialize(catalog)
	var work_c := HMWorkSession.new()
	check(work_c.initialize(catalog, c), "Independent risk-gating case initialized")
	check(not work_c.release_once({"part_id": "fixture/harbour/bell", "reachable": true}).get("ok", false),
		"Protected bell cannot release")
	check(not work_c.release_once({"part_id": "fixture/shed/loose_rope", "reachable": false}).get("ok", false),
		"Out-of-reach release refused")
	check(c.find_from_world("claw_hammer") and c.select_tool("claw_hammer"), "Risk test tool prepared")
	c.state["world"]["parts"]["fixture/shed/posts"]["work"] = 3
	var initial_revision: int = int(c.state["revision"])
	check(not work_c.release_once({"part_id": "fixture/shed/posts", "reachable": true}).get("ok", false)
		and int(c.state["revision"]) == initial_revision, "Still-loaded support never triggers local damage automatically")
	var prefix: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot + ".hmsave.json"))
	for extension: String in ["", ".previous", ".writing"]:
		if FileAccess.file_exists(prefix + extension):
			DirAccess.remove_absolute(prefix + extension)
	if failures.is_empty():
		print("HOLLOWMERE_STEP10_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP10_TEST_FAIL count=", failures.size())
		quit(1)
