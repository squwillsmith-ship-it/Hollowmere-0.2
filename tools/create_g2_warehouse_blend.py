#!/usr/bin/env python3
"""Build one actually editable G2 warehouse asset master in Blender."""
import bpy,json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/"art/g2/source"
SOURCE.mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/"art/g2/warehouse_model_manifest.json").read_text())
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for name in manifest["warehouses"]:
    collection=bpy.data.collections.new(name.replace("/","_"))
    bpy.context.scene.collection.children.link(collection)
    for owner,asset in manifest["owner_assets"].items():
        if not owner.startswith("village/04/" if name=="district/old_warehouse" else "village/05/"):
            continue
        before=set(bpy.data.objects)
        path=ROOT/asset["path"]
        bpy.ops.import_scene.gltf(filepath=str(path))
        new=[o for o in bpy.data.objects if o not in before]
        part=bpy.data.collections.new(owner.replace("/","_"))
        collection.children.link(part)
        for obj in new:
            for old in list(obj.users_collection):
                old.objects.unlink(obj)
            part.objects.link(obj)
            obj["g2_original_salvage_owner"]=owner
            obj["original_collision"]="Godot catalogue, separate immutable target"
        part["salvage_owner_id"]=owner
bpy.context.scene.unit_settings.system="METRIC"
bpy.context.preferences.filepaths.save_version=0
path=SOURCE/"Hollowmere_Warehouses_G2_Master.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(path))
print("G2_WAREHOUSE_BLENDER_EDITABLE_OK owner_collections="+str(len(manifest["owner_assets"])))
