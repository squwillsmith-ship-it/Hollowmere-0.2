class_name HMCoastalRoadWear
extends Node3D
## Visual Rebuild Batch03: grounded, deterministic road-surface wear on the
## original collision-backed roads. Deliberately no new walking or salvage
## bodies. Attached to each road in local space so sloping cart ramps retain
## exactly their original traversable grade.
const CART_ROADS: Array[String] = [
    "HarbourCartRoad", "LowerToUpperRamp", "UpperCartRoad",
    "UpperRampLowerTurn", "UpperToHeadlandRamp", "UpperRampHeadlandTurn",
    "HeadlandTrack", "LandingApproach"
]
var dressed_roads: int = 0
var surface_patches: int = 0
var triangles: int = 0

func build(roads: Node3D) -> void:
    if dressed_roads != 0:
        return
    var finish := StandardMaterial3D.new()
    finish.vertex_color_use_as_albedo = true
    finish.roughness = 1.0
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    for target_name: String in CART_ROADS:
        var solid: StaticBody3D = roads.get_node_or_null(target_name) as StaticBody3D
        if solid == null:
            push_error("Missing original cart route for visual wear: " + target_name)
            continue
        var shape_node: CollisionShape3D = solid.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if bool(solid.get_meta("authored_haul_route", false)):
            # Grounded full-width mesh has its own authentic surface finish.
            dressed_roads += 1
            continue
        if shape_node == null or not (shape_node.shape is BoxShape3D):
            push_error("Visual wear requires the original physical road slab: " + target_name)
            continue
        var size: Vector3 = (shape_node.shape as BoxShape3D).size
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var rng := RandomNumberGenerator.new()
        rng.seed = absi(target_name.hash()) + 386517
        # Subtle staggered damp earth between two cart-wheel worn tracks.
        # Mesh hovers only centimetres over the true existing paved top.
        var n: int = clampi(ceili(size.x/1.55), 4, 58)
        var y: float = size.y * 0.5 + 0.037
        for i: int in range(n):
            var x0: float = -size.x*0.5 + (float(i) + 0.13) * size.x/float(n)
            var x1: float = -size.x*0.5 + (float(i) + 0.85) * size.x/float(n)
            for side: float in [-1.0,1.0]:
                # Worn wheelpaths are subtle broken fragments, not painted
                # unbroken double lines or collision-bearing speed bumps.
                if rng.randf() < 0.20:
                    continue
                var z: float = side*minf(size.z*0.28,1.65)
                var half_width: float = rng.randf_range(0.17,0.27)
                var fade: float = rng.randf_range(0.68,0.96)
                var tone: Color = Color("706b5d") * fade
                _patch(st,Vector3(x0,y,z-half_width),Vector3(x1,y,z+half_width),tone)
                surface_patches += 1
            # Sparse irregular stone and shell inclusions between tracks.
            # These remain flush, do not carry separate material resources,
            # and are visual context rather than player-collectable goods.
            if i % 3 == 0:
                var mid: float = (x0+x1)*0.5
                var zstone: float = rng.randf_range(-0.45,0.45)
                var radius: float = rng.randf_range(0.10,0.24)
                var stone: Color = Color("9d9785") * rng.randf_range(0.76,0.97)
                _facet(st,Vector3(mid,y+0.006,zstone),radius,stone)
                surface_patches += 1
        var skin := MeshInstance3D.new()
        skin.name = "GroundedCartRutsAndAggregate"
        skin.mesh = st.commit()
        skin.material_override = finish
        skin.set_meta("cosmetic_only",true)
        solid.add_child(skin)
        dressed_roads += 1
    set_meta("all_art_uses_existing_road_colliders",true)

func _patch(st: SurfaceTool, a: Vector3, b: Vector3, shade: Color) -> void:
    var centre := (a+b)*0.5
    var wobble: float = (b.x-a.x)*0.08
    _tri(st,Vector3(a.x,a.y,a.z),Vector3(b.x,b.y,b.z-0.06),
        centre+Vector3(wobble,0.002,0),shade)
    _tri(st,centre+Vector3(wobble,0.002,0),Vector3(b.x,b.y,b.z+0.05),
        Vector3(a.x,a.y,b.z),shade.darkened(0.095))
    triangles += 2

func _facet(st: SurfaceTool, centre: Vector3, radius: float, shade: Color) -> void:
    var a := centre+Vector3(-radius,0.0,-radius*0.25)
    var b := centre+Vector3(radius*0.25,0.0,-radius*0.62)
    var c := centre+Vector3(radius,0.0,radius*0.27)
    var d := centre+Vector3(-radius*0.40,0.0,radius*0.70)
    _tri(st,a,b,c,shade)
    _tri(st,a,c,d,shade.darkened(0.07))
    triangles += 2

static func _tri(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(p)
