class_name HMPhaseCHarbourDressing
extends Node3D
## V09: single-batch harbour set dressing outside service pads, no physics,
## pickup, sellable lot, obstruction or altered site placement.
var quay_batches: int = 0
var fishing_batches: int = 0
var hull_planks: int = 0
const OAK: Color = Color("695642")
const IRON: Color = Color("656663")
const ROPE: Color = Color("a19675")

func build(sites: Dictionary) -> void:
    if quay_batches > 0:
        return
    var quay: Node3D = sites["brinewick/site_01"]
    var origin: Vector3 = quay.position
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Mooring piles occupy the seaward edge of the permanent quay rather
    # than the actual quay/pad/counter or any player-operated unload zone.
    for i: int in range(5):
        var z: float = -7.3 + float(i) * 3.7
        var x: float = -8.5 - float(i % 2) * 0.45
        _box(st,origin + Vector3(x,-1.14,z),Vector3(0.46,3.0,0.49),OAK * (0.88 + 0.04 * float(i % 3)))
        _box(st,origin + Vector3(x,0.53,z),Vector3(0.65,0.15,0.67),OAK.darkened(0.14))
        _box(st,origin + Vector3(x,0.15,z),Vector3(0.54,0.09,0.58),ROPE * 0.84)
    # Faceted clinker hull with tapered bow/stern, exposed ribs and an open
    # interior. Earlier provisional boat was a rectangular crate silhouette.
    # It remains uncollidable history outside every receiving/hauling pad.
    var boat: Vector3 = origin + Vector3(-13.4,-1.5,-2.0)
    _clinker_hull(st,boat)
    # The retaining-face courses are deliberately staggered, interrupted
    # and uneven in size instead of a single flat quay-box silhouette.
    # They live *outside* the seaward edge (x < -9 in quay-local metres),
    # so the existing collision-backed deposit and cargo route is untouched.
    var rng := RandomNumberGenerator.new()
    rng.seed = 217503
    for course: int in range(3):
        var z_cursor: float = -8.5 + float(course % 2)*0.47
        var block: int = 0
        while z_cursor < 8.4:
            var length: float = rng.randf_range(0.63,1.67)
            var stone: Color = Color("696b62").lerp(Color("918a75"),rng.randf_range(0.08,0.55))
            var position := origin + Vector3(-9.25-rng.randf_range(0.0,0.42),
                -1.78+float(course)*0.45 + rng.randf_range(-0.08,0.06),z_cursor+length*0.5)
            _box(st,position,Vector3(rng.randf_range(0.43,0.77),
                rng.randf_range(0.40,0.51),length-0.07),stone)
            z_cursor += length + rng.randf_range(0.06,0.18)
            block += 1
    _mesh(st,"OutboardMooringsAndClinker",true)
    quay_batches = 1

    var fish_site: Node3D = sites["brinewick/site_06"]
    var fishing := SurfaceTool.new()
    fishing.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Net-drying rack is offset past the site envelope; sparse rope line
    # is only readable visual history, no phantom physical work surface.
    var rack: Vector3 = fish_site.position + Vector3(-7.8,0.0,-6.4)
    for i: int in range(3):
        _box(fishing,rack + Vector3(float(i)*1.8,1.40,0),Vector3(0.18,2.8,0.18),OAK)
    _box(fishing,rack + Vector3(1.8,2.67,0),Vector3(3.7,0.13,0.18),OAK.darkened(0.1))
    for i: int in range(7):
        _box(fishing,rack + Vector3(float(i)*0.48+0.35,1.91,0),Vector3(0.045,1.15,0.045),ROPE)
    _mesh(fishing,"DisusedFishingNetRack",false)
    fishing_batches = 1
    set_meta("visual_only_harbour_no_colliders",true)

func _clinker_hull(st: SurfaceTool, at: Vector3) -> void:
    # Four broad strakes along each side. Station breadth falls away from
    # amidships; the keel stays below the gunwale to make a true boat profile.
    var stations := PackedFloat32Array([-2.25,-1.72,-0.82,0.0,0.82,1.72,2.25])
    var breadth := PackedFloat32Array([0.22,0.63,0.83,0.91,0.83,0.63,0.22])
    var heights := PackedFloat32Array([0.75,0.55,0.49,0.47,0.49,0.55,0.75])
    var plank_tints: Array[Color] = [Color("554738"),Color("67513b"),
        Color("756047"),Color("615342")]
    for side: float in [-1.0,1.0]:
        for course: int in range(4):
            var low: float = float(course)/4.0
            var high: float = float(course+1)/4.0
            for i: int in range(stations.size()-1):
                var x0: float = stations[i]
                var x1: float = stations[i+1]
                # Raked clinker layers flare progressively toward the sheer.
                var w0: float = breadth[i]
                var w1: float = breadth[i+1]
                var a := at + Vector3(x0,heights[i]*low,side*w0*(0.20+0.80*low))
                var b := at + Vector3(x1,heights[i+1]*low,side*w1*(0.20+0.80*low))
                var c := at + Vector3(x1,heights[i+1]*high,side*w1*(0.20+0.80*high))
                var d := at + Vector3(x0,heights[i]*high,side*w0*(0.20+0.80*high))
                var colour: Color = plank_tints[course] * (0.90+float(i%3)*0.035)
                _quad(st,a,b,c,d,colour)
                hull_planks += 1
        # Slightly broken rubbing strake, its thin sections follow the hull
        # rather than forming a generic long rectangular side rail.
        for i: int in range(stations.size()-1):
            var a := at + Vector3(stations[i],heights[i]+0.025,side*breadth[i])
            var b := at + Vector3(stations[i+1],heights[i+1]+0.025,side*breadth[i+1])
            var d := a + Vector3(0,0.065,side*0.032)
            var c := b + Vector3(0,0.065,side*0.032)
            _quad(st,a,b,c,d,Color("88745b"))
    # Thwarts and the visible inner keel preserve the empty vessel silhouette.
    for x: float in [-0.92,0.0,0.92]:
        _box(st,at+Vector3(x,0.41,0),Vector3(0.14,0.085,1.34),
            Color("857154"))
    _box(st,at+Vector3(0,0.11,0),Vector3(3.35,0.10,0.14),
        Color("4f463a"))
    # Interior ribs are carried by the boat artwork, not by salvaged part IDs.
    for i: int in range(1,stations.size()-1):
        var rib_width: float = breadth[i]*1.68
        _box(st,at+Vector3(stations[i],0.22,0),
            Vector3(0.075,0.11,rib_width),Color("4f4336"))

static func _quad(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,d: Vector3,
        tint: Color) -> void:
    _tri(st,a,b,c,tint)
    _tri(st,a,c,d,tint.darkened(0.075))

static func _tri(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,
        tint: Color) -> void:
    var n: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        st.set_normal(n)
        st.set_color(tint)
        st.add_vertex(p)

func _mesh(st: SurfaceTool, name: String, sea: bool) -> void:
    var visual := MeshInstance3D.new()
    visual.name = name
    visual.mesh = st.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.97 if sea else 0.99
    visual.material_override = material
    add_child(visual)

static func _box(st: SurfaceTool, center: Vector3, size: Vector3, tint: Color) -> void:
    HMPhaseCSurfaceDetail._box(st,center,size,tint)
