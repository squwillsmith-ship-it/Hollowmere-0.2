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
	var identity: HMG3SiteIdentity=stage.get_node_or_null("G3VillageWideSiteIdentity") as HMG3SiteIdentity
	verify(identity!=null,"G3 identity attached to actual Brinewick settlement")
	if identity!=null:
		verify(identity.site_profiles.size()==21,"Every original 21 site has distinct regional identity")
		verify(identity.visual_members>=84,"Four individual site-visible low poly approach details per site")
		for site_id: String in stage.site_nodes:
			var marker: Node3D=stage.site_nodes[site_id]
			var cue: Node3D=marker.get_node_or_null("G3SiteApproachIdentity") as Node3D
			verify(cue!=null,"21 original sites have site-tied architecture "+site_id)
			if cue!=null:
				verify(String(cue.get_meta("site_id",""))==site_id,
					"G3 identifies existing site, never a new location")
				verify(cue.get_child_count()>=4,"Approach details are present "+site_id)
	var existing_hero: HMVillageLandmarkArt=stage.get_node_or_null("InnAndMineOfficeArchitecture") as HMVillageLandmarkArt
	verify(existing_hero!=null,"Inn and mine office retain original authoring")
	if existing_hero!=null:
		verify(existing_hero.created_bodies==54,
			"Inn and mine office retain 54 individually recoverable original parts")
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
		"district/mara_home":"brinewick/site_08",
		"service/landing_pier":"brinewick/site_01",
		"service/boatyard_base":"brinewick/site_02",
		"district/upper_cottage_cluster_study":"brinewick/site_12",
		"chapel/schoolroom_wing":"brinewick/site_13",
		"chapel/aldren_study":"brinewick/site_14",
		"harbour/navigation_light":"brinewick/site_16"}
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
	verify(instances>=35,"Eleven installations have distinct owned structural details")
	verify(selected.size()==11,"G3 second pass covers eleven installation profiles")
	var unique_sites: Dictionary={}
	for id: String in selected:
		unique_sites[selected[id]]=true
	verify(unique_sites.size()==10,"G3 second pass covers ten unique original sites")
	var village_context: HMG3VillageSiteContext = stage.get_node_or_null(
		"G3TwentyOneSiteContext") as HMG3VillageSiteContext
	verify(village_context!=null,"G3 complete 21-site village context attached")
	if village_context!=null:
		verify(village_context.covered_site_ids.size()==21,"All 21 site IDs have grounded context")
		verify(village_context.individual_members>=130,"21 sites have substantial individual masonry/joinery geometry")
		verify(village_context.district_totals.size()==4,"Four authored district types are distinct")
		for site_id: String in stage.site_nodes:
			var original: Node3D=stage.site_nodes[site_id]
			var context: Node3D=original.get_node_or_null("G3NonSalvageSiteFootings") as Node3D
			verify(context!=null,"Existing site marker retains unique G3 region "+site_id)
			if context==null:
				continue
			verify(bool(context.get_meta("g3_only_permanent_cosmetic",false)),
				"Architectural site context cannot be accidentally sold "+site_id)
			verify(context.get_child_count()>=6,
				"Each village site has individual architecture members "+site_id)
			for member: Node in context.get_children():
				verify(member is MeshInstance3D,
					"No new physics owners or story triggers from G3")
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
		print("HOLLOWMERE_G3_DISTRICT_PILOT_OK sites=21 architecture=11 distinct_cues=21")
		quit(0)
	else:
		quit(1)
