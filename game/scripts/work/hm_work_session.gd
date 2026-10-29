class_name HMWorkSession
extends RefCounted
## One manually requested, tool-matched unit of work per accepted action.
## Release and generated salvage are separate later milestones.
## For normal player runs Step05 HMSaveStore writes each unit atomically;
## engine test-yard automation uses an explicitly isolated ephemeral session.

var catalog: HMCatalog
var belt: HMToolbelt
var store: HMSaveStore
var last_error: String = ""


func initialize(source_catalog: HMCatalog, source_belt: HMToolbelt,
		persist: bool = false, slot_id: String = "engineering_manual_work") -> bool:
	catalog = source_catalog
	belt = source_belt
	last_error = ""
	store = null
	belt.save_store = null
	if persist:
		var candidate := HMSaveStore.new()
		if not candidate.open_slot(catalog, slot_id):
			last_error = candidate.last_error
			return false
		store = candidate
		belt.save_store = store
		belt.state = store.snapshot()
		if not belt.is_owned(belt.selected_tool_id):
			belt.selected_tool_id = "hands"
	return true


func has_checkpointed_player_pose() -> bool:
	for transaction_id: Variant in belt.state.get("completed_transactions", {}):
		if String(transaction_id).begins_with("player_pose:"):
			return true
	return false


func checkpoint_player_pose(pose: Dictionary) -> bool:
	# Only player-navigation checkpoints. No salvage output or economy changes.
	if store == null:
		return true
	var previous: Dictionary = belt.state["world"]["carriers"]["player"]
	var a: Array = previous["position"]
	var b: Array = pose.get("position", [])
	if b.size() == 3 and Vector3(float(a[0]), float(a[1]), float(a[2])).distance_squared_to(
			Vector3(float(b[0]), float(b[1]), float(b[2]))) < 0.01 \
			and absf(wrapf(float(previous["yaw"]) - float(pose.get("yaw", 0.0)), -PI, PI)) < 0.02:
		return true
	var transaction: Dictionary = {
		"transaction_id": "player_pose:" + str(int(belt.state["revision"]) + 1),
		"user_initiated": true, "op": "set_player_pose",
		"position": pose.get("position", []), "yaw": pose.get("yaw", 0.0)
	}
	if not store.commit(transaction):
		last_error = store.last_error
		return false
	belt.state = store.snapshot()
	last_error = ""
	return true


func work_once(info: Dictionary, actively_pressed: bool = true,
		access_aids: Array = [], allow_loaded: bool = false) -> Dictionary:
	# info must originate from the fresh first-blocking physics probe in
	# the active player scene; validate again before committing.
	if not actively_pressed:
		return _deny("Work requires an engaged player action")
	var pid: String = String(info.get("part_id", ""))
	if pid.is_empty() or not bool(info.get("reachable", false)):
		return _deny("No reachable authored component")
	var part: Dictionary = catalog.by_part_id(pid)
	if part.is_empty() or bool(part.get("protected", false)):
		return _deny("Unknown or protected component")
	var records: Dictionary = belt.state["world"]["parts"]
	if String(records.get(pid, {}).get("phase", "")) != "attached":
		return _deny("Component is not attached")
	for aid: Variant in part.get("requires_access_aids", []):
		if not access_aids.has(aid):
			return _deny("Missing safe access aid")
	var selected: String = belt.selected_tool_id
	if not belt.is_owned(selected) or not HMRules.can_use(catalog, pid, [selected]):
		return _deny("Select the matching discovered tool")
	var attached: Array = []
	for part_key: Variant in records:
		if String(records[part_key].get("phase", "")) == "attached":
			attached.append(String(part_key))
	var gate: Dictionary = HMInspectionRules.describe(catalog, pid, attached,
			belt.owned_ids(), access_aids, true, selected, records)
	if not bool(gate.get("read_only_actionable", false)):
		var support: Dictionary = HMSupportGraph.release_diagnostic(catalog, pid, attached)
		# Opting into risk permits *manual* preparation only for a small,
		# unprotected loaded chain. Access, reach, tool and phase were checked.
		var deliberate: bool = allow_loaded and not support.get("direct_ids", []).is_empty() \
			and support.get("protected_ids", []).is_empty() and not bool(support.get("truncated", false))
		if not deliberate:
			return _deny(String(gate.get("status", "Unavailable")))
	var before: int = int(records[pid]["work"])
	var maximum: int = int(part["work_units"])
	if before >= maximum:
		return _deny("Work complete; release is a separate action")
	# No support removal, fall damage, item creation, credits or movement here.
	var event: Dictionary = {
		"transaction_id": "manual_work:" + pid + ":" + str(before + 1),
		"user_initiated": true, "op": "partial_work", "part_id": pid,
		"cycles": 1
	}
	if store != null:
		if not store.commit(event):
			return _deny(store.last_error)
		belt.state = store.snapshot()
	else:
		var result: Dictionary = HMTransactions.apply(catalog, belt.state, event)
		if not bool(result.get("ok", false)):
			return _deny(String(result.get("reason", "Work refused")))
		belt.state = result["state"]
	var now: int = int(belt.state["world"]["parts"][pid]["work"])
	last_error = ""
	return {"ok": true, "part_id": pid, "work": now,
		"total": maximum, "complete": now == maximum}


