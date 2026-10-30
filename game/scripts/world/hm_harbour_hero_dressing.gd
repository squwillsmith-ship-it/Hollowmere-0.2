class_name HMHarbourHeroDressing
extends Node3D
## G1 art dressing on REAL authored coastal ground. Everything here is
## noninteractive visual scatter, never an ore/salvage target or a collider.
## Batched local-world geometry keeps draw calls low and avoids phantom props.
var stones: int = 0
var shoulder_patches: int = 0
var fragments: int = 0

func build() -> void:
	if stones > 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 18492311
	var stone_mesh := SurfaceTool.new()
	stone_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Weathered scree islands, gathered by tide and cart traffic. Keep the
	# company yard's fixed receiving, counter and processing pads visibly open.
	for i: int in range(460):
		var x: float = rng.randf_range(-44.0,46.0)
		var z: float = rng.randf_range(-43.0,43.0)
		var site_access: bool = absf(x+18.0) < 8.0 and absf(z-18.0) < 10.0
		var yard_access: bool = absf(x+33.0) < 8.0 and absf(z-10.0) < 9.0
		var cottage_access: bool = absf(x-35.0) < 5.5 and absf(z-24.0) < 5.5
		var warehouse_access: bool = absf(x-18.0) < 7.0 and absf(z-30.0) < 6.0
		if site_access or yard_access or cottage_access or warehouse_access:
			continue
		var p := Vector3(x,HMHarbourBenchmarkCoast.ground_height(x,z)+0.03,z)
		var radius: float = rng.randf_range(0.12,0.39)
		_rock(stone_mesh,p,radius,rng.randf_range(0.05,0.19),
			Color("77766a").lerp(Color("9c9787"),rng.randf_range(0.04,0.47)),rng)
		stones += 1
	# Broken shoulder stones deliberately follow, but never invade, both
	# sides of the established hand-haul route. No lane markings or slabs.
	for route: Array[Vector2] in [HMHarbourBenchmarkCoast.QUAY_TO_YARD,
			HMHarbourBenchmarkCoast.YARD_TO_COTTAGE,
			HMHarbourBenchmarkCoast.WAREHOUSE_SPUR]:
		for i: int in range(route.size()-1):
			var from: Vector2 = route[i]
			var to: Vector2 = route[i+1]
			var direction: Vector2 = (to-from).normalized()
			var across := Vector2(-direction.y,direction.x)
			var n: int = maxi(2,ceili((to-from).length()/1.85))
			for step: int in range(n):
				if rng.randf() < 0.28:
					continue
				var t: float = (float(step)+rng.randf_range(0.08,0.92))/float(n)
				var centre: Vector2 = from.lerp(to,t)
				for side: float in [-1.0,1.0]:
					if rng.randf() < 0.22:
						continue
					var pos: Vector2 = centre+across*(side*rng.randf_range(1.73,2.02))
					var y: float = HMHarbourBenchmarkCoast.ground_height(pos.x,pos.y)+0.075
					_rock(stone_mesh,Vector3(pos.x,y,pos.y),rng.randf_range(0.16,0.37),
						rng.randf_range(0.05,0.12),
						Color("807969").lerp(Color("aaa18a"),rng.randf_range(0.12,0.36)),rng)
					shoulder_patches += 1
	# Scattered shell and lime aggregate within the old route itself.
	for i: int in range(220):
		var s: float = rng.randf()
		var start: Vector2 = Vector2(-16.0,9.0) if s < 0.65 else Vector2(26.5,29.5)
		var finish: Vector2 = Vector2(23.0,14.0) if s < 0.65 else Vector2(18.0,38.0)
		var centre: Vector2 = start.lerp(finish,rng.randf())
		centre += Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-0.9,0.9))
		var y: float = HMHarbourBenchmarkCoast.ground_height(centre.x,centre.y)+0.145
		_rock(stone_mesh,Vector3(centre.x,y,centre.y),
			rng.randf_range(0.035,0.10),0.011,Color("b2aa96")*rng.randf_range(0.81,0.97),rng)
		fragments += 1
	var surface := MeshInstance3D.new()
	surface.name = "BatchedCoastalStonesRoadEdgingAndShellAggregate"
	surface.mesh = stone_mesh.commit()
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.98
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = finish
	add_child(surface)
	set_meta("cosmetic_only_no_new_colliders", true)
	set_meta("manual_salvage_owned_elsewhere", true)

static func _rock(st: SurfaceTool, p: Vector3,
		radius: float, height: float, colour: Color,
		rng: RandomNumberGenerator) -> void:
	var ring: Array[Vector3] = []
	for side: int in range(6):
		var angle: float = TAU*float(side)/6.0
		var r: float = radius*rng.randf_range(0.74,1.15)
		ring.append(p+Vector3(cos(angle)*r,0,sin(angle)*r))
	var peak: Vector3 = p+Vector3(rng.randf_range(-0.035,0.035),height,
		rng.randf_range(-0.035,0.035))
	for side: int in range(6):
		var shade: Color = colour*(0.92+0.07*float(side%3))
		_tri(st,ring[side],ring[(side+1)%6],peak,shade)

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		tint: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for point: Vector3 in [a,b,c]:
		st.set_color(tint)
		st.set_normal(normal)
		st.add_vertex(point)
