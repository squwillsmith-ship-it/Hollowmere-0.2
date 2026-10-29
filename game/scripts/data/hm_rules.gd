class_name HMRules
extends RefCounted
## Pure Step 4 gameplay rules: no scenes, timers, inventory autopickup or physics.


static func can_use(catalog: HMCatalog, part_id: String, owned_tools: Array) -> bool:
	var part: Dictionary = catalog.by_part_id(part_id)
	if part.is_empty() or bool(part.get("protected", false)):
		return false
	var tid: String = String(part.get("tool_id", ""))
	if not owned_tools.has(tid):
		return false
	var tool: Dictionary = catalog.by_id("tools", "tools", tid)
	return not tool.is_empty() and tool.get("operations", []).has(part.get("operation", ""))


static func inspect_release(catalog: HMCatalog, part_id: String, active_ids: Array, owned_tools: Array, access_aids: Array, confirm_risk: bool = false) -> Dictionary:
	var part: Dictionary = catalog.by_part_id(part_id)
	if part.is_empty():
		return {"allowed": false, "reason": "Unknown component"}
	if bool(part.get("protected", false)):
		return {"allowed": false, "reason": "Protected story/infrastructure component"}
	if not active_ids.has(part_id):
		return {"allowed": false, "reason": "Component already removed or unavailable"}
	if not can_use(catalog, part_id, owned_tools):
		return {"allowed": false, "reason": "Required discovered tool or operation is missing"}
	for aid: Variant in part.get("requires_access_aids", []):
		if not access_aids.has(aid):
			return {"allowed": false, "reason": "Required safe access or handling aid: " + String(aid)}
	var structural: Dictionary = HMSupportGraph.release_diagnostic(catalog, part_id, active_ids)
	var at_risk: Array = structural.get("direct_ids", [])
	if not at_risk.is_empty() and not confirm_risk:
		return {"allowed": false, "warning": true,
			"reason": String(structural["reason"]), "at_risk": at_risk}
	if not structural.get("protected_ids", []).is_empty():
		return {"allowed": false, "warning": true,
			"reason": "Protected dependency blocks destructive release", "at_risk": at_risk}
	if bool(structural.get("truncated", false)):
		return {"allowed": false, "warning": true,
			"reason": "Too many local dependents: unsafe cascade blocked", "at_risk": at_risk}
	return {"allowed": true, "warning": not at_risk.is_empty(),
		"damaged_dependents": structural.get("cascade_ids", []), "at_risk": at_risk}


static func make_outputs(catalog: HMCatalog, part_id: String, condition: String) -> Array:
	var part: Dictionary = catalog.by_part_id(part_id)
	if part.is_empty() or bool(part.get("protected", false)) or not HMSchema.CONDITIONS.has(condition):
		return []
	var outputs: Array = []
	for raw: Variant in part.get("outputs", []):
		var child: Dictionary = raw
		outputs.append({
			"id": part_id + "/out/" + String(child["suffix"]),
			"source_part_id": part_id,
			"site_id": part["site_id"],
			"allocation": child["allocation"].duplicate(true),
			"condition": condition,
			"location": "world_released",
			"protected": false,
			"registered": false,
			"sold": false
		})
	return outputs


static func requisition_met(catalog: HMCatalog, requisition_id: String, ledger: Dictionary, owned_tools: Array, story_flags: Array) -> bool:
	var req: Dictionary = catalog.by_id("requisitions", "requisitions", requisition_id)
	if req.is_empty():
		return false
	var count: int = 0
	var sites: Dictionary = {}
	for raw: Variant in ledger.get("registered", {}).values():
		var lot: Dictionary = raw
		sites[String(lot.get("site_id", ""))] = true
		var allocation: Dictionary = lot.get("allocation", {})
		for family: Variant in allocation:
			if req.get("families", []).is_empty() or req.get("families", []).has(family):
				count += int(allocation[family])
	if count < int(req.get("min_registered_units", 0)) or sites.size() < int(req.get("min_distinct_sites", 0)):
		return false
	for tid: Variant in req.get("required_tool_ids", []):
		if not owned_tools.has(tid):
			return false
	for flag: Variant in req.get("requires_flags", []):
		if not story_flags.has(flag):
			return false
	return true