func release_once(info: Dictionary, actively_pressed: bool = true,
		access_aids: Array = [], confirm_risk: bool = false) -> Dictionary:
	# A deliberate, single R press on an unobstructed first-hit target.
	# Step12 callers must acquire a second explicit player risk confirmation.
	if not actively_pressed or not bool(info.get("reachable", false)):
		return _deny("Release needs a close, explicit player action")
	var pid: String = String(info.get("part_id", ""))
	var part: Dictionary = catalog.by_part_id(pid)
	if part.is_empty() or bool(part.get("protected", false)):
		return _deny("Protected or unknown component")
	var records: Dictionary = belt.state["world"]["parts"]
	if String(records.get(pid, {}).get("phase", "")) != "attached":
		return _deny("Component already removed")
	if int(records[pid]["work"]) != int(part["work_units"]):
		return _deny("Complete the manual work before release")
	var active: Array = []
	for part_key: Variant in records:
		if String(records[part_key].get("phase", "")) == "attached":
			active.append(String(part_key))
	if not belt.is_owned(belt.selected_tool_id):
		return _deny("Selected tool not discovered")
	var clearance: Dictionary = HMRules.inspect_release(catalog, pid, active,
			[belt.selected_tool_id], access_aids, confirm_risk)
	if not bool(clearance.get("allowed", false)):
		return _deny(String(clearance.get("reason", "Release blocked")))
	var origin: Array = info.get("hit_position", [0.0, 0.3, 0.0])
	var event: Dictionary = {
		"transaction_id": "manual_release:" + pid,
		"user_initiated": true, "op": "release", "part_id": pid,
		"access_aids": access_aids.duplicate(), "confirm_risk": confirm_risk,
		"spawn_origin": origin
	}
	if store != null:
		if not store.commit(event):
			return _deny(store.last_error)
		belt.state = store.snapshot()
	else:
		var result: Dictionary = HMTransactions.apply(catalog, belt.state, event)
		if not bool(result.get("ok", false)):
			return _deny(String(result.get("reason", "Release refused")))
		belt.state = result["state"]
	var spawned: Array[String] = []
	for output_id: Variant in belt.state["world"]["outputs"]:
		if String(belt.state["world"]["outputs"][output_id]["source_part_id"]) == pid:
			spawned.append(String(output_id))
	spawned.sort()
	last_error = ""
	return {"ok": true, "part_id": pid, "output_ids": spawned,
		"damaged_dependents": clearance.get("damaged_dependents", [])}


func commit_player_progress(event: Dictionary) -> Dictionary:
	# Main requests an explicit event; only this service can write the
	# existing transactional state and durable player save.
	if store != null:
		if not store.commit(event):
			return _deny(store.last_error)
		belt.state = store.snapshot()
	else:
		var result: Dictionary = HMTransactions.apply(catalog, belt.state, event)
		if not bool(result.get("ok", false)):
			return _deny(String(result.get("reason", "Event refused")))
		belt.state = result["state"]
	return {"ok": true, "operation": String(event.get("op", ""))}


func _deny(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "reason": reason}
