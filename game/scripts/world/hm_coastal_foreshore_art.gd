class_name HMCoastalForeshoreArt
extends Node3D
## Low-poly surf and accumulated stone below Brinewick's western seawall.
## All parts are visual-only so working quay, crane, salvage transport and
## tide machinery remain real deliberate player interactions.
var wash_bands: int = 0
var shore_rocks: int = 0

func build() -> void:
    if wash_bands > 0:
        return
    var stone_material := StandardMaterial3D.new()
    stone_material.vertex_color_use_as_albedo = true
    stone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    stone_material.roughness = 0.96
    var surf_material := StandardMaterial3D.new()
    surf_material.vertex_color_use_as_albedo = true
    surf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    surf_material.roughness = 0.85
    for i: int in range(12):
        var band := MeshInstance3D.new()
        band.name = "MutedSpindrift_%02d"%i
        band.mesh = _wash_strip(i)
        band.material_override = surf_material
        add_child(band)
        wash_bands += 1
    var rng := RandomNumberGenerator.new()
    rng.seed = 412197
    # Seaward side, not across any first-person access route or receiving
    # pad. Broken rock is scenic, not a new invisible ore or salvage lot.
    for i: int in range(94):
        # Clusters of deposited basalt instead of two parallel 47-rock rows.
        # This stays on the sea side of the quay, clear of its working pad.
        var cluster: int = int(i / 8)
        var z: float = -43.0 + float(cluster) * 7.7 + rng.randf_range(-3.1,3.1)
        var x: float = -45.5 - float(cluster % 3) * 1.55 + rng.randf_range(-3.6,3.1)
        var radius: float = rng.randf_range(0.29,1.18)
        var color := Color("5d625a").lerp(Color("827d69"),rng.randf_range(0.16,0.58))
        var rock := MeshInstance3D.new()
        rock.name = "ShoreBasalt_%02d"%i
        rock.mesh = _basalt(radius, radius*rng.randf_range(0.48,0.82),
            radius*rng.randf_range(0.66,1.27),i,color)
        rock.material_override = stone_material
        rock.position = Vector3(x,-0.28,z+rng.randf_range(-0.55,0.55))
        rock.rotation_degrees.y = rng.randf_range(-175,175)
        add_child(rock)
        shore_rocks += 1
    set_meta("non_salveable_coastal_scenery",true)

static func _wash_strip(index: int) -> ArrayMesh:
    # A separate short, tapering wave-break per coastal segment. The previous
    # 12 continuous 97-metre strips looked like rigid parallel ruler lines.
    # Deterministic meshes keep authoring and screenshot parity reproducible.
    var mesh := SurfaceTool.new()
    mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7139 + index * 611
    var edge: float = -43.5 - float(index) * 1.65
    var tint: Color = Color("879b92").lerp(Color("617d77"),float(index)/12.0)
    var groups: int = 9 + index % 4
    for group: int in range(groups):
        var midpoint: float = -44.0 + (float(group) + 0.5) * 90.0 / float(groups)
        midpoint += rng.randf_range(-1.1,1.1)
        var extent: float = rng.randf_range(2.0,5.3)
        var width: float = rng.randf_range(0.055,0.16)
        var drift: float = rng.randf_range(-1.15,1.15)
        var segments: int = 6
        var y: float = -0.43 + float(index % 3) * 0.003
        for j: int in range(segments):
            var t0: float = float(j)/float(segments)
            var t1: float = float(j+1)/float(segments)
            var z0: float = midpoint - extent*0.5 + extent*t0
            var z1: float = midpoint - extent*0.5 + extent*t1
            var x0: float = edge + drift + sin(t0*TAU + float(group))*0.12
            var x1: float = edge + drift + sin(t1*TAU + float(group))*0.12
            var w0: float = width * sin(t0*PI)
            var w1: float = width * sin(t1*PI)
            var hue: Color = tint * (0.85 + rng.randf_range(0.0,0.11))
            _tri(mesh,Vector3(x0,y,z0),Vector3(x1,y,z1),
                Vector3(x1-w1,y,z1),hue)
            _tri(mesh,Vector3(x0,y,z0),Vector3(x1-w1,y,z1),
                Vector3(x0-w0,y,z0),hue.darkened(0.08))
    return mesh.commit()

static func _basalt(rx: float, height: float, rz: float,
        seed: int, tint: Color) -> ArrayMesh:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed+82111
    var mesh := SurfaceTool.new()
    mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    var ring: Array[Vector3] = []
    var count: int = 7+seed%3
    for n: int in range(count):
        var a: float = TAU*float(n)/float(count)
        var noise: float = rng.randf_range(0.78,1.14)
        ring.append(Vector3(cos(a)*rx*noise,
            rng.randf_range(-0.05,0.10),sin(a)*rz*noise))
    var apex := Vector3(rx*0.12,height,rz*0.05)
    for n: int in range(count):
        var m: int = (n+1)%count
        _tri(mesh,ring[n],apex,ring[m],tint*rng.randf_range(0.76,1.1))
        _tri(mesh,Vector3.ZERO,ring[m],ring[n],tint.darkened(0.21))
    return mesh.commit()

static func _tri(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        color: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a,b,c]:
        tool.set_color(color)
        tool.set_normal(normal)
        tool.add_vertex(p)
