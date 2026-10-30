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