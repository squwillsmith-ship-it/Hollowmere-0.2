#!/usr/bin/env python3
"""Source-owned 9-part cottage verification. Requires trimesh and numpy."""
import hashlib
import json
from pathlib import Path
import numpy as np
import trimesh
ROOT=Path(__file__).resolve().parent.parent
MODEL=ROOT/'game/assets/models/g2/cottage'
PARTS=('beam','cladding','curtain','front_infill','rear_infill','shutters','slate_patch','stone_block','threshold')
manifest=json.loads((ROOT/'art/g2/cottage_model_manifest.json').read_text())
assert set(manifest['original_cottage_part_ids'])==set(PARTS)
assert set(manifest['g2_part_owner_assets'])==set(PARTS)
for p in PARTS:
    assert manifest['original_cottage_part_ids'][p]=='fixture/house/'+p
    path=MODEL/f'part_{p}.glb'
    assert path.exists(),path
    assert manifest['g2_part_owner_assets'][p]['sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
    s=trimesh.load(path,force='scene')
    assert np.isfinite(s.bounds).all()
    for g in s.geometry.values():
        assert len(g.faces)>0 and np.max(g.faces)<len(g.vertices)
        assert np.isfinite(g.vertices).all()
        mat=g.visual.material
        assert mat and mat.name
        assert mat.baseColorTexture is not None
        assert mat.metallicRoughnessTexture is not None
    if p=='front_infill':
        assert any('front_gable_fill' in n for n in s.geometry)
        assert any('door_plank' in n for n in s.geometry)
        assert any('front_wall_continuity' in n for n in s.geometry)
    elif p=='rear_infill':
        assert any('rear_real_gable' in n for n in s.geometry)
        assert any('rear_continuous_lime_wall' in n for n in s.geometry)
    elif p=='beam':
        assert any('underslate_fascia' in n for n in s.geometry)
    elif p=='stone_block':
        assert any('mortar_backing' in n for n in s.geometry)
assert manifest['version']==2
print('HOLLOWMERE_G2_COTTAGE_REFERENCE_GLB_OK')
print('NOTE: does not replace Godot gameplay, collider or GPU testing')
# Additional visual-revision invariants discovered from actual z-buffered 3D views.
# Fail immediately if an older G2 production mesh reintroduces the hidden rear
# timber facade, stepped plaster eaves or the floating front-door sill.
cladding=trimesh.load(MODEL/'part_cladding.glb',force='scene')
for key in ('cladding','cladding_1'):
    mesh=cladding.geometry[key]
    vertices=mesh.vertices[mesh.faces]
    rear_wood=(np.max(vertices[:,:,2],axis=1)<-2.14)&(np.max(np.abs(vertices[:,:,0]),axis=1)<2.35)&(np.min(vertices[:,:,1],axis=1)>.48)
    assert not rear_wood.any(),f'rear exterior timber facade still occludes plaster in {key}'
front=trimesh.load(MODEL/'part_front_infill.glb',force='scene')
planks=[g for n,g in front.geometry.items() if '_door_plank_' in n]
assert len(planks)==7
assert max(abs(float(m.bounds[0,1])-.291) for m in planks)<.005,'door still floats above threshold'
back=trimesh.load(MODEL/'part_rear_infill.glb',force='scene')
assert 'rear_infill_2' not in back.geometry,'old overlapping tiled rear lime remains'
assert any('rear_real_gable' in n for n in back.geometry)
roof=trimesh.load(MODEL/'part_slate_patch.glb',force='scene')
assert max(m.bounds[1,1] for m in roof.geometry.values())>4.0
under=trimesh.load(MODEL/'part_beam.glb',force='scene')
assert max(m.bounds[1,1] for m in under.geometry.values())<3.93
step=trimesh.load(MODEL/'part_threshold.glb',force='scene')
assert any('integrated_landing' in n for n in step.geometry)
print('G2_VISUAL_V3_REAR_PLASTER_ROOF_UNDERTILE_DOOR_JOIN_OK')