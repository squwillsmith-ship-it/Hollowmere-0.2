class_name HMG3VillageEnvironmentFinal
extends Node3D
## Third G3 art pass: coherent faceted coastal ground between actual buildings.
## Four batched noncolliding vertex-coloured meshes rather than thousands of
## individual node objects. Never provides ore, passive harvesting, story
## evidence, environmental blockers, new salvage owners or automatic work.
const GRANITE: Color = Color("666b61")
const LIMESTONE: Color = Color("908b79")
const SEA_STONE: Color = Color("626b66")
const MOSS: Color = Color("68725b")
const WET_SOIL: Color = Color("595b4d")
const HEATHER: Color = Color("777565")
const OAK: Color = Color("685641")
const DARK_OAK: Color = Color("51483d")
const QUIET_STONE: Color = Color("787466")
var finished: bool = false
var covered_sites: Dictionary = {}
var boulders: int = 0
var vegetation_clumps: int = 0
var civic_stones: int = 0
var shoreline_details: int = 0
var batched_meshes: int = 0

func build(site_nodes: Dictionary) -> void:
	if finished:
		return
	if site_nodes.size() != 21:
		push_error("G3 final environmental pass requires twenty-one canonical locations")
		return
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var square := SurfaceTool.new()
	square.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids: Array=site_nodes.keys()
	ids.sort()
	for raw_id: Variant in ids:
		var id: String=String(raw_id)
		var marker: Node3D=site_nodes[id] as Node3D
		if marker == null:
			push_error("G3 environmental art missing canonical marker "+id)
			continue
		var ordinal: int=int(id.get_file().trim_prefix("site_"))
		var world: Vector3=marker.global_position
		var rng := RandomNumberGenerator.new()
		rng.seed=567891+ordinal*3079
		var region: String=_region(ordinal)
		var clear_radius: float=13.5 if ordinal in [4,5,13,18] else 10.8
		# Site centres, doorways, quay receiving pad and haul road are clear.
		# Faceted clusters lie near the terrain perimeter; no floating trees,
		# blue-painted cottages, hard orthogonal cobble grids or props blocking E.
		for i: int in range(17):
			var angle: float=TAU*(float(i)+rng.randf_range(-.34,.34))/17.0
			var radius: float=clear_radius+rng.randf_range(0.5,5.0)
			var dx: float=cos(angle)*radius
			var dz: float=sin(angle)*radius
			var x: float=world.x+dx
			var z: float=world.z+dz
			if _skip(x,z,ordinal):
				continue
			var stony: Color=SEA_STONE if region=="harbour" else (LIMESTONE if region=="civic" else GRANITE)
			var radius_rock: float=rng.randf_range(.21,.78)
			_boulder(stone,Vector3(x,world.y+.018,z),radius_rock,
				radius_rock*rng.randf_range(.43,.79),stony,
				ordinal*47+i,rng.randf_range(-PI,PI))
			boulders+=1
			# Scrub is only in shallow, low stalks, wind swept toward the sea.
			if i%2==0:
				for blade: int in range(4):
					var p:=Vector3(x+rng.randf_range(-.45,.45),
						world.y+.025,z+rng.randf_range(-.37,.37))
					_blade(grass,p,rng.randf_range(.21,.61),
						MOSS.lerp(HEATHER,rng.randf_range(.12,.77)),
						rng.randf_range(-.18,.06),float(blade))
				vegetation_clumps+=1
		if ordinal in [9,10,15]:
			# Worn irregular flagging makes the well/square/inn civic cluster
			# legible while preserving the existing well/bell puzzle access.
			for ring: int in range(2):
				for tile: int in range(18+ring*9):
					var count: int=18+ring*9
					var angle: float=TAU*(float(tile)+.35*float(ring))/float(count)
					var rr: float=4.7+float(ring)*2.65+float((tile*7+ordinal)%3)*.18
					var at:=world+Vector3(cos(angle)*rr,.046,sin(angle)*rr)
					_flag(square,at,rng.randf_range(.51,.86),
						angle*.32+rng.randf_range(-.2,.2),
						QUIET_STONE.lerp(LIMESTONE,rng.randf_range(.07,.52)))
					civic_stones+=1
		if region=="harbour" and ordinal in [1,2,6,20,21]:
			# Rope-haul staging and abandoned short dock timbers: small
			# NON-salvage land dressing at least seven metres from the centre.
			# The real player's manual depot/boarding mechanics remain separate.
			for piece: int in range(6):
				var px: float=world.x+(-1.0 if piece%2==0 else 1.0)*(7.2+float(piece%3)*1.1)
				var pz: float=world.z-7.2+float(piece%3)*1.3
				if _skip(px,pz,ordinal):
					continue
				_driftwood(wood,Vector3(px,world.y+.18,pz),
					Vector3(.72+float(piece%3)*.19,.13,.17),
					DARK_OAK if piece%3==0 else OAK)
				shoreline_details+=1
		covered_sites[id]=region
	if covered_sites.size()!=21:
		push_error("G3 final environmental pass did not reach original 21 markers")
		return
	_batch("BeddedIrregularCoastalStone",stone)
	_batch("SedgeAndWindBeatenCoastalScrub",grass)
	_batch("IrregularCivicFlagstones",square)
	_batch("ShoreWornTimberEnds",wood)
	finished=true
	set_meta("g3_21_site_environment_integrated",true)
	set_meta("g3_no_new_physics_salvage_or_story",true)

