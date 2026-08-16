"""Rebuild World Path endgame from clean Stormwake (11-zone) base + strip art.

Usage:
  py -3 tool/rebuild_world_path_endgame.py

Reads:
  tool/out/world_path_11.png          (auto-extracted from git 9f54ed8 if missing)
  tool/out/world_path_endgame_strip.png  (optional painted continuation)

Writes:
  assets/custom/ui/world_path_map.png
  prints updated markerNorm for hub_screen.dart
"""

from __future__ import annotations

import math
import os
import subprocess

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
OUT_MAP = os.path.join(ROOT, 'assets', 'custom', 'ui', 'world_path_map.png')
BASE_11 = os.path.join(ROOT, 'tool', 'out', 'world_path_11.png')
STRIP = os.path.join(ROOT, 'tool', 'world_path_endgame_strip.png')
STRIP_FALLBACK = os.path.join(ROOT, 'tool', 'out', 'world_path_endgame_strip.png')
EXTRA = 996  # 1536 + 996 = 2532

MARKERS_11 = [
    (0.491, 0.070),
    (0.483, 0.145),
    (0.474, 0.240),
    (0.514, 0.325),
    (0.454, 0.410),
    (0.479, 0.500),
    (0.465, 0.585),
    (0.503, 0.665),
    (0.466, 0.740),
    (0.478, 0.845),
    (0.485, 0.940),
]
LABELS = [
    'sandy', 'goblin', 'king', 'underworld', 'dead', 'hell', 'crystal',
    'tide', 'ember', 'grove', 'storm', 'rime', 'fen', 'brass', 'veil',
]


def ensure_base_11() -> Image.Image:
    os.makedirs(os.path.dirname(BASE_11), exist_ok=True)
    if not os.path.exists(BASE_11):
        data = subprocess.check_output(
            ['git', 'cat-file', 'blob', '9f54ed8:assets/custom/ui/world_path_map.png'],
        )
        open(BASE_11, 'wb').write(data)
    im = Image.open(BASE_11).convert('RGBA')
    assert im.size == (1024, 1536), im.size
    return im


def main() -> None:
    base = ensure_base_11()
    w, h = base.size
    new_h = h + EXTRA
    assert os.path.exists(STRIP) or os.path.exists(STRIP_FALLBACK), (
        f'Missing strip art: {STRIP}'
    )
    strip_path = STRIP if os.path.exists(STRIP) else STRIP_FALLBACK
    strip = Image.open(strip_path).convert('RGBA')
    sw, sh = strip.size
    strip = strip.crop((0, int(sh * 0.08), sw, sh)).resize((w, EXTRA), Image.NEAREST)
    strip = strip.resize((w // 2, EXTRA // 2), Image.NEAREST).resize((w, EXTRA), Image.NEAREST)

    out = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    out.paste(base, (0, 0))
    fade = Image.new('L', (w, EXTRA), 255)
    fd = ImageDraw.Draw(fade)
    for i in range(80):
        fd.line([(0, i), (w, i)], fill=int(255 * (i / 79)))
    strip2 = strip.copy()
    strip2.putalpha(fade)
    out.paste(strip2, (0, h), strip2)

    bridge = Image.new('RGBA', (w, 100), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bridge)
    for i in range(100):
        a = int(70 * (1 - abs(i - 50) / 50))
        bd.line([(0, i), (w, i)], fill=(16, 6, 22, a))
    bl = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    bl.paste(bridge, (0, h - 45), bridge)
    out = Image.alpha_composite(out, bl)

    chunk = base.crop((int(w * 0.38), int(h * 0.30), int(w * 0.62), int(h * 0.40))).convert('RGBA')
    for i in range(24):
        t = i / 23
        y = h - 28 + int(110 * t)
        x = int(w * (0.49 + 0.035 * math.sin(t * 5.5)))
        tile = chunk.resize((int(w * 0.17), 13), Image.NEAREST)
        m = Image.new('L', tile.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, tile.size[0] - 1, tile.size[1] - 1], fill=215)
        tile.putalpha(m)
        layer = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
        layer.paste(tile, (x - tile.size[0] // 2, y), tile)
        out = Image.alpha_composite(out, layer)

    px = out.load()
    cands: list[tuple[int, int]] = []
    for y in range(h + 40, new_h - 20, 2):
        for x in range(int(w * 0.42), int(w * 0.58), 2):
            r, g, b = px[x, y][:3]
            if r > 175 and 120 < g < 200 and b < 100 and r > b + 50:
                cands.append((x, y))
    clusters: list[list[float]] = []
    for x, y in cands:
        placed = False
        for c in clusters:
            if abs(y - c[1]) < 50 and abs(x - c[0]) < 60:
                n = c[2]
                c[0] = (c[0] * n + x) / (n + 1)
                c[1] = (c[1] * n + y) / (n + 1)
                c[2] = n + 1
                placed = True
                break
        if not placed:
            clusters.append([float(x), float(y), 1.0])
    clusters = sorted([c for c in clusters if c[2] >= 12], key=lambda c: c[1])
    picked: list[list[float]] = []
    for c in clusters:
        if not picked or c[1] - picked[-1][1] > new_h * 0.07:
            picked.append(c)
        if len(picked) == 4:
            break
    fallbacks = [(0.50, 0.68), (0.49, 0.77), (0.505, 0.87), (0.50, 0.96)]
    while len(picked) < 4:
        nx, ny = fallbacks[len(picked)]
        picked.append([nx * w, ny * new_h, 1.0])

    cx0, cy0 = int(w * 0.485), int(h * 0.940)
    rr = 48
    ring = base.crop((cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr)).convert('RGBA')
    mask = Image.new('L', ring.size, 0)
    ImageDraw.Draw(mask).ellipse([1, 1, ring.size[0] - 2, ring.size[1] - 2], fill=255)
    ring.putalpha(mask)
    glows = [
        (55, 190, 220, 52),
        (140, 185, 30, 48),
        (200, 150, 40, 46),
        (195, 135, 210, 50),
    ]
    for (cx, cy, _n), glow in zip(picked, glows):
        cx_i, cy_i = int(cx), int(cy)
        g = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
        ImageDraw.Draw(g).ellipse([cx_i - 54, cy_i - 30, cx_i + 54, cy_i + 38], fill=glow)
        g = g.filter(ImageFilter.GaussianBlur(6))
        out = Image.alpha_composite(out, g)
        out.paste(ring, (cx_i - ring.size[0] // 2, cy_i - ring.size[1] // 2), ring)

    final = out.convert('RGB')
    final.save(OUT_MAP, optimize=True)
    print('wrote', OUT_MAP, final.size)

    scale = h / new_h
    print('HUB markerNorm:')
    for (nx, ny), lab in zip(MARKERS_11, LABELS):
        print(f'    Offset({nx:.3f}, {ny * scale:.3f}), // {lab}')
    for (cx, cy, _n), lab in zip(picked, LABELS[11:]):
        print(f'    Offset({cx / w:.3f}, {cy / new_h:.3f}), // {lab}')


if __name__ == '__main__':
    main()
