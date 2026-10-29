class_name HMSaveState
extends RefCounted
## Step 5 source-of-truth logical state. No runtime NodePaths, scene instance IDs,
## automatically gathered goods, or random output IDs are ever persisted.

const SAVE_SCHEMA_VERSION: int = 1
const DATA_SCHEMA_VERSION: int = 1
const ALLOWED_LOCATIONS: Array[String] = [
	"world_released", "staged", "carried", "cart", "receiving_pad", "registered", "sold"
]


static func fresh(catalog: HMCatalog) -> Dictionary:
	var parts: Dictionary = {}
	for raw: Variant in catalog.entries("sample_parts", "parts"):
		var part: Dictionary = raw
		parts[String(part["id"])] = {"phase": "attached", "work": 0}
	return {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"data_schema_version": DATA_SCHEMA_VERSION,
		"revision": 0,
		"world": {"parts": parts, "outputs": {},
			"carriers": {"player": {"position": [0.0, 0.0, 0.0], "yaw": 0.0}, "carts": {}}},
		"economy": HMLedger.fresh(),
		"progress": {"act": 1, "tools": ["hands"], "discoveries": [], "encounters": [],
			"ending": "none", "requisition_flags": [], "finale_actions": []},
		"completed_transactions": {}
	}


static func validate(catalog: HMCatalog, save: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(save.get("save_schema_version", -1)) != SAVE_SCHEMA_VERSION:
		errors.append("Unsupported save schema version")
	if int(save.get("data_schema_version", -1)) != DATA_SCHEMA_VERSION:
		errors.append("Wrong content schema version")
	if not (save.get("revision", null) is int) or int(save.get("revision", -1)) < 0:
		errors.append("Invalid save revision")
	for key: String in ["world", "economy", "progress", "completed_transactions"]:
		if not (save.get(key, null) is Dictionary):
			errors.append("Missing state dictionary: " + key)
	if not errors.is_empty():
		return errors

	var world: Dictionary = save["world"]
	var economy: Dictionary = save["economy"]
	var progress: Dictionary = save["progress"]
	var parts: Variant = world.get("parts", null)
	var outputs: Variant = world.get("outputs", null)
	var carriers: Variant = world.get("carriers", null)
	if not (parts is Dictionary) or not (outputs is Dictionary) or not (carriers is Dictionary):
		errors.append("Missing part/output/carrier maps")
		return errors
	if not (carriers.get("player", null) is Dictionary) or not (carriers.get("carts", null) is Dictionary):
		errors.append("Missing player or cart-carrier state")
		return errors
	if not (economy.get("registered", null) is Dictionary) or not (economy.get("sold", null) is Dictionary) or not (economy.get("upgrades", null) is Dictionary):
		errors.append("Invalid economy tables")
		return errors
	if int(economy.get("schema_version", -1)) != 1 or not (economy.get("credits", null) is int) or int(economy["credits"]) < 0:
		errors.append("Invalid economy version/credits")
	if not (progress.get("tools", null) is Array) or not (progress.get("discoveries", null) is Array) or not (progress.get("encounters", null) is Array) or not (progress.get("requisition_flags", null) is Array):
		errors.append("Invalid progress arrays")
		return errors
	# Optional in legacy schema-v1 saves: missing is exactly an empty sequence.
	# Enforce a sequential prefix so crafted or corrupt saves cannot skip work.
	var actions: Variant = progress.get("finale_actions", [])
	if not (actions is Array):
		errors.append("Invalid manual finale action history")
	else:
		var steps: Array = actions
		var bell_path: bool = steps.size() > 0 and HMCampaignRules.BELL.has(String(steps[0]))
		var sequence: Array[String] = HMCampaignRules.BELL if bell_path else HMCampaignRules.REPAIR
		for i: int in range(steps.size()):
			if i >= sequence.size() or String(steps[i]) != sequence[i]:
				errors.append("Finale action order or branch was changed")
				break
		if steps.size() > 0 and not progress.get("requisition_flags", []).has("req_act_04"):
			errors.append("Finale work without submitted Act IV requisition")
		var ending_value: String = String(progress.get("ending", "none"))
		if ending_value != "none":
			var expected: Array[String] = HMCampaignRules.BELL if ending_value == "bell_delivery" else HMCampaignRules.REPAIR
			if progress.has("finale_actions") and steps != expected:
				errors.append("Ending without all manual physical operations")
	var act: int = int(progress.get("act", -1))
	if act < 1 or act > 4:
		errors.append("Invalid act")
	if not ["none", "bell_delivery", "repair_escape"].has(String(progress.get("ending", ""))):
		errors.append("Invalid ending")

	var all_parts: Dictionary = {}
	for raw: Variant in catalog.entries("sample_parts", "parts"):
		var definition: Dictionary = raw
		all_parts[String(definition["id"])] = definition
	if parts.size() != all_parts.size():
		errors.append("Part map cardinality changed")
	for id: Variant in parts:
		var pid: String = String(id)
		if not all_parts.has(pid):
			errors.append("Unknown saved part: " + pid)
			continue
		var rec: Variant = parts[id]
		if not (rec is Dictionary):
			errors.append("Invalid part record: " + pid)
			continue
		var record: Dictionary = rec
		if not ["attached", "released"].has(String(record.get("phase", ""))):
			errors.append("Invalid part phase: " + pid)
		if not (record.get("work", null) is int) or int(record["work"]) < 0 or int(record["work"]) > int(all_parts[pid]["work_units"]):
			errors.append("Invalid partial work: " + pid)
		if bool(all_parts[pid].get("protected", false)) and String(record.get("phase", "")) == "released":
			errors.append("Protected part released: " + pid)
	for pid: Variant in all_parts:
		if not parts.has(pid):
			errors.append("Missing saved part: " + String(pid))

	var authentic_outputs: Dictionary = {}
	for pid: Variant in all_parts:
		var original: Dictionary = all_parts[pid]
		if bool(original.get("protected", false)):
			continue
		for expected: Variant in HMRules.make_outputs(catalog, String(pid), "intact"):
			authentic_outputs[String(expected["id"])] = expected
	for id: Variant in outputs:
		var oid: String = String(id)
		if not authentic_outputs.has(oid) or not (outputs[id] is Dictionary):
			errors.append("Unknown/malformed saved output: " + oid)
			continue
		var out: Dictionary = outputs[id]
		var expected: Dictionary = authentic_outputs[oid]
		var parent_id: String = String(expected["source_part_id"])
		if String(parts.get(parent_id, {}).get("phase", "")) != "released":
			errors.append("Parent still attached for output: " + oid)
		if String(out.get("id", "")) != oid or String(out.get("source_part_id", "")) != parent_id or String(out.get("site_id", "")) != String(expected["site_id"]):
			errors.append("Output provenance altered: " + oid)
		if not (out.get("allocation", null) is Dictionary) or not HMSchema.same_allocation(out.get("allocation", {}), expected["allocation"]):
			errors.append("Output units altered: " + oid)
		if not HMSchema.CONDITIONS.has(String(out.get("condition", ""))) or bool(out.get("protected", true)):
			errors.append("Output condition or protection invalid: " + oid)
		if not ALLOWED_LOCATIONS.has(String(out.get("location", ""))):
			errors.append("Output location invalid: " + oid)
		if not (out.get("processed", null) is bool):
			errors.append("Output processed flag invalid: " + oid)
		var location_id: String = String(out.get("location", ""))
		var carrier_id: String = String(out.get("carrier_id", ""))
		if location_id == "carried" and carrier_id != "player":
			errors.append("Carried output missing player carrier identity: " + oid)
		if location_id == "cart" and not carriers["carts"].has(carrier_id):
			errors.append("Output refers to missing cart: " + oid)
		if not ["carried", "cart"].has(location_id) and not carrier_id.is_empty():
			errors.append("Stale carrier association for output: " + oid)
		if not (out.get("position", null) is Array):
			errors.append("Output has no position: " + oid)
		else:
			var pos: Array = out["position"]
			if pos.size() != 3:
				errors.append("Output position dimensionality invalid: " + oid)
			else:
				for n: Variant in pos:
					if not (n is int or n is float) or (is_nan(float(n)) or is_inf(float(n))):
						errors.append("Nonfinite output position: " + oid)
		var registered: bool = economy["registered"].has(oid)
		var sold: bool = economy["sold"].has(oid)
		if bool(out.get("registered", false)) != registered or bool(out.get("sold", false)) != sold:
			errors.append("Output lifecycle flags and ledger differ: " + oid)
		if String(out.get("location", "")) == "registered" and not registered:
			errors.append("Registered output missing ledger entry: " + oid)
		if String(out.get("location", "")) == "sold" and not sold:
			errors.append("Sold output missing ledger entry: " + oid)
		if sold and not registered:
			errors.append("Sold without registering: " + oid)
		if sold and String(out.get("location", "")) != "sold":
			errors.append("Sold output not in sold state: " + oid)
		if registered and not ["registered", "sold"].has(String(out.get("location", ""))):
			errors.append("Registered output still physical: " + oid)
	for pid: Variant in all_parts:
		if String(parts.get(pid, {}).get("phase", "")) == "released":
			for expected: Variant in HMRules.make_outputs(catalog, String(pid), "intact"):
				if not outputs.has(expected["id"]):
					errors.append("Missing released child: " + String(expected["id"]))

	for id: Variant in economy["registered"]:
		if not outputs.has(id) or not (economy["registered"][id] is Dictionary):
			errors.append("Unknown registered lot: " + String(id))
			continue
		var lot: Dictionary = economy["registered"][id]
		var out: Dictionary = outputs[id]
		if not HMSchema.same_allocation(lot.get("allocation", {}), out.get("allocation", {})) or String(lot.get("condition", "")) != String(out.get("condition", "")) or String(lot.get("source_part_id", "")) != String(out.get("source_part_id", "")) or bool(lot.get("processed", false)) != bool(out.get("processed", false)):
			errors.append("Registered lot snapshot inconsistent: " + String(id))
	for id: Variant in economy["sold"]:
		if not economy["registered"].has(id) or not (economy["sold"][id] is int):
			errors.append("Invalid sold lot: " + String(id))
			continue
		var expected_price: int = HMLedger.sale_price(catalog, economy["registered"][id])
		if int(economy["sold"][id]) != expected_price:
			errors.append("Wrong single sale price: " + String(id))
	var receipts: int = 0
	for amount: Variant in economy["sold"].values():
		if amount is int:
			receipts += int(amount)
	var spent: int = 0
	for key: Variant in economy["upgrades"]:
		var levels: Array = catalog.by_id("upgrades", "upgrades", String(key)).get("levels", [])
		var num: Variant = economy["upgrades"][key]
		if not (num is int) or int(num) < 0 or int(num) > levels.size():
			errors.append("Invalid upgrade level: " + String(key))
			continue
		for ix: int in range(int(num)):
			spent += int(levels[ix].get("price", 0))
	if receipts - spent != int(economy.get("credits", -1)):
		errors.append("Credits do not reconcile against sales and purchases")

	var tool_seen: Dictionary = {}
	for tool: Variant in progress["tools"]:
		if not HMSchema.TIERS.has(String(tool)) or tool_seen.has(tool):
			errors.append("Invalid or duplicate owned tool")
		tool_seen[tool] = true
	if not tool_seen.has("hands"):
		errors.append("Innate hands must remain owned")
	for key: Variant in economy["upgrades"]:
		var definition: Dictionary = catalog.by_id("upgrades", "upgrades", String(key))
		var applies: String = String(definition.get("applies_to", ""))
		if definition.is_empty() or (HMSchema.TIERS.has(applies) and not tool_seen.has(applies)):
			errors.append("An upgrade was purchased for an unowned tool")
	var flag_seen: Dictionary = {}
	for key: String in ["discoveries", "encounters"]:
		for flag: Variant in progress[key]:
			var definition: Dictionary = catalog.by_id("story", "discoveries", String(flag))
			if definition.is_empty() or flag_seen.has(flag):
				errors.append("Unknown/duplicate story flag: " + String(flag))
			flag_seen[flag] = true
	for flag: Variant in progress["requisition_flags"]:
		if catalog.by_id("requisitions", "requisitions", String(flag)).is_empty():
			errors.append("Unknown requisition flag: " + String(flag))
	if String(progress.get("ending", "none")) != "none":
		if int(progress.get("act", 1)) != 4 or not progress["discoveries"].has("containment_understood"):
			errors.append("Ending recorded without prerequisites")

	var player: Dictionary = carriers["player"]
	if not _valid_pose(player):
		errors.append("Player pose is invalid")
	for cart_id: Variant in carriers["carts"]:
		if String(cart_id).is_empty() or not (carriers["carts"][cart_id] is Dictionary) or not _valid_pose(carriers["carts"][cart_id]):
			errors.append("Cart pose is invalid: " + String(cart_id))
	var tx_seen: Dictionary = save["completed_transactions"]
	for key: Variant in tx_seen:
		if String(key).is_empty() or not (tx_seen[key] is int) or int(tx_seen[key]) < 1 or int(tx_seen[key]) > int(save["revision"]):
			errors.append("Invalid transaction marker")
	if tx_seen.size() != int(save["revision"]):
		errors.append("Transaction count disagrees with revision")
	return errors


static func _valid_pose(pose: Dictionary) -> bool:
	var position: Variant = pose.get("position", null)
	if not (position is Array) or position.size() != 3:
		return false
	for number: Variant in position:
		if not (number is int or number is float) or is_inf(float(number)) or is_nan(float(number)):
			return false
	var yaw: Variant = pose.get("yaw", null)
	return (yaw is int or yaw is float) and not is_inf(float(yaw)) and not is_nan(float(yaw))
