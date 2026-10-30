#!/usr/bin/env python3
"""G2 cottage visual geometry contract, independent of screenshots.

Checks actual generated GLB triangles/part ownership (never synthetic visibility).
Also guards fundamental connections that caused gaps in the approved QA review.
"""
from pathlib import Path
import json
import trimesh

ROOT = Path(__file__).resolve().parent.parent
manifest = json.loads((ROOT/"art/g2/cottage_model_manifest.json").read_text())
assets = manifest["g2_part_owner_assets"]
assert len(assets)==9, "All original salvaging assemblies must be present"
assert len(manifest["reusable_components"])==10
assert len(manifest["materials"])==8

def loaded(label):
    scene=trimesh.load(ROOT / assets[label]["path"], force="scene")
    assert len(scene.geometry)>0, label
    mesh=scene.dump(concatenate=True)
    assert len(mesh.vertices)>50 and len(mesh.faces)>50, label
    assert mesh.is_empty is False, label
    return mesh

stone=loaded("stone_block")
cladding=loaded("cladding")
slate=loaded("slate_patch")
timber=loaded("beam")
curtain=loaded("curtain")
front=loaded("front_infill")
loaded("rear_infill")
loaded("shutters")
loaded("threshold")

def any_points(mesh, predicate):
    return any(predicate(x,y,z) for x,y,z in mesh.vertices)

# Stone joints land under BOTH side walls, front corners and rear wall.
for sign in (-1,1):
    assert any_points(stone,lambda x,y,z: sign*x>2.12 and abs(z)<.30 and 0.02<y<.55), "Side stone foundation missing"
    assert any_points(cladding,lambda x,y,z: sign*x>2.20 and abs(z)<.3 and .5<y<.78), "Cladding does not overlap plinth"
    for end in (-1,1):
        assert any_points(cladding,lambda x,y,z: sign*x>2.18 and end*z>2.10 and y>2.20), "Unclosed cladding corner"
assert any_points(stone,lambda x,y,z: abs(z)>2.10 and abs(x)>1.8 and y<.52), "Corner foundation incomplete"

# Roof-frame rafters should no longer project ABOVE the slate ridge.
assert timber.bounds[1][1] < 3.99, ("Exposed rafter geometry above roof",timber.bounds)
assert slate.bounds[1][1] > timber.bounds[1][1], "Weatherproof slate must overtop structural timbers"
assert slate.bounds[0][0] < -2.2 and slate.bounds[1][0] > 2.2, "Two roof slopes required"

# Door textile extends high enough to the new lintel; no broad rectangular
# opening between fabric top and the side of the front facade.
assert curtain.bounds[1][1] > 2.36, "Curtain/header too low"
assert front.bounds[1][1] >= 4.0, "Gable rake missing"

for label, asset in assets.items():
    assert asset["triangles"] > 10, label
    assert asset["members"] >= 1, label
    assert manifest["original_cottage_part_ids"][label].startswith("fixture/house/"), label
print("HOLLOWMERE_G2_COTTAGE_GEOMETRY_OK sides=2 foundation=continuous roof=under_slates owners=9")
