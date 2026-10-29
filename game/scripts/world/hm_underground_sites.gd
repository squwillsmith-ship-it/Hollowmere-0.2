class_name HMUndergroundSites
extends Node3D
## Phase E (31-33): deliberately authored, player-scale protected passage
## studies. Coordinates are provisional and must not be treated as approved
## site positions. Nothing in these passages can be sold or auto-dismantled.
const ROCK: Color = Color("777365")
const CUT_STONE: Color = Color("878172")
const TIMBER: Color = Color("584839")
const SLATE: Color = Color("555a56")
var stage_counts: Dictionary = {}
var locations: Dictionary = {}

func build(sites: Dictionary) -> void:
	if not locations.is_empty():
		return
	for id: String in ["brinewick/site_09", "brinewick/site_14",
		"brinewick/site_15", "brinewick/site_18"]:
		assert(sites.has(id), "Missing established Brinewick story site " + id)
	for proxy_id: String in ["brinewick/site_09", "brinewick/site_14", "brinewick/site_15",
		"brinewick/site_17", "brinewick/site_18", "brinewick/site_20", "brinewick/site_21"]:
		_suppress_proxy(sites[proxy_id])
	_build_well(sites["brinewick/site_09"].position)
	_build_mine(sites["brinewick/site_18"].position)
	_build_undercroft(sites["brinewick/site_14"].position,
		sites["brinewick/site_15"].position)
	_build_containment_facilities(sites["brinewick/site_17"].position,
		sites["brinewick/site_20"].position, sites["brinewick/site_21"].position)

