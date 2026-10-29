"""Author editable GLB/glTF-compatible comparison geometry from Step21 PNGs.
Run `python tools/generate_step21_materials.py` then this file.
Requires trimesh, NumPy, Pillow. The comparison board is NOT salvage geometry.
"""
from pathlib import Path
import json
import numpy as np
import trimesh
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
assets = ROOT/'game/assets/materials/step21'
settings = json.loads((ROOT/'art/material_sources/step21_materials.json').read_text())
scene=trimesh.Scene()
# A reproducible, editable UV-authored slim rectangular swatch board.
# Each panel gets independent material and UV, exactly as a GLB modeller would.
for i, key in enumerate(settings['materials']):
    box = trimesh.creation.box(extents=[1.65, 1.65, 0.12])
    # Set a repeatable planar UV projection for each face after unmerging.
    box.unmerge_vertices()
    uv = np.stack([(box.vertices[:,0]/1.65+0.5),(box.vertices[:,1]/1.65+0.5)],axis=1)
    albedo = Image.open(assets/f'{key}_albedo.png').convert('RGBA')
    rough = Image.open(assets/f'{key}_roughness.png').convert('RGB')
    mr = Image.new('RGBA', rough.size, (0, 255, 0, 255))
    mr = Image.merge('RGBA', (Image.new('L',rough.size,0), rough.getchannel('R'), Image.new('L',rough.size,0), Image.new('L',rough.size,255)))
    material = trimesh.visual.material.PBRMaterial(
        name=key, baseColorTexture=albedo,
        metallicRoughnessTexture=mr,
        metallicFactor=0.0, roughnessFactor=1.0,
        doubleSided=False, alphaMode='OPAQUE')
    box.visual=trimesh.visual.TextureVisuals(uv=uv,material=material)
    x=(i%3-1)*2.15; y=(0.5 - i//3)*2.15
    box.apply_translation([x,y,0])
    scene.add_geometry(box,node_name=f'HM21_{key}')
path=assets/'step21_material_swatches.glb'
path.write_bytes(scene.export(file_type='glb'))
check=trimesh.load(path,force='scene')
assert len(check.geometry)==len(settings['materials']), f'Expected six independent swatches, found {len(check.geometry)}'
print('GLB export validated',len(check.geometry),'panels',path.stat().st_size,'bytes')