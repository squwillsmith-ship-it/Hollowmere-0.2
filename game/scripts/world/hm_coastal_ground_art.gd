class_name HMCoastalGroundArt
extends Node3D
## Deterministic geological skins over the *existing* physics-backed Brinewick
## terrain and roads. Sculptural faceting and mineral variation change neither
## their approved dimensions nor the 291 salvage target identifiers.
var dressed_landforms: int = 0
var dressed_paths: int = 0

func build(terraces: Node3D, roads: Node3D) -> void:
	for source: Node3D in [terraces,roads]:
		for raw: Node in source.get_children():
			var volume: StaticBody3D = raw as StaticBody3D
			if volume == null:
				continue
			var under: MeshInstance3D
			for mesh_child: Node in volume.get_children():
				var candidate: MeshInstance3D = mesh_child as MeshInstance3D
				if candidate != null and candidate.mesh is BoxMesh:
					under = candidate
					break
			if under == null:
				continue
			var is_track: bool = source == roads
			var size: Vector3 = (under.mesh as BoxMesh).size
			var color: Color = (under.material_override as StandardMaterial3D).albedo_color
			var art := MeshInstance3D.new()
			art.name = "WeatheredPathwayStudy" if is_track else "IrregularCoastalRockStudy"
			art.mesh = HMCoastalProductionSurface.create(
                size, String(volume.name), color, is_track)
			var finish := StandardMaterial3D.new()
			finish.vertex_color_use_as_albedo = true
			finish.roughness = 0.96
			finish.cull_mode = BaseMaterial3D.CULL_DISABLED
			art.material_override = finish
			volume.add_child(art)
			# Replace the raw orthogonal block rendering. Preserve its actual
			# collision and do not add floating physical cliff geometry.
			under.visible = false
			if is_track:
				dressed_paths += 1
			else:
				dressed_landforms += 1

static func _build_skin(size: Vector3, title: String, base: Color, path: bool) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = absi(title.hash()) + 90231
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count_x: int = clampi(ceili(size.x/(1.6 if path else 2.7)),2,40)
	var count_z: int = clampi(ceili(size.z/(1.6 if path else 2.7)),2,40)
	for j: int in range(count_z):
		for i: int in range(count_x):
			var x0: float = -size.x*0.5 + size.x*float(i)/float(count_x)
			var x1: float = -size.x*0.5 + size.x*float(i+1)/float(count_x)
			var z0: float = -size.z*0.5 + size.z*float(j)/float(count_z)
			var z1: float = -size.z*0.5 + size.z*float(j+1)/float(count_z)
			var y: float = size.y*0.5 + (0.023 if path else 0.043)
			var jitter: float = 0.015 if path else 0.065
			var a := Vector3(x0,y + r.randf_range(-jitter,jitter),z0)
			var b := Vector3(x1,y + r.randf_range(-jitter,jitter),z0)
			var c := Vector3(x1,y + r.randf_range(-jitter,jitter),z1)
			var d := Vector3(x0,y + r.randf_range(-jitter,jitter),z1)
			var tint: Color = base * r.randf_range(0.87,1.10)
			_emit(builder,a,c,b,tint)
			_emit(builder,a,d,c,tint.darkened(r.randf_range(0.01,0.09)))
	if not path:
		# Slanted lithic faces interrupt giant straight cube walls. Their core
		# stays intact behind the non-colliding decorative faceting.
		for face: int in range(4):
			var along_x: bool = face < 2
			var width: float = size.x if along_x else size.z
			var cols: int = clampi(ceili(width/2.7),3,40)
			var rows: int = clampi(ceili(size.y/2.1),2,12)
			for j: int in range(rows):
				for i: int in range(cols):
					var u0: float = -width*0.5 + width*float(i)/float(cols)
					var u1: float = -width*0.5 + width*float(i+1)/float(cols)
					var v0: float = -size.y*0.5 + size.y*float(j)/float(rows)
					var v1: float = -size.y*0.5 + size.y*float(j+1)/float(rows)
					var offset: float = r.randf_range(0.07,0.38)
					var p0: Vector3 = _cliff_point(face,size,u0,v0,offset)
					var p1: Vector3 = _cliff_point(face,size,u1,v0,offset*0.85)
					var p2: Vector3 = _cliff_point(face,size,u1,v1,offset*0.67)
					var p3: Vector3 = _cliff_point(face,size,u0,v1,offset*0.78)
					var stain: Color = base * r.randf_range(0.74,1.09)
					_emit(builder,p0,p1,p2,stain)
					_emit(builder,p0,p2,p3,stain.darkened(r.randf_range(0.03,0.14)))
	return builder.commit()

static func _cliff_point(face: int, size: Vector3,
		u: float,v: float, protrusion: float) -> Vector3:
	match face:
		0: return Vector3(u,v,size.z*0.5+protrusion)
		1: return Vector3(-u,v,-size.z*0.5-protrusion)
		2: return Vector3(size.x*0.5+protrusion,v,-u)
		_: return Vector3(-size.x*0.5-protrusion,v,u)

static func _emit(tool: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for p: Vector3 in [a,b,c]:
		tool.set_color(tint)
		tool.set_normal(normal)
		tool.add_vertex(p)
