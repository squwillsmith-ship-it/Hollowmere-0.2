class_name HMSettlementProductionArt
extends Node3D
## Replaces provisional box *rendering* with authored faceted material assemblies.
## Child meshes belong to their original collider-backed target. No new
## dismantle target, save ID, tool tier, or machine action is ever introduced.
const STONE: Color = Color("6c6b60")
const TIMBER: Color = Color("554738")
const LIME: Color = Color("aaa087")
const SLATE: Color = Color("444f51")
var finished_bodies: int = 0
var finished_roofs: int = 0
var stone_courses: int = 0
var carved_details: int = 0
var original_visible_boxes: int = 0
var grain_texture: Texture2D

func build(installations: Dictionary) -> void:
    if finished_bodies > 0:
        return
    for id: String in installations:
        var installation: Node3D = installations[id]
        var queue: Array[Node] = [installation]
        while not queue.is_empty():
            var node: Node = queue.pop_back()
            for child: Node in node.get_children():
                queue.append(child)
            var body: StaticBody3D = node as StaticBody3D
            if body == null or body.has_node("ProductionFacetSkin"):
                continue
            # Explicit architectural-detail profiles already have separate,
            # per-removable-part meshes. Never conceal those source assemblies.
            if body.has_node("ArchitecturalDetail"):
                continue
            var old: MeshInstance3D
            for child: Node in body.get_children():
                var candidate: MeshInstance3D = child as MeshInstance3D
                if candidate != null and candidate.mesh is BoxMesh:
                    old = candidate
                    break
            if old == null:
                continue
            var dimensions: Vector3 = (old.mesh as BoxMesh).size
            var old_finish: StandardMaterial3D = old.material_override as StandardMaterial3D
            var base_color: Color = old_finish.albedo_color if old_finish != null else STONE
            var profile: String = _profile(id, String(body.name), base_color)
            var detail := MeshInstance3D.new()
            detail.name = "ProductionFacetSkin"
            if profile == "stone":
                detail.mesh = _stonework(dimensions, String(body.name), base_color)
            elif profile == "roof":
                detail.mesh = _slates(dimensions, String(body.name), base_color)
                finished_roofs += 1
            elif profile == "deck":
                detail.mesh = _lapped_board_surface(dimensions, String(body.name), base_color)
            elif profile == "lime":
                detail.mesh = _lime_infill(dimensions, String(body.name), base_color)
            else:
                detail.mesh = _hand_hewn(dimensions, String(body.name), base_color)
            # V03: common tileable material overlays, keeping the original
            # source-coloured faces and the EXACT same collider/body owner.
            var surface_key: String = "slate" if profile == "roof" else ("stone" if profile == "stone" else ("lime" if profile == "lime" else ("deck" if profile == "deck" else "timber")))
            var material: StandardMaterial3D = HMPhaseBMaterials.make_tinted(surface_key,Color.WHITE)
            detail.material_override = material
            body.add_child(detail)
            old.visible = false
            original_visible_boxes += 1
            finished_bodies += 1
        _landmark(installation, id)
    set_meta("visual_only_preserves_colliders", true)
    set_meta("source_boxes_concealed", original_visible_boxes)

func _grain() -> Texture2D:
    if grain_texture != null:
        return grain_texture
    var noise := FastNoiseLite.new()
    noise.seed = 71531
    noise.frequency = 0.12
    noise.fractal_octaves = 3
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    var img := Image.create_empty(128,128,false,Image.FORMAT_RGB8)
    for y: int in range(128):
        for x: int in range(128):
            var amount: float = clampf(0.964 + noise.get_noise_2d(float(x),float(y))*0.055,0.90,0.99)
            img.set_pixel(x,y,Color(amount,amount*0.991,amount*0.975))
    grain_texture = ImageTexture.create_from_image(img)
    return grain_texture

