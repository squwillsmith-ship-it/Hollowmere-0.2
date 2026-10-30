class_name HMG3ArchitecturalSignature
extends Node3D
## Purely visual, original-owner-bound G3 architectural repair skins.
const DATA: String = "res://data/v1/brinewick_district_builds.json"
const GROUPS: Array[String] = [
    "district/mara_home", "district/upper_cottage_cluster_study",
    "craft/tomas_workshop", "harbour/net_store", "harbour/office",
    "chapel/ordinary_hall", "chapel/schoolroom_wing", "chapel/aldren_study"
]
var finished: bool = false
var decorated_faces: int = 0
var removable_faces: int = 0
var roof_rakes: int = 0
var group_counts: Dictionary = {}

func build(installations: Dictionary, facade: HMG3TexturedStructureAssembly) -> void:
    if finished:
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    if not (parsed is Dictionary) or facade == null or not facade.finished:
        push_error("G3 signatures missing installed source")
        return
    for raw: Variant in parsed.get("installations", []):
        if not (raw is Dictionary):
            continue
        var entry: Dictionary = raw
        var key: String = String(entry.get("id", ""))
        if not GROUPS.has(key):
            continue
        var group: Node3D = installations.get(key, null) as Node3D
        if group == null:
            push_error("G3 signature missing original "+key)
            continue
        var count: int = 0
        for row: Variant in entry.get("geometry", []):
            if not (row is Dictionary):
                continue
            var piece: Dictionary = row
            var name: String = String(piece.get("name", ""))
            var material: String = String(piece.get("material", ""))
            var values: Array = piece.get("size", [])
            if values.size() != 3:
                continue
            var size := Vector3(float(values[0]), float(values[1]), float(values[2]))
            var roof: bool = material == "roof" and (
                name.ends_with("Course_01") or name.ends_with("Course_06") or
                (not name.contains("Course_")))
            var wall: bool = _should_repair(name, material, size)
            if not roof and not wall:
                continue
            var owner: StaticBody3D = facade._original_owner(group, piece)
            if owner == null:
                push_error("G3 signature owner absent "+key+"/"+name)
                continue
            if owner.has_node("G3ArchitecturalSignature"):
                continue
            var surface := SurfaceTool.new()
            surface.begin(Mesh.PRIMITIVE_TRIANGLES)
            if roof:
                _roof_rake(surface, size)
            else:
                _repair(surface, size, material, owner.position, name)
            var mesh: ArrayMesh = surface.commit()
            if mesh == null or mesh.get_surface_count() == 0:
                continue
            var skin := MeshInstance3D.new()
            skin.name = "G3ArchitecturalSignature"
            skin.mesh = mesh
            var finish := StandardMaterial3D.new()
            finish.vertex_color_use_as_albedo = true
            finish.cull_mode = BaseMaterial3D.CULL_DISABLED
            finish.roughness = .98
            skin.material_override = finish
            skin.set_meta("g3_noncolliding", true)
            skin.set_meta("g3_original_group", key)
            if owner is HMInspectTarget:
                skin.set_meta("g3_saved_owner_part_id", (owner as HMInspectTarget).part_id)
                removable_faces += 1
            owner.add_child(skin)
            decorated_faces += 1
            count += 1
            if roof:
                roof_rakes += 1
        group_counts[key] = count
    finished = true
    set_meta("g3_visual_only_preserves_345_owners", true)

func _should_repair(name: String, material: String, dims: Vector3) -> bool:
    if not material in ["plaster", "stone", "wood", "wood_dark", "wood_salt"]:
        return false
    var lower: String = name.to_lower()
    if lower.contains("door") or lower.contains("entry") or lower.contains("lintel"):
        return false
    var valid: bool = false
    for marker: String in ["panel", "stud", "frame", "wall", "masonry",
            "spine", "pier", "weatherboard", "studyback"]:
        if lower.contains(marker):
            valid = true
            break
    return valid and dims.y > .7 and (posmod(name.hash(), 3) == 0 or dims.x > 4.1)

func _repair(st: SurfaceTool, dims: Vector3, material: String,
        pos: Vector3, name: String) -> void:
    var along_x: bool = dims.x >= dims.z
    var span: float = dims.x if along_x else dims.z
    var depth: float = dims.z if along_x else dims.x
    var signum: float = 1.0 if (pos.z if along_x else pos.x) >= 0.0 else -1.0
    var face: float = signum * (depth * .60 + .055)
    if material == "plaster":
        _panel(st, along_x, -span * .10, -.12 * dims.y, face,
            span * .45, dims.y * .28, Color("afa997"))
        _bar(st, along_x, -span * .38, -dims.y * .39,
            span * .25, dims.y * .31, face, .047, Color("514c42"))
    elif material == "stone":
        _panel(st, along_x, span * .12, -dims.y * .28, face,
            span * .73, .095, Color("79796c"))
    else:
        _bar(st, along_x, -span * .34, -dims.y * .37,
            span * .18, dims.y * .30, face, .063, Color("777064"))
        _bar(st, along_x, span * .15, -dims.y * .40,
            span * .32, dims.y * .13, face, .052, Color("4c4941"))
        if posmod(name.hash(), 2) == 0:
            _panel(st, along_x, -span * .13, dims.y * .20,
                face, span * .34, .09, Color("555248"))

func _roof_rake(st: SurfaceTool, dims: Vector3) -> void:
    var y: float = dims.y * .55 + .040
    _bar(st, true, -dims.x * .43, y, dims.x * .43, y,
        -dims.z * .51, .080, Color("656157"))
    _bar(st, true, -dims.x * .38, y + .006, dims.x * .41, y + .006,
        dims.z * .51, .062, Color("4a5251"))

func _at(long_x: bool, u: float, v: float, w: float) -> Vector3:
    return Vector3(u, v, w) if long_x else Vector3(w, v, u)

func _panel(st: SurfaceTool, long_x: bool, u: float, v: float,
        w: float, dx: float, dy: float, color: Color) -> void:
    var a := _at(long_x, u-dx*.51, v-dy*.49, w)
    var b := _at(long_x, u+dx*.49, v-dy*.50, w)
    var c := _at(long_x, u+dx*.46, v+dy*.48, w)
    var d := _at(long_x, u-dx*.48, v+dy*.51, w)
    _tri(st, a, b, c, color)
    _tri(st, a, c, d, color.darkened(.045))

func _bar(st: SurfaceTool, along_x: bool, u0: float, v0: float,
        u1: float, v1: float, depth: float, thick: float, tone: Color) -> void:
    var direction := Vector2(u1-u0, v1-v0).normalized()
    var n := Vector2(-direction.y, direction.x) * thick * .5
    var a := _at(along_x, u0+n.x, v0+n.y, depth)
    var b := _at(along_x, u1+n.x, v1+n.y, depth)
    var c := _at(along_x, u1-n.x, v1-n.y, depth)
    var d := _at(along_x, u0-n.x, v0-n.y, depth)
    _tri(st, a, b, c, tone)
    _tri(st, a, c, d, tone.darkened(.06))

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        tint: Color) -> void:
    var normal: Vector3 = (b-a).cross(c-a).normalized()
    for p: Vector3 in [a, b, c]:
        st.set_color(tint)
        st.set_normal(normal)
        st.add_vertex(p)
