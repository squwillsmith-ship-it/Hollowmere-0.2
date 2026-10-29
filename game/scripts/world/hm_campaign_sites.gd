class_name HMCampaignSites
extends Node3D
## Physical evidence for the approved four-act, two-ending village narrative.
## The two earlier story targets retain their original scene and saved flags.
const SPEC: String = "res://data/v1/campaign_sites.json"
var clue_nodes: Dictionary = {}
var finale_nodes: Dictionary = {}
var work_nodes: Dictionary = {}

func build(sites: Dictionary, catalogue: HMCatalog) -> void:
	if not clue_nodes.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	if not (parsed is Dictionary):
		push_error("Missing narrative installations")
		return
	var seen: Dictionary = {}
	for item: Variant in parsed.get("evidence", []):
		if not (item is Dictionary):
			continue
		var flag: String = String(item.get("flag_id", ""))
		var id: String = String(item.get("site_id", ""))
		var row: Dictionary = catalogue.by_id("story", "discoveries", flag)
		if seen.has(flag) or row.is_empty() or not sites.has(id) or String(row.get("location_id", "")) != id:
			push_error("Invalid campaign evidence " + flag)
			continue
		seen[flag] = true
		var offset: Array = item.get("offset", [])
		if offset.size() != 3:
			push_error("Invalid campaign evidence position " + flag)
			continue
		var clue := HMStoryClue.new()
		clue.flag_id = flag
		clue.minimum_act = int(row["minimum_act"])
		clue.event_kind = "encounter" if String(row.get("kind", "")) == "one_time_encounter" else "discover"
		clue.display_name = String(item.get("title", flag))
		clue.evidence_text = String(item.get("text", ""))
		clue.name = "CampaignEvidence_" + flag
		clue.position = sites[id].position + Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		clue.set_meta("protected_story", true)
		add_child(clue)
		_physical_record(clue, bool(item.get("slate", false)))
		_dress_evidence(clue,flag)
		clue_nodes[flag] = clue
		assert(clue.is_valid(catalogue))
	for item: Variant in parsed.get("finales", []):
		if not (item is Dictionary):
			continue
		var ending: String = String(item.get("ending_id", ""))
		var id: String = String(item.get("site_id", ""))
		var offset: Array = item.get("offset", [])
		if finale_nodes.has(ending) or not sites.has(id) or offset.size() != 3:
			push_error("Invalid finale placement " + ending)
			continue
		var choice := HMFinaleChoice.new()
		choice.name = "PhysicalEnding_" + ending
		choice.ending_id = ending
		choice.display_name = String(item.get("title", ending))
		choice.position = sites[id].position + Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		choice.set_meta("protected_story", true)
		add_child(choice)
		_physical_record(choice, true)
		finale_nodes[ending] = choice
		assert(choice.is_valid())
	# Every final mechanism is a separate reach-constrained physical object.
	# The unloading target lives at the real receiving pad, not an imaginary depot.
	for action_id: String in HMCampaignRules.TASKS:
		var spec: Dictionary = HMCampaignRules.TASKS[action_id]
		var site_id: String = String(spec["site"])
		if not sites.has(site_id):
			push_error("Missing finale mechanism site: " + action_id)
			continue
		var position_data: Array = spec["offset"]
		var target := HMFinaleWorkTarget.new()
		target.name = "ManualMechanism_" + action_id
		target.action_id = action_id
		target.display_name = String(spec["title"])
		var at: Vector3 = sites[site_id].position + Vector3(float(position_data[0]),float(position_data[1]),float(position_data[2]))
		if action_id == "bell_unload":
			at = Vector3(-17.8, 2.9, 15.7)
		target.position = at
		target.set_meta("protected_story", true)
		add_child(target)
		_physical_record(target, true)
		_dress_mechanism(target,action_id)
		work_nodes[action_id] = target
		assert(target.is_valid())
	assert(finale_nodes.size() == 2, "Exactly two approved endings exist")

func _physical_record(parent: StaticBody3D, slate: bool) -> void:
	parent.collision_layer = 1
	parent.collision_mask = 2
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.64, 0.85, 0.24)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6f7065") if slate else Color("9c8869")
	material.roughness = 0.95
	mesh.material_override = material
	parent.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	parent.add_child(collision)

