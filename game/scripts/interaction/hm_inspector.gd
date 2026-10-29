class_name HMInspector
extends Node3D
## Center-screen physical ray. First collider wins; no through-wall inspection.
signal inspection_changed(info: Dictionary)

@export_range(0.5, 8.0, 0.1) var scan_distance: float = 4.8
@export_range(0.5, 5.0, 0.1) var interaction_reach: float = 3.3

var actor: HMFirstPerson
var camera: Camera3D
var catalog: HMCatalog
var active_ids: Array = []
var owned_tools: Array = ["hands"]
var selected_tool_id: String = "hands"
var work_records: Dictionary = {}
var output_records: Dictionary = {}
var access_aids: Array = []
var enabled: bool = false
var current_act: int = 1
var story_flags: Array = []
var finale_actions: Array = []
var current: Dictionary = {}


func setup(player: HMFirstPerson) -> bool:
	actor = player
	camera = player.view_camera
	catalog = HMCatalog.new()
	if not catalog.load_all():
		push_error("Inspection catalog load failed: " + str(catalog.errors))
		return false
	# Engineering fixtures only; Step 8+ will supply the actual game state.
	for part: Variant in catalog.entries("sample_parts", "parts"):
		active_ids.append(String(part.get("id", "")))
	return true


func set_enabled_inspection(is_enabled: bool) -> void:
	enabled = is_enabled
	if not enabled:
		_publish({})


func _physics_process(_delta: float) -> void:
	if enabled:
		_publish(probe())


