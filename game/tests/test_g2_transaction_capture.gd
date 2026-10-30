extends SceneTree
## G2 REAL transaction-driven screenshot states. The work/release events are
## valid user-initiated HMTransactions, not direct state edits. This is still a
## scripted operator rehearsal, not proof of a human keyboard/mouse playthrough.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func require(ok: bool,reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error("G2_REAL_CAPTURE: "+reason)

func _apply(catalog: HMCatalog,state: Dictionary,id: String,op: String,
		cycles: int = 0) -> Dictionary:
	var event: Dictionary = {
		"transaction_id":"g2/capture/"+op+"/"+id,
		"op":op,"user_initiated":true,"part_id":id}
	if op == "partial_work":
		event["cycles"]=cycles
	else:
		event["access_aids"]=catalog.by_part_id(id).get("requires_access_aids",[])
		event["spawn_origin"]=[-6.5,0.8,-2.5]
	return HMTransactions.apply(catalog,state,event)

func _order_ids(catalog: HMCatalog,prefix: String) -> Array[String]:
	var ids: Array[String] = []
	for entry: Variant in catalog.tables["sample_parts"]["parts"]:
		var id: String = String(entry["id"])
		if id.begins_with(prefix):
			ids.append(id)
	ids.sort_custom(func(a: String,b: String) -> bool:
		var score_a: int = 0 if a.contains("/roof_") else (4 if a.contains("/back_frame") else 2)
		var score_b: int = 0 if b.contains("/roof_") else (4 if b.contains("/back_frame") else 2)
		return score_a < score_b if score_a != score_b else a < b)
	return ids

func _shot(folder: String,stage: HMBrinewickBlockout,camera: Camera3D,
		label: String,removed: int,total: int) -> void:
	for frame: int in range(19):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture: Image = root.get_texture().get_image()
	require(capture != null and not capture.is_empty() and capture.get_width() >= 640,
		"Actual rendered framebuffer present for "+label)
	if capture == null or capture.is_empty():
		return
	var path: String = folder.path_join("g2-transaction-"+label+".png")
	require(capture.save_png(path) == OK,"Real transaction frame saved "+label)
	print("G2_TRANSACTION_FRAME "+label+" removed="+str(removed)+"/"+str(total))

func _run() -> void:
	var folder: String = OS.get_environment("HOLLOWMERE_G2_TRANSACTION_DIR")
	if folder.is_empty():
		require(false,"HOLLOWMERE_G2_TRANSACTION_DIR missing")
		quit(1)
		return
	var cat := HMCatalog.new()
	require(cat.load_all(),"Catalogue load")
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player = false
	root.add_child(stage)
	var life := HMPartLifecycle.new()
	stage.add_child(life)
	life.bind_stage(stage)
	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 210.0
	camera.current = true
	stage.add_child(camera)
	var pristine: Dictionary = HMSaveState.fresh(cat)
	for building: String in ["cottage","warehouse"]:
		var state: Dictionary = pristine.duplicate(true)
		for tool: String in ["claw_hammer","crowbar","pickaxe","saw"]:
			var found: Dictionary = HMTransactions.apply(cat,state,{
				"transaction_id":"g2/capture/"+building+"/find/"+tool,
				"op":"find_tool","tool_id":tool,"source":"world_discovery",
				"user_initiated":true})
			require(bool(found.get("ok",false)),"Found existing tool "+tool)
			if bool(found.get("ok",false)):
				state=found["state"]
		var ids: Array[String] = []
		if building == "cottage":
			var manifest: Dictionary = HMBuildingPrefab.read_manifest(
				"res://data/v1/buildings/cottage_working_01.json")
			for row: Variant in manifest["parts"]:
				ids.append(String(row["id"]))
		else:
			ids = _order_ids(cat,"village/04/old_warehouse/")
		var required_count: int = 9 if building == "cottage" else 42
		require(ids.size() == required_count,"Canonical "+building+" parts all present")
		life.reconcile(state)
		var site: String = "brinewick/site_07" if building=="cottage" else "brinewick/site_04"
		var origin: Vector3 = stage.site_nodes[site].global_position
		camera.global_position = origin + (Vector3(7.4,5.8,12) if building=="cottage"
			else Vector3(13,9,18))
		camera.look_at(origin+(Vector3(0,1.7,0) if building=="cottage"
			else Vector3(0,2.8,0)),Vector3.UP)
		await _shot(folder,stage,camera,building+"-intact",0,ids.size())
		var removed: int = 0
		var half: bool = false
		var left: Array[String] = ids.duplicate()
		for pass_index: int in range(5):
			if left.is_empty():
				break
			var next: Array[String] = []
			for id: String in left:
				var part: Dictionary = cat.by_part_id(id)
				var worked: Dictionary = _apply(cat,state,id,"partial_work",int(part["work_units"]))
				if not bool(worked.get("ok",false)):
					next.append(id)
					continue
				state=worked["state"]
				var release: Dictionary = _apply(cat,state,id,"release")
				if not bool(release.get("ok",false)):
					next.append(id)
					continue
				state=release["state"]
				removed += 1
				life.reconcile(state)
				if not half and removed >= ceili(float(ids.size())*0.5):
					await _shot(folder,stage,camera,building+"-half",removed,ids.size())
					half=true
			left=next
			if next.size() >= ids.size() and removed == 0:
				break
		require(half,"Actual ordered manual transaction sequence reaches half "+building)
		require(removed >= ceili(float(ids.size())*0.75),"Actual player-initiated teardown reaches near-empty "+building)
		life.reconcile(state)
		await _shot(folder,stage,camera,building+"-heavy",removed,ids.size())
		require(HMSaveState.validate(cat,state).is_empty(),"Real "+building+" transaction state valid")
		var slot: String = "g2_capture_"+building
		var saved := HMSaveStore.new()
		require(saved.open_slot(cat,slot),"Open "+building+" capture save")
		saved.state=state.duplicate(true)
		require(saved.save_now(),"Save "+building+" real removal state")
		var cold := HMSaveStore.new()
		require(cold.open_slot(cat,slot),"Reload "+building+" changed building")
		life.reconcile(cold.snapshot())
		for id: String in ids:
			var detached: bool = String(state["world"]["parts"][id]["phase"])=="released"
			if detached:
				require(not (life.installed[id] as HMInspectTarget).visible,
					"No floating detail after reload "+id)
		for suffix: String in ["",".previous",".writing"]:
			var save_path: String = ProjectSettings.globalize_path(
				HMSaveStore.SAVE_DIRECTORY.path_join(slot+".hmsave.json"+suffix))
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOLLOWMERE_G2_REAL_TRANSACTIONS_RENDER_OK")
		quit(0)
	else:
		quit(1)
