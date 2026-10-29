class_name HMTransactions
extends RefCounted
## Pure, atomic manual actions. State mutation occurs only on a valid cloned snapshot.
## Actual scene input, proximity, safe supports, and tools must be validated by callers.

const MAX_LOCAL_FALL_PARTS: int = 4


static func apply(catalog: HMCatalog, current: Dictionary, event: Dictionary) -> Dictionary:
	var bad: PackedStringArray = HMSaveState.validate(catalog, current)
	if not bad.is_empty():
		return {"ok": false, "reason": "Invalid prior state: " + bad[0]}
	var transaction_id: String = String(event.get("transaction_id", ""))
	if transaction_id.is_empty() or current["completed_transactions"].has(transaction_id):
		return {"ok": false, "reason": "Missing or previously completed transaction ID"}
	if not bool(event.get("user_initiated", false)):
		return {"ok": false, "reason": "No automatic transactions"}
	var draft: Dictionary = current.duplicate(true)
	var reason: String = _perform(catalog, draft, event)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	draft["revision"] = int(draft["revision"]) + 1
	draft["completed_transactions"][transaction_id] = draft["revision"]
	var broken: PackedStringArray = HMSaveState.validate(catalog, draft)
	if not broken.is_empty():
		return {"ok": false, "reason": "Failed post-transaction invariants: " + broken[0]}
	return {"ok": true, "state": draft}