func _first_hit() -> Dictionary:
	if not enabled or actor == null or camera == null or catalog == null:
		return {}
	if not actor.movement_enabled or not camera.is_inside_tree():
		return {}
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * scan_distance, 1)
	query.exclude = [actor.get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func aimed_tool_pickup() -> HMToolPickup:
	var hit: Dictionary = _first_hit()
	if hit.is_empty():
		return null
	var candidate: HMToolPickup = hit.get("collider") as HMToolPickup
	if candidate == null or not candidate.is_valid_discovery(catalog):
		return null
	if camera.global_position.distance_to(hit["position"]) > interaction_reach:
		return null
	return candidate


func aimed_story_clue() -> HMStoryClue:
	var hit: Dictionary = _first_hit()
	if hit.is_empty():
		return null
	var clue: HMStoryClue = hit.get("collider") as HMStoryClue
	if clue == null or not clue.is_valid(catalog):
		return null
	if camera.global_position.distance_to(hit["position"]) > interaction_reach:
		return null
	return clue


func aimed_finale_work_target() -> HMFinaleWorkTarget:
	var hit: Dictionary = _first_hit()
	if hit.is_empty():
		return null
	var target: HMFinaleWorkTarget = hit.get("collider") as HMFinaleWorkTarget
	if target == null or not target.is_valid():
		return null
	if camera.global_position.distance_to(hit["position"]) > interaction_reach:
		return null
	return target


func aimed_finale_choice() -> HMFinaleChoice:
	var hit: Dictionary = _first_hit()
	if hit.is_empty():
		return null
	var candidate: HMFinaleChoice = hit.get("collider") as HMFinaleChoice
	if candidate == null or not candidate.is_valid():
		return null
	if camera.global_position.distance_to(hit["position"]) > interaction_reach:
		return null
	return candidate


func probe() -> Dictionary:
	var hit: Dictionary = _first_hit()
	if hit.is_empty():
		return {}
	var distance: float = camera.global_position.distance_to(hit["position"])
	var mechanism: HMFinaleWorkTarget = hit.get("collider") as HMFinaleWorkTarget
	if mechanism != null and mechanism.is_valid():
		var tool: String = String(HMCampaignRules.TASKS[mechanism.action_id]["tool"])
		return {"kind": "finale_mechanism", "part_id": "",
			"title": mechanism.display_name,
			"status": "Already operated" if finale_actions.has(mechanism.action_id) else
				("Press E with " + tool.replace("_", " ") + " equipped to operate"),
			"details": "Manual protected finale mechanism, never ordinary saleable salvage.",
			"reachable": distance <= interaction_reach, "distance": distance}
	var choice: HMFinaleChoice = hit.get("collider") as HMFinaleChoice
	if choice != null and choice.is_valid():
		return {"kind": "finale", "part_id": "", "title": choice.display_name,
			"status": "Press E to review your irreversible ending choice" if current_act == 4 else "Complete the company requisitions first",
			"details": "Requires completed Act IV contract and surviving village evidence. No choice is automatic.",
			"reachable": distance <= interaction_reach, "distance": distance}
	var clue: HMStoryClue = hit.get("collider") as HMStoryClue
	if clue != null and clue.is_valid(catalog):
		var already: bool = story_flags.has(clue.flag_id)
		var gated: bool = current_act < clue.minimum_act
		return {"kind": "story_clue", "part_id": "", "title": clue.display_name,
			"status": "Press E to reread evidence" if already else (
				"Evidence emerges in a later act" if gated else "Press E to examine"),
			"details": (clue.evidence_text if already else "One-time physical evidence; press E to examine. No automatic story trigger."),
			"reachable": distance <= interaction_reach, "distance": distance}
	var loose_tool: HMToolPickup = hit.get("collider") as HMToolPickup
	if loose_tool != null and loose_tool.is_valid_discovery(catalog):
		var available: bool = distance <= interaction_reach and current_act >= loose_tool.minimum_act and not owned_tools.has(loose_tool.tool_id)
		var definition: Dictionary = catalog.by_id("tools", "tools", loose_tool.tool_id)
		var display: String = String(definition.get("name", loose_tool.tool_id))
		return {"kind": "tool", "part_id": "", "title": display,
			"status": ("Press E to discover " + display) if available else
				("Already discovered" if owned_tools.has(loose_tool.tool_id) else ("Not available until Act " + str(loose_tool.minimum_act) if current_act < loose_tool.minimum_act else "Out of reach — move closer")),
			"details": "Tool discovery is manual; use 1–5 to select discovered tools.",
			"reachable": distance <= interaction_reach, "distance": distance}
	var released: HMRecoveredOutput = hit.get("collider") as HMRecoveredOutput
	if released != null:
		var record: Dictionary = output_records.get(released.output_id, {})
		if record.is_empty():
			return {}
		var units: Array[String] = []
		for family: Variant in record.get("allocation", {}):
			units.append(String(family) + " x" + str(record["allocation"][family]))
		units.sort()
		var quote: Dictionary = HMLedger.quote(catalog, record)
		var pack_units: int = HMSalvageLogistics.units(record)
		return {"kind": "loose_output", "title": "Released salvage",
			"output_id": released.output_id,
			"status": "C lift / place: " + str(pack_units) + " pack units; "
				+ String(record.get("condition", "intact"))
				+ " estimated " + str(quote["estimated_credits"]) + " credits",
			"details": "Lot: " + released.output_id + "\n" + ", ".join(units)
				+ "\n" + ("Manually sorted at bench" if bool(record.get("processed", false))
					else "Optional H: manually sort when staged at workbench")
				+ "\nValue uses provisional prices; no credit is awarded on inspection.",
			"part_id": "", "reachable": distance <= interaction_reach,
			"distance": distance}
	var target: HMInspectTarget = hit.get("collider") as HMInspectTarget
	if target == null or not target.is_catalogued(catalog):
		return {}
	var info: Dictionary = HMInspectionRules.describe(
		catalog, target.part_id, active_ids, owned_tools, access_aids,
		distance <= interaction_reach, selected_tool_id, work_records)
	info["distance"] = distance
	var pos: Vector3 = hit["position"]
	info["hit_position"] = [pos.x, maxf(0.28, pos.y - 0.64), pos.z]
	return info


func _publish(info: Dictionary) -> void:
	if info != current:
		current = info
		inspection_changed.emit(current)
