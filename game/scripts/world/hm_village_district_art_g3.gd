class_name HMVillageDistrictArtG3
extends Node3D
## G3 district architecture pilot. All new facets belong to existing world
## structures and never create manual targets, loot, collision or automation.
## Pilot is NOT a 21-site visual acceptance claim.
const WOOD: Color = Color("6e5743")
const SALT: Color = Color("877665")
const STONE: Color = Color("78766b")
const IRON: Color = Color("4b4941")
var district_counts: Dictionary = {}
var site_variant_ids: Dictionary = {}
var attached_visuals: int = 0

func build(installations: Dictionary) -> void:
	if attached_visuals > 0:
		return
	var profiles: Dictionary = {
		"harbour/office":"harbour_ledger",
		"harbour/net_store":"net_drying",
		"craft/tomas_workshop":"working_framed",
		"chapel/ordinary_hall":"chapel_masonry",
		"district/mara_home":"upland_dwelling"
	}
	for id: String in profiles:
		if not installations.has(id):
			push_error("G3 district architecture pilot missing "+id)
			continue
		var group: Node3D = installations[id] as Node3D
		var completed: int = 0
		for item: Node in group.get_children():
			var owner: StaticBody3D = item as StaticBody3D
			if owner == null:
				continue
			var dimensions: Vector3 = _bounds(owner)
			if dimensions == Vector3.ZERO:
				continue
			var title: String = String(owner.name).to_lower()
			var profile: String = String(profiles[id])
			if not _is_matching(profile,title):
				continue
			if owner.has_node("G3OwnedDistrictDetail"):
				continue
			var detail := Node3D.new()
			detail.name = "G3OwnedDistrictDetail"
			detail.set_meta("g3_district_id",id)
			if owner is HMInspectTarget:
				detail.set_meta("g3_owner_part_id",(owner as HMInspectTarget).part_id)
			else:
				detail.set_meta("g3_static_architecture",true)
			owner.add_child(detail)
			_decorate(detail,dimensions,profile,title)
			if detail.get_child_count()==0:
				detail.queue_free()
				continue
			attached_visuals+=1
			completed+=1
		district_counts[id]=completed
		site_variant_ids[id]=String(group.get_meta("site_id",""))
	set_meta("g3_pilot_not_final_21_site_art",true)

func _is_matching(profile: String,title: String) -> bool:
	match profile:
		"harbour_ledger":
			return title.contains("ledgerroomfront") or title.contains("upperweatherboard")
		"net_drying":
			return title.contains("netdryingframe") or title.contains("frontrail")
		"working_framed":
			return title.contains("westtimberwall") or title.contains("easternframe")
		"chapel_masonry":
			return title.contains("southentrance") or title.contains("frontdoorlintel")
		"upland_dwelling":
			return title.contains("frontleftpanel") or title.contains("frontrightpanel")
	return false

func _bounds(body: StaticBody3D) -> Vector3:
	for child: Node in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			return ((child as MeshInstance3D).mesh as BoxMesh).size
	for child: Node in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size
	return Vector3.ZERO

func _decorate(detail: Node3D,size: Vector3,profile: String,title: String) -> void:
	var hx: float = size.x*.5
	var hy: float = size.y*.5
	var hz: float = size.z*.5
	match profile:
		"harbour_ledger":
			# Salt-worn office trim, ledger room portal and raised beam joints.
			_bar(detail,Vector3(-hx*.86,-hy*.80,hz+.07),
				Vector3(-hx*.86,hy*.81,hz+.07),.11,WOOD)
			_bar(detail,Vector3(hx*.86,-hy*.80,hz+.07),
				Vector3(hx*.86,hy*.81,hz+.07),.11,WOOD)
			_bar(detail,Vector3(-hx*.88,hy*.82,hz+.09),
				Vector3(hx*.88,hy*.82,hz+.09),.12,SALT)
			_bar(detail,Vector3(-hx*.77,-hy*.30,hz+.09),
				Vector3(hx*.12,hy*.37,hz+.09),.074,WOOD)
		"net_drying":
			# Braced long drying frames are individually dismantled with original
			# frame IDs, never persist as floating rope/net dressing.
			var x: float = hx+.075
			_bar(detail,Vector3(x,-hy*.87,-hz*.72),
				Vector3(x,hy*.86,hz*.64),.105,WOOD)
			_bar(detail,Vector3(x,hy*.70,-hz*.82),
				Vector3(x,hy*.70,hz*.82),.095,SALT)
			_bar(detail,Vector3(x,-hy*.42,-hz*.81),
				Vector3(x,-hy*.42,hz*.81),.080,WOOD)
		"working_framed":
			var x: float = hx+.066
			_bar(detail,Vector3(x,-hy*.84,-hz*.82),
				Vector3(x,hy*.79,hz*.71),.11,WOOD)
			_bar(detail,Vector3(x,-hy*.75,hz*.76),
				Vector3(x,hy*.63,-hz*.66),.085,SALT)
			_bar(detail,Vector3(x,hy*.78,-hz*.82),
				Vector3(x,hy*.78,hz*.82),.10,IRON)
		"chapel_masonry":
			# Structural carved stone string-courses on existing protected wall.
			# No shrine, clue, occult symbol or story asset invented.
			var face: float = hz+.085
			_bar(detail,Vector3(-hx*.91,hy*.72,face),
				Vector3(hx*.91,hy*.72,face),.20,STONE)
			_bar(detail,Vector3(-hx*.85,-hy*.73,face),
				Vector3(-hx*.85,hy*.77,face),.19,STONE)
			_bar(detail,Vector3(hx*.85,-hy*.73,face),
				Vector3(hx*.85,hy*.77,face),.19,STONE)
		"upland_dwelling":
			# Asymmetric repaired infill braces that follow saved panels.
			var face: float = hz+.067
			_bar(detail,Vector3(-hx*.76,-hy*.82,face),
				Vector3(hx*.64,hy*.51,face),.085,WOOD)
			_bar(detail,Vector3(-hx*.85,hy*.80,face),
				Vector3(hx*.85,hy*.80,face),.096,SALT)

func _bar(parent: Node3D,a: Vector3,b: Vector3,thick: float,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "G3FittedArchitecturalMember"
	var shape := BoxMesh.new()
	shape.size=Vector3(thick,(b-a).length(),thick)
	mesh.mesh=shape
	mesh.position=(a+b)*.5
	mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=.94
	mesh.material_override=mat
	mesh.set_meta("g3_noncolliding",true)
	parent.add_child(mesh)
