extends SceneTree
## Exercises the real center-screen HMInspector on the live production main
## scene, instead of approximating every evidence/ending with generic rays.
## It DOES NOT claim a real human-operated end-to-end four-act playthrough.
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _aim(app: Node, target: StaticBody3D) -> bool:
	var player: HMFirstPerson = app.player
	var inspector: HMInspector = app.inspector
	for dir: Vector3 in [Vector3(0,0,2.35), Vector3(0,0,-2.35),
		Vector3(2.35,0,0), Vector3(-2.35,0,0)]:
		# Actor is at a valid *candidate* stance; independent capsule/ground
		# checks in test_phase_e_f_path.gd constrain physical standing space.
		player.global_position = target.global_position + dir - Vector3(0,0.59,0)
		player.velocity = Vector3.ZERO
		player.view_camera.look_at(target.global_position, Vector3.UP)
		var ray: Dictionary = inspector._first_hit()
		if ray.get("collider") == target and player.view_camera.global_position.distance_to(
			ray["position"]) <= inspector.interaction_reach:
			return true
	return false

func _assert(condition: bool,label: String) -> void:
	if not condition:
		errors.append(label)
		push_error("FIRST PERSON ROUTE QA: " + label)

func _run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	for i: int in range(4):
		await physics_frame
	app.show_stage()
	var village: HMBrinewickBlockout = app.stage as HMBrinewickBlockout
	_assert(village != null,"Real Brinewick production scene loads")
	var art: Node3D = village.get_node_or_null("BrinewickFacetedGroundArt") as Node3D
	_assert(art != null,"Same world has coast and route art")
	for flag: String in village.campaign_sites.clue_nodes:
		var clue: HMStoryClue = village.campaign_sites.clue_nodes[flag]
		_assert(_aim(app,clue),"Player camera can target story evidence " + flag)
	for action: String in village.campaign_sites.work_nodes:
		var target: HMFinaleWorkTarget = village.campaign_sites.work_nodes[action]
		_assert(_aim(app,target),"Player camera can target finale mechanism " + action)
	for ending: String in village.campaign_sites.finale_nodes:
		var choice: HMFinaleChoice = village.campaign_sites.finale_nodes[ending]
		_assert(_aim(app,choice),"Player camera can aim at final choice " + ending)
	app.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_FIRST_PERSON_TARGET_QA_OK")
		quit(0)
	else:
		quit(1)
