extends SceneTree
## G2 part-ownership and real catalogue-based manual work/release validation.
## Not a human manual GUI traversal or owner final art acceptance.
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func demand(ok: bool,label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("G2_HERO: "+label)
func _run() -> void:
	var cat := HMCatalog.new()
	demand(cat.load_all(),"Authoritative salvage catalogue loads")
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	for tick: int in range(5):
		await physics_frame
	var district := stage.district_sites
	var hero: HMHeroBuildingArtG2 = district.get_node_or_null("G2PartOwnedHeroArchitecture") as HMHeroBuildingArtG2
	demand(hero != null,"G2 hero renderer installed on live settlement")
	if hero == null:
		quit(1)
		return
	demand(hero.cottage_owners == 0,"Standalone G2 cottage GLBs supersede doubled procedural joinery")
	demand(hero.warehouse_owners >= 40,"G2 braces and roof ribs on original and expanded warehouses")
	demand(hero.batched_meshes == hero.warehouse_owners,"Existing warehouse bracing stays individually part-owned")
	var lifecycle := HMPartLifecycle.new()
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	demand(lifecycle.installed.size() == 345,"G2 did not introduce or lose dismantling part IDs")
	for expected_id: String in ["fixture/house/front_infill","fixture/house/beam",
		"village/04/old_warehouse/back_frame","village/04/old_warehouse/roof_left"]:
		demand(lifecycle.installed.has(expected_id),"Hero detail has saved target "+expected_id)
		if not lifecycle.installed.has(expected_id):
			continue
		var part: HMInspectTarget = lifecycle.installed[expected_id]
		var count: int = 0
		for child: Node in part.get_children():
			if child.has_meta("g2_owner_part_id"):
				count += 1
				demand(String(child.get_meta("g2_owner_part_id")) == expected_id,
					"Owned G2 visual is child of authoritative part "+expected_id)
		demand(count == 1,"One production G2 visual for "+expected_id)
	var state: Dictionary = HMSaveState.fresh(cat)
	for tool: String in ["claw_hammer","crowbar","pickaxe","saw"]:
		var found: Dictionary = HMTransactions.apply(cat,state,{"transaction_id":"g2/tool/"+tool,
			"op":"find_tool","tool_id":tool,"source":"world_discovery","user_initiated":true})
		demand(bool(found.get("ok",false)),"Player finds existing tool "+tool)
		if bool(found.get("ok",false)):
			state = found["state"]
	# Use the exact existing cottage dependency order, performing real manually
	# initiated work/release events, not a synthetic visibility-only snapshot.
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	for row: Variant in manifest["parts"]:
		var part_id: String = String(row["id"])
		var authored: Dictionary = cat.by_part_id(part_id)
		var worked: Dictionary = HMTransactions.apply(cat,state,{
			"transaction_id":"g2/work/"+part_id,"op":"partial_work","user_initiated":true,
			"part_id":part_id,"cycles":int(authored["work_units"])})
		demand(bool(worked.get("ok",false)),"Existing player work transaction "+part_id)
		if not bool(worked.get("ok",false)):
			continue
		state=worked["state"]
		var released: Dictionary = HMTransactions.apply(cat,state,{
			"transaction_id":"g2/release/"+part_id,"op":"release","user_initiated":true,
			"part_id":part_id,"access_aids":authored.get("requires_access_aids",[]),
			"spawn_origin":[-7.5,0.7,-4.0]})
		demand(bool(released.get("ok",false)),"Existing player part release "+part_id)
		if bool(released.get("ok",false)):
			state=released["state"]
	lifecycle.reconcile(state)
	for id: String in ["fixture/house/front_infill","fixture/house/beam"]:
		demand(not (lifecycle.installed[id] as HMInspectTarget).visible,
			"Removed original part hides G2 child detail "+id)
	demand(HMSaveState.validate(cat,state).is_empty(),"G2 mesh additions preserve save schema")
	var store := HMSaveStore.new()
	demand(store.open_slot(cat,"g2_hero_architecture"),"G2 save slot opens")
	store.state = state.duplicate(true)
	demand(store.save_now(),"Real removal state written to disk")
	var cold := HMSaveStore.new()
	demand(cold.open_slot(cat,"g2_hero_architecture"),"Cold reload of G2 changed building state")
	lifecycle.reconcile(cold.snapshot())
	demand(not (lifecycle.installed["fixture/house/front_infill"] as HMInspectTarget).visible,
		"Cold load retains disappearance of front owned visual")
	for suffix: String in ["",".previous",".writing"]:
		var save_path: String = ProjectSettings.globalize_path(
			HMSaveStore.SAVE_DIRECTORY.path_join("g2_hero_architecture.hmsave.json"+suffix))
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
	stage.queue_free()
	await process_frame
	if errors.is_empty():
		print("HOLLOWMERE_G2_HERO_OWNERSHIP_OK")
		quit(0)
	else:
		quit(1)
