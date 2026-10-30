class_name HMG3RoofWeatherFinish
extends Node3D
## G3: hand-sized slate sections with salt-worn edges on the sixty-four
## original pitched roof owners. Independent roof colliders/part IDs and
## saved manual dismantling are unmodified; each tile batch dies with owner.
const SPEC: String = "res://data/v1/brinewick_district_builds.json"
const GROUPS: Array[String] = [
    "chapel/ordinary_hall",
    "district/mara_home",
    "district/upper_cottage_cluster_study",
    "craft/tomas_workshop",
    "harbour/office",
    "harbour/net_store"]
var owners: int=0
var triangles: int=0

func build(installations: Dictionary) -> void:
    if owners>0:
        return
    var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(SPEC))
    if not (doc is Dictionary):
        push_error("G3 roof art cannot read canonical roof manifest")
        return
    for raw: Variant in doc["installations"]:
        var entry: Dictionary=raw
        var id: String=String(entry["id"])
        if not GROUPS.has(id):
            continue
        var group: Node3D=installations.get(id,null) as Node3D
        if group==null:
            push_error("G3 roof finish missing original installation "+id)
            continue
        for raw_part: Variant in entry["geometry"]:
            var component: Dictionary=raw_part
            if String(component.get("material",""))!="roof":
                continue
            var angles: Array=component.get("rotation",[])
            var offset: Array=component.get("offset",[])
            if angles.size()!=3 or offset.size()!=3 or is_zero_approx(float(offset[0])):
                continue
            var title: String=String(component["name"])
            var body: StaticBody3D=group.get_node_or_null(title) as StaticBody3D
            if body==null:
                push_error("G3 roof finish missing physical part "+id+"/"+title)
                continue
            if body.has_node("G3SlateWeatherCourses"):
                continue
            var size_data: Array=component["size"]
            var dims:=Vector3(float(size_data[0]),float(size_data[1]),float(size_data[2]))
            var surface:=SurfaceTool.new()
            surface.begin(Mesh.PRIMITIVE_TRIANGLES)
            var cols: int=clampi(roundi(dims.x/.43),3,24)
            var rows: int=clampi(roundi(dims.z/.42),2,28)
            for row: int in range(rows):
                for col: int in range(cols):
                    var seed: int=(row*13+col*29+title.hash())
                    var variation: float=float(posmod(seed,7))/6.0
                    var x0: float=-dims.x*.5+float(col)*dims.x/float(cols)+(.016 if row%2 else -.012)
                    var z0: float=-dims.z*.5+float(row)*dims.z/float(rows)
                    var width: float=dims.x/float(cols)*(.975-.025*variation)
                    var length: float=dims.z/float(rows)*(1.008+variation*.013)
                    var y: float=dims.y*.5+.018+variation*.004
                    var tone:=Color("59615d").lerp(Color("70726b"),variation*.66)
                    var p:=Vector3(x0,y,z0)
                    _tri(surface,p,p+Vector3(width,0,0),p+Vector3(width,0,length),tone)
                    _tri(surface,p,p+Vector3(width,0,length),p+Vector3(0,0,length),tone.darkened(.027))
                    triangles+=2
            var visual:=MeshInstance3D.new()
            visual.name="G3SlateWeatherCourses"
            visual.mesh=surface.commit()
            var mat:=StandardMaterial3D.new()
            mat.vertex_color_use_as_albedo=true
            mat.roughness=.97
            mat.cull_mode=BaseMaterial3D.CULL_DISABLED
            visual.material_override=mat
            visual.set_meta("g3_original_roof_owner",title)
            visual.set_meta("g3_noncolliding",true)
            body.add_child(visual)
            owners+=1
    set_meta("g3_original_roof_art_owners",owners)
    set_meta("g3_no_new_salvage_collider",true)

func _tri(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
    var normal: Vector3=(b-a).cross(c-a).normalized()
    for v: Vector3 in [a,b,c]:
        tool.set_normal(normal)
        tool.set_color(color)
        tool.add_vertex(v)
