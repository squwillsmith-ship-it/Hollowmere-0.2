class_name HMSalvageLogistics
extends RefCounted
## Capacity is a working engineering fixture, never a balance decision.
const BASE_PACK_UNITS: int = 6

static func units(lot: Dictionary) -> int:
	var sum: int = 0
	for family: Variant in lot.get("allocation", {}):
		sum += int(lot["allocation"][family])
	return sum

static func capacity(economy: Dictionary) -> int:
	var level: int = int(economy.get("upgrades", {}).get("pack_straps", 0))
	var bonus: int = 20 if level == 1 else (40 if level >= 2 else 0)
	return BASE_PACK_UNITS + int(floor(float(BASE_PACK_UNITS * bonus) / 100.0))

static func held_id(world: Dictionary) -> String:
	for key: Variant in world.get("outputs", {}):
		if String(world["outputs"][key].get("location", "")) == "carried":
			return String(key)
	return ""

static func can_lift(world: Dictionary, economy: Dictionary, lot_id: String) -> bool:
	var outputs: Dictionary = world.get("outputs", {})
	if not outputs.has(lot_id) or not held_id(world).is_empty():
		return false
	var lot: Dictionary = outputs[lot_id]
	if not ["world_released", "staged"].has(String(lot.get("location", ""))):
		return false
	return units(lot) <= capacity(economy)

static func nearby(player: Vector3, point: Vector3, limit: float = 2.6) -> bool:
	return player.distance_to(point) <= limit
