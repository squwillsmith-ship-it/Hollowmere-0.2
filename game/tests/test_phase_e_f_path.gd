extends SceneTree
## Independent real physics checks: no renderer-only fake spaces or floating props.
var issues: Array[String] = []

func demand(ok: bool, reason: String) -> void:
	if not ok:
		issues.append(reason)
		push_error("PHASE E/F PATH: " + reason)

func _initialize() -> void:
	call_deferred("run")

func _hit(village: HMBrinewickBlockout, a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, 1)
	return village.get_world_3d().direct_space_state.intersect_ray(query)

func _stand_clear(village: HMBrinewickBlockout, position: Vector3,
		excluded: RID) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.70
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform = Transform3D(Basis(),position)
	query.exclude = [excluded]
	return village.get_world_3d().direct_space_state.intersect_shape(query,16).is_empty()

func run() -> void:
	var village := HMBrinewickBlockout.new()
	village.spawn_exploration_player = false
	root.add_child(village)
	for tick: int in range(5):
		await physics_frame
	# Check actual collision beneath safe accessible sections, not just visible
	# box meshes. Coordinates are deliberately provisional engineering authoring.
	var walking: Dictionary = {
		"well_square": Vector3(79,8.3,-20),
		"well_gallery": Vector3(79,4.3,-64),
		"mine_approach": Vector3(170.5,13.5,-24),
		"mine_gallery": Vector3(206,6.4,-24),
		"undercroft": Vector3(128.5,10.25,0.5)
	}
	for label: String in walking:
		var spot: Vector3 = walking[label]
		var hit: Dictionary = _hit(village, spot + Vector3(0,1.7,0), spot - Vector3(0,1.1,0))
		demand(not hit.is_empty(), "Actual ground collision beneath " + label)
	# Sample the actual descending ramps rather than accepting a disconnected
	# floor at each endpoint. A ray must land near the authored walking grade.
	var route_grades: Dictionary = {
		"well_high": Vector3(79.0,8.3,-45.7),
		"well_mid": Vector3(79.0,6.35,-50.0),
		"well_low": Vector3(79.0,4.14,-57.6),
		"undercroft_threshold": Vector3(128.5,13.08,-16.2),
		"undercroft_entry": Vector3(128.5,13.12,-13.2),
		"undercroft_incline": Vector3(128.5,11.9,-9.0),
		"mine_high": Vector3(176.6,12.95,-24),
		"mine_low": Vector3(188.4,6.9,-24)
	}
	for label: String in route_grades:
		var foot: Vector3 = route_grades[label]
		var ray: Dictionary = _hit(village,foot + Vector3(0,1.30,0),
			foot - Vector3(0,1.30,0))
		demand(not ray.is_empty(), "A real collider supports route section " + label)
		if not ray.is_empty():
			demand(absf(Vector3(ray["position"]).y-foot.y) < 0.85,
				"Walking grade is continuous at " + label)
	# The final options must be physical, separately targeted and remain
	# non-salvage throughout the session.
	for key: String in ["bell_delivery", "repair_escape"]:
		var choice: HMFinaleChoice = village.campaign_sites.finale_nodes[key]
		var at: Vector3 = choice.global_position
		var hit: Dictionary = _hit(village, at + Vector3(0, 0.1, 2.25), at)
		demand(hit.get("collider") == choice,
			"Physical first-hit access to protected " + key + " decision")
	# Each essential page must be visible from at least one plausible standing
	# direction, rather than embedded behind an opaque building proxy.
	for flag: String in village.campaign_sites.clue_nodes:
		var clue: HMStoryClue = village.campaign_sites.clue_nodes[flag]
		var at: Vector3 = clue.global_position
		var reachable: bool = false
		for direction: Vector3 in [Vector3(0,0,2.6), Vector3(0,0,-2.6),
			Vector3(2.6,0,0), Vector3(-2.6,0,0)]:
			var hit: Dictionary = _hit(village, at + direction + Vector3(0,0.05,0), at)
			if hit.get("collider") == clue and _stand_clear(village,
					at+direction+Vector3(0,0.72,0), clue.get_rid()):
				reachable = true
				break
		demand(reachable, "At least one collision-clear first-hit ray to campaign clue " + flag)
	for id: String in HMCampaignRules.TASKS:
		var target: HMFinaleWorkTarget = village.campaign_sites.work_nodes.get(id)
		demand(target != null, "Each physical final mechanism is installed: " + id)
		if target != null:
			var at: Vector3 = target.global_position
			var visible: bool = false
			for offset: Vector3 in [Vector3(0,0,2.0),Vector3(0,0,-2.0),
				Vector3(-2.0,0,0),Vector3(2.0,0,0)]:
				var ray: Dictionary = _hit(village,at+offset+Vector3(0,0.03,0),at)
				if ray.get("collider") == target and _stand_clear(village,
						at+offset+Vector3(0,0.72,0), target.get_rid()):
					visible = true
					break
			demand(visible, "Mechanism has a first-hit physical line of sight: " + id)
	village.free()
	await process_frame
	if issues.is_empty():
		print("HOLLOWMERE_PHASE_E_F_PATH_OK")
		quit(0)
	else:
		quit(1)
