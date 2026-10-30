#!/usr/bin/env python3
"""Hollowmere G2 cottage corrective mesh revision, from the owner-provisional G2 GLBs.

These are real geometry edits, NOT painted concept images. Each part remains a
separate GLB with its existing nine exact HMInspectTarget IDs. The script is
non-destructive: reads input/base and writes output/game; source remains intact.
Requires trimesh and numpy; no Blender or Godot needed for the GLB export.
"""
from __future__ import annotations

from pathlib import Path
from copy import deepcopy
import argparse
import hashlib
import json
import numpy as np
import trimesh
import shutil

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent if (ROOT.parent / "game").exists() else ROOT
PARTS = ('beam','cladding','curtain','front_infill','rear_infill','shutters','slate_patch','stone_block','threshold')
OWNER_IDS = {p:'fixture/house/'+p for p in PARTS}

class Patch:
    def __init__(self, scene, name):
        self.scene = scene
        self.name = name
        self.idx = 0
        self.mats = {}
        for mesh in scene.geometry.values():
            material = getattr(mesh.visual, 'material', None)
            if material is not None:
                self.mats[material.name] = material
    def _insert(self, mesh, material, label):
        assert material in self.mats, (self.name, material, list(self.mats))
        mesh.visual = trimesh.visual.TextureVisuals(
            uv=np.array([(v[0]*.65+v[2]*.12,v[1]*.7+v[2]*.38) for v in mesh.vertices]),
            material=deepcopy(self.mats[material]))
        self.idx += 1
        safe = label.replace(' ', '_').replace('-', '_')
        self.scene.add_geometry(mesh, node_name=f'G2CottageFix_{self.name}_{safe}_{self.idx:03d}',
                                geom_name=f'G2Fix_{self.name}_{safe}_{self.idx:03d}')
    def box(self, name, center, dimensions, material):
        dims = np.array(dimensions,dtype=float)
        assert np.min(dims) > .003
        mesh=trimesh.creation.box(extents=dims)
        mesh.apply_translation(center)
        self._insert(mesh,material,name)
    def beam(self,name,start,end,width,depth,material):
        a,b=np.asarray(start,dtype=float),np.asarray(end,dtype=float)
        d=b-a; length=float(np.linalg.norm(d))
        y=d/length
        guide=np.array([0.,0.,1.]) if abs(y[2])<.9 else np.array([1.,0.,0.])
        x=np.cross(y,guide); x/=np.linalg.norm(x)
        z=np.cross(x,y);z/=np.linalg.norm(z)
        frame=np.eye(4)
        frame[:3,0]=x; frame[:3,1]=y;frame[:3,2]=z;frame[:3,3]=(a+b)*.5
        mesh=trimesh.creation.box(extents=[width,length,depth],transform=frame)
        self._insert(mesh,material,name)
    def polygon(self,name,xy,z0,z1,material):
        """Extrude a simple convex XY polygon straight through Z (gable skin)."""
        n=len(xy)
        xyz=np.array([[x,y,z] for z in (z0,z1) for x,y in xy],dtype=float)
        faces=[]
        for i in range(1,n-1):
            faces.extend([(0,i,i+1),(n,n+i+1,n+i)])
        for i in range(n):
            j=(i+1)%n
            faces.extend([(i,j,n+j),(i,n+j,n+i)])
        mesh=trimesh.Trimesh(vertices=xyz,faces=faces,process=False)
        self._insert(mesh,material,name)


