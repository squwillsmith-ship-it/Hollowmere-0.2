class_name HMG4ProtectedStoryVisuals
extends Node3D
## G4 audio-first protected environment art. Every visual is a CHILD of an
## EXISTING story-zone structure. No entity representation, fog apparition,
## extra colliders, direct clue, loot, new audio events or passage blocking.
const SHALE: Color=Color("555951")
const OAK: Color=Color("65523f")
const IRON: Color=Color("474742")
const LIMESTONE: Color=Color("827b6d")
var zones: Dictionary={}
var owners_dressed: int=0
var pieces: int=0

func build(underground: HMUndergroundSites) -> void:
	if owners_dressed>0:
		return
	for child: Node in underground.get_children():
		if not (child is Node3D):
			continue
		var group: Node3D=child as Node3D
		var kind: String=String(group.name)
		if not [
			"WellAndListeningGallery",
			"MineApproachOfficeAndSealedGallery",
			"UndercroftBellAndContainment",
			"ProtectedTidalMechanismAndEscape"].has(kind):
			continue
		var count: int=0
		for element: Node in group.get_children():
			var wall: StaticBody3D=element as StaticBody3D
			if wall==null or wall.has_node("G4StorySurfaceJoinery"):
				continue
			var dims: Vector3=_dimensions(wall)
			if dims==Vector3.ZERO:
				continue
			var kind_name: String=String(wall.name)
			if not _decorate(wall,dims,kind_name):
				continue
			count+=1
			owners_dressed+=1
		zones[kind]=count
	set_meta("g4_visual_only_story_protected",true)
	set_meta("g4_entity_never_visualized",true)

func _dimensions(wall: StaticBody3D) -> Vector3:
	for node: Node in wall.get_children():
		var collision: CollisionShape3D=node as CollisionShape3D
		if collision!=null and collision.shape is BoxShape3D:
			return (collision.shape as BoxShape3D).size
	return Vector3.ZERO

func _decorate(wall: StaticBody3D,dims: Vector3,name: String) -> bool:
	var profile: String=""
	if name.begins_with("WellStone_"):
		profile="well"
	elif name.begins_with("MinePost_") or name.begins_with("MineRoofTie_"):
		profile="mine"
	elif name=="PermanentInnerSeal":
		profile="seal"
	elif name.begins_with("UndercroftVaultSlope_"):
		profile="undercroft"
	elif name.begins_with("BellHouseWeatheredPier_"):
		profile="bell"
	elif name.begins_with("DrainageWingWall_"):
		profile="outlet"
	elif name.begins_with("OakMechanismStand"):
		profile="mechanism"
	elif name=="EscapeTimberLanding":
		profile="escape"
	else:
		return false
	var detail:=Node3D.new()
	detail.name="G4StorySurfaceJoinery"
	detail.set_meta("protected_story",true)
	detail.set_meta("g4_visual_only",true)
	detail.set_meta("g4_zone_profile",profile)
	wall.add_child(detail)
	var x: float=dims.x*.5
	var y: float=dims.y*.5
	var z: float=dims.z*.5
	match profile:
		"well":
			# Rough voussoir top courses. Keep open centre and existing rim
			# collision, so the well never becomes a walkable solid cover.
			_box(detail,"ChippedWellCap",Vector3(dims.x*.91,.065,dims.z*.88),
				Vector3(0,y+.035,0),LIMESTONE)
		"mine":
			# Small fitted iron/hardwood straps, entirely on old roof ties/posts.
			_box(detail,"WroughtMineJoin",Vector3(minf(.29,dims.x*.86),.105,
					minf(.29,dims.z*.84)),Vector3(0,y*.56,0),IRON)
			_box(detail,"OakBraceScarf",Vector3(minf(.23,dims.x*.76),.18,
					minf(.23,dims.z*.74)),Vector3(0,-y*.45,0),OAK)
		"seal":
			# A massive unbroken door: hairline stratification, not a slit.
			# Never imply the hidden presence can be directly viewed.
			for i: int in range(5):
				var yy: float=-y*.71+float(i)*dims.y*.35
				_box(detail,"WeatheredSealJoint_%d"%i,
					Vector3(.026,.035,dims.z*.91),
					Vector3(-x-.015,yy,0),SHALE)
		"undercroft":
			_box(detail,"BlindStoneEdge",
				Vector3(dims.x*.68,.055,dims.z*.78),
				Vector3(0,y+.018,0),LIMESTONE.darkened(.09))
		"bell":
			_box(detail,"BellHouseWornCapital",
				Vector3(dims.x*.88,.10,dims.z*.89),
				Vector3(0,y+.035,0),LIMESTONE)
		"outlet":
			_box(detail,"RainDarkenedStoneSeam",
				Vector3(.035,dims.y*.67,dims.z*.65),
				Vector3(x+.013,-y*.05,0),SHALE.darkened(.08))
		"mechanism":
			_box(detail,"OldClampIron",
				Vector3(dims.x*.97,.11,.035),
				Vector3(0,y*.46,z+.016),IRON)
		"escape":
			# Empty berth retains the story's ambiguity, no occupier or note.
			_box(detail,"SaltWornBoardEdge",
				Vector3(dims.x*.93,.055,.09),
				Vector3(0,y+.015,-z*.75),OAK.darkened(.07))
	return true

func _box(parent: Node3D,title: String,size: Vector3,at: Vector3,tint: Color) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	mesh.position=at
	var block:=BoxMesh.new()
	block.size=size
	mesh.mesh=block
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.roughness=.97
	mesh.material_override=mat
	mesh.set_meta("g4_noncolliding",true)
	parent.add_child(mesh)
	pieces+=1
