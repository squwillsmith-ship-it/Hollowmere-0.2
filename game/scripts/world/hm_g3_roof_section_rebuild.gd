class_name HMG3RoofSectionRebuild
extends Node3D
## Replaces repeated flat rectangular roof skins on the 64 original roof
## bodies with complete low-poly slate/timber course geometry. Original
## independent HMInspectTarget bodies and physics volumes remain authoritative.
const SPEC: String = "res://data/v1/brinewick_district_builds.json"
const GROUPS: Array[String] = [
    "chapel/ordinary_hall", "district/mara_home",
    "district/upper_cottage_cluster_study", "craft/tomas_workshop",
    "harbour/office", "harbour/net_store"
]
var replaced: int = 0
var tessellated_triangles: int = 0
var original_removable: int = 0
var per_installation: Dictionary = {}
var finished: bool = false

func build(installations: Dictionary, facades: HMG3TexturedStructureAssembly) -> void:
    if finished:
        return
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
    if not (doc is Dictionary):
        push_error("G3 roof geometry requires existing district manifest")
        return
    for raw: Variant in doc.get("installations", []):
        if not (raw is Dictionary):
            continue
        var entry: Dictionary = raw
        var key: String = String(entry.get("id", ""))
        if not GROUPS.has(key):
            continue
        var group: Node3D = installations.get(key, null) as Node3D
        if group == null:
            push_error("G3 roof replacement missing group "+key)
            continue
        var count: int = 0
        for raw_piece: Variant in entry.get("geometry", []):
            if not (raw_piece is Dictionary):
                continue
            var piece: Dictionary = raw_piece
            if String(piece.get("material", "")) != "roof":
                continue
            var dimensions: Array = piece.get("size", [])
            if dimensions.size() != 3:
                continue
            var dims := Vector3(float(dimensions[0]),
                float(dimensions[1]),float(dimensions[2]))
            var original: StaticBody3D = facades._original_owner(group,piece)
            if original == null:
                push_error("G3 roof replacement lacks old owner "+key)
                continue
            if original.has_node("G3FullSlateSection"):
                continue
            var roof: ArrayMesh = _section(dims,String(piece.get("name","")))
            if roof == null or roof.get_surface_count() == 0:
                continue
            var visual := MeshInstance3D.new()
            visual.name = "G3FullSlateSection"
            visual.mesh = roof
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.roughness = .98
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            visual.material_override = material
            visual.set_meta("g3_original_roof_name",String(piece.get("name","")))
            visual.set_meta("g3_noncolliding",true)
            if original is HMInspectTarget:
                visual.set_meta("g3_original_saved_roof",
                    (original as HMInspectTarget).part_id)
                original_removable += 1
            for old: Node in original.get_children():
                if old is MeshInstance3D and (
                    (old as MeshInstance3D).mesh is BoxMesh or
                    old.name == "G3SlateWeatherCourses"):
                    (old as MeshInstance3D).visible = false
            original.add_child(visual)
            count += 1
            replaced += 1
        per_installation[key] = count
    finished = true
    set_meta("g3_preserves_individual_roof_dismantling",true)

func _section(size: Vector3,title: String) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var columns: int = clampi(roundi(size.x/.42),5,22)
    var rows: int = clampi(roundi(size.z/.34),2,12)
    var top: float = size.y*.5 + .026
    var underside: float = -size.y*.5
    var z_end: float = .13 if title.ends_with("Course_01") else (
        .12 if title.ends_with("Course_06") or title.ends_with("Course_07") else .015)
    for zi: int in range(rows):
        for xi: int in range(columns):
            var h: int = posmod(title.hash()+xi*19+zi*53,17)
            var variation: float = float(h)/16.0
            var u0: float = -size.x*.5+size.x*float(xi)/float(columns)
            var u1: float = -size.x*.5+size.x*float(xi+1)/float(columns)
            var v0: float = -size.z*.5+size.z*float(zi)/float(rows)
            var v1: float = -size.z*.5+size.z*float(zi+1)/float(rows)
            if xi == 0:
                u0 -= .11+variation*.045
            if xi == columns-1:
                u1 += .10+variation*.05
            if zi == 0:
                v0 -= z_end
            if zi == rows-1:
                v1 += z_end
            var rise: float = .014+variation*.025
            var base: Color=Color("505a57").lerp(Color("74766b"),variation*.78)
            var a:=Vector3(u0,top+rise,v0)
            var b:=Vector3(u1,top+rise*.77,v0)
            var c:=Vector3(u1,top+rise*.86,v1)
            var d:=Vector3(u0,top+rise*.92,v1)
            _tri(st,a,c,b,base)
            _tri(st,a,d,c,base.darkened(.052))
            tessellated_triangles += 2
    # Actual hewn edges, not just a floating coloured texture on the old box.
    var min_x: float=-size.x*.5-.13
    var max_x: float=size.x*.5+.14
    var front: float=-size.z*.5-z_end
    var back: float=size.z*.5+z_end
    var trim: Color=Color("564e44")
    _tri(st,Vector3(min_x,underside,front),Vector3(max_x,top,front),
        Vector3(max_x,underside,front),trim)
    _tri(st,Vector3(min_x,underside,front),Vector3(min_x,top,front),
        Vector3(max_x,top,front),trim.darkened(.07))
    _tri(st,Vector3(min_x,underside,back),Vector3(max_x,underside,back),
        Vector3(max_x,top,back),trim.darkened(.11))
    _tri(st,Vector3(min_x,underside,back),Vector3(max_x,top,back),
        Vector3(min_x,top,back),trim)
    _tri(st,Vector3(min_x,underside,front),Vector3(min_x,underside,back),
        Vector3(min_x,top,back),trim.darkened(.11))
    _tri(st,Vector3(min_x,underside,front),Vector3(min_x,top,back),
        Vector3(min_x,top,front),trim)
    _tri(st,Vector3(max_x,underside,front),Vector3(max_x,top,back),
        Vector3(max_x,underside,back),trim.darkened(.14))
    _tri(st,Vector3(max_x,underside,front),Vector3(max_x,top,front),
        Vector3(max_x,top,back),trim)
    tessellated_triangles += 8
    return st.commit()

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    var normal: Vector3=(b-a).cross(c-a).normalized()
    for point: Vector3 in [a,b,c]:
        st.set_color(tint)
        st.set_normal(normal)
        st.add_vertex(point)
