class_name HMSchema
extends RefCounted
## Structural validator: catches incompatible definitions before content authoring.

const FAMILIES = [
	"timber", "stone", "fired_clay", "iron", "copper_bronze",
	"fibres", "glass", "mineral_fill"
]
const CONDITIONS = ["intact", "damaged"]
const TIERS = {"hands": 1, "claw_hammer": 2, "crowbar": 3, "pickaxe": 3, "saw": 4}


static func allocation_valid(a: Dictionary) -> bool:
	if a.is_empty():
		return false
	for key: Variant in a:
		if not FAMILIES.has(String(key)):
			return false
		# JSON.parse_string() represents integral JSON numbers as floats in Godot.
		# Accept whole finite positive quantities without truncating fractions.
		if not (a[key] is int or a[key] is float):
			return false
		var units: float = float(a[key])
		if units <= 0.0 or units != floor(units):
			return false
	return true


static func same_allocation(a: Dictionary, b: Dictionary) -> bool:
	for family: String in FAMILIES:
		if int(a.get(family, 0)) != int(b.get(family, 0)):
			return false
	return true


static func sum_outputs(outputs: Array) -> Dictionary:
	var result: Dictionary = {}
	for output: Variant in outputs:
		if not output is Dictionary:
			continue
		var allocation: Dictionary = output.get("allocation", {})
		for family: Variant in allocation:
			result[family] = int(result.get(family, 0)) + int(allocation[family])
	return result