static func _perform(catalog: HMCatalog, state: Dictionary, event: Dictionary) -> String:
	var op: String = String(event.get("op", ""))
	var world: Dictionary = state["world"]
	var parts: Dictionary = world["parts"]
	var outputs: Dictionary = world["outputs"]
	var econ: Dictionary = state["economy"]
	var progress: Dictionary = state["progress"]
	var pid: String = String(event.get("part_id", ""))
	var oid: String = String(event.get("output_id", ""))
	if op == "set_player_pose":
		if not _valid_position(event.get("position", null)):
			return "Invalid player position"
		var heading: float = float(event.get("yaw", 0.0))
		if is_nan(heading) or is_inf(heading):
			return "Invalid player heading"
		world["carriers"]["player"] = {"position": event["position"].duplicate(true), "yaw": heading}
		return ""
	if op == "partial_work":
		var part: Dictionary = catalog.by_part_id(pid)
		if part.is_empty() or String(parts.get(pid, {}).get("phase", "")) != "attached":
			return "Part unavailable"
		if not HMRules.can_use(catalog, pid, progress["tools"]):
			return "Missing required capability"
		var count: int = int(event.get("cycles", 0))
		if count < 1 or count > 100:
			return "Work cycles must be explicitly positive"
		var rec: Dictionary = parts[pid]
		rec["work"] = mini(int(part["work_units"]), int(rec["work"]) + count)
		return ""
	if op == "release":
		var def: Dictionary = catalog.by_part_id(pid)
		if def.is_empty() or String(parts.get(pid, {}).get("phase", "")) != "attached":
			return "Part is not attached"
		if int(parts[pid]["work"]) != int(def["work_units"]):
			return "Manual work not completed"
		var active: Array = []
		for key: Variant in parts:
			if String(parts[key].get("phase", "")) == "attached":
				active.append(String(key))
		var access: Array = event.get("access_aids", [])
		var check: Dictionary = HMRules.inspect_release(catalog, pid, active, progress["tools"], access, bool(event.get("confirm_risk", false)))
		if not bool(check.get("allowed", false)):
			return String(check.get("reason", "Blocked release"))
		var origin: Array = event.get("spawn_origin", [0.0, 0.3, 0.0])
		if not _valid_position(origin):
			return "Invalid salvage placement origin"
		var affected: Array[String] = []
		for dependent: Variant in check.get("damaged_dependents", []):
			affected.append(String(dependent))
		var fall_index: int = 0
		for dependent: String in affected:
			var local_origin: Array = [float(origin[0]) + float(fall_index) * 0.55,
				float(origin[1]), float(origin[2]) + 0.40]
			_release_one(catalog, state, dependent, "damaged", local_origin)
			fall_index += 1
		_release_one(catalog, state, pid, "intact", origin)
		return ""
	if op == "pickup":
		if not outputs.has(oid) or not ["world_released", "staged"].has(String(outputs[oid].get("location", ""))):
			return "Output not available to collect"
		var carrier: String = String(event.get("carrier", ""))
		if not ["carried", "cart"].has(carrier):
			return "Pick-up must use player or manually driven cart"
		if carrier == "carried" and not HMSalvageLogistics.can_lift(world, econ, oid):
			return "Pack occupied or salvage too heavy for manual carry"
		var carrier_id: String = "player" if carrier == "carried" else String(event.get("cart_id", ""))
		if carrier == "cart" and not world["carriers"]["carts"].has(carrier_id):
			return "Unknown stable cart ID"
		outputs[oid]["location"] = carrier
		outputs[oid]["carrier_id"] = carrier_id
		return ""
	if op == "place":
		if not outputs.has(oid) or not ["carried", "cart"].has(String(outputs[oid].get("location", ""))):
			return "Output is not currently being carried"
		var position: Variant = event.get("position", null)
		if not _valid_position(position):
			return "Invalid placement position"
		outputs[oid]["location"] = "staged"
		outputs[oid]["carrier_id"] = ""
		outputs[oid]["position"] = position.duplicate(true)
		return ""
	if op == "process":
		# Explicit one-time sorting at the workbench, never passive production.
		if not outputs.has(oid) or String(outputs[oid].get("location", "")) != "staged":
			return "Salvage must be manually staged beside bench"
		if bool(outputs[oid].get("processed", false)) or not bool(event.get("bench_confirmed", false)):
			return "Already sorted or no physically verified workbench"
		outputs[oid]["processed"] = true
		return ""
	if op == "unload":
		if not outputs.has(oid) or not ["carried", "cart"].has(String(outputs[oid].get("location", ""))):
			return "Output must be physically carried to receiving pad"
		if not bool(event.get("receiving_pad_confirmed", false)):
			return "Receiving pad proximity not confirmed"
		outputs[oid]["location"] = "receiving_pad"
		outputs[oid]["carrier_id"] = ""
		if event.has("position"):
			if not _valid_position(event["position"]):
				return "Invalid receiving pad location"
			outputs[oid]["position"] = event["position"].duplicate(true)
		return ""
	if op == "register":
		if not outputs.has(oid) or String(outputs[oid].get("location", "")) != "receiving_pad":
			return "Lot must be unloaded on receiving pad"
		if not HMLedger.register_unloaded(catalog, econ, outputs[oid], true):
			return "Manual lot registration refused"
		outputs[oid]["location"] = "registered"
		outputs[oid]["registered"] = true
		return ""
	if op == "sell":
		if not outputs.has(oid) or String(outputs[oid].get("location", "")) != "registered":
			return "Only a registered ordinary lot may be sold"
		if not HMLedger.sell_registered(catalog, econ, oid):
			return "Lot has already been sold or is protected"
		outputs[oid]["location"] = "sold"
		outputs[oid]["sold"] = true
		return ""
	if op == "purchase":
		if not HMLedger.purchase(catalog, econ, String(event.get("upgrade_id", "")), progress["tools"]):
			return "Upgrade unavailable, unaffordable or already maximised"
		return ""
	if op == "find_tool":
		var tool: String = String(event.get("tool_id", ""))
		var tool_data: Dictionary = catalog.by_id("tools", "tools", tool)
		if tool_data.is_empty() or tool == "hands" or String(tool_data.get("discovery", "")) != "world" or progress["tools"].has(tool):
			return "Tool already owned or unknown"
		if String(event.get("source", "")) != "world_discovery":
			return "Tool must be discovered by player action"
		progress["tools"].append(tool)
		return ""
	if op == "discover" or op == "encounter":
		var flag: String = String(event.get("flag_id", ""))
		var story_definition: Dictionary = catalog.by_id("story", "discoveries", flag)
		if story_definition.is_empty() or int(progress["act"]) < int(story_definition.get("minimum_act", 1)):
			return "Unknown or premature narrative event"
		var field: String = "encounters" if op == "encounter" else "discoveries"
		if progress[field].has(flag) or progress["discoveries"].has(flag) or progress["encounters"].has(flag):
			return "One-time story event already completed"
		progress[field].append(flag)
		return ""
	if op == "requisition":
		var req: String = String(event.get("requisition_id", ""))
		var req_definition: Dictionary = catalog.by_id("requisitions", "requisitions", req)
		if req_definition.is_empty() or int(req_definition.get("act", 0)) != int(progress["act"]) or progress["requisition_flags"].has(req):
			return "Wrong act or already completed requisition"
		if not HMRules.requisition_met(catalog, req, econ, progress["tools"], progress["discoveries"] + progress["encounters"]):
			return "Requisition requirements unmet"
		progress["requisition_flags"].append(req)
		return ""
	if op == "advance_act":
		var current: int = int(progress["act"])
		if current >= 4:
			return "Already in final act"
		var found: bool = false
		for raw: Variant in catalog.entries("requisitions", "requisitions"):
			var req_def: Dictionary = raw
			if int(req_def.get("act", 0)) == current and progress["requisition_flags"].has(String(req_def["id"])):
				found = true
		if not found:
			return "Act requisition not completed"
		progress["act"] = current + 1
		return ""
	if op == "finale_action":
		var action_id: String = String(event.get("action_id", ""))
		var problem: String = HMCampaignRules.work_blocker(state, action_id)
		if not problem.is_empty():
			return problem
		var task: Dictionary = HMCampaignRules.TASKS[action_id]
		if not bool(event.get("world_target_validated", false)) or String(event.get("site_id", "")) != String(task["site"]):
			return "Action must be performed at its actual mechanism"
		if String(event.get("selected_tool_id", "")) != String(task["tool"]):
			return "Use the specified discovered tool for the manual operation"
		if not progress.has("finale_actions"):
			progress["finale_actions"] = []
		progress["finale_actions"].append(action_id)
		return ""
	if op == "ending":
		if not bool(event.get("explicit_confirmation", false)) or String(progress["ending"]) != "none":
			return "Ending must be an explicit first-time choice"
		var ending: String = String(event.get("ending_id", ""))
		var story_blocker: String = HMCampaignRules.finale_blocker(state, ending)
		if not story_blocker.is_empty():
			return story_blocker
		# The caller must physically target the protected decision document.
		# Data-layer validation also refuses a mismatched site or non-confirmation.
		if String(event.get("finale_site", "")) != HMCampaignRules.required_site(ending) or not bool(event.get("finale_validated", false)):
			return "Finale site was not physically validated"
		progress["ending"] = ending
		return ""
	return "Unknown manual transaction type"


static func _release_one(catalog: HMCatalog, state: Dictionary, part_id: String, condition: String,
		origin: Array = [0.0, 0.3, 0.0]) -> void:
	state["world"]["parts"][part_id]["phase"] = "released"
	var index: int = 0
	for raw: Variant in HMRules.make_outputs(catalog, part_id, condition):
		var output: Dictionary = raw
		output["processed"] = false
		output["carrier_id"] = ""
		output["position"] = [float(origin[0]) + float(index) * 0.42,
			float(origin[1]), float(origin[2])]
		index += 1
		state["world"]["outputs"][String(output["id"])] = output


static func _valid_position(value: Variant) -> bool:
	if not (value is Array) or value.size() != 3:
		return false
	for number: Variant in value:
		if not (number is int or number is float) or (is_nan(float(number)) or is_inf(float(number))):
			return false
	return true
