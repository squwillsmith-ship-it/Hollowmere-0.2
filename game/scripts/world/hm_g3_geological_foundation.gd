class_name HMG3GeologicalFoundation
extends Node3D
## Original six plateaus: matching rendered and physical faceted earthwork.
const NAMES = ["UpperNorth","UpperSouth","HeadlandNorth",
    "HeadlandNorthEast","HeadlandNorthRear","HeadlandSouth"]
var reshaped: int = 0
var triangles: int = 0
var complete: bool = false
var original_bodies: Dictionary = {}

func build(terraces: Node3D,sites: Dictionary) -> void:
    if complete:
        return
    if sites.size()!=21:
        push_error("G3 terrain missing original site markers")
        return
    for title: String in NAMES:
        var body: StaticBody3D=terraces.get_node_or_null(title) as StaticBody3D
        if body==null:
            push_error("G3 missing plateau "+title)
            continue
        var collision: CollisionShape3D=body.get_node_or_null("CollisionShape3D")
        if collision==null or not (collision.shape is BoxShape3D):
            push_error("G3 missing original box collider "+title)
            continue
        var dims: Vector3=(collision.shape as BoxShape3D).size
        var st:=SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var faces:=PackedVector3Array()
        var nx: int=clampi(ceili(dims.x/2.25),6,44)
        var nz: int=clampi(ceili(dims.z/2.25),6,38)
        for zi: int in range(nz):
            for xi: int in range(nx):
                var x0: float=dims.x*(float(xi)/float(nx)-.5)
                var x1: float=dims.x*(float(xi+1)/float(nx)-.5)
                var z0: float=dims.z*(float(zi)/float(nz)-.5)
                var z1: float=dims.z*(float(zi+1)/float(nz)-.5)
                var a:=Vector3(x0,_height(body,dims,x0,z0,sites),z0)
                var b:=Vector3(x1,_height(body,dims,x1,z0,sites),z0)
                var c:=Vector3(x1,_height(body,dims,x1,z1,sites),z1)
                var d:=Vector3(x0,_height(body,dims,x0,z1,sites),z1)
                var t: float=sin(x0*.09+z0*.07+body.position.x*.031)
                var colour:=Color("697263").lerp(Color("858071"),.48+.27*t)
                _triangle(st,faces,a,d,c,colour)
                _triangle(st,faces,a,c,b,colour.darkened(.04))
        for side: int in range(4):
            var count: int=nx if side<2 else nz
            for yi: int in range(9):
                var t0: float=float(yi)/9.0
                var t1: float=float(yi+1)/9.0
                for i: int in range(count):
                    var u0: float=float(i)/float(count)
                    var u1: float=float(i+1)/float(count)
                    var a: Vector3=_edge(dims,title,side,u0,t0)
                    var b: Vector3=_edge(dims,title,side,u1,t0)
                    var c: Vector3=_edge(dims,title,side,u1,t1)
                    var d: Vector3=_edge(dims,title,side,u0,t1)
                    var tint:=Color("5f6960").lerp(Color("787668"),
                        .22+.36*t0+.1*sin(u0*17.0+float(side)))
                    _triangle(st,faces,a,b,c,tint)
                    _triangle(st,faces,a,c,d,tint.darkened(.10))
        var low: float=-dims.y*.5
        _triangle(st,faces,Vector3(-dims.x*.5,low,-dims.z*.5),
            Vector3(dims.x*.5,low,dims.z*.5),
            Vector3(-dims.x*.5,low,dims.z*.5),Color("4f5852"))
        _triangle(st,faces,Vector3(-dims.x*.5,low,-dims.z*.5),
            Vector3(dims.x*.5,low,-dims.z*.5),
            Vector3(dims.x*.5,low,dims.z*.5),Color("4f5852"))
        var mesh: ArrayMesh=st.commit()
        if mesh==null or faces.is_empty():
            push_error("G3 could not build geological mesh "+title)
            continue
        var shape:=ConcavePolygonShape3D.new()
        shape.backface_collision=true
        shape.data=faces
        var skin:=MeshInstance3D.new()
        skin.name="G3MatchedSculptedTopography"
        skin.mesh=mesh
        var mat:=StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo=true
        mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        mat.roughness=.98
        skin.material_override=mat
        for old: Node in body.get_children():
            if old is MeshInstance3D:
                (old as MeshInstance3D).visible=false
        body.add_child(skin)
        collision.shape=shape
        body.set_meta("g3_original_colliding_plateau",true)
        original_bodies[title]=body
        reshaped+=1
    complete=reshaped==6

func _height(body: StaticBody3D,dims: Vector3,x: float,z: float,
        sites: Dictionary) -> float:
    var edge: float=minf(dims.x*.5-absf(x),dims.z*.5-absf(z))
    var clearance: float=smoothstep(0.0,4.8,maxf(0.0,edge))
    var at: Vector3=body.to_global(Vector3(x,dims.y*.5,z))
    for item: Variant in sites.values():
        var marker: Node3D=item as Node3D
        var distance: float=Vector2(marker.global_position.x-at.x,
            marker.global_position.z-at.z).length()
        clearance=minf(clearance,smoothstep(8.0,16.0,distance))
    if at.x>48.0 and absf(at.z)<10.0:
        clearance=0.0
    var grain: float=.22*sin(at.x*.19+at.z*.11)
    grain+=.16*cos(at.x*.084-at.z*.165)
    return dims.y*.5+clearance*grain

func _edge(dims: Vector3,title: String,side: int,
        u: float,t: float) -> Vector3:
    var along: float=(u-.5)*(dims.x if side<2 else dims.z)
    var apron: float=0.0
    if title=="UpperNorth" or title=="UpperSouth":
        if (title=="UpperNorth" and side==1) or (
                title=="UpperSouth" and side==0):
            apron=8.0
        elif side<2:
            apron=1.0
    elif title=="HeadlandSouth":
        if side==0 or side==2:
            apron=9.0
    elif side==1:
        apron=8.5
    var spread: float=pow(t,1.55)*(apron+
        .48*sin(u*12.0+float(side)*1.6))
    spread=maxf(0.0,spread)
    var y: float=lerpf(dims.y*.5,-dims.y*.5,t)
    if side==0:
        return Vector3(along,y,dims.z*.5+spread)
    if side==1:
        return Vector3(along,y,-dims.z*.5-spread)
    if side==2:
        return Vector3(dims.x*.5+spread,y,along)
    return Vector3(-dims.x*.5-spread,y,along)

func _triangle(st: SurfaceTool,faces: PackedVector3Array,
        a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    var normal: Vector3=(b-a).cross(c-a).normalized()
    for v: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(v)
        faces.append(v)
    triangles+=1