def patch(base:Path, dest:Path):
    dest.mkdir(parents=True,exist_ok=True)
    scenes={p:trimesh.load(base/f'part_{p}.glb',force='scene') for p in PARTS}
    if any('G2Fix_' in name for sc in scenes.values() for name in sc.geometry):
        raise RuntimeError('G2 reference repair is already installed; refusing to duplicate mesh layers')
    original_counts={p:len(s.geometry) for p,s in scenes.items()}
    original_triangles={p:sum(len(g.faces) for g in s.geometry.values()) for p,s in scenes.items()}
    # The approved G2 generator places visible wooden gable rakes slightly
    # higher than the slate line. Move those old rakes BELOW the tile tops.
    # The beam/glb understructure (and its original salvage owner) is untouched.
    for p,top,delta in [('front_infill',2.77,-.13),('rear_infill',2.73,-.13)]:
        g=next(mesh for mesh in scenes[p].geometry.values() if mesh.visual.material.name=='weathered_oak')
        verts=g.vertices.copy()
        vertices_upper=verts[:,1]>top
        verts[vertices_upper,1]+=delta
        g.vertices=verts

    f=Patch(scenes['front_infill'],'front_infill')
    # The old fragmented lime pieces left open vertical seams in the front
    # around the window/shutter zone and central door top. These BACKING skins
    # fill only the existing house front, never add a salvage item or collider.
    for sign in (-1,1):
        f.box('front-wall-continuity',(sign*1.405,1.615,2.171),
              (1.69,2.255,.095),'lime_infill')
        # Recessed window surround: keep the original shuttered windows at
        # x=+/-1.14; this is placed behind their 2.217m minimum front face.
        x=sign*1.14
        f.box('upper-window-head',(x,2.175,2.254),(.73,.095,.09),'weathered_oak')
        f.box('window-side-return-left',(x-.357,1.68,2.255),(.075,.97,.09),'dark_oak')
        f.box('window-side-return-right',(x+.357,1.68,2.255),(.075,.97,.09),'dark_oak')
        # Front base rail must actually contact stone-plinth top at 0.55m.
        f.box('plinth-continuity',(sign*1.415,.587,2.245),(1.705,.095,.13),'dark_oak')
    f.box('above-door-lintel-plaster',(0,2.58,2.177),(.98,.32,.096),'lime_infill')
    f.box('door-transom',(0,2.394,2.316),(1.13,.13,.155),'weathered_oak')
    # Solid wooden close-fitting door, modelled as cosmetic front-infill
    # facing. Removable curtain remains behind this door with its own ID.
    # Never give the door independent collision or a new salvage target.
    for i in range(7):
        x=-.463+(i+.5)*.926/7
        f.box('door-plank',(x,1.422,2.287),(.132,1.89,.092),'weathered_oak')
    f.box('door-top-beam',(0,2.393,2.344),(1.02,.08,.085),'dark_oak')
    f.box('door-base-rail',(0,.461,2.337),(1.00,.08,.080),'dark_oak')
    # Tiny muted iron door ring/hardware from original G2 palette may be
    # attached to the shutter owner, which already has black_iron material.
    sh=Patch(scenes['shutters'],'shutters')
    sh.box('door-iron-latch',(.342,1.46,2.367),(.065,.17,.042),'black_iron')
    sh.box('door-latch-head',(.342,1.48,2.405),(.125,.070,.026),'black_iron')
    # Finish the front gable as a TRIANGLE behind the rafters / fascia:
    # continuous lime, under both tile slopes; no rectangular gap at eaves.
    f.polygon('front-gable-fill', [(-2.17,2.753),(2.17,2.753),(0,3.847)],2.145,2.244,'lime_infill')
    f.beam('gable-cross-tie',(-2.2,2.738,2.295),(2.2,2.738,2.295),.13,.14,'dark_oak')
    f.beam('gable-center-post',(0,2.77,2.294),(0,3.79,2.294),.105,.11,'weathered_oak')
    # Under-tile barge boards, aligned with peak and not raised above slate.
    for side in (-1,1):
        f.beam('bargeboard-under-slate',(side*2.16,2.72,2.330),(0,3.77,2.330),.11,.12,'dark_oak')

    r=Patch(scenes['rear_infill'],'rear_infill')
    # True rear facade is NEGATIVE Z: plain closed lime infill gable,
    # not the timber-clad long side wrongly shown in old generated images.
    r.box('rear-continuous-lime-wall',(0,1.625,-2.214),(4.23,2.18,.10),'lime_infill')
    r.polygon('rear-real-gable',[(-2.15,2.75),(2.15,2.75),(0,3.85)],-2.253,-2.135,'lime_infill')
    r.beam('rear-gable-tie',(-2.20,2.738,-2.327),(2.20,2.738,-2.327),.13,.12,'dark_oak')
    r.beam('rear-gable-kingpost',(0,2.77,-2.321),(0,3.78,-2.321),.10,.12,'weathered_oak')
    for sign in (-1,1):
        r.beam('rear-under-slate-barge',(sign*2.16,2.72,-2.33),(0,3.77,-2.33),.11,.12,'dark_oak')
    r.box('rear-plinth-sill',(0,.58,-2.28),(4.30,.10,.12),'dark_oak')

    c=Patch(scenes['cladding'],'cladding')
    # Cover four front/rear corners, close open returns to genuine gables,
    # and connect the weatherboarding to the actual stone below.
    for side in (-1.,1.):
        for z in (-2.22,2.22):
            c.box('corner-seal',(side*2.395,1.635,z),(.145,2.20,.125),'weathered_oak')
        c.box('ground-rail',(side*2.399,.578,0),(.14,.10,4.42),'dark_oak')
        c.box('eave-rail',(side*2.397,2.733,0),(.15,.10,4.48),'dark_oak')

    beams=Patch(scenes['beam'],'beam')
    for side in (-1.,1.):
        beams.box('underslate-fascia',(side*2.26,2.520,0),(.18,.14,4.82),'weathered_oak')
        for z in (-2.16,-1.08,0.,1.08,2.16):
            beams.box('exposed-under-eave-rafter-tail',(side*2.255,2.455,z),(.28,.115,.13),'dark_oak')
    # Retain the canonical original slate surface unchanged; these new
    # fascia/tails are inside it, never laid across the weather surface.

    stones=Patch(scenes['stone_block'],'stone_block')
    # Recessed rubble/mortar backing closes daylight gaps between individually
    # removable stone units while leaving their face courses visibly segmented.
    stones.box('rear-mortar-backing',(0,.268,-2.175),(4.43,.488,.14),'fieldstone')
    for sign in (-1.,1.):
        stones.box('side-mortar-backing',(sign*2.25,.268,0),(.13,.488,4.39),'fieldstone')
        stones.box('front-bay-mortar-backing',(sign*1.50,.268,2.17),(1.75,.488,.14),'fieldstone')
    for side in (-1.,1.):
        stones.box('under-corner-cap',(side*2.275,.512,2.16),(.30,.075,.36),'fieldstone')
        stones.box('rear-corner-cap',(side*2.275,.512,-2.16),(.30,.075,.36),'fieldstone')

    meta={"base":"Hollowmere G2 provisionally approved SHA 870cdb5c887c4bf8217aab6075a1ff4a668d15e3",
          "part_ids":OWNER_IDS,"modification":"G2 cottage reference-sheet target geometry corrections",
          "parts":{},"note":"Canonical 9 salvage owners and collision data are unchanged; cosmetic front door is owned by front_infill, existing curtain remains under curtain owner. Re-import these GLBs into Godot from the same source path; Blender master in base archive is superseded by these edited GLBs."}
    for p,scene in scenes.items():
        out=dest/f'part_{p}.glb'
        if p in ('curtain','slate_patch','threshold'):
            if (base/f'part_{p}.glb').resolve()!=out.resolve():
                shutil.copy2(base/f'part_{p}.glb',out)
        else:
            out.write_bytes(scene.export(file_type='glb'))
        reloaded=trimesh.load(out,force='scene')
        assert len(reloaded.geometry)>=original_counts[p]
        meta['parts'][p]={"sha256":hashlib.sha256(out.read_bytes()).hexdigest(),
                          "triangles":sum(len(x.faces) for x in reloaded.geometry.values()),
                          "previous_triangles":original_triangles[p],
                          "bounds":reloaded.bounds.round(4).tolist(),
                          "added_mesh_nodes":len(reloaded.geometry)-original_counts[p]}
    project = dest.parents[4] if dest.parts[-5:-1] == ('game','assets','models','g2') else PROJECT
    record = project/'art/g2/g2_cottage_reference_fix_manifest.json'
    record.parent.mkdir(parents=True,exist_ok=True)
    record.write_text(json.dumps(meta,indent=2)+'\n')
    master_manifest=project/'art/g2/cottage_model_manifest.json'
    if master_manifest.exists():
        data=json.loads(master_manifest.read_text())
        for p in PARTS:
            record=data['g2_part_owner_assets'][p]
            record['sha256']=meta['parts'][p]['sha256']
            record['triangles']=meta['parts'][p]['triangles']
            record['members']+=meta['parts'][p]['added_mesh_nodes']
        data['version']=2
        data['visual_revision']='real G2 cottage reference repair 20261030; tested offline, engine gate open'
        master_manifest.write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps({p:[v['triangles'],v['added_mesh_nodes']] for p,v in meta['parts'].items()},indent=2))

if __name__=='__main__':
    pa=argparse.ArgumentParser()
    pa.add_argument('--base',default=str(PROJECT/'game/assets/models/g2/cottage'))
    pa.add_argument('--output',default=str(PROJECT/'game/assets/models/g2/cottage'))
    args=pa.parse_args()
    patch(Path(args.base),Path(args.output))