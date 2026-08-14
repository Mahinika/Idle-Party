"""Mothveil art: pale lilac moth-dust recolors + World Path strip under Brassvault."""

from __future__ import annotations

import os
import random
import shutil

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
CUSTOM = os.path.join(ROOT, 'assets', 'custom')
MAP_SRC = os.path.join(CUSTOM, 'ui', 'world_path_map.png')
MAP_BAK = os.path.join(CUSTOM, 'ui', 'world_path_map_14zone_bak.png')

# Hub markers on the 14-zone (2292px) map — rescale after extend.
OLD_MARKERS = [
    (0.492, 0.038),
    (0.478, 0.092),
    (0.470, 0.152),
    (0.508, 0.213),
    (0.448, 0.268),
    (0.475, 0.329),
    (0.460, 0.385),
    (0.500, 0.439),
    (0.458, 0.492),
    (0.472, 0.560),
    (0.488, 0.633),
    (0.500, 0.752),
    (0.489, 0.855),
    (0.505, 0.960),
]


def moth_recolor(im: Image.Image) -> Image.Image:
    """Shift toward dusty lilac / moth wing (not brass gold, not fen green)."""
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if g > r + 14 and g > b:
                # greens → dusty mauve
                nr = max(0, min(255, int(r * 0.70 + 70)))
                ng = max(0, min(255, int(g * 0.42 + 36)))
                nb = max(0, min(255, int(b * 0.55 + 88)))
                px[x, y] = (nr, ng, nb, a)
            elif r > g + 18 and r > b + 12 and g > 90:
                # brass/ember gold → pale wing cream
                nr = max(0, min(255, int(r * 0.72 + 48)))
                ng = max(0, min(255, int(g * 0.62 + 40)))
                nb = max(0, min(255, int(b * 0.85 + 70)))
                px[x, y] = (nr, ng, nb, a)
            elif b > r + 10 and b > g:
                # cool blues → lilac
                nr = max(0, min(255, int(r * 0.85 + 55)))
                ng = max(0, min(255, int(g * 0.70 + 32)))
                nb = max(0, min(255, int(b * 0.78 + 40)))
                px[x, y] = (nr, ng, nb, a)
            else:
                nr = max(0, min(255, int(r * 0.82 + 42)))
                ng = max(0, min(255, int(g * 0.68 + 28)))
                nb = max(0, min(255, int(b * 0.90 + 58)))
                px[x, y] = (nr, ng, nb, a)
    return im


