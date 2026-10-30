class_name HMBrinewickSites
extends Node3D
## Steps 26–30 production scene: manually removable catalogue-backed components.
## Envelope and component geometry remain working low-poly authoring, not final.
const SPEC: String = "res://data/v1/brinewick_district_builds.json"
const COTTAGE: String = "res://data/v1/buildings/cottage_working_01.json"
const PALETTE: Dictionary = {
	"jetty": Color("6c6250"), "wood": Color("78604a"),
	"wood_dark": Color("554538"), "wood_salt": Color("888074"),
	"stone": Color("858174"), "plaster": Color("b4aa90"),
	"roof": Color("626668"), "rope": Color("a69b79"),
	"iron": Color("777670"), "earth": Color("797360")
}
var installation_nodes: Dictionary = {}
var stage_counts: Dictionary = {}
var occupied_sites: Dictionary = {}
var cottage: Node3D

func build(sites: Dictionary) -> void:
	if not installation_nodes.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	if not (parsed is Dictionary) or not (parsed.get("installations", null) is Array):
		push_error("Brinewick district specification unavailable")
		return
	var cat := HMCatalog.new()
	if not cat.load_all():
		push_error("Cannot place Brinewick structures without canonical catalogue")
		return
	for raw: Variant in parsed["installations"]:
		if not (raw is Dictionary):
			push_error("Non-object Brinewick installation")
			return
		var entry: Dictionary = raw
		var id: String = String(entry.get("id", ""))
		var site_id: String = String(entry.get("site_id", ""))
		var phase: int = int(entry.get("step", -1))
		if id.is_empty() or installation_nodes.has(id) or not sites.has(site_id) or phase < 26 or phase > 30:
			push_error("Invalid or repeated Brinewick installation " + id)
			return
		var site: Node3D = sites[site_id]
		var group := Node3D.new()
		group.name = id.replace("/", "_")
		group.position = site.position
		group.set_meta("site_id", site_id)
		group.set_meta("roadmap_step", phase)
		group.set_meta("development_status", "WORKING_PROVISIONAL_GEOMETRY")
		group.set_meta("ordinary_salvage", bool(entry.get("has_removable_components", false)))
		group.set_meta("protected_story", bool(entry.get("protected_story", false)))
		add_child(group)
		installation_nodes[id] = group
		stage_counts[phase] = int(stage_counts.get(phase, 0)) + 1
		if not occupied_sites.has(site_id):
			occupied_sites[site_id] = true
			# Remove overlapping Step25 massing proxies only in populated sites.
			var placeholder: StaticBody3D = site.get_node_or_null("NonSalvageVolume") as StaticBody3D
			if placeholder != null:
				placeholder.visible = false
				placeholder.collision_layer = 0
				var old_collision: CollisionShape3D = placeholder.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if old_collision != null:
					old_collision.set_deferred("disabled", true)
		for geom: Variant in entry.get("geometry", []):
			if geom is Dictionary:
				_solid(group, geom)
		var kind: String = String(entry.get("kind", "scenery"))
		if kind == "cottage":
			var manifest: Dictionary = HMBuildingPrefab.read_manifest(COTTAGE)
			var origin: Vector3 = site.position
			manifest["origin"] = [origin.x, origin.y, origin.z]
			if not HMBuildingPrefab.validate(manifest, cat).is_empty():
				push_error("Village cottage invalid against canonical saved IDs")
				return
			cottage = HMBuildingPrefab.build(manifest, cat)
			if cottage != null:
				# Global-coordinate cottage is a sibling, not child of site offset.
				add_child(cottage)
		elif kind == "navigation_light":
			var lantern := OmniLight3D.new()
			lantern.name = "PracticalHarbourNavigationLamp"
			lantern.position = Vector3(0, 10.65, 0)
			lantern.light_color = Color("e7c88f")
			lantern.light_energy = 0.55
			lantern.omni_range = 16.0
			group.add_child(lantern)
		elif kind == "tool_pickup":
			var tool_id: String = String(entry.get("tool_id", ""))
			var pickup := HMToolPickup.new()
			pickup.name = "ManualDiscovery_" + tool_id
			pickup.tool_id = tool_id
			var at: Array = entry.get("pickup_offset", [0.0, 0.8, 0.0])
			pickup.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
			group.add_child(pickup)
			_pickup_mesh(pickup)
			if not pickup.is_valid_discovery(cat):
				push_error("Proposed pickup uses unknown/non-world tool: " + tool_id)

	# All existing physical/removable bodies retain their owners and collision.
	# Only raw visual box renderings are exchanged for authored material skins.
	var authored := HMSettlementProductionArt.new()
	authored.name = "BrinewickAuthoredArchitecture"
	add_child(authored)
	authored.build(installation_nodes)
	set_meta("production_art_bodies", authored.finished_bodies)
	set_meta("production_art_roofs", authored.finished_roofs)
	set_meta("production_art_stones", authored.stone_courses)
	# Phase C: attach joinery/wear to EXISTING removable bodies only.
	# Neither catalogue definitions nor colliders are expanded.
	var extra := HMPhaseCSurfaceDetail.new()
	extra.name = "PhaseCDistrictJoinery"
	add_child(extra)
	extra.build(installation_nodes)
	set_meta("phase_c_dressed_parts", extra.treated_parts)

	# G2 production hero pass: distinctive low-poly, noncolliding detail
	# owned by the original cottage and warehouse HMInspectTarget bodies.
	# The original saved IDs and authoritative colliders remain untouched.
	var hero := HMHeroBuildingArtG2.new()
	hero.name = "G2PartOwnedHeroArchitecture"
	add_child(hero)
	hero.build(cottage,installation_nodes)
	set_meta("g2_hero_owned_meshes",hero.batched_meshes)

	# G3 pilot: give five different districts distinctive architecture using
	# only existing static/removable scene owners, keeping all 21 sites fixed.
	var district_art := HMVillageDistrictArtG3.new()
	district_art.name = "G3DistrictArchitecturalPilots"
	add_child(district_art)
	district_art.build(installation_nodes)
	set_meta("g3_pilot_architectural_owners",district_art.attached_visuals)
	# Final G3 roof surface: individual worn slate courses remain children
	# of the 64 ORIGINAL pitched roof bodies/colliders, never own gameplay.
	var roof_finish := HMG3RoofWeatherFinish.new()
	roof_finish.name = "G3OriginalRoofWeatherFinish"
	add_child(roof_finish)
	roof_finish.build(installation_nodes)
	set_meta("g3_64_roof_surfaces",roof_finish.owners)

	# World discoveries and narrative cues reference existing site markers.
	for data: Variant in parsed.get("world_discoveries", []):
		if not (data is Dictionary) or not sites.has(String(data.get("site_id", ""))):
			push_error("Invalid tool discovery site")
			continue
		var tool := HMToolPickup.new()
		tool.tool_id = String(data.get("tool_id", ""))
		tool.minimum_act = int(data.get("minimum_act", 1))
		tool.name = "VillagePickup_" + tool.tool_id
		if not tool.is_valid_discovery(cat):
			push_error("Invalid tool discovery " + tool.tool_id)
			continue
		var at: Array = data.get("offset", [])
		if at.size() != 3:
			continue
		tool.position = sites[String(data["site_id"])].position + Vector3(float(at[0]),float(at[1]),float(at[2]))
		add_child(tool)
		_pickup_mesh(tool)
	for data: Variant in parsed.get("world_story_clues", []):
		if not (data is Dictionary) or not sites.has(String(data.get("site_id", ""))):
			push_error("Invalid story clue site")
			continue
		var clue := HMStoryClue.new()
		clue.flag_id = String(data.get("flag_id", ""))
		clue.minimum_act = int(data.get("minimum_act", 1))
		clue.event_kind = String(data.get("kind", "discover"))
		clue.display_name = String(data.get("label", clue.flag_id))
		clue.evidence_text = String(data.get("text", ""))
		if not clue.is_valid(cat):
			push_error("Invalid story clue " + clue.flag_id)
			continue
		var at: Array = data.get("offset", [])
		if at.size() != 3:
			continue
		clue.position = sites[String(data["site_id"])].position + Vector3(float(at[0]),float(at[1]),float(at[2]))
		clue.name = "VillageClue_" + clue.flag_id
		add_child(clue)
		_clue_mesh(clue)

