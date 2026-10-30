extends SceneTree
## Nine actual textured standalone GLBs must be owned by original salvageable
## bodies, not create new IDs, colliders, outputs or passive harvesting.
var errors: Array[String] = []
const PARTS: Array[String] = [
    "curtain","shutters","cladding","slate_patch","beam","stone_block",
    "front_infill","rear_infill","threshold"]

func _initialize() -> void:
    call_deferred("_check")

func demand(ok: bool,label: String) -> void:
    if not ok:
        errors.append(label)
        push_error("G2_COTTAGE_ASSET: "+label)

func _meshes(node: Node) -> int:
    var count: int = 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
    for child: Node in node.get_children():
        count += _meshes(child)
    return count

func _check() -> void:
    var cat := HMCatalog.new()
    demand(cat.load_all(),"Canonical catalogue")
    var manifest: Dictionary = HMBuildingPrefab.read_manifest(
        "res://data/v1/buildings/cottage_working_01.json")
    demand(HMBuildingPrefab.validate(manifest,cat).is_empty(),"Original part ID manifest")
    var cottage: Node3D = HMBuildingPrefab.build(manifest,cat)
    demand(cottage != null,"Nine-source GLB cottage builds")
    if cottage == null:
        quit(1)
        return
    root.add_child(cottage)
    var targets: Dictionary = {}
    for child: Node in cottage.get_children():
        if child is HMInspectTarget:
            targets[(child as HMInspectTarget).part_id.get_file()] = child
    demand(targets.size() == 9,"Nine original removable targets, no extras")
    for part: String in PARTS:
        var asset: String = "res://assets/models/g2/cottage/part_"+part+".glb"
        demand(ResourceLoader.exists(asset),"Standalone textured GLB "+part)
        var owner: HMInspectTarget = targets.get(part,null) as HMInspectTarget
        demand(owner != null,"Authoritative owner "+part)
        if owner == null:
            continue
        var model: Node3D = owner.get_node_or_null("G2ProductionPart") as Node3D
        demand(model != null,"Real GLB instance attached to "+part)
        demand(bool(owner.get_meta("g2_assembled",false)),"Authored G2 meta on "+part)
        var proxies: int = 0
        for node: Node in owner.get_children():
            if node is CollisionShape3D:
                proxies += 1
        demand(proxies > 0,"Original part collision preserved "+part)
        if model != null:
            demand(_meshes(model) > 0,"GLB has visible mesh primitives "+part)
            demand(String(model.get_meta("g2_owner_part_id","")) == owner.part_id,
                "No detached GLB owner for "+part)
    var holder := Node3D.new()
    root.add_child(holder)
    cottage.reparent(holder)
    var life := HMPartLifecycle.new()
    holder.add_child(life)
    life.bind_stage(holder)
    demand(life.installed.size() == 9,"No new or removed salvage IDs")
    var state: Dictionary = HMSaveState.fresh(cat)
    life.reconcile(state)
    demand(HMSaveState.validate(cat,state).is_empty(),"Save schema unchanged")
    var id: String = "fixture/house/curtain"
    var progress: Dictionary = HMTransactions.apply(cat,state,{
        "transaction_id":"g2/cottage/models/work","op":"partial_work",
        "part_id":id,"cycles":1,"user_initiated":true})
    demand(bool(progress.get("ok",false)),"Real user-initiated work unaffected")
    if bool(progress.get("ok",false)):
        var released: Dictionary = HMTransactions.apply(cat,progress["state"],{
            "transaction_id":"g2/cottage/models/release","op":"release",
            "part_id":id,"user_initiated":true,"access_aids":[]})
        demand(bool(released.get("ok",false)),"Original curtain release")
        if bool(released.get("ok",false)):
            life.reconcile(released["state"])
            demand(not (life.installed[id] as HMInspectTarget).visible,
                "New GLB disappears together with removed owner")
            demand(HMSaveState.validate(cat,released["state"]).is_empty(),
                "New visual does not change salvage conservation")
    holder.queue_free()
    await process_frame
    if errors.is_empty():
        print("HOLLOWMERE_G2_COTTAGE_ASSET_OK nine_owners=9")
        quit(0)
    else:
        quit(1)