def extract_ring(base: Image.Image) -> Image.Image:
    w, h = base.size
    cx, cy = int(w * 0.505), int(h * 0.960)
    r = 46
    box = (cx - r, cy - r, cx + r, cy + r)
    ring = base.crop(box).convert('RGBA')
    mask = Image.new('L', ring.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([2, 2, ring.size[0] - 3, ring.size[1] - 3], fill=255)
    ring.putalpha(mask)
    return moth_recolor(ring)


def write_still(src: str, dest: str, *, darken: float = 0.88) -> None:
    im = Image.open(src)
    out = moth_recolor(im)
    out = ImageEnhance.Color(out).enhance(1.12)
    out = ImageEnhance.Brightness(out).enhance(darken)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print('wrote', dest, out.size)


def write_boss(src: str, dest: str) -> None:
    im = Image.open(src).convert('RGBA')
    out = moth_recolor(im)
    out = ImageEnhance.Brightness(out).enhance(0.92)
    out = ImageEnhance.Color(out).enhance(1.18)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print('wrote', dest, out.size)


def extend_map() -> tuple[float, float, float, int, int]:
    if not os.path.exists(MAP_BAK):
        shutil.copy2(MAP_SRC, MAP_BAK)
    base = Image.open(MAP_BAK).convert('RGBA')
    w, h = base.size
    print('base', w, h)
    extra = 240
    new_h = h + extra

    band = base.crop((0, int(h * 0.18), w, int(h * 0.32))).resize(
        (w, extra + 36),
        Image.NEAREST,
    )
    band = moth_recolor(band)
    band = ImageEnhance.Brightness(band).enhance(0.78)
    band = ImageEnhance.Color(band).enhance(1.15)
    band = ImageOps.flip(band)

    out = Image.new('RGBA', (w, new_h), (18, 8, 16, 255))
    out.paste(base, (0, 0))
    dark = Image.new('RGBA', (w, extra), (16, 6, 14, 255))
    out.paste(dark, (0, h))

    piece = band.crop((0, 16, w, 16 + extra)).convert('RGBA')
    fade = Image.new('L', (w, extra), 255)
    fd = ImageDraw.Draw(fade)
    for y in range(40):
        fd.line([(0, y), (w, y)], fill=int(255 * (y / 39)))
    piece.putalpha(fade)
    out.paste(piece, (0, h), piece)

    path_src = base.crop((int(w * 0.42), int(h * 0.92), int(w * 0.58), int(h * 0.99)))
    path_src = moth_recolor(path_src)
    for i, y0 in enumerate(range(h - 10, h + int(extra * 0.58), 6)):
        tile = path_src.resize((int(w * 0.16), 10), Image.NEAREST)
        x = int(w * 0.43) + (3 if i % 2 == 0 else -3)
        out.paste(tile, (x, y0), tile if tile.mode == 'RGBA' else None)

    tip = out.crop((0, h - 24, w, h)).convert('RGBA')
    tip = Image.alpha_composite(tip, Image.new('RGBA', tip.size, (200, 150, 210, 36)))
    out.paste(tip, (0, h - 24))

    rng = random.Random(15)
    spark = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    for _ in range(80):
        x = rng.randint(40, w - 40)
        y = rng.randint(h + 24, new_h - 16)
        s = rng.randint(1, 2)
        sd.ellipse(
            [x, y, x + s, y + s],
            fill=(230, 190, 230, rng.randint(40, 130)),
        )
    out = Image.alpha_composite(out, spark)

    ring = extract_ring(base)
    ring_cx = int(w * 0.498)
    ring_cy = h + int(extra * 0.62)
    glow = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [ring_cx - 58, ring_cy - 34, ring_cx + 58, ring_cy + 42],
        fill=(200, 140, 210, 48),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    out = Image.alpha_composite(out, glow)
    rw, rh = ring.size
    out.paste(ring, (ring_cx - rw // 2, ring_cy - rh // 2), ring)

    final = out.convert('RGB')
    final.save(MAP_SRC)
    print('wrote', MAP_SRC, final.size)
    print('ring_norm', round(ring_cx / w, 4), round(ring_cy / new_h, 4))
    print('mapAspect', new_h, '/', w)
    print('HUB_MARKERS')
    scale = h / new_h
    labels = [
        'sandy', 'goblin', 'king', 'underworld', 'dead', 'hell', 'crystal',
        'tide', 'ember', 'grove', 'storm', 'rime', 'fen', 'brass',
    ]
    for i, (nx, ny) in enumerate(OLD_MARKERS):
        print(f'    Offset({nx:.3f}, {ny * scale:.3f}), // {labels[i]}')
    print(f'    Offset({ring_cx / w:.3f}, {ring_cy / new_h:.3f}), // veil')
    return ring_cx / w, ring_cy / new_h, new_h / w, w, new_h


def main() -> None:
    write_still(
        os.path.join(CUSTOM, 'portraits', 'grove.png'),
        os.path.join(CUSTOM, 'portraits', 'veil.png'),
        darken=0.86,
    )
    write_still(
        os.path.join(CUSTOM, 'ui', 'backdrops', 'grove.png'),
        os.path.join(CUSTOM, 'ui', 'backdrops', 'veil.png'),
        darken=0.80,
    )
    write_still(
        os.path.join(CUSTOM, 'enemies', 'bat.png'),
        os.path.join(CUSTOM, 'enemies', 'veil_mite.png'),
        darken=0.94,
    )
    write_boss(
        os.path.join(CUSTOM, 'enemies', 'ghost.png'),
        os.path.join(CUSTOM, 'enemies', 'boss_veil.png'),
    )
    nx, ny, aspect, w, h = extend_map()
    print('HUB_MARKER', nx, ny, 'aspect', round(aspect, 6), 'size', w, h)


if __name__ == '__main__':
    main()
