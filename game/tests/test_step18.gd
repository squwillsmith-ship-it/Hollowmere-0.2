extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("STEP18 FAIL: " + label)
func run_tests() -> void:
	var config := HMInterfaceSettings.new()
	check(config.font_scale == 1.0, "Default readable fonts")
	check(HMInterfaceSettings.FONT_SCALES.has(1.5), "Large type option exists")
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(world.inventory_overlay != null and world.radial_buttons.size() == 5, "Inventory and five-tool radial built")
	world.show_stage()
	world._open_overlay("inventory")
	check(world.ui_open == "inventory" and not world.player.movement_enabled, "Inventory stops unintentional work/movement")
	var original: int = int(world.toolbelt.state["economy"]["credits"])
	check(world._inventory_summary().contains("Physical") or world._inventory_summary().contains("physical"), "Inventory labels physical lots")
	world._close_overlay()
	check(world.player.movement_enabled and world.ui_open.is_empty(), "Inventory close recaptures movement")
	world._open_overlay("radial")
	check(not world.radial_buttons[0].disabled and world.radial_buttons[1].disabled, "Undiscovered tools disabled")
	world._choose_radial("saw")
	check(world.toolbelt.selected_tool_id == "hands", "Radial cannot grant capability")
	world._close_overlay()
	check(int(world.toolbelt.state["economy"]["credits"]) == original, "UI does not change credits")
	world.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_STEP18_TEST_OK")
		quit(0)
	else:
		quit(1)