func _solid(parent: Node3D, data: Dictionary) -> void:
	var dims: Array = data.get("size", [])
	var offset: Array = data.get("offset", [])
	if dims.size() != 3 or offset.size() != 3 or not PALETTE.has(String(data.get("material", ""))):
		push_error("Invalid Brinewick solid " + String(data.get("name", "")))
		return
	var size := Vector3(float(dims[0]), float(dims[1]), float(dims[2]))
	var at := Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		push_error("Nonpositive Brinewick dimensions")
		return
	var body: StaticBody3D
	var removable: String = String(data.get("removable_part_id", ""))
	if not removable.is_empty():
		body = HMInspectTarget.new()
		(body as HMInspectTarget).part_id = removable
	else:
		body = StaticBody3D.new()
	body.name = String(data.get("name", "Massing"))
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	parent.add_child(body)
	var geometry := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	geometry.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PALETTE[String(data["material"])]
	material.roughness = 0.92
	geometry.material_override = material
	body.add_child(geometry)
	if data.has("detail_profile"):
		geometry.visible = false
		var display := Node3D.new()
		display.name = "ArchitecturalDetail"
		body.add_child(display)
		HMArchitecturalDetail.decorate(display, size, PALETTE[String(data["material"])],
			String(data["detail_profile"]), String(data.get("name", "")))
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if String(data.get("detail_profile", "")) == "framed_bay":
		collider.disabled = true
		HMArchitecturalDetail.add_frame_colliders(body, size)
	if data.has("rotation"):
		var angles: Array = data["rotation"]
		body.rotation_degrees = Vector3(float(angles[0]), float(angles[1]), float(angles[2]))
	if not removable.is_empty() and (
		removable.begins_with("village/04/old_warehouse/") or
		removable.begins_with("village/05/expanded_warehouse/")):
		_install_g2_warehouse_model(body as HMInspectTarget,removable)

