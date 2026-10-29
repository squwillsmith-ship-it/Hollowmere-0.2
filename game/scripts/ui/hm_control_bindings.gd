class_name HMControlBindings
extends RefCounted
## Step 41: keyboard/mouse remapping is local-only and never touches saved world.
## Escape/ui_cancel is reserved, preventing a trapped menu.

const PATH: String = "user://control-bindings.cfg"
const LABELS: Dictionary = {
	"hm_forward": "Forward", "hm_backward": "Backward", "hm_left": "Strafe left",
	"hm_right": "Strafe right", "hm_sprint": "Sprint", "hm_jump": "Jump",
	"hm_inspect": "Inspect details", "hm_inventory": "Inventory",
	"hm_tool_radial": "Tool wheel", "hm_tool_next": "Next tool",
	"hm_find_tool": "Interact / discover", "hm_release": "Release part",
	"hm_lift_place": "Lift / place", "hm_unload": "Unload",
	"hm_register": "Register salvage", "hm_sell": "Sell salvage",
	"hm_shop_next": "Next upgrade", "hm_shop_buy": "Buy upgrade",
	"hm_requisition": "Contract / next act", "hm_process": "Manual sorting",
	"hm_risk_modifier": "Risk modifier", "hm_work": "Manual work",
	"hm_tool_1": "Tool 1", "hm_tool_2": "Tool 2", "hm_tool_3": "Tool 3",
	"hm_tool_4": "Tool 4", "hm_tool_5": "Tool 5"
}
const DEFAULT_KEYS: Dictionary = {
	"hm_forward": KEY_W, "hm_backward": KEY_S, "hm_left": KEY_A,
	"hm_right": KEY_D, "hm_sprint": KEY_SHIFT, "hm_jump": KEY_SPACE,
	"hm_inspect": KEY_F, "hm_inventory": KEY_I,
	"hm_tool_radial": KEY_TAB, "hm_tool_next": KEY_Q,
	"hm_find_tool": KEY_E, "hm_release": KEY_R,
	"hm_lift_place": KEY_C, "hm_unload": KEY_U,
	"hm_register": KEY_N, "hm_sell": KEY_M,
	"hm_shop_next": KEY_J, "hm_shop_buy": KEY_K,
	"hm_requisition": KEY_B, "hm_process": KEY_H,
	"hm_risk_modifier": KEY_G,
	"hm_tool_1": KEY_1, "hm_tool_2": KEY_2, "hm_tool_3": KEY_3,
	"hm_tool_4": KEY_4, "hm_tool_5": KEY_5
}

func restore_defaults(persist: bool = true) -> void:
	HMPlayerInput.ensure_defaults()
	for action: String in LABELS:
		var event: InputEvent
		if action == "hm_work":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			event = mouse
		else:
			var key := InputEventKey.new()
			key.physical_keycode = int(DEFAULT_KEYS[action])
			event = key
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
	if persist:
		save_local()


func load_local(path: String = PATH) -> void:
	restore_defaults(false)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	# Read saved overrides against the complete final mapping, so a rotated
	# set of keys can be loaded without being rejected by transient defaults.
	var requested: Dictionary = {}
	for action: String in LABELS:
		var value: String = String(config.get_value("bindings", action, ""))
		var event: InputEvent = decode(value)
		if event != null:
			requested[action] = value
	var final_map: Dictionary = {}
	for action: String in LABELS:
		final_map[action] = requested.get(action, current_binding(action))
	var used: Dictionary = {}
	for action: String in LABELS:
		var value: String = String(final_map[action])
		if used.has(value):
			# Corrupt/duplicate mapping cannot silently remove an action.
			return
		used[value] = true
	for action: String in requested:
		var event: InputEvent = decode(String(requested[action]))
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func current_binding(action: String) -> String:
	if not LABELS.has(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode != KEY_NONE:
			return "k:" + str((event as InputEventKey).physical_keycode)
		if event is InputEventMouseButton:
			return "m:" + str((event as InputEventMouseButton).button_index)
	return ""


static func decode(value: String) -> InputEvent:
	var segments: PackedStringArray = value.split(":")
	if segments.size() != 2 or not segments[1].is_valid_int():
		return null
	var numeric: int = int(segments[1])
	if segments[0] == "k" and numeric > 0 and numeric != KEY_ESCAPE and numeric < 20000000:
		var key := InputEventKey.new()
		key.physical_keycode = numeric
		return key
	if segments[0] == "m" and numeric >= MOUSE_BUTTON_LEFT and numeric <= MOUSE_BUTTON_XBUTTON2:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = numeric
		return mouse
	return null


static func binding_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return ""
		var code: Key = key.physical_keycode
		if code == KEY_NONE or code == KEY_ESCAPE:
			return ""
		return "k:" + str(code)
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index <= MOUSE_BUTTON_XBUTTON2:
			return "m:" + str(mouse.button_index)
	return ""


func change_binding(action: String, binding: String) -> bool:
	if not LABELS.has(action) or decode(binding) == null:
		return false
	for other: String in LABELS:
		if other != action and current_binding(other) == binding:
			return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, decode(binding))
	return true


func display(action: String) -> String:
	var event: InputEvent = decode(current_binding(action))
	if event == null:
		return "(unbound)"
	return event.as_text().replace(" (Physical)", "")


func save_local(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	for action: String in LABELS:
		config.set_value("bindings", action, current_binding(action))
	return config.save(path)
