#!/usr/bin/env python3
"""Build the editable Blender master for G2 cottage and reusable part kit.

Run after generate_g2_cottage_assets.py using Blender:
  blender --background --factory-startup --python tools/create_g2_cottage_blend.py
The .blend is an editable collection of real textured meshes with stable
original salvage owner names. Neither script changes the canonical catalogue.
"""
from pathlib import Path
import json
import bpy

ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT/"game/assets/models/g2"
SOURCE=ROOT/"art/g2/source"
SOURCE.mkdir(parents=True,exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name!="Collection":
        bpy.data.collections.remove(collection)

kit=bpy.data.collections.new("G2 Reusable Component Models")
bpy.context.scene.collection.children.link(kit)
cottage=bpy.data.collections.new("G2 Cottage — Nine Salvage Owners")
bpy.context.scene.collection.children.link(cottage)

manifest=json.loads((ROOT/"art/g2/cottage_model_manifest.json").read_text())
outputs=[]
for name,folder,group in [
    *[(f"part_{part}",ASSETS/"cottage"/f"part_{part}.glb",cottage)
      for part in manifest["g2_part_owner_assets"]],
    *[(key,ASSETS/"kit"/f"{key}.glb",kit)
      for key in manifest["reusable_components"]]]:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(folder))
    new=[obj for obj in bpy.data.objects if obj not in before]
    part_collection=bpy.data.collections.new(name)
    group.children.link(part_collection)
    for obj in new:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        part_collection.objects.link(obj)
        obj["hollowmere_g2_asset"]=name
        if name.startswith("part_"):
            obj["salvage_owner_id"]=manifest["original_cottage_part_ids"][name[5:]]
            obj["authoritative_collision"]="Godot HMInspectTarget, not this mesh"
    outputs.append({"asset":name,"mesh_objects":sum(o.type=="MESH" for o in new),
                    "owner":manifest["original_cottage_part_ids"].get(name[5:],"")
                    if name.startswith("part_") else ""})

# Set scene units for deliberate real-world metre scale, preserve geometry.
bpy.context.scene.unit_settings.system="METRIC"
bpy.context.scene.unit_settings.scale_length=1.0
bpy.context.scene.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in \
    {entry.identifier for entry in bpy.context.scene.render.bl_rna.properties["engine"].enum_items} \
    else "BLENDER_EEVEE"
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"Hollowmere_Cottage_G2_Master.blend"))
(SOURCE/"blender_source_manifest.json").write_text(json.dumps({
    "version":1,"blender_version":bpy.app.version_string,
    "editable_source":"art/g2/source/Hollowmere_Cottage_G2_Master.blend",
    "source_models":outputs,
    "asset_owner_authority":"game/data/v1/buildings/cottage_working_01.json",
    "geometry_authoring":"tools/generate_g2_cottage_assets.py",
},indent=2))
print("G2_COTTAGE_BLENDER_EDITABLE_OK assets="+str(len(outputs)))
