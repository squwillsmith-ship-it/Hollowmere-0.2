class_name HMLedger
extends RefCounted
## Step 4 reference ledger, not a live shop/inventory scene.
## The caller must perform the physical interaction; these operations never transport goods.


static func fresh() -> Dictionary:
	return {"schema_version": 1, "credits": 0, "registered": {}, "sold": {}, "upgrades": {}}


static func register_unloaded(catalog: HMCatalog, state: Dictionary, output: Dictionary, physically_on_pad: bool) -> bool:
	if not physically_on_pad or String(output.get("location", "")) != "receiving_pad":
		return false
	if bool(output.get("protected", false)) or bool(output.get("registered", false)):
		return false
	if not HMSchema.CONDITIONS.has(String(output.get("condition", ""))):
		return false
	var allocation: Dictionary = output.get("allocation", {})
	if not HMSchema.allocation_valid(allocation):
		return false
	var id: String = String(output.get("id", ""))
	var parent_id: String = String(output.get("source_part_id", ""))
	var source_part: Dictionary = catalog.by_part_id(parent_id)
	if id.is_empty() or source_part.is_empty() or bool(source_part.get("protected", false)) or state["registered"].has(id):
		return false
	# Reject forged IDs, family allocations or origins. In later milestones the
	# committed parent->children transaction becomes authoritative in the save.
	var authentic: bool = false
	for expected: Variant in HMRules.make_outputs(catalog, parent_id, String(output.get("condition", ""))):
		if id == String(expected.get("id", "")) and HMSchema.same_allocation(allocation, expected.get("allocation", {})) and String(output.get("site_id", "")) == String(expected.get("site_id", "")):
			authentic = true
			break
	if not authentic:
		return false
	# Persist the immutable accepted snapshot instead of a mutable scene object reference.
	state["registered"][id] = output.duplicate(true)
	state["registered"][id]["registered"] = true
	return true


static func quote(catalog: HMCatalog, lot: Dictionary) -> Dictionary:
	# Estimate only; credits cannot change until pad unload, registration and sale.
	# Material rates and damaged percentage are provisional catalog fixtures.
	var allocation: Dictionary = lot.get("allocation", {})
	var base: int = 0
	for family: Variant in allocation:
		var material: Dictionary = catalog.by_id("materials", "families", String(family))
		base += int(allocation[family]) * int(material.get("credits_per_unit", 0))
	var condition: String = String(lot.get("condition", ""))
	var total: int = sale_price(catalog, lot)
	return {"base": base, "condition": condition, "estimated_credits": total,
		"damaged_discount": base - total, "priced": HMSchema.CONDITIONS.has(condition),
		"provisional": true}


static func sale_price(catalog: HMCatalog, lot: Dictionary) -> int:
	var total: int = 0
	var allocation: Dictionary = lot.get("allocation", {})
	for family: Variant in allocation:
		var match_row: Dictionary = catalog.by_id("materials", "families", String(family))
		total += int(allocation[family]) * int(match_row.get("credits_per_unit", 0))
	if String(lot.get("condition", "")) == "damaged":
		total = int(floor(float(total * int(catalog.tables["materials"].get("damaged_value_multiplier_percent", 60))) / 100.0))
	# Optional one-time player-sorted preparation. No repaired condition,
	# allocation changes, or new item families; premium is provisional.
	if bool(lot.get("processed", false)) and total > 0:
		total += maxi(1, int(floor(float(total) / 10.0)))
	return total


static func sell_registered(catalog: HMCatalog, state: Dictionary, lot_id: String) -> bool:
	if not state["registered"].has(lot_id) or state["sold"].has(lot_id):
		return false
	var lot: Dictionary = state["registered"][lot_id]
	if bool(lot.get("protected", false)):
		return false
	var payout: int = sale_price(catalog, lot)
	if payout < 0:
		return false
	state["sold"][lot_id] = payout
	state["credits"] = int(state["credits"]) + payout
	return true


static func purchase(catalog: HMCatalog, state: Dictionary, upgrade_id: String, owned_tools: Array) -> bool:
	var upgrade: Dictionary = catalog.by_id("upgrades", "upgrades", upgrade_id)
	if upgrade.is_empty() or upgrade.has("new_capabilities") or upgrade.has("tier"):
		return false
	var applies: String = String(upgrade.get("applies_to", ""))
	if applies != "player" and applies != "cart" and not owned_tools.has(applies):
		return false
	var levels: Array = upgrade.get("levels", [])
	var current: int = int(state["upgrades"].get(upgrade_id, 0))
	if current < 0 or current >= levels.size():
		return false
	var price: int = int(levels[current].get("price", -1))
	if price <= 0 or int(state["credits"]) < price:
		return false
	state["credits"] = int(state["credits"]) - price
	state["upgrades"][upgrade_id] = current + 1
	return true


static func recovered_units(state: Dictionary, family: String = "") -> int:
	var units: int = 0
	for raw: Variant in state["registered"].values():
		var lot: Dictionary = raw
		var a: Dictionary = lot.get("allocation", {})
		if family.is_empty():
			for k: Variant in a:
				units += int(a[k])
		else:
			units += int(a.get(family, 0))
	return units
