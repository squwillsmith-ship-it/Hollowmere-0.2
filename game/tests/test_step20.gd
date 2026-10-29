extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("STEP20 FAIL: " + label)
func run_tests() -> void:
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog loads")
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	var prefab: Node3D = HMBuildingPrefab.build(manifest, cat)
	check(prefab != null, "Cottage prefab compiled")
	root.add_child(prefab)
	var stage := Node3D.new()
	root.add_child(stage)
	prefab.reparent(stage)
	var lifecycle := HMPartLifecycle.new()
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	check(lifecycle.installed.size() >= 9, "All wall infill and threshold assemblies independently removable")
	var state: Dictionary = HMSaveState.fresh(cat)
	lifecycle.reconcile(state)
	check(HMSaveState.validate(cat, state).is_empty(), "Cottage uses existing save/schema IDs")
	var all_collisions: bool = true
	for id: Variant in lifecycle.installed:
		var body: HMInspectTarget = lifecycle.installed[id]
		var proxies: int = 0
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				proxies += 1
		if proxies == 0:
			all_collisions = false
	check(all_collisions, "Each part has own collision proxies")
	# Reconcile a legitimate manual-work/release transaction against a physical
	# cottage part, never remotely crediting or auto-collecting recovered lots.
	var id: String = "fixture/house/curtain"
	var worked: Dictionary = HMTransactions.apply(cat, state, {"transaction_id":"20/manual/work", "op":"partial_work", "user_initiated":true,"part_id":id,"cycles":1})
	check(bool(worked.get("ok", false)), "Manual cottage work transaction")
	if bool(worked.get("ok", false)):
		state = worked["state"]
		var release: Dictionary = HMTransactions.apply(cat, state, {"transaction_id":"20/manual/release", "op":"release", "user_initiated":true,"part_id":id})
		check(bool(release.get("ok", false)), "Physical cottage part release transaction")
		if bool(release.get("ok", false)):
			state = release["state"]
			lifecycle.reconcile(state)
			check(not lifecycle.installed[id].visible and lifecycle.recovered.size() > 0, "Released cottage part disappears and creates separate salvage")
			check(HMSaveState.validate(cat, state).is_empty(), "No forged material on release")
	stage.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_STEP20_TEST_OK")
		quit(0)
	else:
		quit(1)
