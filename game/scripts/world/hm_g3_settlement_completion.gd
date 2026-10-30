class_name HMG3SettlementCompletion
extends Node3D
## G3 production link pass. World architecture remains in its original
## existing instalment / narrative systems. Only unbuilt inn and mine-office
## receive new protected architectural volumes; no catalogue IDs are created.
const STONE: Color = Color("817d6f")
const LIME: Color = Color("b6aa94")
const OAK: Color = Color("715a44")
const DARK: Color = Color("554838")
const SLATE: Color = Color("585f5e")
var site_cues: Dictionary = {}
var completed_buildings: Dictionary = {}
var visual_members: int = 0
var new_collision_bodies: int = 0

func build(sites: Dictionary) -> void:
	if not site_cues.is_empty():
		return
	# Every original 21-site marker receives a site-specific approach
	# treatment. These are not 21 new salvage targets or story triggers.
	for site_id: String in sites:
		var anchor: Node3D = sites[site_id] as Node3D
		if anchor == null:
			continue
		var ordinal: int = int(site_id.get_file().trim_prefix("site_"))
		var category: String = _district_for(ordinal)
		var cue := Node3D.new()
		cue.name = "G3ApproachArchitecture"
		cue.set_meta("site_id",site_id)
		cue.set_meta("g3_district",category)
		cue.set_meta("visual_only",true)
		anchor.add_child(cue)
		# Low staggered lane-facing edging instead of repeated vertical
		# box landmarks; position off the central walking/carry corridor.
		var lane_tint: Color = STONE if category == "civic" else (DARK if category == "harbour" else OAK)
		var near_distance: float = 5.8 if category == "harbour" else (5.4 if category == "upland" else 6.2)
		for side: float in [-1.0,1.0]:
			var length: float = 1.05 + float((ordinal+int(side)+4)%4)*.18
			_visual(cue,"G3LaneCurb",Vector3(length,.13,.22),
				Vector3(side*near_distance,.09,2.1),lane_tint)
			if category == "industrial":
				_visual(cue,"G3WeatheredTie",Vector3(.19,.23,.9),
					Vector3(side*near_distance,.20,2.1),DARK)
			elif category == "harbour":
				_visual(cue,"G3MooringEndgrain",Vector3(.29,.25,.32),
					Vector3(side*near_distance,.20,2.1),OAK)
		site_cues[site_id]=category
	# Existing G3 installed architecture already includes warehouse, cottage,
	# chapel, study, well and bell. Only these two had no authored buildings.
	_inn(sites["brinewick/site_10"] as Node3D)
	_mine_office(sites["brinewick/site_19"] as Node3D)
	set_meta("g3_21_original_sites_covered",site_cues.size())
	set_meta("g3_non_savagable_protected_massing",true)

func _district_for(index: int) -> String:
	if index <= 8 or index == 20 or index == 21:
		return "harbour"
	if index <= 12 or index == 15:
		return "civic"
	if index == 18 or index == 19 or index == 17:
		return "industrial"
	return "upland"

func _inn(anchor: Node3D) -> void:
	_suppress_old_proxy(anchor)
	var hall:=Node3D.new()
	hall.name="G3TimberInnAndGatheringHall"
	hall.set_meta("g3_site_id","brinewick/site_10")
	hall.set_meta("protected_story",true)
	anchor.add_child(hall)
	_piece(hall,"GroundStoneFoot",Vector3(9.3,.32,7.25),Vector3(0,.14,0),STONE)
	# Frame and lime infill are separated into multiple actual sections.
	for x: float in [-4.27,4.27]:
		for z: float in [-2.45,0.0,2.45]:
			_piece(hall,"SideLimeBay",Vector3(.22,2.82,2.36),
				Vector3(x,1.80,z),LIME)
		for z: float in [-3.2,-1.6,0.0,1.6,3.2]:
			_piece(hall,"OakSideStud",Vector3(.23,3.12,.25),
				Vector3(x,1.80,z),DARK)
	for z: float in [-3.47,3.47]:
		for x: float in [-3.15,3.15]:
			_piece(hall,"InnEndWall",Vector3(2.52,2.97,.23),
				Vector3(x,1.81,z),LIME)
		for x: float in [-4.0,-2.22,2.22,4.0]:
			_piece(hall,"InnEndPost",Vector3(.21,3.22,.27),
				Vector3(x,1.86,z),OAK)
		_piece(hall,"InnEndLintel",Vector3(9.0,.22,.25),
			Vector3(0,3.33,z),DARK)
	# Actual walk-in front doorway through the 1.90m unblocked gap.
	for x: float in [-2.15,2.15]:
		_piece(hall,"DoorJamb",Vector3(.16,2.70,.18),
			Vector3(x,1.47,3.58),OAK)
	_piece(hall,"ShortDoorHead",Vector3(4.35,.20,.2),Vector3(0,2.79,3.57),DARK)
	# Roof sheets physically slant inward; old eave and ridge gaps closed.
	for side: float in [-1.0,1.0]:
		var roof:=_piece(hall,"InnSlateRoof",Vector3(5.05,.23,7.6),
			Vector3(side*2.18,4.14,0),SLATE)
		roof.rotation_degrees.z=-side*26.0
		for z: float in [-2.8,-1.4,0,1.4,2.8]:
			var ra:=_visual(roof,"SaltWornRafter",Vector3(.12,.12,.65),
				Vector3(0,.14,z),DARK)
			ra.rotation_degrees.z=0.0
	_visual(hall,"InnSlimSlateRidge",Vector3(.33,.15,7.65),Vector3(0,5.32,0),SLATE)
	for x: float in [-3.6,-2.8,2.8,3.6]:
		_visual(hall,"InnWindowShutter",Vector3(.30,.78,.075),
			Vector3(x,2.13,3.62),OAK)
	completed_buildings["brinewick/site_10"]=hall

