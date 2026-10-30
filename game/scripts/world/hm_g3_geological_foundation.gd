class_name HMG3GeologicalFoundation
extends Node3D
## Final G3 structural terrain attempt. Replaces SIX existing rectangular
## upper/headland earthwork meshes AND their collision with one matching,
## sculpted trimesh per original StaticBody3D. No new nodes with physics,
## no change in original body identity, saved IDs, roads or site positions.
const LAND: Array[String] = [
    "UpperNorth", "UpperSouth", "HeadlandNorth",
    "HeadlandNorthEast", "HeadlandNorthRear", "HeadlandSouth"
]
const ROCK: Color = Color("60685e")
const ROCK_DARK: Color = Color("4d5853")
const ROCK_LIGHT: Color = Color("818070")
var reshaped: int = 0
var original_bodies: Dictionary = {}
var triangles: int = 0
var complete: bool = false

func build(terraces: Node3D, sites: Dictionary) -> void:
    if complete:
        return
    if sites.size() != 21:
        push_error("G3 geological rebuild requires all 21 original site markers")
        return
    for key: String in LAND:
        var body: StaticBody3D = terraces.get_node_or_null(key) as StaticBody3D
        if body == null:
            push_error("Missing G3 original plateau body "+key)
            continue
        var collider: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if collider == null or not (collider.shape is BoxShape3D):
            push_error("Missing unchanged prior cliff BoxShape3D "+key)
            continue
        var original: Vector3 = (collider.shape as BoxShape3D).size
        if original.x < 3.0 or original.y < 5.0 or original.z < 8.0:
            push_error("Invalid plateau envelope "+key)
            continue
        var terrain: ArrayMesh = _mesh(body, original, key, sites)
        if terrain == null or terrain.get_surface_count() == 0:
            push_error("No replacement geology mesh "+key)
            continue
        var shape: ConcavePolygonShape3D = terrain.create_trimesh_shape() as ConcavePolygonShape3D
        if shape == null:
            push_error("Cannot create matched terrain collision "+key)
            continue
        shape.backface_collision = true
        var surface := MeshInstance3D.new()
        surface.name = "G3MatchedSculptedTopography"
        surface.mesh = terrain
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.roughness = .98
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        surface.material_override = mat
        # Hide original box and all prior overlaid rectangular cliff skin.
        # CollisionShape3D and road bodies must remain visible and active.
        for sibling: Node in body.get_children():
            if sibling is MeshInstance3D:
                (sibling as MeshInstance3D).visible = false
        body.add_child(surface)
        collider.shape = shape
        body.set_meta("g3_geology_original_body",true)
        body.set_meta("g3_geology_original_envelope",original)
        original_bodies[key] = body
        reshaped += 1
    complete = reshaped == LAND.size()
    set_meta("g3_true_visual_and_physics_geology",complete)

func _mesh(body: StaticBody3D,dims: Vector3,key: String,sites: Dictionary) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var nx: int = clampi(ceili(dims.x / 2.0),6,55)
    var nz: int = clampi(ceili(dims.z / 2.0),6,45)
    var height: Array[PackedFloat32Array] = []
    for zi: int in range(nz+1):
        var row := PackedFloat32Array()
        for xi: int in range(nx+1):
            var x: float = dims.x*(float(xi)/float(nx)-.5)
            var z: float = dims.z*(float(zi)/float(nz)-.5)
            row.append(_top(body,dims,x,z,sites))
        height.append(row)
    for zi: int in range(nz):
        for xi: int in range(nx):
            var x0: float = dims.x*(float(xi)/float(nx)-.5)
            var x1: float = dims.x*(float(xi+1)/float(nx)-.5)
            var z0: float = dims.z*(float(zi)/float(nz)-.5)
            var z1: float = dims.z*(float(zi+1)/float(nz)-.5)
            var a := Vector3(x0,height[zi][xi],z0)
            var b := Vector3(x1,height[zi][xi+1],z0)
            var c := Vector3(x1,height[zi+1][xi+1],z1)
            var d := Vector3(x0,height[zi+1][xi],z1)
            var grain: float = sin((x0+body.position.x)*.057+
                (z0+body.position.z)*.103)*.41+cos(x0*.092-z0*.037)*.24
            var base: Color = Color("747568").lerp(Color("646e61"),
                clampf(.45+grain*.38,0.0,1.0))
            _tri(st,a,d,c,base)
            _tri(st,a,c,b,base.darkened(.012))
            triangles += 2
    for side: int in range(4):
        var along_x: bool = side < 2
        var count: int = nx if along_x else nz
        var rings: int = clampi(ceili(dims.y/1.25),6,18)
        for yi: int in range(rings):
            var t0: float = float(yi)/float(rings)
            var t1: float = float(yi+1)/float(rings)
            for i: int in range(count):
                var u0: float = float(i)/float(count)
                var u1: float = float(i+1)/float(count)
                var a: Vector3 = _rim(body,dims,key,side,u0,t0,height,nx,nz)
                var b: Vector3 = _rim(body,dims,key,side,u1,t0,height,nx,nz)
                var c: Vector3 = _rim(body,dims,key,side,u1,t1,height,nx,nz)
                var d: Vector3 = _rim(body,dims,key,side,u0,t1,height,nx,nz)
                var mineral: float = sin(u0*17.7+t0*5.3+float(side)*2.6)
                var shade: Color = ROCK_DARK.lerp(ROCK_LIGHT,
                    clampf(t0*.37+.26+.21*mineral,.07,.80))
                _tri(st,a,b,c,shade)
                _tri(st,a,c,d,shade.darkened(.13))
                triangles += 2
    # Closed underside prevents a fall-through if a traversal ray or
    # physics test ever approaches from under the original fixed earthwork.
    var y: float = -dims.y*.5
    _tri(st,Vector3(-dims.x*.5,y,-dims.z*.5),
        Vector3(dims.x*.5,y,dims.z*.5),
        Vector3(-dims.x*.5,y,dims.z*.5),ROCK_DARK)
    _tri(st,Vector3(-dims.x*.5,y,-dims.z*.5),
        Vector3(dims.x*.5,y,-dims.z*.5),
        Vector3(dims.x*.5,y,dims.z*.5),ROCK_DARK)
    triangles += 2
    return st.commit()