static func _profile(installation_id: String, title: String, color: Color) -> String:
    var lower: String = title.to_lower()
    if lower.contains("roof") or lower.contains("slate") or lower.contains("cowl"):
        return "roof"
    if lower.contains("lime") or lower.contains("plaster") or lower.contains("wattle") or lower.contains("infill") or lower.contains("schoolwall") or lower.contains("studywest") or lower.contains("studyeast"):
        return "lime"
    if lower.contains("deck") or lower.contains("landing") or lower.contains("ramp"):
        return "deck"
    if lower.contains("stone") or lower.contains("foot") or lower.contains("wall") or lower.contains("pier") or lower.contains("spine") or lower.contains("lintel") or lower.contains("plinth") or lower.contains("foundation") or lower.contains("masonry") or lower.contains("base"):
        return "stone"
    if installation_id.begins_with("chapel/") and (lower.contains("southentrance") or lower.contains("northend")):
        return "stone"
    if color.r > 0.58 and color.g > 0.55 and color.b > 0.45:
        return "lime"
    return "timber"

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tone)
        st.add_vertex(p)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        d: Vector3, tone: Color) -> void:
    _tri(st,a,b,c,tone)
    _tri(st,a,c,d,tone.darkened(0.028))

static func _rng(key: String, salt: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = absi(key.hash()) + salt
    return r

static func _core(st: SurfaceTool, dims: Vector3, tone: Color) -> void:
    var hx: float = dims.x*0.5
    var hy: float = dims.y*0.5
    var hz: float = dims.z*0.5
    # Eight shallow bevels remove the perfectly rectangular stone/timber edges.
    var bevel: float = minf(0.12,minf(dims.x,dims.z)*0.13)
    var ring: Array[Vector2] = [
        Vector2(-hx+bevel,-hz),Vector2(hx-bevel,-hz),
        Vector2(hx,-hz+bevel),Vector2(hx,hz-bevel),
        Vector2(hx-bevel,hz),Vector2(-hx+bevel,hz),
        Vector2(-hx,hz-bevel),Vector2(-hx,-hz+bevel)]
    for i: int in range(8):
        var j: int = (i+1)%8
        var a: Vector2 = ring[i]
        var b: Vector2 = ring[j]
        _quad(st,Vector3(a.x,-hy,a.y),Vector3(b.x,-hy,b.y),
            Vector3(b.x,hy,b.y),Vector3(a.x,hy,a.y),
            tone * (0.78+float(i%4)*0.056))
        _tri(st,Vector3(0,hy,0),Vector3(a.x,hy,a.y),Vector3(b.x,hy,b.y),tone)
        _tri(st,Vector3(0,-hy,0),Vector3(b.x,-hy,b.y),Vector3(a.x,-hy,a.y),
            tone.darkened(0.19))

func _stonework(dims: Vector3,key: String,base: Color) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _core(st,dims,base.darkened(0.23))
    var r: RandomNumberGenerator = _rng(key,505)
    # Irregular, staggered dressed courses along the two dominant wall faces,
    # and grain-free slab facets for footings; all one batched drawable mesh.
    var facing_x: bool = dims.z > dims.x
    var span: float = dims.z if facing_x else dims.x
    var depth: float = dims.x if facing_x else dims.z
    var rows: int = clampi(ceili(dims.y/0.67),1,14)
    var cols: int = clampi(ceili(span/1.12),2,35)
    var tile_h: float = dims.y/float(rows)
    var tile_w: float = span/float(cols)
    for face: int in [-1,1]:
        for j: int in range(rows):
            var stagger: float = -0.5*tile_w if j%2 == 1 else 0.0
            for i: int in range(cols+1):
                var u0: float = maxf(-span*0.5, -span*0.5+float(i)*tile_w+stagger)
                var u1: float = minf(span*0.5, -span*0.5+float(i+1)*tile_w+stagger)
                if u1-u0 < tile_w*0.23:
                    continue
                var bottom: float = -dims.y*0.5+float(j)*tile_h+0.028
                var top: float = bottom+tile_h-0.047
                var gap: float = r.randf_range(0.014,0.042)
                var lift: float = float(face)*(depth*0.5+r.randf_range(0.022,0.066))
                var tint: Color = base * r.randf_range(0.84,1.04)
                var a := Vector3(lift,bottom,u0+gap) if facing_x else Vector3(u0+gap,bottom,lift)
                var b := Vector3(lift,top,u0+gap*0.8) if facing_x else Vector3(u0+gap*0.8,top,lift)
                var c := Vector3(lift,top-0.016,u1-gap) if facing_x else Vector3(u1-gap,top-0.016,lift)
                var d := Vector3(lift,bottom+0.015,u1-gap) if facing_x else Vector3(u1-gap,bottom+0.015,lift)
                _quad(st,a,b,c,d,tint)
                stone_courses += 1
    return st.commit()

func _hand_hewn(dims: Vector3,key: String,base: Color) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _core(st,dims,base)
    var r: RandomNumberGenerator = _rng(key,612)
    var segments: int = clampi(ceili(maxf(dims.x,maxf(dims.y,dims.z))/0.52),2,24)
    var long_y: bool = dims.y >= dims.x and dims.y >= dims.z
    for i: int in range(segments):
        var center: float = -0.5+(float(i)+0.5)/float(segments)
        var width: float = r.randf_range(0.014,0.032)
        var shade: Color = base * r.randf_range(0.72,0.91)
        if long_y:
            var y: float = center*dims.y
            _quad(st,Vector3(-dims.x*0.51,y,-dims.z*0.5),
                Vector3(dims.x*0.51,y,-dims.z*0.5),
                Vector3(dims.x*0.51,y+width,-dims.z*0.5),
                Vector3(-dims.x*0.51,y+width,-dims.z*0.5),shade)
        else:
            var x: float = center*dims.x
            _quad(st,Vector3(x,-dims.y*0.5,-dims.z*0.515),
                Vector3(x+width,-dims.y*0.5,-dims.z*0.515),
                Vector3(x+width,dims.y*0.5,-dims.z*0.515),
                Vector3(x,dims.y*0.5,-dims.z*0.515),shade)
    return st.commit()

func _lime_infill(dims: Vector3,key: String,base: Color) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _core(st,dims,base.darkened(0.035))
    var r: RandomNumberGenerator = _rng(key,1771)
    var w: float = maxf(dims.x,dims.z)
    var long_x: bool = dims.x > dims.z
    for side: int in [-1,1]:
        var depth: float = float(side)*(minf(dims.x,dims.z)*0.5+0.006)
        for x: int in range(5):
            for y: int in range(4):
                var u0: float = -w*0.5+w*float(x)/5.0
                var u1: float = u0+w/5.0
                var v0: float = -dims.y*0.5+dims.y*float(y)/4.0
                var v1: float = v0+dims.y/4.0
                var tint: Color = base * r.randf_range(0.93,1.035)
                var a := Vector3(u0,v0,depth) if long_x else Vector3(depth,v0,u0)
                var b := Vector3(u1,v0,depth) if long_x else Vector3(depth,v0,u1)
                var c := Vector3(u1,v1,depth) if long_x else Vector3(depth,v1,u1)
                var d := Vector3(u0,v1,depth) if long_x else Vector3(depth,v1,u0)
                _quad(st,a,b,c,d,tint)
    return st.commit()

func _lapped_board_surface(dims: Vector3,key: String,base: Color) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _core(st,dims,base.darkened(0.1))
    var r: RandomNumberGenerator = _rng(key,3514)
    var along_z: bool = dims.z > dims.x
    var width: float = dims.x if along_z else dims.z
    var count: int = clampi(ceili(width/0.41),2,44)
    for i: int in range(count):
        var left: float = -width*0.5+width*float(i)/float(count)+0.017
        var right: float = -width*0.5+width*float(i+1)/float(count)-0.018
        var y: float = dims.y*0.5+0.012+r.randf_range(0,0.026)
        var tint: Color = base * r.randf_range(0.75,1.1)
        if along_z:
            _quad(st,Vector3(left,y,-dims.z*0.5),Vector3(left,y,dims.z*0.5),
                Vector3(right,y,dims.z*0.5),Vector3(right,y,-dims.z*0.5),tint)
        else:
            _quad(st,Vector3(-dims.x*0.5,y,left),Vector3(dims.x*0.5,y,left),
                Vector3(dims.x*0.5,y,right),Vector3(-dims.x*0.5,y,right),tint)
    return st.commit()

func _slates(dims: Vector3,key: String,base: Color) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _core(st,dims,base.darkened(0.16))
    var r: RandomNumberGenerator = _rng(key,2901)
    var across: int = clampi(ceili(dims.x/0.50),3,42)
    var rows: int = clampi(ceili(dims.z/0.66),3,35)
    for row: int in range(rows):
        for col: int in range(across):
            var slate_width: float = dims.x/float(across)
            var offset: float = slate_width*0.32 if row%2 == 1 else 0.0
            var x0: float = maxf(-dims.x*0.5,-dims.x*0.5+slate_width*float(col)-offset)
            var x1: float = minf(dims.x*0.5,-dims.x*0.5+slate_width*float(col+1)-offset-0.012)
            if x1-x0 < slate_width*0.28:
                continue
            var z0: float = -dims.z*0.5+dims.z*float(row)/float(rows)
            var z1: float = -dims.z*0.5+dims.z*float(row+1)/float(rows)+0.035
            var h: float = dims.y*0.5+0.022+r.randf_range(0.0,0.018)
            var tint: Color = base * r.randf_range(0.82,1.03)
            _quad(st,Vector3(x0,h,z0),Vector3(x0,h,z1),
                Vector3(x1,h,z1),Vector3(x1,h,z0),tint)
    return st.commit()

func _landmark(site: Node3D, id: String) -> void:
    # Distinct skyline silhouettes in addition to reworked visible volumes.
    # Extra members are non-colliding protected architectural dressing.
    if id == "harbour/navigation_light":
        for y: float in [2.25,4.7,7.1]:
            for sign: float in [-1.0,1.0]:
                _beam(site,"LightWindBrace",Vector3(sign*1.9,y,-1.9),
                    Vector3(sign*1.9,y+1.6,1.9),0.17,Color("4b514d"))
        _beam(site,"LanternRainCap",Vector3(-2.4,12.27,0),
            Vector3(2.4,12.27,0),0.24,SLATE)
    elif id == "chapel/ordinary_hall":
        for x: float in [-6.35,6.35]:
            for z: float in [-3.65,0.0,3.65]:
                _beam(site,"ChapelRakedButtress",
                    Vector3(x,0.32,z),Vector3(x*0.94,4.6,z),
                    0.38,STONE)
        for x: float in [-6.2,6.2]:
            _beam(site,"ChapelWeatheredFascia",
                Vector3(x,6.3,-5.45),Vector3(x,6.3,5.45),
                0.18,TIMBER)
    elif id == "service/landing_pier":
        for x: float in [-4.8,-2.4,0.0,2.4,4.8]:
            _beam(site,"LandingFender",Vector3(x,-1.1,-2.7),
                Vector3(x,0.5,-2.7),0.24,Color("574b3c"))
    elif id == "service/boatyard_base":
        for z: float in [-2.7,2.7]:
            _beam(site,"ShelterKneeBrace",
                Vector3(-4.25,2.35,z),Vector3(-3.08,3.4,z),0.2,TIMBER)
            _beam(site,"ShelterKneeBrace",
                Vector3(4.25,2.35,z),Vector3(3.08,3.4,z),0.2,TIMBER)

func _beam(parent: Node3D, title: String, a: Vector3,b: Vector3,
        width: float, color: Color) -> void:
    # Anchor each facade brace to a pre-existing structural part rather
    # than the immortal installation root. When the player dismantles that
    # part, this entire decorative beam disappears with its parent, and
    # restored saves cannot leave an independent floating beam behind.
    var owner: StaticBody3D
    var closest: float = INF
    var middle: Vector3 = (a+b)*0.5
    var has_removable: bool = false
    for node: Node in parent.get_children():
        if node is HMInspectTarget:
            has_removable = true
            break
    for node: Node in parent.get_children():
        var candidate: StaticBody3D = node as StaticBody3D
        if candidate == null:
            continue
        if has_removable and not (candidate is HMInspectTarget):
            continue
        var distance: float = candidate.position.distance_squared_to(middle)
        if distance < closest:
            closest = distance
            owner = candidate
    # Do not add a detached piece where no part can actually own it.
    if owner == null:
        return
    var local_a: Vector3 = owner.to_local(parent.to_global(a))
    var local_b: Vector3 = owner.to_local(parent.to_global(b))
    var direction: Vector3 = local_b-local_a
    if direction.length() < 0.1:
        return
    var mesh := MeshInstance3D.new()
    mesh.name = title+"_"+str(carved_details)
    var box := BoxMesh.new()
    box.size = Vector3(width,direction.length(),width*0.83)
    mesh.mesh = box
    mesh.position = (local_a+local_b)*0.5
    mesh.quaternion = Quaternion(Vector3.UP,direction.normalized())
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    mesh.material_override = mat
    owner.add_child(mesh)
    carved_details += 1
