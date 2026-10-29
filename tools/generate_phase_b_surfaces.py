"""Phase B: deterministic, editable production surface overlays for Brinewick.

These are deliberately subtle *neutral* PBR tile overlays: geometry and authored
vertex colours establish the palette; overlays contribute weathering only.
Run: python tools/generate_phase_b_surfaces.py
No downloaded textures, photorealism, gameplay data or save IDs.
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'art' / 'material_sources' / 'phase_b_surfaces.json'
DEST = ROOT / 'game' / 'assets' / 'materials' / 'phase_b'


def periodic_noise(size: int, nx: int, ny: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    coarse = rng.random((ny, nx), dtype=np.float32)
    coarse = np.pad(coarse, ((0,1),(0,1)), mode='wrap')
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    x = (x / size) * nx
    y = (y / size) * ny
    ix = np.floor(x).astype(np.int32)
    iy = np.floor(y).astype(np.int32)
    dx = x - ix
    dy = y - iy
    dx = dx * dx * (3.0 - 2.0 * dx)
    dy = dy * dy * (3.0 - 2.0 * dy)
    a = coarse[iy,ix]*(1-dx)+coarse[iy,ix+1]*dx
    b = coarse[iy+1,ix]*(1-dx)+coarse[iy+1,ix+1]*dx
    return a*(1-dy)+b*dy


def make_pair(profile: str, row: dict, size: int) -> tuple[Image.Image, Image.Image]:
    seed = int(row['seed'])
    low = periodic_noise(size, 5, 6, seed)
    medium = periodic_noise(size, 23, 19, seed + 107)
    high = periodic_noise(size, 58, 60, seed + 211)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    base = float(row['tone'])
    grain = 0.0
    if profile in ('timber','deck'):
        wave = (xx / size * (37 if profile == 'timber' else 22)
                + 0.13 * np.sin(2*np.pi*yy/size))
        grain = 1.6*np.sin(wave*2*np.pi) + 0.5*np.cos(wave*4*np.pi)
    elif profile == 'slate':
        # Sparse micaceous mineral fleck; geometry provides the tile boundaries.
        grain = np.sin((xx+yy)*2*np.pi/size*12.0)*1.1
    elif profile == 'stone':
        grain = (medium - 0.5) * 2.2
    else:
        grain = (low - 0.5) * 2.4
    v = base + (low-0.5)*float(row['macro']) + (medium-0.5)*float(row['meso']) + (high-0.5)*2.4 + grain
    rgb = np.stack([v,v*0.994,v*0.982],axis=-1)
    albedo = Image.fromarray(np.uint8(np.clip(rgb, 0, 255)), 'RGB')
    rough = float(row['roughness']) + (low-0.5)*0.032 + (medium-0.5)*0.024
    rough_8 = np.uint8(np.clip(rough,0.78,1.0)*255)
    roughness = Image.fromarray(rough_8,'L').convert('RGB')
    return albedo, roughness


def main() -> None:
    config = json.loads(INPUT.read_text(encoding='utf-8'))
    size = int(config['resolution'])
    if size != 512:
        raise ValueError('Phase B surface overlays are specified at 512px')
    profiles = config['profiles']
    if sorted(profiles) != ['deck','lime','slate','stone','timber']:
        raise ValueError('Profile keys changed; update the Godot consumer explicitly')
    DEST.mkdir(parents=True, exist_ok=True)
    preview = Image.new('RGB', (size*5,size+46), '#d4d0c8')
    draw = ImageDraw.Draw(preview)
    for i,(name,details) in enumerate(sorted(profiles.items())):
        alb, rough = make_pair(name,details,size)
        alb.save(DEST / (name+'_albedo.png'),optimize=True)
        rough.save(DEST / (name+'_roughness.png'),optimize=True)
        preview.paste(alb, (i*size,0))
        draw.text((i*size+14,size+12),name,fill='#20211d')
    preview.save(DEST / 'phase_b_surface_contact.png',optimize=True)
    print('Phase B material overlays generated: 5 albedo + 5 roughness, 512px each')

if __name__ == '__main__':
    main()
