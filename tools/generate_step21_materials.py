"""Deterministic editable source for Hollowmere Step21 PBR texture studies.

Requires Python 3, Pillow, NumPy. Run from repository root:
  python tools/generate_step21_materials.py
The generated PNGs are committed assets; rebuilding them is not required to run Godot.
No procedural texture runtime cost or reliance on unapproved material prices.
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'game' / 'assets' / 'materials' / 'step21'
SETTINGS = ROOT / 'art' / 'material_sources' / 'step21_materials.json'


def periodic_noise(n: int, rows: int, cols: int, seed: int) -> np.ndarray:
    """Periodic smooth 2D noise: opposite edges share values exactly."""
    r = np.random.default_rng(seed)
    coarse = r.random((rows, cols), dtype=np.float32)
    coarse = np.pad(coarse, ((0, 1), (0, 1)), mode='wrap')
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    fx = x / n * cols; fy = y / n * rows
    ix = np.floor(fx).astype(np.int32); iy = np.floor(fy).astype(np.int32)
    sx = (fx - ix); sy = (fy - iy)
    sx = sx*sx*(3-2*sx); sy = sy*sy*(3-2*sy)
    a = coarse[iy, ix]*(1-sx) + coarse[iy, ix+1]*sx
    b = coarse[iy+1, ix]*(1-sx) + coarse[iy+1, ix+1]*sx
    return a*(1-sy) + b*sy


def create(m: dict, n: int) -> tuple[Image.Image, Image.Image]:
    base = np.array(tuple(bytes.fromhex(m['base_hex'].lstrip('#'))), dtype=np.float32)
    salt = int(m['seed']); timber = m['family'] == 'timber'
    big = periodic_noise(n, 4, 5, salt)
    mid = periodic_noise(n, 12, 9, salt+11)
    fine = periodic_noise(n, 37, 36, salt+23)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # Long, uneven grain follows board length, with subtle waviness and weather.
    if timber:
        lateral = xx / n * 19.0 + 0.20*np.sin(yy/n*2*np.pi)*np.sin(xx/n*2*np.pi)
        grain = np.sin(lateral*2*np.pi + (mid-.5)*0.9)
        grain2 = np.sin(lateral*2*np.pi*2.9 + (big-.5)*1.2)
        variation = (big-.5)*13 + (mid-.5)*11 + grain*2.4 + grain2*0.8 + (fine-.5)*2.1
        rgb = base[None,None,:] + variation[:,:,None]*np.array([1.00,0.95,0.82])[None,None,:]
        # A few long exposed fibres, not a high-contrast photoreal wood photograph.
        rough = m['roughness'] + (mid-.5)*0.09 + (fine-.5)*0.025
    else:
        # Broad hand-applied plaster mottling, small lime-aggregate warmth.
        variation = (big-.5)*19 + (mid-.5)*9 + (fine-.5)*3
        rgb = base[None,None,:] + variation[:,:,None]*np.array([1.0,0.94,0.87])[None,None,:]
        rough = m['roughness'] + (big-.5)*0.06 + (mid-.5)*0.025
    diffuse = Image.fromarray(np.asarray(np.clip(rgb, 0, 255), dtype=np.uint8), 'RGB')
    grey = np.uint8(np.clip(rough, 0.63, 1.0)*255)
    return diffuse, Image.fromarray(grey, 'L').convert('RGB')


def main() -> None:
    config = json.loads(SETTINGS.read_text())
    n = int(config['resolution'])
    if n not in (512, 1024):
        raise ValueError('Only 512 and 1024 study textures are expected')
    DEST.mkdir(parents=True, exist_ok=True)
    tiles = []
    for key, item in config['materials'].items():
        albedo, rough = create(item, n)
        albedo.save(DEST / (key + '_albedo.png'), optimize=True)
        rough.save(DEST / (key + '_roughness.png'), optimize=True)
        tiles.append((key, albedo))
    # A contact sheet is a non-engine design preview, not render proof.
    preview = Image.new('RGB', (n*3, (n+48)*2), '#d3d0ca')
    d = ImageDraw.Draw(preview)
    for i,(key,im) in enumerate(tiles):
        x = (i % 3) * n; y = (i // 3)*(n+48)
        preview.paste(im, (x,y))
        d.text((x+12,y+n+14), key, fill='#25251f')
    preview.save(DEST / 'step21_contact_sheet.png', optimize=True)
    print('Generated', len(tiles), 'PBR material pairs at', n, 'px')

if __name__ == '__main__':
    main()