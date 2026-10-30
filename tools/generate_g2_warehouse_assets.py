#!/usr/bin/env python3
"""Deterministic, separately removable G2 warehouses: 93 authored GLBs.

Reuses the tested G2 cottage vertex/UV/texture exporter; each GLB is built in
the local coordinate system of its original catalogue-backed part/collider.
No saved part IDs, transforms, tools, yields, or collision shapes are modified.
"""
from __future__ import annotations
import json
from pathlib import Path
from generate_g2_cottage_assets import Builder, textures, _save_glb, ROOT

OUTPUT=ROOT/"game/assets/models/g2/warehouse"
MANIFEST=ROOT/"art/g2/warehouse_model_manifest.json"
SOURCE=ROOT/"game/data/v1/brinewick_district_builds.json"

def make(key, entry):
    name=str(entry["name"])
    dims=[float(x) for x in entry["size"]]
    x,y,z=dims
    b=Builder(name)
    lower=name.lower()
    salt="weathered_oak"
    dark="dark_oak"
    if "roof" in lower:
        # Slate tiles overlap in two dimensions on the already-rotated body.
        # Their underside is coherent; no visible floating support beams.
        b.box((0,-.071,0),(x,.067,z*1.01),dark,bevel=.015)
        rows=max(2,round(z/.43))
        cols=max(4,round(x/.37))
        for iz in range(rows):
            for ix in range(cols):
                jitter=((ix*7+iz*11+len(key))%5-2)*.004
                zz=-z/2+(iz+.5)*z/rows+jitter
                xx=-x/2+(ix+.5)*x/cols+(.011 if iz%2 else -.011)
                b.box((xx,.035+((ix+2*iz)%3)*.002,zz),
                      (x/cols*.98,.071,z/rows*1.075),"slate",
                      bevel=.022+(.005 if ix%4==0 else 0))
        for ix in range(3):
            xx=-x*.40+ix*x*.40
            b.beam((xx,-.17,-z*.45),(xx,-.17,z*.45),
                   .11,.10,dark)
    elif "backframe" in lower or "back_frame" in lower:
        # Real per-bay upright frame; divided plaster infill rather than an
        # enormous plain dark block. Lower wall is braced on two diagonals.
        b.box((0,0,0),(x*.94,y*.92,z*.75),"lime_infill",bevel=.025)
        for s in (-1,1):
            xx=s*x*.44
            b.beam((xx,-y*.47,z*.48),(xx,y*.46,z*.48),
                   .16,.15,dark)
            b.beam((xx,-y*.23,z*.48),(s*x*.08,y*.10,z*.48),
                   .10,.11,salt)
        for yy in (-y*.40,0,y*.41):
            b.beam((-x*.46,yy,z*.48),(x*.46,yy,z*.48),
                   .14,.14,dark)
    elif "side" in lower or "wall" in lower or "door" in lower:
        # Board direction follows the visible wall plane, not hard-coded
        # world axes; west/east panels run along Z, pier-door panels along X.
        along_x=x>=z
        length=x if along_x else z
        count=max(8,round(y/.23))
        for row in range(count):
            yy=-y/2+(row+.5)*y/count
            bleed=.008*((row+len(key))%3-1)
            if along_x:
                b.box((0,yy,0),(x*1.015,y/count*1.025,z*.89),
                      salt if row%5 else dark,bevel=.013)
                b.box((0,yy+y/count*.5,z*.52),
                      (x*.99,.014,.018),dark)
            else:
                b.box((0,yy,0),(x*.89,y/count*1.025,z*1.015),
                      salt if row%5 else dark,bevel=.013)
                b.box((x*.52,yy+y/count*.5,0),
                      (.018,.014,z*.99),dark)
        for end in (-1,1):
            if along_x:
                b.beam((end*x*.45,-y*.49,z*.59),
                       (end*x*.45,y*.48,z*.59),.13,.12,dark)
            else:
                b.beam((x*.59,-y*.49,end*z*.43),
                       (x*.59,y*.48,end*z*.43),.13,.12,dark)
        # Hand-fitted timber corner/diagonal instead of regular stone grids.
        if along_x:
            b.beam((-x*.36,-y*.28,z*.59),(x*.30,y*.25,z*.59),
                   .075,.078,salt)
        else:
            b.beam((x*.59,-y*.28,-z*.36),(x*.59,y*.25,z*.30),
                   .075,.078,salt)
    elif "rack" in lower:
        for s in (-1,1):
            for side in (-1,1):
                b.beam((s*x*.43,-y*.48,side*z*.41),
                       (s*x*.43,y*.47,side*z*.41),.12,.13,dark)
        for yy in (-y*.34,0,y*.29):
            for side in (-1,1):
                b.beam((-x*.47,yy,side*z*.42),(x*.47,yy,side*z*.42),
                       .13,.12,salt)
        b.beam((-x*.44,-y*.30,-z*.40),(x*.44,y*.36,-z*.40),
               .10,.10,dark)
    else:
        b.box((0,0,0),tuple(dims),salt,bevel=.02)
        b.beam((-x*.44,-y*.38,z*.49),(x*.40,y*.33,z*.49),
               .075,.07,dark)
    return b

def main():
    textures()
    spec=json.loads(SOURCE.read_text())
    output={"version":1,"source":"tools/generate_g2_warehouse_assets.py",
            "owner_assets":{},"warehouses":[]}
    count=0
    for group in spec["installations"]:
        if group["id"] not in ("district/old_warehouse","district/expanded_warehouse"):
            continue
        output["warehouses"].append(group["id"])
        for geo in group["geometry"]:
            owner=str(geo.get("removable_part_id",""))
            if not owner:
                continue
            filename=owner.replace("/","__")+".glb"
            b=make(owner,geo)
            meta=_save_glb(b,OUTPUT/filename)
            output["owner_assets"][owner]={**meta,"source_name":geo["name"],
                "size":geo["size"],"rotation":geo.get("rotation",[0,0,0])}
            count+=1
    assert len(output["owner_assets"])==93,(len(output["owner_assets"]),count)
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    MANIFEST.write_text(json.dumps(output,indent=2,sort_keys=True)+"\n")
    print("G2_WAREHOUSE_ASSETS_OK owners=93 warehouses=2"+
          " triangles="+str(sum(x["triangles"] for x in output["owner_assets"].values())))

if __name__=="__main__":
    main()
