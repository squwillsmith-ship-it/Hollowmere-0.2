extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("STEP28: " + message)
func run() -> void:
	var level: HMBrinewickBlockout = (load("res://scenes/brinewick_blockout.tscn") as PackedScene).instantiate() as HMBrinewickBlockout
	root.add_child(level)
	var sites: HMBrinewickSites = level.district_sites
	check(sites.stage_counts.get(28,0) == 2, "Workshop and separate discoverable tool cache installed")
	var row: Node3D = sites.installation_nodes.get("discovery/workshop_hammer")
	check(row != null, "Hammer location represented in spatial world")
	if row != null:
		var pickup: HMToolPickup = row.get_node_or_null("ManualDiscovery_claw_hammer") as HMToolPickup
		check(pickup != null, "Physical ray-interactable hammer pickup")
		var cat := HMCatalog.new()
		check(cat.load_all() and pickup != null and pickup.is_valid_discovery(cat),
			"Hammer still requires legitimate world discovery")
		var world: Dictionary = HMSaveState.fresh(cat)
		check(not world["progress"]["tools"].has("claw_hammer"), "No automatic tool unlock")
	var svc := HMYardService.new()
	var bench: Vector3 = level.site_nodes["brinewick/site_11"].position + Vector3(1.8,0.5,-0.6)
	svc.add_manual_sorting_bench(bench)
	svc.add_manual_sorting_bench(bench)
	check(svc.additional_benches.size() == 1, "Manual sorting bench is optional and unique")
	check(svc.bench_center == HMYardService.BENCH_CENTER, "Original manual bench retained")
	check(sites.installation_nodes.has("craft/tomas_workshop"), "Workshop physical geometry exists")
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_STEP28_TEST_OK")
		quit(0)
	else:
		quit(1)
