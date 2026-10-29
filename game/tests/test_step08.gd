extends SceneTree
## Exact Godot physics and capability test. Must execute on both QA platforms.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("STEP08 FAILED: " + detail)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "Main scene exists")
	if packed == null:
		quit(1)
		return
	var app: Node = packed.instantiate()
	get_root().add_child(app)
	await process_frame
	var belt: HMToolbelt = app.get("toolbelt") as HMToolbelt
	var inspector: HMInspector = app.get("inspector") as HMInspector
	var player: HMFirstPerson = app.get("player") as HMFirstPerson
	check(belt != null and inspector != null and player != null, "Toolbelt, inspector, player connected")
	if belt == null or inspector == null or player == null:
		quit(1)
		return
	check(belt.owned_ids() == ["hands"], "Only hands available initially")
	check(belt.selected_tool_id == "hands", "Starts using hands")
	check(not belt.select_tool("saw") and not belt.select_slot(5), "Cannot select undiscovered saw")
	check(not belt.grants_operation("cut_unloaded_frame"), "Tier 4 capability not automatically available")
	check(belt.cycle() == "hands", "Cycle only available tools")
	check(not belt.find_from_world("hands"), "Innate hands cannot be discovered again")
	check(not belt.find_from_world("invented_tool"), "Unknown tool cannot be discovered")
	check(InputMap.has_action("hm_tool_next") and InputMap.has_action("hm_tool_2") and InputMap.has_action("hm_find_tool"), "Mapped selection and physical discovery inputs")
	var catalog: HMCatalog = inspector.catalog
	var owned: Array = ["hands", "claw_hammer"]
	var active: Array = inspector.active_ids
	var wrong: Dictionary = HMInspectionRules.describe(catalog, "fixture/shed/roof_patch", active, owned, [], true, "hands")
	check(String(wrong.get("status", "")).contains("Select") and not wrong.get("read_only_actionable", true), "Owned but unselected tool is blocked")
	var ready: Dictionary = HMInspectionRules.describe(catalog, "fixture/shed/roof_patch", active, owned, [], true, "claw_hammer")
	check(ready.get("read_only_actionable", false), "Matching selected operation is eligible in read-only inspection")
	var wrong_tier: Dictionary = HMInspectionRules.describe(catalog, "fixture/house/beam", active, ["hands", "claw_hammer", "saw"], [], true, "claw_hammer")
	check(not wrong_tier.get("read_only_actionable", true), "Lower tool cannot substitute for structural saw")
	var protected: Dictionary = HMInspectionRules.describe(catalog, "fixture/harbour/bell", active, ["hands", "saw"], [], true, "saw")
	check(protected.get("protected", false) and not protected.get("read_only_actionable", true), "Protected story geometry stays blocked")
	var baseline_revision: int = int(belt.state["revision"])
	app.call("show_stage")
	for i: int in range(5):
		await physics_frame
	check(inspector.owned_tools == ["hands"] and inspector.selected_tool_id == "hands", "Inspector reflects selected tools")
	# From spawn the rope is in front; the hammer is offset right.
	check(not inspector.aimed_tool_pickup() is HMToolPickup, "Cannot remotely acquire off-axis hammer")
	app.call("request_find_tool")
	for i: int in range(3):
		await physics_frame
	check(belt.state["revision"] == baseline_revision, "Attempt without aim changes no persistent state")
	player.global_position = Vector3(2.6, 0.96, 8.0)
	for i: int in range(3):
		await physics_frame
	var pickup: HMToolPickup = inspector.aimed_tool_pickup()
	check(pickup != null and pickup.tool_id == "claw_hammer", "Actual camera ray sees hammer inside reach")
	app.call("request_find_tool")
	for i: int in range(3):
		await physics_frame
	check(belt.is_owned("claw_hammer") and belt.owned_ids().size() == 2, "Manual E discovery grants hammer once")
	check(belt.state["revision"] == baseline_revision + 1, "Only one Step05 transaction recorded")
	check(belt.selected_tool_id == "hands", "Discovery never auto-equips")
	check(not belt.select_slot(3), "Crowbar slot still unavailable")
	check(belt.select_slot(2) and belt.selected_tool_id == "claw_hammer", "Quick slot 2 equips owned hammer")
	check(belt.grants_operation("separate_light_wood") and not belt.grants_operation("loosen_masonry"), "Selected hammer grants its operations only")
	check(belt.cycle() == "hands", "Cycling wraps discovered tools")
	check(not belt.find_from_world("claw_hammer") and belt.state["revision"] == baseline_revision + 1, "Duplicate discovery cannot grant or change state")
	app.call("pause_stage")
	check(not inspector.enabled, "Paused targeting disabled")
	app.call("request_find_tool")
	for i: int in range(2):
		await physics_frame
	check(belt.state["revision"] == baseline_revision + 1, "Pause blocks world discovery")
	app.call("show_menu")
	app.free()
	if failures.is_empty():
		print("HOLLOWMERE_STEP08_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP08_TEST_FAIL count=", failures.size())
		quit(1)
