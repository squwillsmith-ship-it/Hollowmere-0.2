class_name HMG3SiteIdentity
extends Node3D
## Low-profile village architectural wayfinding, keyed to existing twenty-one
## canonical locations. This is decorative, non-colliding and contains NO
## salvage, narrative interactions, travel automation or invented evidence.
var site_profiles: Dictionary = {}
var visual_members: int = 0

func build(sites: Dictionary) -> void:
	if not site_profiles.is_empty():
		return
	var ids: Array = sites.keys()
	ids.sort()
	for key: Variant in ids:
		var site_id: String = String(key)
		var marker: Node3D = sites[site_id] as Node3D
		if marker == null:
			continue
		var index: int = int(site_id.get_file().trim_prefix("site_"))
		var region: String = _region(index)
		var detail := Node3D.new()
		detail.name = "G3SiteApproachIdentity"
		detail.set_meta("site_id",site_id)
		detail.set_meta("region",region)
		detail.set_meta("g3_noncolliding",true)
		marker.add_child(detail)
		# Contrasting regional stone/wood infrastructure creates readable
		# local scale. Keep central 4 m path and existing manual haul lanes free.
		var offset: float = 6.1 if region=="headland" else 5.4
		var tier: float = 0.20 if region=="civic" else .13
		for signum: float in [-1.0,1.0]:
			var xpos: float = signum*offset
			if region == "harbour":
				_wood(detail,"SaltWornLandingSleeper",
					Vector3(.21,.17,1.56),Vector3(xpos,.12,2.7),Color("75634e"))
				_wood(detail,"OldQuayEndGrain",
					Vector3(.42,.26,.35),Vector3(xpos,.27,3.37),Color("5e5141"))
			elif region == "civic":
				_stone(detail,"IrregularTownThreshold",
					Vector3(1.0,.22,.43),Vector3(xpos,tier,3.15),Color("837e70"))
				_stone(detail,"WornBoundaryBlock",
					Vector3(.39,.39,.44),Vector3(xpos,.22,2.54),Color("726f65"))
			elif region == "upland":
				_stone(detail,"CutHeadlandWaymark",
					Vector3(.68,.28,.48),Vector3(xpos,.19,3.20),Color("8b8577"))
				_wood(detail,"CappedOakStop",
					Vector3(.42,.16,.37),Vector3(xpos,.39,2.80),Color("67523d"))
			else:
				_stone(detail,"IndustrialWornSetting",
					Vector3(.85,.25,.52),Vector3(xpos,.19,3.16),Color("706d61"))
				_wood(detail,"SideSleeper",
					Vector3(.18,.17,1.02),Vector3(xpos,.14,2.48),Color("564a3b"))
		site_profiles[site_id]=region
	set_meta("g3_original_site_count",site_profiles.size())
	set_meta("g3_no_synthetic_story_or_salvage",true)

func _region(index: int) -> String:
	if index <= 8 or index == 20 or index == 21:
		return "harbour"
	if index <= 12 or index == 15:
		return "civic"
	if index in [17,18,19]:
		return "industrial"
	return "upland"

func _wood(parent: Node3D,title: String,size: Vector3,at: Vector3,tint: Color) -> void:
	_box(parent,title,size,at,tint)
func _stone(parent: Node3D,title: String,size: Vector3,at: Vector3,tint: Color) -> void:
	_box(parent,title,size,at,tint)
func _box(parent: Node3D,title: String,size: Vector3,at: Vector3,tint: Color) -> void:
	var surface := MeshInstance3D.new()
	surface.name=title
	surface.position=at
	var model := BoxMesh.new()
	model.size=size
	surface.mesh=model
	var material := StandardMaterial3D.new()
	material.albedo_color=tint
	material.roughness=.95
	surface.material_override=material
	surface.set_meta("g3_derived_from_existing_marker",true)
	parent.add_child(surface)
	visual_members+=1
