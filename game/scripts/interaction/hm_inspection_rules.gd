class_name HMInspectionRules
extends RefCounted
## Read-only presentation based on the Step04 mechanical authority.

static func describe(catalog: HMCatalog, part_id: String, active_ids: Array,
		owned_tools: Array, access_aids: Array, reachable: bool, selected_tool_id: String = "", work_records: Dictionary = {}) -> Dictionary:
	var part: Dictionary = catalog.by_part_id(part_id)
	if part.is_empty():
		return {}
	var archetype: String = String(part.get("archetype_id", part_id))
	var title: String = archetype.get_slice(":", 1).replace("_", " ").capitalize()
	var required_id: String = String(part.get("tool_id", ""))
	var tool: Dictionary = catalog.by_id("tools", "tools", required_id)
	var tool_name: String = String(tool.get("name", required_id.replace("_", " ").capitalize()))
	var present: bool = active_ids.has(part_id)
	var protected_part: bool = bool(part.get("protected", false))
	var support: Dictionary = HMSupportGraph.release_diagnostic(catalog, part_id, active_ids)
	var risks: Array[String] = []
	for dependent: Variant in support.get("direct_ids", []):
		risks.append(String(dependent))
	var missing_aids: Array[String] = []
	for aid: Variant in part.get("requires_access_aids", []):
		if not access_aids.has(aid):
			missing_aids.append(String(aid).replace("_", " "))
	var progress: int = int(work_records.get(part_id, {}).get("work", 0))
	var total: int = int(part.get("work_units", 1))
	var status: String = "Hold left mouse button to work"
	var can_work_later: bool = reachable and present and not protected_part
	if protected_part:
		status = "Protected — not ordinary salvage"
		can_work_later = false
	elif not present:
		status = "Already removed or unavailable"
		can_work_later = false
	elif not reachable:
		status = "Out of reach — move closer"
		can_work_later = false
	elif not HMRules.can_use(catalog, part_id, owned_tools):
		status = "Requires discovered tool: " + tool_name
		can_work_later = false
	elif not selected_tool_id.is_empty() and not HMRules.can_use(catalog, part_id, [selected_tool_id]):
		status = "Select " + tool_name + " to work on this component"
		can_work_later = false
	elif not missing_aids.is_empty():
		status = "Needs access: " + ", ".join(missing_aids)
		can_work_later = false
	elif not risks.is_empty():
		status = "Blocked: " + String(support["reason"])
		if support.get("protected_ids", []).is_empty() and not bool(support.get("truncated", false)):
			status += " — hold G+Mouse for risky work; G+R twice after work"
		can_work_later = false
	elif progress >= total:
		status = "Work complete — press R to release carefully"
		can_work_later = false
	elif progress > 0:
		status = "Partial work " + str(progress) + " / " + str(total) + " — hold mouse to continue"
	var allocation: Dictionary = part.get("allocation", {})
	var materials: Array[String] = []
	for family: Variant in allocation:
		materials.append(String(family).replace("_", " ") + " x" + str(int(allocation[family])))
	materials.sort()
	var details: String = "Tool: " + tool_name + " (tier " + str(int(part.get("tier", 0))) + ")"
	details += "\nMaterials: " + (", ".join(materials) if not materials.is_empty() else "not ordinary salvage")
	details += "\nOutput groups: " + str(part.get("outputs", []).size())
	details += "\nManual work: " + str(progress) + " / " + str(total)
	if not risks.is_empty():
		details += "\nRemove these first: " + ", ".join(risks)
		var cascade: Array = support.get("cascade_ids", [])
		if cascade.size() > risks.size():
			details += "\nAt risk downstream: " + str(cascade.size() - risks.size())
		if not support.get("protected_ids", []).is_empty():
			details += "\nProtected component beneath this support"
	if not missing_aids.is_empty():
		details += "\nAccess needed: " + ", ".join(missing_aids)
	return {
		"part_id": part_id,
		"title": title,
		"status": status,
		"details": details,
		"reachable": reachable,
		"protected": protected_part,
		"read_only_actionable": can_work_later,
		"work": progress, "work_total": total,
		"risks": risks, "support_cascade": support.get("cascade_ids", []),
		"protected_dependents": support.get("protected_ids", [])
	}