func _region(site: int) -> String:
	if site<=8 or site in [20,21]:
		return "harbour"
	if site in [9,10,11,15]:
		return "civic"
	if site in [17,18,19]:
		return "industrial"
	return "upland"

func _skip(x: float,z: float,site: int) -> bool:
	# Never scatter a little island of stone in the sea, on the lower quay
	# or the central X-oriented multi-tier manual haul route.
	if x < -42.0:
		return true
	if absf(z)<5.6 and x>-.5 and x<171.0:
		return true
	if x< -24.0 and z>1.0 and z<23.0:
		return true
	if site==13 and z>-14.0 and x<150.0:
		return true
	return false

func _boulder(st: SurfaceTool,at: Vector3,r: float,h: float,
		color: Color,seed: int,turn: float) -> void:
	# Nine flat facets with broken colour and irregular radii, low enough
	# that feet do not appear to float above collision-backed land.
	var sides: int=7
	var lower: Array[Vector3]=[]
	var upper: Array[Vector3]=[]
	for i: int in range(sides):
		var angle: float=TAU*float(i)/float(sides)+turn
		var wobble: float=0.83+0.13*sin(float(seed+i*7)*1.21)
		var direction:=Vector3(cos(angle),0,sin(angle))
		lower.append(at+direction*r*wobble+Vector3(0,-.14,0))
		upper.append(at+direction*r*.64*wobble+Vector3(0,h*(.66+.08*float(i%3)),0))
	var crown: Vector3=at+Vector3(0,h,0)
	for i: int in range(sides):
		var j: int=(i+1)%sides
		var tone: Color=color.darkened(.015*float((i+seed)%5))
		_tri(st,lower[i],lower[j],upper[i],tone.darkened(.12))
		_tri(st,lower[j],upper[j],upper[i],tone)
		_tri(st,upper[i],upper[j],crown,tone.lightened(.06))

func _blade(st: SurfaceTool,at: Vector3,h: float,tint: Color,
		drift: float,index: float) -> void:
	var x: float=.07+.015*index
	var tip: Vector3=at+Vector3(drift,h,.035*index)
	_tri(st,at+Vector3(-x,0,-.04),at+Vector3(x,0,.04),tip,tint)
	_tri(st,at+Vector3(0,0,-x),at+Vector3(0,0,x),tip,
		tint.darkened(.11))

func _flag(st: SurfaceTool,at: Vector3,r: float,angle: float,tint: Color) -> void:
	var ax:=Vector3(cos(angle),0,sin(angle))*r
	var az:=Vector3(-sin(angle),0,cos(angle))*r*.67
	var a: Vector3=at-ax-az
	var b: Vector3=at+ax-az*.91
	var c: Vector3=at+ax*.93+az
	var d: Vector3=at-ax*.89+az*.98
	_tri(st,a,b,c,tint)
	_tri(st,a,c,d,tint.darkened(.028))

func _driftwood(st: SurfaceTool,at: Vector3,size: Vector3,tint: Color) -> void:
	var a: Vector3=at+Vector3(-size.x*.5,-size.y*.5,-size.z*.5)
	var b: Vector3=at+Vector3(size.x*.5,-size.y*.5,-size.z*.5)
	var c: Vector3=at+Vector3(size.x*.5,size.y*.5,-size.z*.5)
	var d: Vector3=at+Vector3(-size.x*.5,size.y*.5,-size.z*.5)
	_tri(st,a,b,c,tint.darkened(.12))
	_tri(st,a,c,d,tint)
	var e: Vector3=at+Vector3(-size.x*.5,size.y*.5,size.z*.5)
	var f: Vector3=at+Vector3(size.x*.5,size.y*.5,size.z*.5)
	_tri(st,d,c,f,tint.lightened(.07))
	_tri(st,d,f,e,tint)

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for v: Vector3 in [a,b,c]:
		st.set_normal(normal)
		st.set_color(tint)
		st.add_vertex(v)

func _batch(name: String,st: SurfaceTool) -> void:
	var model: ArrayMesh=st.commit()
	if model==null or model.get_surface_count()<1:
		return
	var instance:=MeshInstance3D.new()
	instance.name=name
	instance.mesh=model
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=.98
	instance.material_override=mat
	instance.set_meta("g3_noncolliding",true)
	add_child(instance)
	batched_meshes+=1