func _phase_root(step: int, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.set_meta("roadmap_step", step)
	node.set_meta("protected_story", true)
	node.set_meta("development_status", "REVISED_LOW_POLY_STUDY_AWAITING_VISUAL_ACCEPTANCE")
	add_child(node)
	stage_counts[step] = int(stage_counts.get(step, 0)) + 1
	return node

func _suppress_proxy(site: Node3D) -> void:
	var old: StaticBody3D = site.get_node_or_null("NonSalvageVolume") as StaticBody3D
	if old != null:
		old.visible = false
		old.collision_layer = 0
		var shape: CollisionShape3D = old.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null:
			shape.set_deferred("disabled", true)

func _build_well(well: Vector3) -> void:
	var node := _phase_root(31, "WellAndListeningGallery")
	locations["well"] = well
	# Ten small irregular voussoirs avoid a uniform solid cylinder and leave
	# a readable open mouth; the well is not a drop or a salvage source.
	for i: int in range(10):
		var a: float = TAU * float(i) / 10.0
		var p := well + Vector3(cos(a) * 1.45, 0.57, sin(a) * 1.45)
		_solid(node, "WellStone_%02d" % i,
			Vector3(0.96, 1.14 + float(i % 3) * 0.08, 0.53), p, CUT_STONE,
			Vector3(0.0, -rad_to_deg(a), 0.0))
	_solid(node, "PaddedChainSupport", Vector3(0.24, 2.25, 0.23),
		well + Vector3(-1.6, 1.15, 0), TIMBER)
	# The listening annex emerges beyond the upper terrace cliff. The route
	# follows the north edge of the terrace, then drops only in free space.
	_solid(node, "CliffEdgeApproach", Vector3(3.3, 0.28, 17.5),
		Vector3(well.x, 8.17, -37.5), CUT_STONE)
	_solid(node, "DescendingFootway", Vector3(3.3, 0.28, 14.5),
		Vector3(well.x, 6.15, -51.2), CUT_STONE, Vector3(-16.0, 0, 0))
	_solid(node, "ListeningChamberFloor", Vector3(8, 0.4, 12),
		Vector3(well.x, 3.95, -64), ROCK)
	_shell(node, Vector3(well.x, 4.0, -64), Vector3(8.6, 4.2, 13.0), true)
	_solid(node, "WaitingBench", Vector3(3, 0.32, 0.75),
		Vector3(well.x - 2, 4.8, -66), TIMBER)
	_solid(node, "LowStoneListeningAperture", Vector3(0.4, 1.0, 1.8),
		Vector3(well.x + 4.3, 5.0, -65.5), CUT_STONE)
	locations["well_listening"] = Vector3(well.x, 4.2, -65)

func _build_mine(mine: Vector3) -> void:
	var node := _phase_root(32, "MineApproachOfficeAndSealedGallery")
	# Route heads beyond the existing headland mass. The inner seal cannot
	# be opened by any tool and never enters the salvage part catalogue.
	_solid(node, "MineOuterRoad", Vector3(11, 0.32, 4),
		Vector3(171.2, 13.13, mine.z), ROCK)
	_solid(node, "DecliningMineWalk", Vector3(15.8, 0.35, 3.8),
		Vector3(182.5, 9.5, mine.z), CUT_STONE, Vector3(0, 0, -26))
	_solid(node, "GalleryFloor", Vector3(33.5, 0.38, 3.9),
		Vector3(203.5, 5.93, mine.z), ROCK)
	_shell(node, Vector3(203.5, 6.0, mine.z), Vector3(34, 4.5, 4.7), false, true)
	for x: float in [191.0, 199.0, 207.0]:
		_solid(node, "MineRoofTie_%d" % int(x), Vector3(0.36, 0.42, 4.6),
			Vector3(x, 9.8, mine.z), TIMBER)
		for side: float in [-2.08, 2.08]:
			_solid(node, "MinePost_%d_%d" % [int(x), int(side)],
				Vector3(0.28, 3.7, 0.28), Vector3(x, 8.0, mine.z + side), TIMBER)
	_solid(node, "PermanentInnerSeal", Vector3(0.85, 4.3, 4.6),
		Vector3(220.4, 8.0, mine.z), CUT_STONE)
	_solid(node, "OldQuestionAnswerPlate", Vector3(0.15, 0.9, 1.1),
		Vector3(219.87, 7.8, mine.z - 0.6), SLATE)
	locations["mine_seal"] = Vector3(219.4, 6.25, mine.z)
	locations["mine_office"] = Vector3(157, 13, -9)

func _build_undercroft(study: Vector3, bell: Vector3) -> void:
	var node := _phase_root(33, "UndercroftBellAndContainment")
	# A low protected passage beside the chapel, below the existing headland
	# cart track at z=0; it is not an extra ordinary salvage building.
	_solid(node, "UndercroftThreshold", Vector3(4.1,0.25,7.0),
		Vector3(study.x+1.5,12.94,-16.2),CUT_STONE)
	_solid(node, "UndercroftAccess", Vector3(3.8, 0.3, 10.4),
		Vector3(study.x + 1.5, 11.70, -8.4), CUT_STONE,
		Vector3(16, 0, 0))
	_solid(node, "UndercroftFloor", Vector3(9.0, 0.34, 7.5),
		Vector3(study.x + 1.5, 9.8, 0.5), ROCK)
	_shell(node, Vector3(study.x + 1.5, 9.8, 0.5),
		Vector3(9.4, 2.4, 7.5), false, false, true)
	# Move the scriptorium table against the wall. Keep true collision,
	# replacing the sightline-blocking cube with a slab and two stone legs.
	_solid(node, "StoneWritingTable", Vector3(1.65, 0.17, 0.88),
		Vector3(study.x + 3.58, 10.70, 1.25), CUT_STONE)
	for side: float in [-0.6, 0.6]:
		_solid(node, "StudyTableStoneLeg_%d" % int(side * 10.0),
			Vector3(0.21, 0.57, 0.62),
			Vector3(study.x + 3.58 + side, 10.35, 1.25), ROCK)
	_solid(node, "EmptyChair", Vector3(0.64, 0.68, 0.54),
		Vector3(study.x + 2.05, 10.32, 2.20), TIMBER)
	# The surviving bell-house is a roofless, salt-scoured stone frame.
	# Open front and side arches leave actual walking and work-target access.
	for side_x: float in [-3.35,3.35]:
		for side_z: float in [-3.35,3.35]:
			_solid(node, "BellHouseWeatheredPier_%d_%d" % [int(side_x),int(side_z)],
				Vector3(0.85,4.65,0.86),bell+Vector3(side_x,2.34,side_z),CUT_STONE)
			_solid(node, "BellHouseBrokenCap_%d_%d" % [int(side_x),int(side_z)],
				Vector3(1.10,0.31,1.10),
				bell+Vector3(side_x,4.82,side_z),ROCK)
	for side_x: float in [-3.35,3.35]:
		_solid(node,"BellHouseSideLintel_%d"%int(side_x),
			Vector3(0.58,0.62,7.0),bell+Vector3(side_x,4.59,0),CUT_STONE)
	_solid(node,"BellHouseRearLintel",Vector3(6.9,0.67,0.54),
		bell+Vector3(0,4.65,-3.35),CUT_STONE)
	# A broken eaves line, rather than a solid slate ceiling, leaves the
	# working bronze bell legible from the square and produces true shade.
	for roof_x: float in [-2.85,2.85]:
		_solid(node,"BellHouseRoofRemnant_%d"%int(roof_x),
			Vector3(1.05,0.24,7.4),
			bell+Vector3(roof_x,5.26,0.0),SLATE)
	# Bell and mechanism remain intact and protected; mechanical signalling
	# is a story puzzle, NOT a passive resource processing machine.
	_solid(node, "BellTimberCrossbar", Vector3(4.0, 0.5, 0.55),
		bell + Vector3(0, 5.3, 0), TIMBER)
	_solid(node, "BellMount", Vector3(1.1, 1.1, 1.1),
		bell + Vector3(0, 4.45, 0), SLATE)
	locations["undercroft"] = Vector3(study.x + 1.5, 10.1, 0.5)
	locations["bell_house"] = bell

func _build_containment_facilities(mechanism: Vector3, outlet: Vector3,
		escape: Vector3) -> void:
	var group := _phase_root(33, "ProtectedTidalMechanismAndEscape")
	# Tidal signal equipment, final protected works - never a passive production
	# factory or an upgrade. Task-specific first-hit records are separate colliders.
	locations["containment_machine"] = mechanism
	_solid(group, "StoneCounterweightBed", Vector3(4.6,0.40,2.6),
		mechanism + Vector3(0,0.12,0), CUT_STONE)
	_solid(group, "OakMechanismStandLeft", Vector3(0.27,2.2,0.30),
		mechanism + Vector3(-1.2,1.1,1.0), TIMBER)
	_solid(group, "OakMechanismStandRight", Vector3(0.27,2.2,0.30),
		mechanism + Vector3(1.2,1.1,1.0), TIMBER)
	_solid(group, "RatchetBeam", Vector3(2.85,0.23,0.25),
		mechanism + Vector3(0,2.2,1.0), TIMBER)
	_solid(group, "SlidingStoneWeight", Vector3(0.65,1.25,0.70),
		mechanism + Vector3(0,1.05,-0.7), CUT_STONE)
	for i: int in range(12):
		var angle: float = TAU * float(i)/12.0
		var cog: Vector3 = mechanism + Vector3(sin(angle)*0.88,1.45,1.05+cos(angle)*0.88)
		_visual_cylinder(group, "IronPawlTooth_%02d"%i, 0.14, 0.26, cog,
			Color("494b46"), Vector3(rad_to_deg(angle),0,0))
	# Drainage outlet and float can be reached without entering the sea.
	locations["tide_outfall"] = outlet
	_solid(group, "OutfallStoneLedge", Vector3(7.2,0.24,4.1),
		outlet + Vector3(0,0.77,0), CUT_STONE)
	for side: float in [-3.15,3.15]:
		_solid(group, "DrainageWingWall_%d"%int(side),
			Vector3(0.52,1.35,2.4),outlet+Vector3(side,1.5,-0.65),ROCK)
	_visual_cylinder(group,"TidalFloat",0.84,0.35,
		outlet+Vector3(-0.6,1.35,0.0),TIMBER)
	_solid(group,"WornRopeGuides",Vector3(1.8,0.14,0.18),
		outlet+Vector3(-0.65,2.0,-0.40),TIMBER)
	# The empty secondary berth is playable, never evidence of Mara's survival.
	locations["escape_berth"] = escape
	_solid(group,"EscapeTimberLanding",Vector3(8.0,0.25,6.0),
		escape+Vector3(0,0.84,1.0),TIMBER)
	for z: float in [-1.65,2.95]:
		for x: float in [-3.65,3.65]:
			_solid(group,"BerthPost_%d_%d"%[int(x),int(z)],
				Vector3(0.28,1.8,0.3),escape+Vector3(x,0.15,z),TIMBER)
	# A protected craft waits under the cut rope; no automatic travel or
	# narrative trigger can be caused by this scenery.
	_solid(group,"BoatKeel",Vector3(1.15,0.32,3.5),
		escape+Vector3(3.0,1.22,0.85),TIMBER)
	for side: float in [-0.9,0.9]:
		_solid(group,"BoatGunwale_%d"%int(side),
			Vector3(0.18,0.30,3.8),escape+Vector3(3.0+side,1.46,0.85),TIMBER)
	for z: float in [0.0,1.25]:
		_solid(group,"BoatThwart_%d"%int(z),
			Vector3(1.45,0.16,0.20),escape+Vector3(3.0,1.41,z),TIMBER)

func _visual_cylinder(parent: Node3D, title: String, radius: float, height: float,
		at: Vector3, tint: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = at
	node.rotation_degrees = rotation
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	node.material_override = material
	parent.add_child(node)

func _shell(parent: Node3D, centre: Vector3, size: Vector3,
		with_back: bool, along_x: bool = false, vaulted: bool = false) -> void:
	var wall_height: float = size.y
	for side: float in [-1.0, 1.0]:
		var dimensions := Vector3(size.x, wall_height, 0.65) if along_x else Vector3(0.65, wall_height, size.z)
		var offset := Vector3(0, wall_height * 0.5, side * size.z * 0.5) if along_x else Vector3(side * size.x * 0.5, wall_height * 0.5, 0)
		_solid(parent, "RockSide_%d_%d" % [int(centre.x), int(side)],
			dimensions, centre + offset, ROCK)
	if vaulted:
		# The old one-piece slab crossed the player's eye-level sightline.
		# Two pitched *colliding* stone panels leave headroom at the centre
		# while remaining wholly below the existing headland cart track.
		# No invisible roof or view-only scenery is substituted here.
		for side: int in [-1, 1]:
			_solid(parent, "UndercroftVaultSlope_%d" % side,
				Vector3(size.x * 0.515, 0.39, size.z),
				centre + Vector3(float(side) * size.x * 0.249,
					wall_height - 0.16, 0), ROCK,
				Vector3(0, 0, -float(side) * 10.0))
	else:
		_solid(parent, "RockCeiling_%d" % int(centre.x),
			Vector3(size.x, 0.65, size.z), centre + Vector3(0, wall_height + 0.15, 0), ROCK)
	if with_back:
		_solid(parent, "BackRock_%d" % int(centre.x), Vector3(size.x, wall_height, 0.6),
			centre + Vector3(0, wall_height * 0.5, -size.z * 0.5), ROCK)

func _solid(parent: Node3D, title: String, dims: Vector3,
		at: Vector3, tint: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = at
	body.rotation_degrees = rotation
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("protected_story", true)
	parent.add_child(body)
	var geometry := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dims
	geometry.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.95
	geometry.material_override = mat
	body.add_child(geometry)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dims
	collision.shape = shape
	body.add_child(collision)