func _install_g2_warehouse_model(body: HMInspectTarget,owner: String) -> void:
	# 93 individually saved part IDs, original geometry/colliders/transforms.
	# Authored GLB only takes over the visual, not gameplay ownership.
	var glb: String = "res://assets/models/g2/warehouse/" + owner.replace("/","__") + ".glb"
	if not ResourceLoader.exists(glb):
		push_error("G2 missing independently owned warehouse GLB: " + glb)
		return
	var resource: PackedScene = load(glb) as PackedScene
	if resource == null:
		push_error("G2 bad warehouse GLB: " + glb)
		return
	var visual: Node3D = resource.instantiate() as Node3D
	if visual == null:
		push_error("G2 invalid warehouse GLB scene root: " + glb)
		return
	for old: Node in body.get_children():
		if old is CollisionShape3D:
			continue
		if old is Node3D:
			(old as Node3D).visible = false
	visual.name = "G2WarehousePart"
	visual.set_meta("g2_owner_part_id",owner)
	visual.set_meta("g2_source_glb",glb)
	body.add_child(visual)
	body.set_meta("g2_assembled",true)

func _pickup_mesh(pickup: HMToolPickup) -> void:
	pickup.collision_layer = 1
	pickup.collision_mask = 2
	var mesh := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = Vector3(0.45, 0.16, 0.16)
	mesh.mesh = form
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("66523e")
	mesh.material_override = material
	pickup.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = form.size
	collision.shape = shape
	pickup.add_child(collision)

func get_yard_station_positions() -> Dictionary:
	# Provisional, single fixed base. No automated shipping/market transactions.
	return {
		"pad": Vector3(-20.2, 2.1, 15.7),
		"counter": Vector3(-16.5, 2.1, 20.3),
		"bench": Vector3(-16.4, 2.1, 15.7)
	}

func _clue_mesh(clue: HMStoryClue) -> void:
	clue.collision_layer = 1
	clue.collision_mask = 2
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.48, 0.66, 0.22)
	visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("716557")
	mat.roughness = 0.94
	visual.material_override = mat
	clue.add_child(visual)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = box.size
	shape.shape = solid
	clue.add_child(shape)
