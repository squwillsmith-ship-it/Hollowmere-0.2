extends SceneTree
## G1/G2 source and real physics assertions. No aesthetic approval implied.
var problems: Array[String] = []

func expect(ok: bool, label: String) -> void:
	if not ok:
		problems.append(label)
		push_error("HARBOUR HERO BENCHMARK: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	await physics_frame
	var terrain: StaticBody3D = stage.get_node_or_null("Terraces/LowerTerrace") as StaticBody3D
	expect(terrain != null, "Existing LowerTerrace name preserved")
	if terrain != null:
		expect(bool(terrain.get_meta("authored_continuous_coast",false)), "Continuous coast replaces old box")
		var ground_shape: CollisionShape3D = terrain.get_node_or_null("CollisionShape3D") as CollisionShape3D
		expect(ground_shape != null and ground_shape.shape is ConcavePolygonShape3D,
			"Faceted coast geometry physically matches concave collision")
	var road_root: Node3D = stage.get_node_or_null("RoadsAndPaths") as Node3D
	for route: String in ["LandingApproach","WarehouseCottageHaulTrack","WarehouseDoorSpur"]:
		var segment: StaticBody3D = road_root.get_node_or_null(route) as StaticBody3D
		expect(segment != null,route+" physically installed")
		if segment != null:
			expect(bool(segment.get_meta("authored_haul_route",false)),route+" uses authored route geometry")
			var collision: CollisionShape3D = segment.get_node_or_null("CollisionShape3D") as CollisionShape3D
			expect(collision != null and collision.shape is ConcavePolygonShape3D,
				route+" collision must agree with visible route")
	# Actual downward physics rays along all three road centrelines: not
	# enough for a visual route to have a collider somewhere in its parent.
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	var supported_samples: int = 0
	for route: Array[Vector2] in [HMHarbourBenchmarkCoast.QUAY_TO_YARD,
			HMHarbourBenchmarkCoast.YARD_TO_COTTAGE,
			HMHarbourBenchmarkCoast.WAREHOUSE_SPUR]:
		for i: int in range(route.size()-1):
			var from: Vector2 = route[i]
			var to: Vector2 = route[i+1]
			var segments: int = maxi(2,ceili((to-from).length()/1.5))
			for n: int in range(segments+1):
				var point: Vector2 = from.lerp(to,float(n)/float(segments))
				var hit: Dictionary = space.intersect_ray(
					PhysicsRayQueryParameters3D.create(
						Vector3(point.x,15.0,point.y),
						Vector3(point.x,-2.0,point.y),1))
				expect(not hit.is_empty(),"Continuous physical ground at "+str(point))
				if not hit.is_empty():
					supported_samples += 1
	expect(supported_samples >= 35,"Entire linked harbour-warehouse-cottage route is physically supported")
	expect(absf(HMHarbourBenchmarkCoast.ground_height(-35,10)-1.1) < 0.65,
		"Dock ramp meets sculpted landing shelf")
	expect(absf(HMHarbourBenchmarkCoast.ground_height(18,30)-1.965) < 0.20,
		"Warehouse on stable lower terrace")
	expect(HMHarbourBenchmarkCoast.shore_at(-20) != HMHarbourBenchmarkCoast.shore_at(20),
		"Tidal edge not ruler straight")
	var cat := HMCatalog.new()
	expect(cat.load_all(),"Catalogue retained")
	var lifecycle := HMPartLifecycle.new()
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	expect(lifecycle.installed.size() == 345,"No new or lost registered salvage targets")
	var ids: Array[String] = []
	for id: Variant in lifecycle.installed.keys():
		ids.append(String(id))
	var warehouse_count: int = 0
	for id: String in ids:
		if id.begins_with("village/04/old_warehouse/"):
			warehouse_count += 1
	expect(warehouse_count == 42,"Old warehouse 42 original removable assemblies preserved")
	var warehouse: Node3D = stage.district_sites.installation_nodes["district/old_warehouse"]
	var restored_back: int = 0
	var roof_courses: int = 0
	for child: Node in warehouse.get_children():
		if child is HMInspectTarget:
			var part := child as HMInspectTarget
			if part.name.begins_with("BackFrame_Section"):
				restored_back += 1
				expect(part.get_node_or_null("RepairedBackBoardCollision") is CollisionShape3D,
					"Warehouse boards physically belong to removable frame " + part.name)
			if part.name.begins_with("Roof"):
				roof_courses += 1
				expect(absf(absf(part.rotation_degrees.z)-27.0) < 0.2,
					"Roof slate and colliders retain a steep, credible pitch")
				expect(part.get_node_or_null("RafterUnderSalvagedRoofCourse") != null,
					"Rafter belongs to individual roof release ID")
	expect(restored_back == 7 and roof_courses == 16,
		"Warehouse rear framing and roof set complete")
	var cottage: Node3D = stage.district_sites.cottage
	var cottage_ids: int = 0
	for child: Node in cottage.get_children():
		if child is HMInspectTarget:
			cottage_ids += 1
	expect(cottage_ids == 9,"Cottage nine original stable salvage assemblies")
	var original_state: Dictionary = HMSaveState.fresh(cat)
	expect(HMSaveState.validate(cat,original_state).is_empty(),"Saved game schema unchanged")
	lifecycle.reconcile(original_state)
	var target_id: String = "village/04/old_warehouse/back_frame"
	var target: HMInspectTarget = lifecycle.installed.get(target_id) as HMInspectTarget
	expect(target != null, "Canonical warehouse frame target in real scene")
	if target != null:
		expect(target.visible and target.collision_layer != 0,
			"Intact building shows boarded frame and real collision")
		var partly_stripped: Dictionary = original_state.duplicate(true)
		partly_stripped["world"]["parts"][target_id]["phase"] = "released"
		lifecycle.reconcile(partly_stripped)
		expect(not target.visible and target.collision_layer == 0,
			"Releasing saved salvage ID hides both repaired planks and frame collision")
		lifecycle.reconcile(original_state)
		expect(target.visible and target.collision_layer != 0,
			"Reloaded intact state restores same assembly without material duplication")
	expect(original_state["world"]["outputs"].is_empty(),
		"No passive salvage, goods or credits introduced by architecture")
	stage.queue_free()
	await process_frame
	# Physical player-operated component release inside this exact hero area:
	# independent of synthetic staging and compatible with original inputs.
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.force_brinewick_for_tests = true
	root.add_child(app)
	await process_frame
	app.show_stage()
	var actor: HMFirstPerson = app.player
	var cloth_owner: HMInspectTarget = app.lifecycle.installed.get("fixture/house/curtain") as HMInspectTarget
	expect(cloth_owner != null,"Actual hero cottage door cloth is a player target")
	if cloth_owner != null:
		var original_cloth: MeshInstance3D = cloth_owner.get_node_or_null("DoorCloth") as MeshInstance3D
		expect(original_cloth != null,"Old physical curtain collider and stable ID retained")
		if original_cloth != null:
			var point: Vector3 = original_cloth.global_position
			actor.global_position = point + Vector3(0,0.12,2.10)
			actor.rotation.y = 0.0
			actor.velocity = Vector3.ZERO
			var eye: Vector3 = actor.view_camera.global_position
			actor.head.rotation.x = -atan2(eye.y-point.y,eye.z-point.z)
			for sample: int in range(7):
				await physics_frame
			var contact: Dictionary = app.inspector.probe()
			var physical_id: String = String(contact.get("part_id",""))
			expect(physical_id == "fixture/house/curtain",
				"First-person first-hit ray selects hero cottage textile")
			if physical_id == "fixture/house/curtain":
				expect(bool(app.perform_work_once().get("ok",false)),
					"Manual hands tool applies actual work at cottage")
				expect(bool(app.perform_release_once().get("ok",false)),
					"Manual player release removes cottage component")
				expect(not cloth_owner.visible and cloth_owner.collision_layer == 0,
					"Player removal eliminates whole authored cloth visual and its collider")
				expect(app.lifecycle.recovered.has("fixture/house/curtain/out/cloth"),
					"Original salvage lot produced only after manual action")
	app.show_menu()
	app.queue_free()
	await process_frame
	if problems.is_empty():
		print("HOLLOWMERE_HARBOUR_HERO_BENCHMARK_OK")
		quit(0)
	else:
		quit(1)
