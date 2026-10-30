class_name HMBrinewickBlockout
extends Node3D
## Step25 terrain now hosts the shared playable Brinewick salvage systems.
## Terrain and site positions remain provisional, not final level design.
## Exact functions are established but all proposed coordinates are provisional.
const LAYOUT: String = "res://data/v1/brinewick_step25_blockout.json"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
var site_nodes: Dictionary = {}
var player: HMFirstPerson
var underground_audio: HMUndergroundAudio
var campaign_sites: HMCampaignSites
var underground_sites: HMUndergroundSites
var district_sites: HMBrinewickSites
var spawn_exploration_player: bool = true

func _ready() -> void:
	build_world()
	# An independent exploratory scene, not a replacement for the working
	# engineering yard's saves or gameplay integration.
	if spawn_exploration_player and not OS.get_cmdline_args().has("--script"):
		player = PLAYER_SCENE.instantiate() as HMFirstPerson
		player.position = Vector3(-17, 3.05, 11)
		add_child(player)
		player.enable_movement(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		player.enable_movement(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func build_world() -> void:
	if has_node("Terraces"):
		return
	var env := WorldEnvironment.new()
	env.name = "CoastalEnvironment"
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = HMCoastalPresentation.OVERCAST_SKY
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = HMCoastalPresentation.AMBIENCE
	sky.ambient_light_energy = 0.33
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Overcast sea mist: sparse enough to keep working distance and road
	# silhouettes readable; occult horror remains primarily auditory.
	sky.fog_enabled = true
	sky.fog_density = HMCoastalPresentation.NORMAL_FOG
	sky.fog_light_color = HMCoastalPresentation.COASTAL_HAZE

	env.environment = sky
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastCoastalSun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = HMCoastalPresentation.LIGHT
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	add_child(sun)
	var water := MeshInstance3D.new()
	water.name = "NonCollidableSeaStudy"
	var plane := PlaneMesh.new()
	plane.size = Vector2(210, 170)
	water.mesh = plane
	water.position = Vector3(-75, -0.45, 0)
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color("526a69")
	sea_mat.roughness = 0.92
	water.material_override = sea_mat
	add_child(water)
	# Real mesh-based coastal wash and eroded stones, visually authored outside
	# all manual receiving and walking routes without new physics blockers.
	var foreshore := HMCoastalForeshoreArt.new()
	foreshore.name = "BrinewickCoastalForeshore"
	add_child(foreshore)
	foreshore.build()

	var terraces := Node3D.new()
	terraces.name = "Terraces"
	add_child(terraces)
	terraces.add_child(HMHarbourTerrainG1.create_lower_terrace())
	# High district is split at its road cutting to prevent a solid cliff
	# blocking the gradual cart route.
	_box(terraces,"UpperNorth",Vector3(54.5,9,38),Vector3(92.75,3.5,-27),Color("706e5b"))
	_box(terraces,"UpperSouth",Vector3(54.5,9,38),Vector3(92.75,3.5,27),Color("716e5b"))
	# Join the upper plateau to the lower village on both sides of the\n\t# existing cart-road cutting, using walkable, independent rock colliders.\n\tterraces.add_child(HMHarbourTerrainG1.create_bluff("UpperNorthTransition",-46.0,-8.0))\n\tterraces.add_child(HMHarbourTerrainG1.create_bluff("UpperSouthTransition",8.0,46.0))\n\t# A narrow cut through the north headland provides a real, collision-open
	# chapel undercroft approach. The retained three masses occupy exactly the
	# original overall headland envelope outside that authored corridor.
	_box(terraces,"HeadlandNorth",Vector3(6.8,14,40),Vector3(122.4,6,-27),Color("686b5c"))
	_box(terraces,"HeadlandNorthEast",Vector3(39.6,14,40),Vector3(151.2,6,-27),Color("686b5c"))
	_box(terraces,"HeadlandNorthRear",Vector3(5.6,14,27),Vector3(128.6,6,-33.5),Color("686b5c"))
	# Retain the existing headland mass behind the cart passage, instead
	# of leaving the road bridge buried inside a 14-metre solid plateau.
	# The opened seaward margin is the road cutting, not a new site.
	_box(terraces,"HeadlandSouth",Vector3(52,14,29.5),
		Vector3(145,6,32.25),Color("6e705e"))

	var roads := Node3D.new()
	roads.name = "RoadsAndPaths"
	add_child(roads)
	_box(roads,"HarbourCartRoad",Vector3(62,0.26,9),Vector3(3,2.09,0),Color("948a76"))
	_box(roads,"LowerToUpperRamp",Vector3(35.6,0.55,10),Vector3(52.5,5.05,0),Color("998a72"),
		Vector3(0,0,rad_to_deg(atan2(6.0,35.0))))
	_box(roads,"UpperCartRoad",Vector3(54,0.4,10),Vector3(95,7.99,0),Color("928672"))
	# The old straight upper/headland cart ramp crossed the occupied chapel
	# undercroft at normal player eye height. Route its existing road link
	# across the seaward side of the cut, with two grounded turning aprons.
	# The undercroft stays at its canonical story coordinates and retains
	# true roof and wall collision; no view-only collision exclusions.
	_box(roads,"UpperRampLowerTurn",Vector3(10.0,0.34,15.0),
		Vector3(108.2,8.12,5.5),Color("948672"))
	_box(roads,"UpperToHeadlandRamp",Vector3(33.5,0.55,10),
		Vector3(124,10.52,11.0),Color("948672"),
		Vector3(0,0,rad_to_deg(atan2(5.0,33.0))))
	_box(roads,"UpperRampHeadlandTurn",Vector3(10.0,0.34,15.0),
		Vector3(139.7,13.0,5.5),Color("948672"))
	_box(roads,"HeadlandTrack",Vector3(48,0.4,10),Vector3(149,12.99,0),Color("938875"))
	_box(roads,"QuayWalk",Vector3(6,0.34,77),Vector3(-39,1.18,0),Color("777567"))
	_box(roads,"LandingApproach",Vector3(25,0.3,12),Vector3(-24,2.12,13),Color("8a7f6a"))
	# Persistent boatyard/quay platforms are never mistaken for reclaimable buildings.
	_box(roads,"PermanentQuayPad",Vector3(11,1.0,14),Vector3(-34,0.65,10),Color("858276"))
	# G1 continuous walking grade meets the existing quay, warehouse and cottage.\n\t# This route does not create an interactive or salvageable component.\n\tvar harbour_route := Node3D.new()\n\tharbour_route.name = "HarbourG1Route"\n\tadd_child(harbour_route)\n\tharbour_route.add_child(HMHarbourTerrainG1.create_haul_path())\n\tharbour_route.add_child(HMHarbourTerrainG1.create_quay_revetment())\n\t# Remaining historical scene-art skins serve the untouched districts.
	# layout, roads, story targets or material registrations.
	var ground_art := HMCoastalGroundArt.new()
	ground_art.name = "BrinewickFacetedGroundArt"
	add_child(ground_art)
	ground_art.build(terraces,roads)
	var ground_edges := HMPhaseCGroundDetail.new()
	ground_edges.name = "PhaseCGroundStratification"
	add_child(ground_edges)
	ground_edges.build(terraces, roads)
	# Batch03 road wear is child-owned by the existing sloped colliders;
	# the 21 provisional site markers and their route heights do not move.
	var road_wear := HMCoastalRoadWear.new()
	road_wear.name = "GroundedCartRoadWear"
	add_child(road_wear)
	road_wear.build(roads)


	var site_root := Node3D.new()
	site_root.name = "SiteMarkers"
	add_child(site_root)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	assert(data is Dictionary)
	site_nodes.clear()
	for entry: Variant in data["sites"]:
		var id: String = String(entry["id"])
		assert(not site_nodes.has(id))
		var marker := Node3D.new()
		marker.name = "Site_" + id.get_file()
		marker.set_meta("site_id",id)
		marker.set_meta("site_name",String(entry["name"]))
		marker.set_meta("status","PROPOSED_VOLUME_ONLY")
		var v: Array = entry["position"]
		marker.position = Vector3(float(v[0]),float(v[1]),float(v[2]))
		site_root.add_child(marker)
		site_nodes[id] = marker
		var zone: String = String(entry["zone"])
		# Low shapes distinguish landmarks, never claim a confirmed envelope.
		var size := Vector3(5,3,5)
		if ["brinewick/site_13","brinewick/site_18"].has(id):
			size = Vector3(8,4,8)
		elif zone == "quay":
			size = Vector3(3,1.3,3)
		var hue := Color("887d68") if zone == "lower" else Color("8e8878")
		if zone == "headland":
			hue = Color("7a7568")
		_box(marker,"NonSalvageVolume",size,Vector3(0,size.y*0.5+0.15,0),hue)


	# The remaining two unpopulated architectural markers become physical,
	# traversable inn and mine-office shells rather than giant solid cubes.
	# Their story/salvage decompositions remain future authored work.
	var landmarks := HMVillageLandmarkArt.new()
	landmarks.name = "InnAndMineOfficeArchitecture"
	add_child(landmarks)
	landmarks.build(site_nodes)

	# New built-world pieces remain separate from permanent terrain and old yard.
	district_sites = HMBrinewickSites.new()
	district_sites.name = "ProductionDistrictStudies"
	add_child(district_sites)
	district_sites.build(site_nodes)
	# Phase C coast props stay outside player-operated service pads.
	var harbour_dressing := HMPhaseCHarbourDressing.new()
	harbour_dressing.name = "PhaseCHarbourHistory"
	add_child(harbour_dressing)
	harbour_dressing.build(site_nodes)
	# The ordinary building and yard systems remain the only salvage catalogue.
	# Protected Phase E locations share the same physical Brinewick stage.
	underground_sites = HMUndergroundSites.new()
	underground_sites.name = "ProtectedUnderground"
	add_child(underground_sites)
	underground_sites.build(site_nodes)
	var dressing := HMUndergroundDressing.new()
	dressing.name = "FacetedUndergroundDetail"
	underground_sites.add_child(dressing)
	dressing.decorate(underground_sites)
	var protected_detail := HMPhaseCUndergroundDetail.new()
	protected_detail.name = "PhaseCProtectedStonesAndTimber"
	underground_sites.add_child(protected_detail)
	protected_detail.build(underground_sites)
	var village_plants := HMPhaseCVillageDressing.new()
	village_plants.name = "PhaseCSettlementVegetation"
	add_child(village_plants)
	village_plants.build(site_nodes)
	var catalogue := HMCatalog.new()
	assert(catalogue.load_all())
	campaign_sites = HMCampaignSites.new()
	campaign_sites.name = "PhysicalVillageEvidence"
	add_child(campaign_sites)
	campaign_sites.build(site_nodes, catalogue)
	underground_audio = HMUndergroundAudio.new()
	underground_audio.name = "SpatialUndergroundAudio"
	add_child(underground_audio)
	underground_audio.build(underground_sites, site_nodes)


static func _box(parent: Node3D, name: String, size: Vector3, at: Vector3,
		colour: Color, rotation: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.name = name
	solid.position = at
	solid.rotation_degrees = rotation
	solid.collision_layer = 1
	solid.collision_mask = 2
	parent.add_child(solid)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	mesh.material_override = material
	solid.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var cuboid := BoxShape3D.new()
	cuboid.size = size
	shape.shape = cuboid
	solid.add_child(shape)
	return solid
