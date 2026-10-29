class_name HMToolbelt
extends RefCounted
## Step 8 selection is a capability choice, never a salvage or work operation.
## Discovered permissions come from the validated Step05 logical state.

var catalog: HMCatalog
var state: Dictionary = {}
var selected_tool_id: String = "hands"
var save_store: HMSaveStore = null


func initialize(source_catalog: HMCatalog) -> void:
	catalog = source_catalog
	state = HMSaveState.fresh(catalog)
	selected_tool_id = "hands"


func owned_ids() -> Array:
	return state["progress"]["tools"].duplicate()


func is_owned(tool_id: String) -> bool:
	return owned_ids().has(tool_id) and not catalog.by_id("tools", "tools", tool_id).is_empty()


func available_ids() -> Array[String]:
	var result: Array[String] = []
	for raw: Variant in catalog.entries("tools", "tools"):
		var definition: Dictionary = raw
		var tid: String = String(definition["id"])
		if is_owned(tid):
			result.append(tid)
	return result


func select_tool(tool_id: String) -> bool:
	if not is_owned(tool_id):
		return false
	selected_tool_id = tool_id
	return true


func select_slot(slot: int) -> bool:
	var definitions: Array = catalog.entries("tools", "tools")
	if slot < 1 or slot > definitions.size():
		return false
	var definition: Dictionary = definitions[slot - 1]
	return select_tool(String(definition["id"]))


func cycle(direction: int = 1) -> String:
	var options: Array[String] = available_ids()
	if options.is_empty():
		return selected_tool_id
	var index: int = options.find(selected_tool_id)
	if index < 0:
		selected_tool_id = options[0]
	else:
		selected_tool_id = options[posmod(index + (1 if direction >= 0 else -1), options.size())]
	return selected_tool_id


func tool_name(tool_id: String = "") -> String:
	var tid: String = selected_tool_id if tool_id.is_empty() else tool_id
	var tool: Dictionary = catalog.by_id("tools", "tools", tid)
	return String(tool.get("name", tid))


func grants_operation(operation: String) -> bool:
	var tool: Dictionary = catalog.by_id("tools", "tools", selected_tool_id)
	return is_owned(selected_tool_id) and tool.get("operations", []).has(operation)


func find_from_world(tool_id: String) -> bool:
	# Called ONLY after the player manually presses the physical pickup key
	# against a first-hit collider within reach. This method performs the
	# authoritative, once-only Step05 find_tool transaction, not a free grant.
	var event: Dictionary = {
		"transaction_id": "fixture/manual-find/" + tool_id,
		"user_initiated": true, "op": "find_tool",
		"tool_id": tool_id, "source": "world_discovery"
	}
	if save_store != null:
		if not save_store.commit(event):
			return false
		state = save_store.snapshot()
	else:
		var result: Dictionary = HMTransactions.apply(catalog, state, event)
		if not bool(result.get("ok", false)):
			return false
		state = result["state"]
	return is_owned(tool_id)
