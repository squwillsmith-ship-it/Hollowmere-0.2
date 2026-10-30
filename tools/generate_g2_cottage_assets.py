#!/usr/bin/env python3
"""Hollowmere G2 cottage production model kit.

Generate actual textured glTF binary assets, not preview geometry. Each of the
nine assembled GLBs maps to an existing HMInspectTarget salvage-owner ID.
Re-run this script for identical asset bytes. Blender sources are created by
tools/create_g2_cottage_blend.py in an engine-capable production environment.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import random
import struct

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MATERIAL_DIR = ROOT / "game/assets/materials/g2"
MODEL_DIR = ROOT / "game/assets/models/g2/cottage"
KIT_DIR = ROOT / "game/assets/models/g2/kit"
MANIFEST = ROOT / "art/g2/cottage_model_manifest.json"
SEED = 270619

MATERIALS = {
    "weathered_oak": ((106, 85, 65), 0.95, "wood"),
    "dark_oak": ((78, 62, 46), 0.94, "wood"),
    "lime_infill": ((183, 174, 151), 0.98, "lime"),
    "fieldstone": ((114, 113, 101), 0.96, "stone"),
    "slate": ((91, 97, 99), 0.93, "slate"),
    "black_iron": ((62, 63, 60), 0.88, "iron"),
    "unbleached_linen": ((152, 143, 119), 0.99, "cloth"),
    "packed_earth": ((119, 111, 94), 0.97, "earth"),
}
PARTS = {
    "curtain": "fixture/house/curtain",
    "shutters": "fixture/house/shutters",
    "cladding": "fixture/house/cladding",
    "slate_patch": "fixture/house/slate_patch",
    "beam": "fixture/house/beam",
    "stone_block": "fixture/house/stone_block",
    "front_infill": "fixture/house/front_infill",
    "rear_infill": "fixture/house/rear_infill",
    "threshold": "fixture/house/threshold",
}
# Local player-scale cottage space: 4.8m width, 4.5m depth.
# Godot's nine original salvaging IDs, origin and physics remain authoritative.


def textures() -> None:
    MATERIAL_DIR.mkdir(parents=True, exist_ok=True)
    y, x = np.indices((256, 256), dtype=np.float32)
    for key, (base, roughness, kind) in MATERIALS.items():
        rng = np.random.default_rng(SEED + sum(ord(c) * (i + 1) for i, c in enumerate(key)))
        grain = rng.normal(0, 1.6, (256, 256))
        if kind == "wood":
            field = 4.0 * np.sin(x * 0.15 + y * 0.012) + 2.5 * np.sin(x * 0.67 + y * 0.013)
            seams = np.where((y.astype(int) % 53) >= 51, -9.0, 0.0)
        elif kind == "stone":
            field = 3.5 * np.sin(x * .057) * np.cos(y * .066)
            seams = np.where((y.astype(int) % 82) >= 80, -5.5, 0.0)
        elif kind == "slate":
            field = 3.8 * np.sin(x * .061 + y * .037)
            seams = np.where((y.astype(int) % 66) >= 64, -3.5, 0.0)
        elif kind == "lime":
            field = 1.9 * np.sin(x * .049) + 2.0 * np.cos(y * .061)
            seams = 0.0
        elif kind == "cloth":
            field = 2.8 * np.sin(x * .37) + 1.0 * np.cos(y * .51)
            seams = 0.0
        else:
            field = 2.0 * np.cos(x * .061 + y * .073)
            seams = 0.0
        surface = np.clip(np.asarray(base)[None, None, :] +
                          (field + seams + grain)[:, :, None], 0, 255).astype(np.uint8)
        Image.fromarray(surface, "RGB").save(MATERIAL_DIR / f"{key}_albedo.png")
        rough_val = np.clip(round(roughness * 255) + rng.integers(-4, 5, (256, 256)), 0, 255)
        # glTF metallicRoughnessTexture convention: G=roughness, B=metallic.
        mask = np.zeros((256, 256, 3), dtype=np.uint8)
        mask[:, :, 0] = 255
        mask[:, :, 1] = rough_val
        mask[:, :, 2] = 22 if kind == "iron" else 0
        Image.fromarray(mask, "RGB").save(MATERIAL_DIR / f"{key}_orm.png")


def _sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _unit(a):
    length = math.sqrt(sum(k*k for k in a))
    return tuple(k/length for k in a) if length > 1e-9 else (0.0, 1.0, 0.0)


def _rotate_z(p, degrees):
    angle = math.radians(degrees)
    cs, sn = math.cos(angle), math.sin(angle)
    return (p[0]*cs-p[1]*sn, p[0]*sn+p[1]*cs, p[2])


class Builder:
    def __init__(self, name):
        self.name = name
        self.verts = {mat: [] for mat in MATERIALS}
        self.norms = {mat: [] for mat in MATERIALS}
        self.uvs = {mat: [] for mat in MATERIALS}
        self.indices = {mat: [] for mat in MATERIALS}
        self.members = 0

    def quad(self, corners, material, uv_scale=1.0):
        a, b, c, d = corners
        normal = _unit(_cross(_sub(b, a), _sub(c, a)))
        start = len(self.verts[material]) // 3
        for i, point in enumerate(corners):
            self.verts[material].extend(point)
            self.norms[material].extend(normal)
            tx, ty = ((0, 0), (uv_scale, 0), (uv_scale, uv_scale), (0, uv_scale))[i]
            self.uvs[material].extend((tx, ty))
        self.indices[material].extend((start, start+1, start+2,
                                       start, start+2, start+3))

    def box(self, center, size, material, angle=0.0, bevel=0.0):
        """Convex six-sided real mesh, optional slight tapered ends."""
        w, h, d = (s*.5 for s in size)
        x, y, z = center
        ring = [(-w, -d), (w, -d), (w, d), (-w, d)]
        # Taper subtly to break the artificial perfectly uniform stone.
        top = [(p[0]*(1.0-bevel), h, p[1]*(1.0-bevel)) for p in ring]
        bottom = [(p[0], -h, p[1]) for p in ring]
        transform = lambda p: tuple(_rotate_z(p, angle)[i] + center[i] for i in range(3))
        top = [transform(p) for p in top]
        bottom = [transform(p) for p in bottom]
        for i in range(4):
            j = (i+1) % 4
            self.quad([bottom[i], bottom[j], top[j], top[i]], material,
                      max(size) / 1.25)
        self.quad([top[0], top[1], top[2], top[3]], material, max(size) / 1.25)
        self.quad([bottom[3], bottom[2], bottom[1], bottom[0]], material,
                  max(size) / 1.25)
        self.members += 1

    def beam(self, start, end, width, depth, material):
        direction = _unit(_sub(end, start))
        guide = (0, 0, 1) if abs(direction[2]) < .9 else (1, 0, 0)
        axis_x = _unit(_cross(direction, guide))
        axis_z = _unit(_cross(axis_x, direction))
        midpoint = tuple((a+b)*.5 for a,b in zip(start, end))
        half_y = math.dist(start, end)*.5
        def corner(x, y, z):
            return tuple(midpoint[i]+axis_x[i]*x+direction[i]*y+axis_z[i]*z
                         for i in range(3))
        w, d = width*.5, depth*.5
        a = [corner(x,y,z) for x,y,z in
             [(-w,-half_y,-d),(w,-half_y,-d),(w,half_y,-d),(-w,half_y,-d),
              (-w,-half_y,d),(w,-half_y,d),(w,half_y,d),(-w,half_y,d)]]
        for q in ((0,1,2,3),(5,4,7,6),(4,0,3,7),
                  (1,5,6,2),(3,2,6,7),(4,5,1,0)):
            self.quad([a[i] for i in q], material, max(width,depth,half_y)/.5)
        self.members += 1

    def stone(self, center, size, row, col):
        # Individually placed staggered slightly tapered 1B/1C stone block.
        j = ((row*17 + col*11 + 7) % 9 - 4) * .009
        c = (center[0]+j,center[1],center[2]-j*.6)
        self.box(c, (size[0]*(.94+j),size[1]*(.94-j),size[2]*.96),
                 "fieldstone", bevel=.035 + (col%3)*.014)

    def panel(self, at, dims, mat):
        self.box(at, dims, mat, bevel=.015)


def _slate_slope(builder, center_x, rotation):
    # Two independent matching roof slopes, owned by one existing roof ID.
    # The original parent collision still governs player interaction.
    cx, cy = center_x, 3.24
    for rz in range(12):
        for rx in range(8):
            u0 = -1.325 + (rx+.5)*2.65/8
            v0 = -2.48 + (rz+.5)*4.96/12
            yj = 0.012*((rx+2*rz)%4)
            local = _rotate_z((u0, yj, v0), rotation)
            b = (cx+local[0], cy+local[1], local[2])
            builder.box(b, (2.65/8*.97,.08,4.96/12*1.07),
                        "slate", angle=rotation, bevel=.016)
    # Ridge underlay and visible rafter ends remain part of roof-owner.
    for z in (-2.28,-1.14,0,1.14,2.28):
        a = _rotate_z((-1.19,-.19,z),rotation)
        b = _rotate_z((1.16,-.19,z),rotation)
        builder.beam((cx+a[0],cy+a[1],a[2]),(cx+b[0],cy+b[1],b[2]),
                     .11,.12,"dark_oak")


def cottage_models():
    m = {part: Builder(part) for part in PARTS}
    b=m["curtain"]
    b.panel((0,1.31,2.215),(.89,1.55,.052),"unbleached_linen")
    for x in (-.31,-.08,.14,.36):
        b.beam((x,.58,2.253),(x,2.03,2.253),.018,.012,"unbleached_linen")
    b.beam((-.52,2.12,2.28),(.52,2.12,2.28),.065,.070,"dark_oak")
    b=m["shutters"]
    for x in (-1.14,1.14):
        for c in range(4):
            xx=x-.20+(c+.5)*.10
            b.box((xx,1.66,2.26),(.092,.94,.085),"weathered_oak",bevel=.025)
        for y in (1.37,1.95):
            b.box((x,y,2.34),(.48,.075,.047),"dark_oak")
        b.box((x-.20,1.65,2.36),(.052,.78,.021),"black_iron")
        for y in (1.31,2.01):
            b.box((x-.20,y,2.39),(.090,.065,.024),"black_iron")
    b=m["cladding"]
    for x in (-2.39,2.39):
        for row in range(9):
            y=.82+row*.205
            for col in range(3):
                zz=-1.76+(col+.5)*3.52/3 + (.12 if row%2 else 0)
                zz=max(-1.89,min(1.89,zz))
                b.box((x,y,zz),(.115,.202,1.24),"weathered_oak",bevel=.035)
        for zz in (-1.85,0,1.85):
            b.beam((x, .72,zz),(x,2.63,zz),.13,.14,"dark_oak")
    for row in range(4):
        for col in range(4):
            x=-2.12+(col+.5)*4.24/4 + (.19 if row%2 else 0)
            x=max(-2.16,min(2.16,x))
            b.box((x,1.77+row*.17,-2.23),(1.13,.165,.105),"weathered_oak")
    b=m["slate_patch"]
    _slate_slope(b,-1.25,28.0)
    _slate_slope(b, 1.25,-28.0)
    b.beam((0,4.10,-2.46),(0,4.10,2.46),.19,.18,"dark_oak")
    b=m["beam"]
    b.beam((0,4.01,-2.45),(0,4.01,2.45),.34,.35,"dark_oak")
    b.beam((-2.34,2.75,2.20),(2.34,2.75,2.20),.24,.24,"weathered_oak")
    for zz in (-2.07,-.9,.28,1.46,2.08):
        b.beam((-2.29,2.79,zz),(2.29,2.79,zz),.17,.17,"weathered_oak")
        b.beam((-2.22,2.82,zz),(0,4.00,zz),.13,.13,"dark_oak")
        b.beam((0,4.00,zz),(2.22,2.82,zz),.13,.13,"dark_oak")
    b=m["stone_block"]
    for x,w,zz in ((-1.65,1.20,2.25),(1.55,1.30,2.25),(0,2.10,-2.2)):
        for row in range(2):
            for col in range(3 if abs(x)>0 else 4):
                localx=x-w/2+(col+.5)*w/(3 if abs(x)>0 else 4)
                b.stone((localx,.15+row*.29,zz),
                        (w/(3 if abs(x)>0 else 4),.29,.69),row,col)
    b=m["front_infill"]
    for x in (-1.14,1.14):
        b.panel((x,.77,2.202),(1.19,.66,.105),"lime_infill")
        b.panel((x,2.25,2.202),(1.19,.53,.105),"lime_infill")
        for dx in (-.47,.47):
            b.panel((x+dx,1.57,2.20),(.285,.95,.105),"lime_infill")
    # A low-poly lime gable fills under the two roof pitches without any
    # large rectangle projecting above the actual roof silhouette.
    for row in range(7):
        y=2.80+row*.16
        width=max(.10,4.49*(1-(y-2.80)/1.28))
        b.panel((0,y,2.204),(width,.166,.115),"lime_infill")
    for x in (-2.25,-.54,.54,2.25):
        b.beam((x,.42,2.325),(x,2.78,2.325),.16,.16,"dark_oak")
    b.beam((-2.32,2.82,2.34),(0,4.06,2.34),.18,.16,"weathered_oak")
    b.beam((0,4.06,2.34),(2.32,2.82,2.34),.18,.16,"weathered_oak")
    b.beam((-2.34,2.76,2.33),(2.34,2.76,2.33),.17,.14,"dark_oak")
    b.beam((0,2.80,2.35),(0,3.89,2.35),.12,.12,"weathered_oak")
    for x in (-1.14,1.14):
        b.box((x,1.08,2.32),(1.24,.11,.18),"weathered_oak")
    b=m["rear_infill"]
    b.panel((0,1.42,-2.20),(4.31,1.88,.10),"lime_infill")
    for row in range(7):
        y=2.80+row*.16
        width=max(.10,4.49*(1-(y-2.80)/1.28))
        b.panel((0,y,-2.20),(width,.17,.12),"lime_infill")
    for x in (-2.25,0,2.25):
        b.beam((x,.43,-2.31),(x,2.78,-2.31),.16,.15,"dark_oak")
    for sign in (-1,1):
        b.beam((sign*2.31,2.80,-2.32),(0,4.06,-2.32),.17,.16,"weathered_oak")
    b=m["threshold"]
    for i in range(4):
        b.stone((-.42+(i+.5)*.21,.09,2.37),(.22,.18,.54),0,i)
    b.box((0,.20,2.24),(1.20,.10,.18),"dark_oak")
    return m


def reusable_kit():
    k = {}
    def one(name, maker):
        part=Builder(name)
        maker(part)
        k[name]=part
    one("oak_post", lambda b:b.beam((0,-1.0,0),(0,1.0,0),.26,.24,"weathered_oak"))
    one("oak_crossbeam", lambda b:b.beam((-1,0,0),(1,0,0),.22,.24,"dark_oak"))
    one("oak_knee_brace", lambda b:b.beam((-.68,-.50,0),(.15,.53,0),.16,.17,"weathered_oak"))
    one("cladding_board", lambda b:b.box((0,0,0),(1.62,.19,.105),"weathered_oak",bevel=.028))
    one("lime_panel", lambda b:b.panel((0,0,0),(1.0,1.25,.13),"lime_infill"))
    one("rough_stone", lambda b:b.stone((0,0,0),(.65,.43,.40),1,2))
    one("slate_tile", lambda b:b.box((0,0,0),(.34,.07,.47),"slate",bevel=.028))
    one("shutter", lambda b:[b.box((-.35+(i+.5)*.175,0,0),(.16,1.0,.10),"weathered_oak")
                             for i in range(4)])
    one("linen_curtain", lambda b:b.panel((0,0,0),(1.0,1.65,.055),"unbleached_linen"))
    one("iron_strap", lambda b:b.box((0,0,0),(.06,.7,.025),"black_iron"))
    return k


def _padding(blob, pad=b"\x00"):
    return blob + pad*((-len(blob))%4)


def _save_glb(builder, target):
    # Single GLB owns all its meshes/materials/textures and imports into
    # Godot 4 as a PackedScene. Each material is one batched primitive.
    binary = bytearray()
    views, accessors, primitives = [], [], []
    images, textures_by_material = [], {}
    def add_view(payload, target_buffer=None):
        while len(binary)%4: binary.append(0)
        start=len(binary)
        binary.extend(payload)
        view={"buffer":0,"byteOffset":start,"byteLength":len(payload)}
        if target_buffer: view["target"]=target_buffer
        views.append(view)
        return len(views)-1
    for material, verts in builder.verts.items():
        if not verts:
            continue
        base_png=(MATERIAL_DIR / f"{material}_albedo.png").read_bytes()
        orm_png=(MATERIAL_DIR / f"{material}_orm.png").read_bytes()
        images.append({"bufferView":add_view(base_png),"mimeType":"image/png",
                       "name":material+"_base"})
        albedo_tex=len(images)-1
        images.append({"bufferView":add_view(orm_png),"mimeType":"image/png",
                       "name":material+"_orm"})
        textures_by_material[material]=(albedo_tex,len(images)-1)
    mats=[]
    tex=[{"source":i,"sampler":0} for i in range(len(images))]
    mat_index={}
    for name in builder.verts:
        if not builder.verts[name]:
            continue
        rough=MATERIALS[name][1]
        mat_index[name]=len(mats)
        albedo, orm=textures_by_material[name]
        mats.append({"name":name,"pbrMetallicRoughness":{
            "baseColorFactor":[1,1,1,1],
            "baseColorTexture":{"index":albedo},
            "metallicRoughnessTexture":{"index":orm},
            "metallicFactor":0.0 if name!="black_iron" else 0.20,
            "roughnessFactor":rough},"doubleSided":True})
    for name in builder.verts:
        p=builder.verts[name]
        if not p:continue
        n=builder.norms[name]
        uv=builder.uvs[name]
        indices=builder.indices[name]
        position=add_view(struct.pack("<%sf"%len(p),*p),34962)
        normal=add_view(struct.pack("<%sf"%len(n),*n),34962)
        uvview=add_view(struct.pack("<%sf"%len(uv),*uv),34962)
        idxview=add_view(struct.pack("<%sI"%len(indices),*indices),34963)
        mins=[min(p[i::3]) for i in range(3)]
        maxs=[max(p[i::3]) for i in range(3)]
        first=len(accessors)
        accessors.extend([
            {"bufferView":position,"componentType":5126,"count":len(p)//3,
             "type":"VEC3","min":mins,"max":maxs},
            {"bufferView":normal,"componentType":5126,"count":len(n)//3,
             "type":"VEC3"},
            {"bufferView":uvview,"componentType":5126,"count":len(uv)//2,
             "type":"VEC2"},
            {"bufferView":idxview,"componentType":5125,"count":len(indices),
             "type":"SCALAR"}])
        primitives.append({"attributes":{"POSITION":first,"NORMAL":first+1,
                                         "TEXCOORD_0":first+2},
                           "indices":first+3,"material":mat_index[name],"mode":4})
    rawbuffer=_padding(bytes(binary))
    doc={"asset":{"version":"2.0","generator":"Hollowmere G2 deterministic cottage authoring"},
         "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":builder.name,"mesh":0}],
         "meshes":[{"name":builder.name,"primitives":primitives}],
         "buffers":[{"byteLength":len(rawbuffer)}],"bufferViews":views,
         "accessors":accessors,"samplers":[{"magFilter":9729,"minFilter":9987,
                                             "wrapS":10497,"wrapT":10497}],
         "images":images,"textures":tex,"materials":mats}
    rawjson=_padding(json.dumps(doc,separators=(",",":"),sort_keys=True).encode()," ".encode())
    length=12+8+len(rawjson)+8+len(rawbuffer)
    blob=struct.pack("<III",0x46546C67,2,length)
    blob+=struct.pack("<II",len(rawjson),0x4E4F534A)+rawjson
    blob+=struct.pack("<II",len(rawbuffer),0x004E4942)+rawbuffer
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(blob)
    return {"path":str(target.relative_to(ROOT)).replace("\\","/"),
            "sha256":hashlib.sha256(blob).hexdigest(),
            "triangles":sum(len(f)//3 for f in builder.indices.values()),
            "members":builder.members}


def main():
    textures()
    assembled=cottage_models()
    components=reusable_kit()
    output={"version":1,"g2_part_owner_assets":{},"reusable_components":{},
            "materials":{},"palette":"1B Balanced Facets + selective 1C weathering",
            "original_cottage_part_ids":PARTS,
            "source":"tools/generate_g2_cottage_assets.py"}
    for key, builder in assembled.items():
        output["g2_part_owner_assets"][key]=_save_glb(
            builder,MODEL_DIR / f"part_{key}.glb")
    for key, builder in components.items():
        output["reusable_components"][key]=_save_glb(
            builder,KIT_DIR / f"{key}.glb")
    for key in MATERIALS:
        output["materials"][key]={
            suffix:{"path":str((MATERIAL_DIR/f"{key}_{suffix}.png").relative_to(ROOT)),
                    "sha256":hashlib.sha256(
                        (MATERIAL_DIR/f"{key}_{suffix}.png").read_bytes()).hexdigest()}
            for suffix in ("albedo","orm")}
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    MANIFEST.write_text(json.dumps(output,indent=2,sort_keys=True)+"\n")
    total=sum(v["triangles"] for v in output["g2_part_owner_assets"].values())
    print(f"G2_COTTAGE_ASSETS_OK owners={len(assembled)} kits={len(components)} "
          f"textures={len(MATERIALS)*2} triangles={total}")


if __name__ == "__main__":
    main()
