class_name HMCoastalProductionSurface
extends RefCounted
## Renderer-only rock/soil/track surfaces generated to match immutable
## HMBrinewickBlockout physics volumes. Angular geological facets, not tiles.
## Deterministic world-space noise prevents fake alternating checkerboards.
static func create(size: Vector3, name: String, base: Color, path: bool) -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(name.hash()) + 98173
    var nx: int = clampi(ceili(size.x/(1.55 if path else 2.75)),3,48)
    var nz: int = clampi(ceili(size.z/(1.55 if path else 2.75)),3,48)
    # Smooth low-poly ruts and turf seams; route heights stay within
    # centimetres of the colliding road slab so player feet do not float.
    var top: float = size.y*0.5+(0.016 if path else 0.045)
    var height: Array[PackedFloat32Array] = []
    for z: int in range(nz+1):
        var row := PackedFloat32Array()
        for x: int in range(nx+1):
            var xx: float = float(x)/float(nx)
            var zz: float = float(z)/float(nz)
            var sweep: float = sin(xx*9.3+zz*4.1+float(name.hash()%11))*0.012
            var noise: float = rng.randf_range(-0.009,0.009) if path else rng.randf_range(-0.075,0.075)
            row.append(top+sweep+noise)
        height.append(row)
    for z: int in range(nz):
        for x: int in range(nx):
            var x0: float = size.x*(float(x)/float(nx)-0.5)
            var x1: float = size.x*(float(x+1)/float(nx)-0.5)
            var z0: float = size.z*(float(z)/float(nz)-0.5)
            var z1: float = size.z*(float(z+1)/float(nz)-0.5)
            var a := Vector3(x0,height[z][x],z0)
            var b := Vector3(x1,height[z][x+1],z0)
            var c := Vector3(x1,height[z+1][x+1],z1)
            var d := Vector3(x0,height[z+1][x],z1)
            var richness: float = rng.randf_range(0.93,1.065)
            var tint: Color = base * richness
            # Silt/gravel and grassy basalt vary in larger patches without
            # high-frequency small noise overpowering the faceted style.
            if not path:
                tint = tint.lerp(Color("6b7160"),0.11+0.10*sin(float(x)*0.51+float(z)*0.37))
            else:
                tint = tint.lerp(Color("716b5b"),0.10+0.06*sin(float(x)*0.4+float(z)*0.25))
            _tri(tool,a,c,b,tint)
            _tri(tool,a,d,c,tint.darkened(rng.randf_range(0.0,0.045)))
    if not path:
        # The entire vertical profile is sculpted into broad strata. The
        # collision remains protected behind this noninteractive art skin.
        for face: int in range(4):
            var along_x: bool = face < 2
            var count: int = nx if along_x else nz
            var span: float = size.x if along_x else size.z
            var rows: int = clampi(ceili(size.y/1.18),3,17)
            var edge: Array[PackedFloat32Array] = []
            for y: int in range(rows+1):
                var offsets := PackedFloat32Array()
                for i: int in range(count+1):
                    var u: float = float(i)/float(count)
                    var v: float = float(y)/float(rows)
                    # Broad grounded talus shoulders replace vertical boxed
                    # headland sides. The top lip stays alongside the original
                    # walkable collider, widening only towards the grounded toe.
                    # Cross-face frequencies intentionally differ so each cliff
                    # does not repeat the same ruler-straight polygon bands.
                    var toe: float = pow(1.0-v,1.55)
                    var apron: float = minf(size.y*0.39,4.65)
                    var broad: float = (sin(u*5.8+float(face)*2.3)*0.36
                        + sin(u*12.7+float(face)*0.91)*0.17)
                    var fractured: float = (sin(u*17.4+v*5.7+float(face))*0.13
                        + sin(u*8.1-v*11.3+float(face)*1.7)*0.11)
                    var expansion: float = 0.065+toe*(apron+broad)
                    offsets.append(maxf(0.04,expansion+
                        fractured*(0.19+toe*0.81)))
                edge.append(offsets)
            for row_index: int in range(rows):
                var height0: float = -size.y*0.5+size.y*float(row_index)/float(rows)
                var height1: float = -size.y*0.5+size.y*float(row_index+1)/float(rows)
                for col: int in range(count):
                    var u0: float = -span*0.5+span*float(col)/float(count)
                    var u1: float = -span*0.5+span*float(col+1)/float(count)
                    var p0: Vector3 = _cliff(face,size,u0,height0,edge[row_index][col])
                    var p1: Vector3 = _cliff(face,size,u1,height0,edge[row_index][col+1])
                    var p2: Vector3 = _cliff(face,size,u1,height1,edge[row_index+1][col+1])
                    var p3: Vector3 = _cliff(face,size,u0,height1,edge[row_index+1][col])
                    # Broken mineral layers vary by face and elevation, not
                    # evenly repeating alternate-colour horizontal belts.
                    var grain: float = rng.randf_range(0.87,1.06)
                    var exposure: float = float(row_index)/float(rows)
                    var dark_rock: Color = Color("4b5551")
                    var lifted_rock: Color = Color("747466")
                    var mineral: Color = dark_rock.lerp(lifted_rock,
                        clampf(exposure*0.58+0.24*sin(float(col)*0.71+
                        float(row_index)*0.83+float(face)),0.08,0.86))
                    var bedded: Color = mineral.lerp(base,0.19+
                        0.19*exposure)*grain
                    if (col+row_index+face)%2 == 0:
                        _tri(tool,p0,p1,p3,bedded)
                        _tri(tool,p1,p2,p3,bedded.darkened(0.055))
                    else:
                        _tri(tool,p0,p1,p2,bedded)
                        _tri(tool,p0,p2,p3,bedded.darkened(0.055))
    else:
        # Road-edge aggregate is flush with physics and visually softens the
        # original perfectly straight paved slab. Keep no shoulder colliders.
        for side: float in [-1.0,1.0]:
            var n: int = clampi(ceili(size.x/0.85),3,80)
            for i: int in range(n):
                var x0: float = size.x*(float(i)/float(n)-0.5)
                var x1: float = size.x*(float(i+1)/float(n)-0.5)
                var z: float = side*size.z*0.5
                var shade: Color = base.darkened(rng.randf_range(0.11,0.26))
                _tri(tool,Vector3(x0,top,z),Vector3(x1,top,z),
                    Vector3(x0+0.23,top-0.07,z+side*0.12),shade)
    return tool.commit()

static func _cliff(face: int, dims: Vector3, u: float,
        y: float, protrusion: float) -> Vector3:
    match face:
        0: return Vector3(u,y,dims.z*0.5+protrusion)
        1: return Vector3(-u,y,-dims.z*0.5-protrusion)
        2: return Vector3(dims.x*0.5+protrusion,y,-u)
        _: return Vector3(-dims.x*0.5-protrusion,y,u)

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3,c: Vector3,
        shade: Color) -> void:
    var n: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        tool.set_color(shade)
        tool.set_normal(n)
        tool.add_vertex(p)