func _mine_office(anchor: Node3D) -> void:
	_suppress_old_proxy(anchor)
	var office:=Node3D.new()
	office.name="G3MineOfficeAndEquipmentShelter"
	office.set_meta("g3_site_id","brinewick/site_19")
	office.set_meta("protected_story",true)
	anchor.add_child(office)
	_piece(office,"StoneSill",Vector3(6.95,.30,5.25),
		Vector3(0,.14,0),STONE)
	for side: float in [-1.0,1.0]:
		_piece(office,"OfficeGritStoneWall",Vector3(.30,2.72,5.02),
			Vector3(side*3.23,1.54,0),STONE)
	for z: float in [-2.37,2.37]:
		for x: float in [-2.45,2.45]:
			_piece(office,"MineOfficeBoardWall",Vector3(1.38,2.7,.23),
				Vector3(x,1.54,z),OAK)
	for x: float in [-3.13,-1.78,1.78,3.13]:
		for z: float in [-2.40,2.40]:
			_piece(office,"MineOfficeFramePost",Vector3(.18,2.92,.22),
				Vector3(x,1.56,z),DARK)
	# The office keeps an unobstructed central work/record entrance.
	for side: float in [-1.0,1.0]:
		var panel:=_piece(office,"MineOfficeSlatePitch",Vector3(3.75,.22,5.65),
			Vector3(side*1.60,3.20,0),SLATE)
		panel.rotation_degrees.z=-side*24.0
	_visual(office,"MineOfficeStoneCap",Vector3(.28,.14,5.65),
		Vector3(0,4.02,0),STONE)
	for x: float in [-2.85,2.85]:
		_visual(office,"OfficeRecordAperture",Vector3(.52,.58,.07),
			Vector3(x,1.95,2.53),LIME)
	completed_buildings["brinewick/site_19"]=office

func _suppress_old_proxy(site: Node3D) -> void:
	var old: StaticBody3D=site.get_node_or_null("NonSalvageVolume") as StaticBody3D
	if old==null:
		return
	old.visible=false
	old.collision_layer=0
	var collision: CollisionShape3D=old.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision!=null:
		collision.set_deferred("disabled",true)

func _piece(root: Node3D,label: String,dims: Vector3,at: Vector3,colour: Color) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=label
	body.position=at
	body.collision_layer=1
	body.collision_mask=2
	body.set_meta("protected_story",true)
	body.set_meta("g3_scene_owner",true)
	root.add_child(body)
	_visual(body,"G3RealLowPolySurface",dims,Vector3.ZERO,colour)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=dims
	collider.shape=shape
	body.add_child(collider)
	new_collision_bodies+=1
	return body

func _visual(root: Node3D,label: String,dims: Vector3,at: Vector3,colour: Color) -> MeshInstance3D:
	var obj:=MeshInstance3D.new()
	obj.name=label
	obj.position=at
	var box:=BoxMesh.new()
	box.size=dims
	obj.mesh=box
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=colour
	mat.roughness=.95
	obj.material_override=mat
	obj.set_meta("g3_visual_only",true)
	root.add_child(obj)
	visual_members+=1
	return obj
