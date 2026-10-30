extends SceneTree
## Test actual Godot collider-backed roof bodies in their current world,
## rather than trusting only source JSON or a picture of the skyline.
var failures: Array[String] = []
const GROUPS: Array[String] = [
    "chapel/ordinary_hall", "district/mara_home",
    "district/upper_cottage_cluster_study", "craft/tomas_workshop",
    "harbour/office", "harbour/net_store"]

func _initialize() -> void:
    call_deferred("_check")

func expect(ok: bool,detail: String) -> void:
    if not ok:
        failures.append(detail)
        push_error("G3_ROOF_GEOMETRY: "+detail)

func _check() -> void:
    var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/v1/brinewick_district_builds.json"))
    expect(raw is Dictionary,"Original world building manifest readable")
    var stage:=HMBrinewickBlockout.new()
    stage.spawn_exploration_player=false
    root.add_child(stage)
    for i: int in range(4):
        await physics_frame
    var counts: Dictionary={}
    for data: Variant in raw["installations"]:
        var group_info: Dictionary=data
        var key: String=String(group_info["id"])
        if not GROUPS.has(key):
            continue
        var group: Node3D=stage.district_sites.installation_nodes.get(key,null)
        expect(group != null,"Existing installed group "+key)
        if group == null:
            continue
        var count: int=0
        for geom: Variant in group_info["geometry"]:
            var entry: Dictionary=geom
            var offset: Array=entry.get("offset",[])
            if String(entry.get("material",""))!="roof" or offset.size()!=3:
                continue
            var sign_x: float=signf(float(offset[0]))
            if is_zero_approx(sign_x):
                continue
            var name: String=String(entry["name"])
            var body: StaticBody3D=group.get_node_or_null(name) as StaticBody3D
            expect(body != null,"Roof installed as original body "+key+"/"+name)
            if body == null:
                continue
            var slope: float=body.rotation_degrees.z
            expect(slope*sign_x<0.0,"Roof must ascend inward: "+key+"/"+name)
            var shape: CollisionShape3D=body.get_node_or_null("CollisionShape3D") as CollisionShape3D
            expect(shape != null,"Roof still has original collider "+key+"/"+name)
            var width: float=float(entry["size"][0])
            var inward: Vector3=Vector3(-sign_x*width*.43,0,0)
            var outward: Vector3=Vector3(sign_x*width*.43,0,0)
            var rise: float=body.to_global(inward).y-body.to_global(outward).y
            expect(rise>0.42,"Original pitched part rises from eaves toward ridge "+key+"/"+name)
            count+=1
        counts[key]=count
    var seen: int=0
    for group: String in GROUPS:
        expect(int(counts.get(group,0))>=2,"Built roof courses checked "+group)
        seen+=int(counts.get(group,0))
    expect(seen==64,"64 original source/collider-backed roof bodies checked")
    var saved:=HMPartLifecycle.new()
    stage.add_child(saved)
    saved.bind_stage(stage)
    expect(saved.installed.size()==345,"Roof fix does not alter original 345 salvage targets")
    stage.queue_free()
    await process_frame
    if failures.is_empty():
        print("HOLLOWMERE_G3_ROOFS_CORRECT_OK sections=64")
        quit(0)
    else:
        quit(1)
