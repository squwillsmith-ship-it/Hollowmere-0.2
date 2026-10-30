#!/usr/bin/env python3
"""Blender-side editable .blend recovery for the six authored G3 GLB models.

Run using Blender 4.x:
    blender --background --python tools/g3_create_blender_master.py

Imports the actual source GLBs, retains material nodes and packed textures,
and saves a proper Blender master without re-authoring or replacing any
existing engine assets. Imported GLB remains independently editable.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "game/assets/models/g3/kit"
TARGET = ROOT / "art/g3/source/Hollowmere_G3_ArchitecturalKit_Master.blend"
NAMES = (
    "stone_wall_x", "stone_wall_z",
    "timber_wall_x", "timber_wall_z",
    "lime_wall_x", "lime_wall_z",
)


def build() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for obj in list(bpy.data.collections):
        if obj.name != "Collection" and obj.users == 0:
            bpy.data.collections.remove(obj)
    for index, name in enumerate(NAMES):
        path = MODEL_DIR / (name + ".glb")
        if not path.is_file():
            raise FileNotFoundError(path)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        created = set(bpy.data.objects) - before
        if not created:
            raise RuntimeError(f"GLB imported no objects: {path}")
        owner = bpy.data.collections.new("G3_" + name)
        bpy.context.scene.collection.children.link(owner)
        for obj in created:
            for collection in list(obj.users_collection):
                collection.objects.unlink(obj)
            owner.objects.link(obj)
            if obj.parent is None:
                obj.location.x += (index % 3) * 2.6
                obj.location.z += (index // 3) * 2.4
    for image in bpy.data.images:
        if image.source == "FILE":
            try:
                image.pack()
            except RuntimeError:
                pass
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET), check_existing=False)
    print(f"G3_EDITABLE_BLENDER_SOURCE_CREATED {TARGET}")


if __name__ == "__main__":
    build()
