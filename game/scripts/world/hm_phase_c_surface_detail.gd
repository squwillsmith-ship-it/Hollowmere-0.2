class_name HMPhaseCSurfaceDetail
extends Node3D
## V07: One batched, noncolliding detail mesh per existing district body.
## Parenting it to the original salvage body guarantees that part lifecycle,
## disappearance, restore, shadow and collision ownership remain unchanged.
var treated_parts: int = 0
var decorative_triangles: int = 0
const WOOD: Color = Color("65503f")
const SALT: Color = Color("8c8371")
const STONE: Color = Color("766f63")
const SLATE: Color = Color("52595a")

func build(installations: Dictionary) -> void:
    if treated_parts > 0:
        return
    var keys: Array = installations.keys()
    keys.sort()
    for key: Variant in keys:
        var group: Node3D = installations[key]
        for item: Node in group.get_children():
            var body: StaticBody3D = item as StaticBody3D
            if body == null or body.has_node("PhaseCJoineryAndWear") or bool(body.get_meta("g2_assembled",false)):
                continue
            var dims: Vector3 = Vector3.ZERO
            for child: Node in body.get_children():
                if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
                    dims = ((child as MeshInstance3D).mesh as BoxMesh).size
                    break
            if dims == Vector3.ZERO:
                continue
            var title: String = String(body.name).to_lower()
            var rng := RandomNumberGenerator.new()
            rng.seed = absi((String(key) + "/" + title).hash()) + 1047
            var st := SurfaceTool.new()
            st.begin(Mesh.PRIMITIVE_TRIANGLES)
            var count: int = 0
            if title.contains("roof") or title.contains("slate"):
                # Broken overlapping courses follow each actual roof body,
                # never form a static shell spanning other removable panels.
                for i: int in range(clampi(ceili(dims.x / 0.85), 2, 8)):
                    var x: float = -dims.x * 0.5 + (float(i) + 0.5) * dims.x / float(clampi(ceili(dims.x / 0.85), 2, 8))
                    _box(st, Vector3(x, dims.y * 0.51 + 0.024, rng.randf_range(-dims.z * 0.35, dims.z * 0.35)),
                        Vector3(minf(0.42, dims.x * 0.17), 0.055, minf(0.51, dims.z * 0.22)),
                        SLATE * rng.randf_range(0.78, 1.13))
                    count += 1
            elif title.contains("stone") or title.contains("foundation") or title.contains("plinth") or title.contains("pier"):
                if dims.y >= 0.25:
                    for i: int in range(clampi(ceili(dims.x / 1.5), 2, 6)):
                        var x: float = -dims.x * 0.43 + dims.x * 0.86 * float(i) / float(maxi(1, clampi(ceili(dims.x / 1.5), 2, 6) - 1))
                        _box(st, Vector3(x, -dims.y * 0.32, dims.z * 0.50 + 0.019),
                            Vector3(minf(0.60, dims.x * 0.18), minf(0.16, dims.y * 0.24), 0.045),
                            STONE * rng.randf_range(0.68, 1.13))
                        count += 1
            elif title.contains("wall") or title.contains("infill") or title.contains("plaster") or title.contains("wattle"):
                if dims.y > 1.1 and maxf(dims.x, dims.z) > 1.0:
                    # Sill and thin diagonals read as structural repair details;
                    # they cannot intercept collision rays or block a doorway.
                    var along_x: bool = dims.x >= dims.z
                    var width: float = minf(maxf(dims.x, dims.z) * 0.44, 1.5)
                    if along_x:
                        _box(st, Vector3(0, -dims.y * 0.13, dims.z * 0.51),
                            Vector3(width, 0.12, 0.095), WOOD * 0.86)
                    else:
                        _box(st, Vector3(dims.x * 0.51, -dims.y * 0.13, 0),
                            Vector3(0.095, 0.12, width), WOOD * 0.86)
                    count += 1
            elif title.contains("post") or title.contains("beam") or title.contains("frame") or title.contains("lintel"):
                if dims.y > 1.5:
                    for i: int in range(3):
                        var y: float = -dims.y * 0.33 + dims.y * float(i) * 0.32
                        _box(st, Vector3(0, y, dims.z * 0.52),
                            Vector3(minf(0.12, dims.x * 0.6), 0.065, 0.025), WOOD * rng.randf_range(0.75, 1.09))
                        count += 1
            if count == 0:
                continue
            var art := MeshInstance3D.new()
            art.name = "PhaseCJoineryAndWear"
            art.mesh = st.commit()
            var finish := StandardMaterial3D.new()
            finish.vertex_color_use_as_albedo = true
            finish.roughness = 0.97
            art.material_override = finish
            body.add_child(art)
            treated_parts += 1
            decorative_triangles += count * 12
    set_meta("visual_only_no_new_salvage", true)
    set_meta("phase_c_treated_bodies", treated_parts)

static func _box(st: SurfaceTool, center: Vector3, dims: Vector3, tint: Color) -> void:
    var a: Vector3 = center - dims * 0.5
    var b: Vector3 = center + dims * 0.5
    var pts: Array[Vector3] = [Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)]
    for face: Array in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]:
        _triangle(st, pts[int(face[0])],pts[int(face[1])],pts[int(face[2])],tint)
        _triangle(st, pts[int(face[0])],pts[int(face[2])],pts[int(face[3])],tint.darkened(0.05))

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    var normal: Vector3 = (b - a).cross(c - a).normalized()
    for point: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(point)
