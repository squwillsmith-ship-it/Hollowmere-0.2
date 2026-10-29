class_name HMYardService
extends RefCounted
## Every move is a user gesture, guarded by first-hit physics at pickup or
## by real player proximity to the fixed engineering yard. No passive income.
const PAD_CENTER: Vector3 = Vector3(8.0, 0.96, 8.0)
const COUNTER_CENTER: Vector3 = Vector3(9.1, 0.96, 8.0)
const BENCH_CENTER: Vector3 = Vector3(6.5, 0.96, 8.0)
const YARD_RADIUS: float = 2.8
var belt: HMToolbelt
var session: HMWorkSession
var last_error: String = ""
var pad_center: Vector3 = PAD_CENTER
var counter_center: Vector3 = COUNTER_CENTER
var bench_center: Vector3 = BENCH_CENTER
var additional_benches: Array[Vector3] = []

func add_manual_sorting_bench(at: Vector3) -> void:
	if not additional_benches.has(at):
		additional_benches.append(at)


func configure_stations(positions: Dictionary) -> bool:
	if not positions.has("pad") or not positions.has("counter") or not positions.has("bench"):
		return false
	for key: String in ["pad", "counter", "bench"]:
		if not (positions[key] is Vector3):
			return false
	pad_center = positions["pad"]
	counter_center = positions["counter"]
	bench_center = positions["bench"]
	return true


func initialize(source_belt: HMToolbelt, source_session: HMWorkSession) -> void:
	belt = source_belt
	session = source_session

func _commit(op: String, oid: String, extra: Dictionary = {}) -> Dictionary:
	var event := {"op": op, "output_id": oid, "user_initiated": true,
		"transaction_id": "manual:" + op + ":" + oid + ":" + str(int(belt.state["revision"]) + 1)}
	event.merge(extra)
	if session.store != null:
		if not session.store.commit(event):
			return _fail(session.store.last_error)
		belt.state = session.store.snapshot()
	else:
		var result: Dictionary = HMTransactions.apply(session.catalog, belt.state, event)
		if not bool(result.get("ok", false)):
			return _fail(String(result.get("reason", "Transaction rejected")))
		belt.state = result["state"]
	last_error = ""
	return {"ok": true, "operation": op, "output_id": oid}

func _fail(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "reason": reason}

func holding_id() -> String:
	return HMSalvageLogistics.held_id(belt.state["world"])

func lift(info: Dictionary) -> Dictionary:
	if not bool(info.get("reachable", false)) or String(info.get("kind", "")) != "loose_output":
		return _fail("Aim at a reachable physical salvage lot")
	var id: String = String(info.get("output_id", ""))
	if not HMSalvageLogistics.can_lift(belt.state["world"], belt.state["economy"], id):
		return _fail("Pack occupied or lot too large for pack")
	return _commit("pickup", id, {"carrier": "carried"})

func stage(position: Vector3) -> Dictionary:
	var oid: String = holding_id()
	if oid.is_empty():
		return _fail("Nothing being carried")
	return _commit("place", oid, {"position":[position.x, maxf(0.22, position.y), position.z]})

func unload(player_position: Vector3) -> Dictionary:
	if not HMSalvageLogistics.nearby(player_position, pad_center, YARD_RADIUS):
		return _fail("Carry the lot physically to the receiving pad")
	var oid: String = holding_id()
	if oid.is_empty():
		return _fail("Carry a lot onto the receiving pad first")
	return _commit("unload", oid, {"receiving_pad_confirmed": true,
		"position": [pad_center.x - 0.45, 0.3, pad_center.z - 0.5]})

func register_lot(player_position: Vector3) -> Dictionary:
	if not HMSalvageLogistics.nearby(player_position, pad_center, YARD_RADIUS):
		return _fail("Register salvage at the receiving pad")
	var ids: Array = belt.state["world"]["outputs"].keys()
	ids.sort()
	for key: Variant in ids:
		if String(belt.state["world"]["outputs"][key].get("location", "")) == "receiving_pad":
			return _commit("register", String(key))
	return _fail("No unloaded lot awaiting registration")

func sell_lot(player_position: Vector3) -> Dictionary:
	if not HMSalvageLogistics.nearby(player_position, counter_center, YARD_RADIUS):
		return _fail("Sell registered salvage at the supply/account counter")
	var ids: Array = belt.state["world"]["outputs"].keys()
	ids.sort()
	for key: Variant in ids:
		if String(belt.state["world"]["outputs"][key].get("location", "")) == "registered":
			return _commit("sell", String(key))
	return _fail("No registered ordinary lot awaiting sale")

func buy(player_position: Vector3, upgrade_id: String) -> Dictionary:
	if not HMSalvageLogistics.nearby(player_position, counter_center, YARD_RADIUS):
		return _fail("Purchase upgrades at the physical counter")
	var row: Dictionary = session.catalog.by_id("upgrades", "upgrades", upgrade_id)
	if row.is_empty():
		return _fail("Unknown upgrade")
	# One deliberate press per tier; never buys a tool capability.
	return _commit("purchase", upgrade_id, {"upgrade_id": upgrade_id})

func process_lot(info: Dictionary, player_position: Vector3) -> Dictionary:
	var usable: Array[Vector3] = [bench_center]
	usable.append_array(additional_benches)
	var selected: Array[Vector3] = []
	for station: Vector3 in usable:
		if HMSalvageLogistics.nearby(player_position, station, 2.6):
			selected.append(station)
	if selected.is_empty():
		return _fail("Use a physical manual sorting bench")
	if not bool(info.get("reachable", false)) or String(info.get("kind", "")) != "loose_output":
		return _fail("Aim at an actual staged lot beside the workbench")
	var oid: String = String(info.get("output_id", ""))
	var lot: Dictionary = belt.state["world"]["outputs"].get(oid, {})
	if String(lot.get("location", "")) != "staged" or bool(lot.get("processed", false)):
		return _fail("Only an unprocessed manually staged lot can be sorted")
	var pos: Array = lot.get("position", [])
	if pos.size() != 3:
		return _fail("Stage the lot beside the workbench")
	var lot_position := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var same_station: bool = false
	for station: Vector3 in selected:
		if HMSalvageLogistics.nearby(lot_position, station, 2.6):
			same_station = true
			break
	if not same_station:
		return _fail("Player and staged lot must share the same workbench")
	return _commit("process", oid, {"bench_confirmed": true})