static func validate(catalog: HMCatalog) -> PackedStringArray:
	var mistakes := PackedStringArray()
	if not catalog.errors.is_empty():
		mistakes.append_array(catalog.errors)
		return mistakes
	var family_ids: Dictionary = {}
	for row: Variant in catalog.entries("materials", "families"):
		var a: Dictionary = row
		var id: String = String(a.get("id", ""))
		if family_ids.has(id) or not FAMILIES.has(id):
			mistakes.append("Invalid/duplicate material: " + id)
		family_ids[id] = true
		if int(a.get("credits_per_unit", 0)) <= 0:
			mistakes.append("Nonpositive material price: " + id)
	if family_ids.size() != 8:
		mistakes.append("Expected exactly eight salvage families")
	var materials: Dictionary = catalog.tables["materials"]
	if materials.get("condition_states", []) != ["intact", "damaged"]:
		mistakes.append("Condition is not strictly binary")
	var penalty: int = int(materials.get("damaged_value_multiplier_percent", -1))
	if penalty < 0 or penalty > 100:
		mistakes.append("Invalid damaged-value multiplier")

	var tool_ids: Dictionary = {}
	for raw: Variant in catalog.entries("tools", "tools"):
		var tool: Dictionary = raw
		var tid: String = String(tool.get("id", ""))
		if tool_ids.has(tid) or not TIERS.has(tid):
			mistakes.append("Unrecognised or duplicate tool: " + tid)
		tool_ids[tid] = true
		if int(tool.get("tier", -1)) != int(TIERS.get(tid, -99)):
			mistakes.append("Wrong tool tier: " + tid)
		if tool.get("operations", []).is_empty():
			mistakes.append("Tool has no operations: " + tid)
		if String(tool.get("discovery", "")) != ("innate" if tid == "hands" else "world"):
			mistakes.append("Wrong tool discovery type: " + tid)
	if tool_ids.size() != 5:
		mistakes.append("Expected hands and four found physical tools")

	var allowed: Array = catalog.tables["upgrades"].get("allowed_modifiers", [])
	var aid: Dictionary = {}
	for raw: Variant in catalog.entries("upgrades", "upgrades"):
		var upgrade: Dictionary = raw
		var uid: String = String(upgrade.get("id", ""))
		if uid.is_empty() or aid.has(uid):
			mistakes.append("Duplicate/missing upgrade ID: " + uid)
		aid[uid] = true
		if not allowed.has(upgrade.get("modifier", "")):
			mistakes.append("Tier-breaking or undefined upgrade modifier: " + uid)
		var applies: String = String(upgrade.get("applies_to", ""))
		if not tool_ids.has(applies) and applies != "player" and applies != "cart":
			mistakes.append("Upgrade references unowned capability: " + uid)
		if upgrade.has("new_capabilities") or upgrade.has("tier"):
			mistakes.append("Upgrade attempts to grant a tier: " + uid)
		var levels: Array = upgrade.get("levels", [])
		if levels.is_empty():
			mistakes.append("No upgrade levels: " + uid)
		for level: Variant in levels:
			if int(level.get("price", 0)) <= 0:
				mistakes.append("Invalid upgrade price: " + uid)

	var sites: Dictionary = {}
	for raw: Variant in catalog.entries("locations", "sites"):
		var location: Dictionary = raw
		var sid: String = String(location.get("id", ""))
		if sid.is_empty() or sites.has(sid):
			mistakes.append("Duplicate/missing site: " + sid)
		sites[sid] = true
	if sites.size() != 21:
		mistakes.append("Expected 21 mapped village functions")

	var flags: Dictionary = {}
	for raw: Variant in catalog.entries("story", "discoveries"):
		var discovery: Dictionary = raw
		var did: String = String(discovery.get("id", ""))
		if did.is_empty() or flags.has(did) or not sites.has(discovery.get("location_id", "")):
			mistakes.append("Invalid story discovery: " + did)
		flags[did] = true
		var act: int = int(discovery.get("minimum_act", 0))
		if act < 1 or act > 4 or not bool(discovery.get("one_time", false)):
			mistakes.append("Invalid story act/one-time flag: " + did)

	var requisition_acts: Dictionary = {}
	for raw: Variant in catalog.entries("requisitions", "requisitions"):
		var req: Dictionary = raw
		var act: int = int(req.get("act", 0))
		if act < 1 or act > 4 or requisition_acts.has(act):
			mistakes.append("Duplicate/invalid requisition act: " + str(act))
		requisition_acts[act] = true
		if not bool(req.get("fixture_only", false)):
			mistakes.append("Unapproved quotas marked live: " + str(act))
		if int(req.get("min_registered_units", 0)) <= 0 or int(req.get("min_distinct_sites", 0)) <= 0:
			mistakes.append("Invalid requisition thresholds: " + str(act))
		for family: Variant in req.get("families", []):
			if not FAMILIES.has(String(family)):
				mistakes.append("Requisition uses unknown material: " + str(family))
		for flag: Variant in req.get("requires_flags", []):
			if not flags.has(flag):
				mistakes.append("Requisition requires unknown flag: " + str(flag))
		for tid: Variant in req.get("required_tool_ids", []):
			if not tool_ids.has(tid):
				mistakes.append("Requisition requires unknown tool: " + str(tid))
	if requisition_acts.size() != 4:
		mistakes.append("Expected four act requisitions")

	var parts: Dictionary = {}
	for raw: Variant in catalog.entries("sample_parts", "parts"):
		var part: Dictionary = raw
		var pid: String = String(part.get("id", ""))
		if pid.is_empty() or parts.has(pid):
			mistakes.append("Duplicate/missing stable part ID: " + pid)
		parts[pid] = part
		if not sites.has(part.get("site_id", "")):
			mistakes.append("Unknown site for part: " + pid)
		var tool: Dictionary = catalog.by_id("tools", "tools", String(part.get("tool_id", "")))
		if tool.is_empty() or int(part.get("tier", 0)) != int(tool.get("tier", -1)):
			mistakes.append("Tool/tier mismatch for part: " + pid)
		elif not tool.get("operations", []).has(part.get("operation", "")):
			mistakes.append("Tool operation forbidden: " + pid)
		var allocation: Dictionary = part.get("allocation", {})
		var outputs: Array = part.get("outputs", [])
		if not allocation.is_empty() and not allocation_valid(allocation):
			mistakes.append("Invalid material allocation: " + pid)
		if not same_allocation(allocation, sum_outputs(outputs)):
			mistakes.append("Output units not conserved: " + pid)
		var suffixes: Dictionary = {}
		for raw_output: Variant in outputs:
			var output: Dictionary = raw_output
			var suffix: String = String(output.get("suffix", ""))
			if suffix.is_empty() or suffixes.has(suffix):
				mistakes.append("Duplicate/missing output suffix: " + pid)
			suffixes[suffix] = true
			if not allocation_valid(output.get("allocation", {})):
				mistakes.append("Invalid output allocation: " + pid)
		if bool(part.get("protected", false)) and not catalog.tables["story"].get("protections", []).has(part.get("protection_id", "")):
			mistakes.append("Unknown protected object purpose: " + pid)
	for raw: Variant in catalog.entries("sample_parts", "parts"):
		var part: Dictionary = raw
		var pid: String = String(part["id"])
		for dep: Variant in part.get("supports", []):
			if not parts.has(dep) or dep == pid:
				mistakes.append("Broken/self support reference: " + pid)
			elif parts[dep].get("building_id", "") != part.get("building_id", ""):
				mistakes.append("Support link crosses buildings: " + pid)
		var visited: Dictionary = {}
		if _has_cycle(pid, parts, visited, {}):
			mistakes.append("Cyclic support graph: " + pid)

	var visual_ids: Dictionary = {}
	for raw: Variant in catalog.entries("visual_reference_index", "object_archetypes"):
		var row: Dictionary = raw
		var vid: String = String(row.get("id", ""))
		if vid.is_empty() or visual_ids.has(vid):
			mistakes.append("Duplicate visual archetype: " + vid)
		visual_ids[vid] = true
	var building_ids: Dictionary = {}
	for raw: Variant in catalog.entries("visual_reference_index", "proposed_buildings"):
		var row: Dictionary = raw
		var bid: String = String(row.get("id", ""))
		if bid.is_empty() or building_ids.has(bid):
			mistakes.append("Duplicate proposed building ID: " + bid)
		building_ids[bid] = true
	if visual_ids.size() != 264 or building_ids.size() != 30:
		mistakes.append("Design register coverage must remain 264 objects / 30 buildings")
	return mistakes


static func _has_cycle(pid: String, parts: Dictionary, seen: Dictionary, stack: Dictionary) -> bool:
	if stack.has(pid):
		return true
	if seen.has(pid):
		return false
	seen[pid] = true
	stack[pid] = true
	var part: Dictionary = parts[pid]
	for child: Variant in part.get("supports", []):
		if parts.has(child) and _has_cycle(String(child), parts, seen, stack):
			return true
	stack.erase(pid)
	return false
