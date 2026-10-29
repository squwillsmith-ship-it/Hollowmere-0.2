extends SceneTree
## Phase G source acceptance. Does NOT substitute for rendered visual/audio QA.
var errors: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("PHASE G FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var bindings := HMControlBindings.new()
	bindings.restore_defaults(false)
	check(bindings.current_binding("hm_work") == "m:" + str(MOUSE_BUTTON_LEFT), "Original manual mouse work")
	check(not bindings.change_binding("hm_forward", bindings.current_binding("hm_backward")), "Duplicate controls rejected")
	check(HMControlBindings.decode("k:" + str(KEY_ESCAPE)) == null, "Escape reserved for menu")
	check(bindings.change_binding("hm_forward", "k:" + str(KEY_Z)), "Free key is assignable")
	check(bindings.current_binding("hm_forward") == "k:" + str(KEY_Z), "Runtime InputMap updated")
	var bindings_path: String = "user://phase_g_control_regression.cfg"
	check(bindings.save_local(bindings_path) == OK, "Bindings persist to isolated test file")
	bindings.restore_defaults(false)
	bindings.load_local(bindings_path)
	check(bindings.current_binding("hm_forward") == "k:" + str(KEY_Z), "Binding reopens from disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bindings_path))
	bindings.restore_defaults(false)
	check(bindings.current_binding("hm_forward") == "k:" + str(KEY_W), "Defaults recoverable")
	check(HMActionFeedback.generate("claw_hammer", "timber", true).data.size() > 0, "Original work sound generated")
	check(HMActionFeedback.generate("pickaxe", "stone", false).data.size() > 0, "Original blocker sound generated")
	check(HMActionFeedback.generate("saw", "timber", true).data !=
		HMActionFeedback.generate("pickaxe", "stone", true).data,
		"Per-tool and material sound sources differ deterministically")
	var local_preferences := HMInterfaceSettings.new()
	local_preferences.master_volume = 0.4
	local_preferences.clearer_fog = true
	var settings_path: String = "user://phase_g_preferences_regression.cfg"
	check(local_preferences.save_local(settings_path) == OK, "Presentation preferences persist")
	local_preferences.master_volume = 1.0
	local_preferences.clearer_fog = false
	local_preferences.load_local(settings_path)
	check(is_equal_approx(local_preferences.master_volume, 0.4) and local_preferences.clearer_fog,
		"Presentation preferences reopen independently of the campaign")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	var coast := Node3D.new()
	var environment := WorldEnvironment.new()
	environment.name = "CoastalEnvironment"
	environment.environment = Environment.new()
	coast.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastCoastalSun"
	coast.add_child(sun)
	root.add_child(coast)
	check(HMCoastalPresentation.apply(coast), "Coastal presentation applied")
	check(HMCoastalPresentation.audit(coast).get("ok", false), "Coastal lighting audit")
	check(HMCoastalPresentation.apply(coast, true), "Clearer mist mode available")
	check(is_equal_approx(environment.environment.fog_density, HMCoastalPresentation.CLEARER_FOG),
		"Reduced fog keeps authored geometry untouched")
	coast.queue_free()
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(world.settings_overlay != null and world.binding_buttons.size() == HMControlBindings.LABELS.size(),
		"Accessible bindings and sliders integrated into actual menu")
	check(world.action_feedback != null, "Manual feedback player installed in actual game")
	check(world.tool_visual != null and world.tool_visual.models.size() == 5,
		"Five distinct camera-space tool meshes authored without extra gameplay abilities")
	check(world.tool_visual.equipped == "hands",
		"Undiscovered tool cannot appear in first-person view")
	check(world.current_view == 0, "Title state starts safely")
	world._show_settings()
	check(world.settings_overlay.visible, "Settings reachable from title")
	world._hide_settings()
	world.show_stage()
	world.pause_stage()
	world._show_settings()
	check(world.settings_overlay.visible and not world.player.movement_enabled,
		"Pause settings do not permit unintended work")
	var before_economy: Dictionary = world.toolbelt.state["economy"].duplicate(true)
	check(not bool(world.perform_work_once().get("ok", false)), "Paused menu cannot perform physical work")
	check(world.toolbelt.state["economy"] == before_economy, "Settings cannot mutate credits or upgrades")
	world._hide_settings()
	world.resume_stage()
	check(world.player.movement_enabled, "Resuming restores player controls")
	world.queue_free()
	await process_frame
	bindings.restore_defaults(false)
	if errors.is_empty():
		print("HOLLOWMERE_PHASE_G_TEST_OK")
		quit(0)
	else:
		quit(1)
