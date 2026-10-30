class_name HMG3TexturedStructureAssembly
extends Node3D
## G3 model -> materials -> assembled-structure stage.
## Authored GLB surfaces replace box-based rendering on the ORIGINAL
## StaticBody3D/HMInspectTarget nodes. Gameplay owners, colliders, positions,
## support rules, tool tiers, save IDs and narrative are never modified.
const SPEC: String = "res://data/v1/brinewick_district_builds.json"
const KIT_ROOT: String = "res://assets/models/g3/kit/"
const APPROVED_GROUPS: Array[String] = [
    "harbour/office", "harbour/net_store", "district/mara_home",
    "district/upper_cottage_cluster_study", "craft/tomas_workshop",
    "chapel/ordinary_hall", "chapel/schoolroom_wing",
    "chapel/aldren_study", "service/boatyard_base",
    "harbour/navigation_light"
]
const MATERIAL_PROFILES: Dictionary = {
    "stone": "stone", "plaster": "lime", "wood": "timber",
    "wood_dark": "timber", "wood_salt": "timber"
}
var finished: bool = false
var assembled_parts: int = 0
var removable_owners: int = 0
var static_owners: int = 0
var installation_counts: Dictionary = {}
var owner_names: Dictionary = {}
var loaded_models: Dictionary = {}

func build(installations: Dictionary) -> void:
    if finished:
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
    if not (parsed is Dictionary):
        push_error("G3 structure assembly requires original district source")
        return
    var rows: Variant = parsed.get("installations", null)
    if not (rows is Array):
        push_error("G3 assembly cannot read original installations")
        return
    for raw: Variant in rows:
        if not (raw is Dictionary):
            continue
        var entry: Dictionary = raw
        var installation_id: String = String(entry.get("id", ""))
        if not APPROVED_GROUPS.has(installation_id):
            continue
        var group: Node3D = installations.get(installation_id, null) as Node3D
        if group == null:
            push_error("G3 model assembly missing original building " + installation_id)
            continue
        var count: int = 0
        for original: Variant in entry.get("geometry", []):
            if not (original is Dictionary):
                continue
            var geometry: Dictionary = original
            var title: String = String(geometry.get("name", ""))
            var material: String = String(geometry.get("material", ""))
            if not _is_structural_face(title, material):
                continue
            var size_values: Array = geometry.get("size", [])
            if size_values.size() != 3:
                continue
            var size := Vector3(float(size_values[0]), float(size_values[1]), float(size_values[2]))
            if size.x <= .05 or size.y <= .05 or size.z <= .05:
                continue
            var owner: StaticBody3D = group.get_node_or_null(title) as StaticBody3D
            if owner == null:
                push_error("G3 asset has no original physical owner: " + installation_id + "/" + title)
                continue
            if owner.has_node("G2WarehousePart") or owner.has_node("G3TexturedFacadeAssembly"):
                continue
            var profile: String = String(MATERIAL_PROFILES[material])
            var axis: String = "x" if size.x < size.z else "z"
            var source: String = KIT_ROOT + profile + "_wall_" + axis + ".glb"
            var packed: PackedScene = _get_model(source)
            if packed == null:
                push_error("G3 model missing or unimportable: " + source)
                continue
            var visual: Node3D = packed.instantiate() as Node3D
            if visual == null:
                push_error("G3 model root must be a Node3D: " + source)
                continue
            visual.name = "G3TexturedFacadeAssembly"
            visual.scale = size
            visual.set_meta("g3_model_source", source)
            visual.set_meta("g3_original_installation", installation_id)
            visual.set_meta("g3_noncolliding", true)
            if owner is HMInspectTarget:
                var original_part: String = (owner as HMInspectTarget).part_id
                if original_part != String(geometry.get("removable_part_id", "")):
                    push_error("G3 refused to bind to a mismatched saved part: " + title)
                    visual.free()
                    continue
                visual.set_meta("g3_saved_owner_part_id", original_part)
                removable_owners += 1
            else:
                visual.set_meta("g3_permanent_existing_owner", true)
                static_owners += 1
            # Do not hide G3 hand-fitted story/roof owner details or any
            # collision: only obsolete box-based visible architectural skins.
            for old: Node in owner.get_children():
                if old is MeshInstance3D:
                    (old as MeshInstance3D).visible = false
                elif old.name == "ArchitecturalDetail":
                    (old as Node3D).visible = false
            owner.add_child(visual)
            owner_names[installation_id + "/" + title] = true
            assembled_parts += 1
            count += 1
        installation_counts[installation_id] = count
    finished = true
    set_meta("g3_original_collider_and_save_schema", true)
    set_meta("g3_assembled_building_faces", assembled_parts)
    set_meta("g3_model_assets_used", loaded_models.size())

func _get_model(path: String) -> PackedScene:
    if loaded_models.has(path):
        return loaded_models[path] as PackedScene
    if not ResourceLoader.exists(path):
        return null
    var scene: PackedScene = load(path) as PackedScene
    if scene != null:
        loaded_models[path] = scene
    return scene

func _is_structural_face(title: String, material: String) -> bool:
    if not MATERIAL_PROFILES.has(material):
        return false
    var name: String = title.to_lower()
    for excluded: String in ["roof", "slope", "door", "floor", "ramp", "shelf", "rack", "window", "lantern"]:
        if name.contains(excluded):
            return false
    for token: String in ["wall", "panel", "masonry", "spine", "frame", "stud",
            "post", "pier", "weatherboard", "lintel", "infill", "studyback"]:
        if name.contains(token):
            return true
    return false
