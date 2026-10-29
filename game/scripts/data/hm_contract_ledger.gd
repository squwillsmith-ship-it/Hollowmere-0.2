class_name HMContractLedger
extends RefCounted
## Read-only paper work order; uses current conserved registration records.
## This never grants an item, event, credit, tool or requisition flag.
const PREFACE: String = "COMPANY SALVAGE CONTRACT — BRINEWICK\n" + \
	"Convicted worker Marin is assigned to recover the abandoned village's materials. " + \
	"Complete all four company requisitions for formal discharge from death row. " + \
	"Recovered goods must be manually carried, unloaded, entered into the yard ledger and handed over.\n"

static func summary(catalog: HMCatalog, state: Dictionary) -> String:
	var progress: Dictionary = state.get("progress", {})
	var act: int = int(progress.get("act", 1))
	var order: Dictionary = catalog.by_id("requisitions", "requisitions", "req_act_0" + str(act))
	var lines: Array[String] = [PREFACE, "ACT " + str(act) + " OF FOUR — " + String(order.get("title", "Contract completed"))]
	var completed: Array = progress.get("requisition_flags", [])
	if completed.has(String(order.get("id", ""))):
		lines.append("Current requisition received by company. Press B at the yard counter to advance when eligible.")
	else:
		var allowed: Array = order.get("families", [])
		var units: int = 0
		var sites: Dictionary = {}
		var econ: Dictionary = state.get("economy", {})
		for raw: Variant in econ.get("registered", {}).values():
			var lot: Dictionary = raw
			sites[String(lot.get("site_id", ""))] = true
			var allocation: Dictionary = lot.get("allocation", {})
			for family: Variant in allocation:
				if allowed.is_empty() or allowed.has(family):
					units += int(allocation[family])
		lines.append("Manually recorded materials: " + str(units) + " / " + str(int(order.get("min_registered_units", 0))) + " provisional units")
		lines.append("Distinct recovery locations: " + str(sites.size()) + " / " + str(int(order.get("min_distinct_sites", 0))))
		lines.append("Eligible materials (any listed; not each required): " + (", ".join(allowed) if not allowed.is_empty() else "all ordinary materials"))
		var not_found: Array[String] = []
		for tool: Variant in order.get("required_tool_ids", []):
			if not progress.get("tools", []).has(tool):
				not_found.append(String(tool))
		if not not_found.is_empty():
			lines.append("Discover required tool: " + ", ".join(not_found))
		var evidence: Array = progress.get("discoveries", []).duplicate()
		evidence.append_array(progress.get("encounters", []))
		var missing: Array[String] = []
		for flag: Variant in order.get("requires_flags", []):
			if not evidence.has(flag):
				missing.append(String(flag).replace("_", " "))
		if not missing.is_empty():
			lines.append("Unresolved village evidence: " + ", ".join(missing))
		lines.append("When requirements are fulfilled, press B at the boatyard ledger to submit.")
	lines.append("The written quantities remain engineering fixtures until balancing is approved.")
	if act == 4:
		lines.append("Final work: " + str(progress.get("finale_actions", []).size()) +
			" manually completed protected mechanism operations.")
		var done: Array = progress.get("finale_actions", [])
		var steps: Array[String] = HMCampaignRules.REPAIR if (
			done.size() > 0 and HMCampaignRules.REPAIR.has(String(done[0]))) else HMCampaignRules.BELL
		for action: String in steps:
			lines.append(("  [x] " if done.has(action) else "  [ ] ") +
				String(HMCampaignRules.TASKS[action]["title"]))
		lines.append("Only one physical finale route may be completed. Choosing the outcome still requires explicit consent.")
	return "\n".join(lines)