func _top(body: StaticBody3D,dims: Vector3,x: float,z: float,
        sites: Dictionary) -> float:
    var top: float = dims.y*.5
    var edge: float = minf(dims.x*.5-absf(x),dims.z*.5-absf(z))
    var fade: float = smoothstep(0.0,5.0,maxf(0.0,edge))
    var world: Vector3 = body.to_global(Vector3(x,top,z))
    # All actual building pads and central haul road retain their prior
    # EXACT nominal top datum: no buried thresholds or unstable walking.
    var clear: float = 1.0
    for marker: Variant in sites.values():
        var at: Vector3 = (marker as Node3D).global_position
        var d: float = Vector2(world.x-at.x,world.z-at.z).length()
        clear = minf(clear,smoothstep(8.0,15.5,d))
    if world.x > 48.0 and absf(world.z) < 10.0:
        clear *= smoothstep(5.5,10.0,absf(world.z))
    var low: float = .20*sin(world.x*.23+world.z*.082)
    var broad: float = .15*cos(world.x*.085-world.z*.17)
    var broken: float = .072*sin(world.x*.64+world.z*.38)
    # Fine, 1B style faceted grades (<0.45m, flat on foundation pads).
    return top + fade*clear*(low+broad+broken)

func _rim(body: StaticBody3D,dims: Vector3,key: String,side: int,
        u: float,lower_fraction: float,heights: Array[PackedFloat32Array],
        nx: int,nz: int) -> Vector3:
    var strip_x: bool = side < 2
    var low: float = -dims.y*.5
    var along: float = (u-.5)*(dims.x if strip_x else dims.z)
    var index: int = roundi(u*float(nx if strip_x else nz))
    var top: float = dims.y*.5
    if side == 0:
        top = heights[nz][index]
    elif side == 1:
        top = heights[0][index]
    elif side == 2:
        top = heights[index][nx]
    else:
        top = heights[index][0]
    var y: float = lerpf(top,low,lower_fraction)
    var side_apron: float = _apron(key,side)
    var fan: float = pow(lower_fraction,1.4)
    var coastal_fold: float = .53*sin(u*10.3+float(side)*1.7)+.23*cos(u*24.7)
    var fractured: float = .19*sin(u*41.0+lower_fraction*9.3+float(side))
    var shift: float = fan*maxf(0.0,side_apron+coastal_fold)+
        fractured*fan*(1.0-lower_fraction)*.8
    if strip_x:
        var z: float = (dims.z*.5+shift) if side==0 else (-dims.z*.5-shift)
        return Vector3(along,y,z)
    var x: float = (dims.x*.5+shift) if side==2 else (-dims.x*.5-shift)
    return Vector3(x,y,along)

func _apron(name: String,side: int) -> float:
    # No overlap into the 10m-wide player-operated haul road.
    if name=="UpperNorth":
        return 7.6 if side==1 else (1.0 if side==0 else 0.0)
    if name=="UpperSouth":
        return 7.6 if side==0 else (1.0 if side==1 else 0.0)
    if name=="HeadlandSouth":
        return 9.2 if side==0 or side==2 else .28
    if name=="HeadlandNorth" or name=="HeadlandNorthEast" or name=="HeadlandNorthRear":
        return 9.0 if side==1 else (8.6 if side==2 and name=="HeadlandNorthEast" else .28)
    return 0.0

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    var n: Vector3=(b-a).cross(c-a).normalized()
    for vertex: Vector3 in [a,b,c]:
        st.set_color(tint)
        st.set_normal(n)
        st.add_vertex(vertex)
