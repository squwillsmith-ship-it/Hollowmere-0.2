extends SceneTree
## G3 architecture pilot tests true world placement, owned visuals and total
## salvage/source conservation, not final human visual acceptance of all sites.
var problems: Array[String]=[]
func _initialize() -> void:
	call_deferred("_run")
func verify(ok: bool,note: String) -> void:
	if not ok:
		problems.append(note)
		push_error("G3_DISTRICT: "+note)
func _run() -> void:
	var stage := HMBrinewickBlockout.new()
	stage.spawn_exploration_player=false
	root.add_child(stage)
	for tick: int in range(4):
		await physics_frame
	verify(stage.site_nodes.size()==21,"All 21 original site markers remain placed")
	var district: HMBrinewickSites=stage.district_sites
	var pilot: HMVillageDistrictArtG3=district.get_node_or_null(
		"G3DistrictArchitecturalPilots") as HMVillageDistrictArtG3
	verify(pilot != null,"Integrated G3 district styling on canonical scene")
	if pilot == null:
		quit(1)
		return
	var selected: Dictionary={
		"harbour/office":"brinewick/site_03",
		"harbour/net_store":"brinewick/site_06",
		"craft/tomas_workshop":"brinewick/site_11",
		"chapel/ordinary_hall":"brinewick/site_13",
		"district/mara_home":"brinewick/site_08"}
	var instances: int=0
	for id: String in selected:
		verify(pilot.site_variant_ids.get(id,"")==selected[id],
			"G3 architecture retains original district/site ID "+id)
		verify(int(pilot.district_counts.get(id,0))>=2,"Distinct owned details present for "+id)
		var group: Node3D=district.installation_nodes.get(id,null) as Node3D
		if group==null:
			continue
		for body: Node in group.get_children():
			var owner: StaticBody3D=body as StaticBody3D
			if owner==null:
				continue
			var visual: Node=owner.get_node_or_null("G3OwnedDistrictDetail")
			if visual==null:
				continue
			verify(visual.get_child_count()>0,"District detail has actual 3D mesh members")
			if owner is HMInspectTarget:
				verify(String(visual.get_meta("g3_owner_part_id",""))==
					(owner as HMInspectTarget).part_id,
					"G3 components belong to original saved part, not a new ID")
			instances+=1
	verify(instances==pilot.attached_visuals,"All G3 visuals owned and counted")
	verify(instances>=12,"Five districts have coherent structural details")
	var life:=HMPartLifecycle.new()
	stage.add_child(life)
	life.bind_stage(stage)
	verify(life.installed.size()==345,"G3 has not changed 345 original manual salvage IDs")
	var cat:=HMCatalog.new()
	verify(cat.load_all(),"G3 preserves actual progression catalogue")
	var state: Dictionary=HMSaveState.fresh(cat)
	verify(HMSaveState.validate(cat,state).is_empty(),
		"G3 changes no 4-act narrative, binary salvage or save schema")
	stage.queue_free()
	await process_frame
	if problems.is_empty():
		print("HOLLOWMERE_G3_DISTRICT_PILOT_OK sites=21 architecture=5")
		quit(0)
	else:
		quit(1)
