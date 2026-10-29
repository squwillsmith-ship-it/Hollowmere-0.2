class_name HMUpgradeEffects
extends RefCounted
## Apply existing capability-preserving upgrade definitions; fixture tune only.
static func bonus(catalog: HMCatalog, economy: Dictionary, upgrade_id: String) -> int:
	var data: Dictionary = catalog.by_id("upgrades", "upgrades", upgrade_id)
	if data.is_empty():
		return 0
	var level: int = int(economy.get("upgrades", {}).get(upgrade_id, 0))
	var tiers: Array = data.get("levels", [])
	if level < 1 or level > tiers.size():
		return 0
	return int(tiers[level - 1].get("bonus_percent", 0))

static func work_interval(catalog: HMCatalog, economy: Dictionary, selected_tool_id: String, base: float = 0.42) -> float:
	var upgrade: String = ""
	match selected_tool_id:
		"claw_hammer": upgrade = "hammer_grip"
		"crowbar": upgrade = "crowbar_handle"
		"saw": upgrade = "saw_teeth"
	return maxf(0.18, base * 100.0 / float(100 + bonus(catalog, economy, upgrade))) if not upgrade.is_empty() else base

static func loaded_speed_multiplier(catalog: HMCatalog, economy: Dictionary) -> float:
	# Upgrade improves loaded comfort, never makes loaded movement faster than walking.
	return minf(1.0, 0.78 + float(bonus(catalog, economy, "walking_shoes")) / 100.0)
