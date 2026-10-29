class_name HMPhaseCVillageDressing
extends Node3D
## V11: one batched inexpensive environmental scatter for all established
## sites. Geometry is noncolliding, noncollectable, and explicitly NOT a
## replacement for individual salvage or narrative evidence components.
var covered_sites: int = 0
var clump_count: int = 0
const SAGE: Color = Color("737d5a")
const GRASS: Color = Color("777a50")
const SOIL: Color = Color("655f4c")

func build(sites: Dictionary) -> void:
    if covered_sites > 0:
        return
    var keys: Array = sites.keys()
    keys.sort()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for key: Variant in keys:
        var site: Node3D = sites[key]
        var site_id: String = String(key)
        var rand := RandomNumberGenerator.new()
        rand.seed = absi(site_id.hash()) + 1928
        var position: Vector3 = site.position
        # Non-blocking grass is tucked to the periphery of buildings and
        # roads, not placed on receiving pads, ladders or salvage targets.
        for i: int in range(8):
            var angle: float = TAU * (float(i) + rand.randf_range(-0.15,0.15)) / 8.0
            var radius: float = rand.randf_range(7.9,10.1)
            var center: Vector3 = position + Vector3(cos(angle)*radius,0.075,sin(angle)*radius)
            # Avoid sea-level piles at protected quay/ending locations.
            if site_id in ["brinewick/site_01","brinewick/site_20","brinewick/site_21"]:
                continue
            for j: int in range(3):
                var root: Vector3 = center + Vector3(float(j-1)*0.15,0,rand.randf_range(-0.16,0.15))
                var height: float = rand.randf_range(0.22,0.57)
                var drift: float = rand.randf_range(-0.19,0.19)
                var tint: Color = SAGE.lerp(GRASS,rand.randf_range(0,1)) * rand.randf_range(0.78,1.12)
                _tri(st,root+Vector3(-0.12,0,0),root+Vector3(0.12,0,0),
                    root+Vector3(drift,height,0),tint)
            clump_count += 1
        covered_sites += 1
    var visual := MeshInstance3D.new()
    visual.name = "MutedAbandonedVillageVegetation"
    visual.mesh = st.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    visual.material_override = material
    add_child(visual)
    set_meta("site_coverage",covered_sites)
    set_meta("visual_only_not_salvage",true)

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for point: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(point)
