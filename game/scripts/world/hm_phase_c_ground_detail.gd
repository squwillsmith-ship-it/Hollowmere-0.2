class_name HMPhaseCGroundDetail
extends Node3D
## V08: permanent noncolliding faceted edge breakup, retaining Step25
## road collision, heights, gradients, entrances and all site coordinates.
var treated_roads: int = 0
var treated_cliffs: int = 0

func build(terraces: Node3D, roads: Node3D) -> void:
    if treated_roads + treated_cliffs > 0:
        return
    for holder: Node3D in [terraces, roads]:
        for child: Node in holder.get_children():
            var body: StaticBody3D = child as StaticBody3D
            if body == null:
                continue
            var size: Vector3 = Vector3.ZERO
            for component: Node in body.get_children():
                if component is MeshInstance3D and (component as MeshInstance3D).mesh is BoxMesh:
                    size = ((component as MeshInstance3D).mesh as BoxMesh).size
                    break
            if size == Vector3.ZERO:
                continue
            var is_road: bool = holder == roads
            var mesh := SurfaceTool.new()
            mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
            var seeded := RandomNumberGenerator.new()
            seeded.seed = absi(String(body.name).hash()) + 7729
            if is_road:
                # Thin broken cobble/earth seams, sunk into the existing top.
                # Leave centreline completely unobstructed and noncolliding.
                for side: float in [-1.0, 1.0]:
                    for i: int in range(clampi(ceili(size.x / 2.8), 2, 24)):
                        var x: float = -size.x * 0.5 + (float(i) + 0.5) * size.x / float(clampi(ceili(size.x / 2.8), 2, 24))
                        var z: float = side * (size.z * 0.45)
                        _patch(mesh, Vector3(x,size.y * 0.5 + 0.026,z),
                            Vector2(minf(0.65,size.x*0.08),0.19),
                            Color("898374") * seeded.randf_range(0.8,1.08))
                treated_roads += 1
            else:
                # Geological strata only on exposed vertical flanks, with
                # zero extension into walkable terrace tops.
                for side: float in [-1.0, 1.0]:
                    for i: int in range(8):
                        var x: float = -size.x * 0.44 + size.x * 0.88 * float(i) / 7.0
                        var z: float = side * (size.z * 0.5 + 0.022)
                        var y: float = -size.y * 0.32 + float(i % 3) * size.y * 0.17
                        _wall(mesh,Vector3(x,y,z),Vector2(minf(size.x*0.11,2.7),minf(size.y*0.11,0.65)),
                            Color("555f56") * seeded.randf_range(0.8,1.18))
                treated_cliffs += 1
            var surface := MeshInstance3D.new()
            surface.name = "PhaseCWeatheredGroundEdges"
            surface.mesh = mesh.commit()
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.roughness = 1.0
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            surface.material_override = material
            body.add_child(surface)
    set_meta("visual_only_road_collision_unchanged", true)

static func _patch(st: SurfaceTool, p: Vector3, half: Vector2, tint: Color) -> void:
    _tri(st,p+Vector3(-half.x,0,-half.y),p+Vector3(half.x,0,-half.y),p+Vector3(half.x,0,half.y),tint)
    _tri(st,p+Vector3(-half.x,0,-half.y),p+Vector3(half.x,0,half.y),p+Vector3(-half.x,0,half.y),tint.darkened(0.07))

static func _wall(st: SurfaceTool, p: Vector3, half: Vector2, tint: Color) -> void:
    _tri(st,p+Vector3(-half.x,-half.y,0),p+Vector3(half.x,-half.y,0),p+Vector3(half.x,half.y,0),tint)
    _tri(st,p+Vector3(-half.x,-half.y,0),p+Vector3(half.x,half.y,0),p+Vector3(-half.x,half.y,0),tint.darkened(0.09))

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for point: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(point)