func _dress_evidence(root: HMStoryClue, flag: String) -> void:
	# Ten different non-colliding low-poly finds, instead of identical slabs.
	# Only the single stable HMStoryClue body receives first-hit interactions.
	var oak := Color("6d533a")
	var vellum := Color("c2b497")
	var iron := Color("51534c")
	match flag:
		"net_store_sabotage":
			_prop(root,"SplinteredBeam",Vector3(1.05,0.15,0.2),Vector3(0,0,0.15),oak)
			_prop(root,"SawKerf",Vector3(0.14,0.19,0.21),Vector3(0.12,0,0.30),iron)
		"council_vote":
			_prop(root,"SlatedVotingTablet",Vector3(0.82,0.62,0.12),Vector3(0,0.16,0.14),Color("454d4a"))
			for n: int in range(7):
				_prop(root,"ChalkVote_%d"%n,Vector3(0.08,0.013,0.02),Vector3(-0.3+float(n)*0.1,0.07,0.22),vellum)
		"first_missing_miner":
			_prop(root,"FoldedBlanket",Vector3(1.0,0.13,0.7),Vector3(0,-0.30,0.21),Color("757066"))
			_cylinder(root,"EmptyCup",0.17,0.25,Vector3(0.34,-0.03,0.31),Color("8d7b6a"))
		"nine_miner_roster":
			for n: int in range(3):
				_prop(root,"RegisterPage_%d"%n,Vector3(0.58,0.73,0.025),
					Vector3(-0.12+float(n)*0.05,0.11,0.14+float(n)*0.026),vellum)
		"returnee_denial":
			_prop(root,"BoltedDoorFragment",Vector3(0.85,1.12,0.22),Vector3(0,-0.04,0.12),oak)
			_prop(root,"InsideIronBolt",Vector3(0.76,0.11,0.13),Vector3(0,0.12,0.30),iron)
		"false_elsbeth_memory":
			_prop(root,"OpenJournalLeft",Vector3(0.45,0.62,0.045),Vector3(-0.22,0.05,0.21),vellum)
			_prop(root,"OpenJournalRight",Vector3(0.45,0.62,0.045),Vector3(0.23,0.05,0.21),vellum)
		"aldren_remains_found":
			_prop(root,"TornTestament",Vector3(0.72,0.62,0.025),Vector3(0,0.12,0.18),vellum)
			_prop(root,"BeneathFloorStone",Vector3(1.0,0.3,0.52),Vector3(0,-0.53,0.08),Color("797367"))
		"containment_understood":
			_prop(root,"RatchetSketch",Vector3(0.88,0.70,0.045),Vector3(0,0.1,0.16),vellum)
			_cylinder(root,"InkGearRing",0.25,0.035,Vector3(-0.17,0.03,0.22),iron)
		"mara_escape_clues":
			_prop(root,"CutRope",Vector3(0.70,0.095,0.12),Vector3(-0.07,-0.05,0.23),Color("a49b78"))
			_cylinder(root,"WornOarlock",0.18,0.18,Vector3(0.30,0.11,0.21),iron)
		"inspection_suppression":
			_prop(root,"SealedCompanyLetter",Vector3(0.74,0.64,0.025),Vector3(0,0.08,0.17),vellum)
			_cylinder(root,"WaxSeal",0.11,0.045,Vector3(0,-0.1,0.21),Color("664b3f"))

func _dress_mechanism(root: HMFinaleWorkTarget, id: String) -> void:
	var metal := Color("555850")
	var wood := Color("725a43")
	if id.begins_with("bell"):
		_cylinder(root,"BellGear",0.34,0.15,Vector3(0,0.06,0.19),Color("746c55"))
		_prop(root,"LeverGrip",Vector3(0.18,0.78,0.16),Vector3(0.15,0.20,0.23),wood)
	elif id.contains("float") or id.contains("weight"):
		_cylinder(root,"RopeDrum",0.3,0.35,Vector3(0,-0.06,0.17),wood)
		_prop(root,"GuideIron",Vector3(0.13,0.9,0.15),Vector3(0.18,0.18,0.21),metal)
	elif id.contains("ratchet") or id.contains("hammer"):
		_cylinder(root,"PawlMechanism",0.33,0.20,Vector3(0,0.06,0.16),metal)
	else:
		_prop(root,"ProtectiveWorkhandle",Vector3(0.76,0.12,0.15),Vector3(0,0.0,0.2),wood)

func _prop(parent: Node3D,title: String,size: Vector3,at: Vector3,tint: Color) -> void:
	var obj := MeshInstance3D.new()
	obj.name = title
	obj.position = at
	var box := BoxMesh.new()
	box.size = size
	obj.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.95
	obj.material_override = mat
	parent.add_child(obj)

func _cylinder(parent: Node3D,title: String,radius: float,height: float,
		at: Vector3,tint: Color) -> void:
	var obj := MeshInstance3D.new()
	obj.name = title
	obj.position = at
	obj.rotation_degrees = Vector3(90,0,0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	obj.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.88
	obj.material_override = mat
	parent.add_child(obj)
