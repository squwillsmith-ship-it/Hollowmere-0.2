class_name HMPlayerInput
extends RefCounted
## Initial physical-key defaults. Existing user/remapped InputMap events are retained.
## Step 18 will supply an editable bindings/settings UI.

static func ensure_defaults() -> void:
	_register_key("hm_forward", KEY_W)
	_register_key("hm_backward", KEY_S)
	_register_key("hm_left", KEY_A)
	_register_key("hm_right", KEY_D)
	_register_key("hm_sprint", KEY_SHIFT)
	_register_key("hm_jump", KEY_SPACE)
	_register_key("hm_inspect", KEY_F)
	_register_key("hm_inventory", KEY_I)
	_register_key("hm_tool_radial", KEY_TAB)
	_register_key("hm_tool_next", KEY_Q)
	_register_key("hm_find_tool", KEY_E)
	_register_key("hm_release", KEY_R)
	_register_key("hm_lift_place", KEY_C)
	_register_key("hm_unload", KEY_U)
	_register_key("hm_register", KEY_N)
	_register_key("hm_sell", KEY_M)
	_register_key("hm_shop_next", KEY_J)
	_register_key("hm_shop_buy", KEY_K)
	_register_key("hm_requisition", KEY_B)
	_register_key("hm_process", KEY_H)
	_register_key("hm_risk_modifier", KEY_G)
	_register_mouse("hm_work", MOUSE_BUTTON_LEFT)
	_register_key("hm_tool_1", KEY_1)
	_register_key("hm_tool_2", KEY_2)
	_register_key("hm_tool_3", KEY_3)
	_register_key("hm_tool_4", KEY_4)
	_register_key("hm_tool_5", KEY_5)


static func _register_mouse(action_name: StringName, button_index: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = button_index
	InputMap.action_add_event(action_name, mouse)


static func _register_key(action_name: StringName, key_code: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = key_code
	InputMap.action_add_event(action_name, keyboard)
