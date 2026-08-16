"""Brassvault art: gold-metal recolors + World Path strip under Blightfen."""

from __future__ import annotations

import os
import random
import shutil

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
CUSTOM = os.path.join(ROOT, 'assets', 'custom')
MAP_SRC = os.path.join(CUSTOM, 'ui', 'world_path_map.png')
MAP_BAK = os.path.join(CUSTOM, 'ui', 'world_path_map_13zone_bak.png')

# Hub markers on the 13-zone (2052px) map — rescale after extend.
OLD_MARKERS = [
    (0.492, 0.043),
    (0.478, 0.103),
    (0.470, 0.170),
    (0.508, 0.238),
    (0.448, 0.299),
    (0.475, 0.367),
    (0.460, 0.430),
    (0.500, 0.490),
    (0.458, 0.550),
    (0.472, 0.625),
    (0.488, 0.707),
    (0.500, 0.840),
    (0.489, 0.955),
]


def brass_recolor(im: Image.Image, *, cool_to_brass: bool = False) -> Image.Image:
    """Shift toward dull gold / copper (not ember-orange, not fen-green)."""
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            # gold rings / UI metal
            if r > 180 and g > 140 and b < 120:
                continue
            if cool_to_brass and b > r + 8:
                nr = max(0, min(255, int(r * 0.55 + 90)))
                ng = max(0, min(255, int(g * 0.70 + 55)))
                nb = max(0, min(255, int(b * 0.22 + 8)))
                px[x, y] = (nr, ng, nb, a)
                continue
            if g > r + 12 and g > b:
                # leftover greens → tarnished brass
                nr = max(0, min(255, int(r * 0.95 + 48)))
                ng = max(0, min(255, int(g * 0.62 + 28)))
                nb = max(0, min(255, int(b * 0.30)))
                px[x, y] = (nr, ng, nb, a)
            elif r > g + 20 and r > b + 20:
                # ember/sand red-orange → yellower metal, less fire
                nr = max(0, min(255, int(r * 0.82 + 18)))
                ng = max(0, min(255, int(g * 1.08 + 22)))
                nb = max(0, min(255, int(b * 0.45 + 6)))
                px[x, y] = (nr, ng, nb, a)
            else:
                nr = max(0, min(255, int(r * 0.88 + 36)))
                ng = max(0, min(255, int(g * 0.82 + 28)))
                nb = max(0, min(255, int(b * 0.38)))
                px[x, y] = (nr, ng, nb, a)
    return im


def extract_ring(base: Image.Image) -> Image.Image:
    w, h = base.size
    cx, cy = int(w * 0.489), int(h * 0.955)
    r = 46
    box = (cx - r, cy - r, cx + r, cy + r)
    ring = base.crop(box).convert('RGBA')
    mask = Image.new('L', ring.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([2, 2, ring.size[0] - 3, ring.size[1] - 3], fill=255)
    ring.putalpha(mask)
    return ring


def write_still(src: str, dest: str, *, cool: bool = False, darken: float = 0.88) -> None:
    im = Image.open(src)
    out = brass_recolor(im, cool_to_brass=cool)
    out = ImageEnhance.Color(out).enhance(1.15)
    out = ImageEnhance.Brightness(out).enhance(darken)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print('wrote', dest, out.size)


def write_boss(src: str, dest: str) -> None:
    im = Image.open(src).convert('RGBA')
    out = brass_recolor(im, cool_to_brass=True)
    out = ImageEnhance.Brightness(out).enhance(0.78)
    out = ImageEnhance.Color(out).enhance(1.22)
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
    band = brass_recolor(band, cool_to_brass=True)
    band = ImageEnhance.Brightness(band).enhance(0.72)
    band = ImageEnhance.Color(band).enhance(1.2)
    band = ImageOps.flip(band)

    out = Image.new('RGBA', (w, new_h), (18, 10, 4, 255))
    out.paste(base, (0, 0))
    dark = Image.new('RGBA', (w, extra), (16, 8, 3, 255))
    out.paste(dark, (0, h))

    piece = band.crop((0, 16, w, 16 + extra)).convert('RGBA')
    fade = Image.new('L', (w, extra), 255)
    fd = ImageDraw.Draw(fade)
    for y in range(40):
        fd.line([(0, y), (w, y)], fill=int(255 * (y / 39)))
    piece.putalpha(fade)
    out.paste(piece, (0, h), piece)

    path_src = base.crop((int(w * 0.42), int(h * 0.92), int(w * 0.58), int(h * 0.99)))
    path_src = brass_recolor(path_src, cool_to_brass=True)
    for i, y0 in enumerate(range(h - 10, h + int(extra * 0.58), 6)):
        tile = path_src.resize((int(w * 0.16), 10), Image.NEAREST)
        x = int(w * 0.43) + (3 if i % 2 == 0 else -3)
        out.paste(tile, (x, y0), tile if tile.mode == 'RGBA' else None)

    tip = out.crop((0, h - 24, w, h)).convert('RGBA')
    tip = Image.alpha_composite(tip, Image.new('RGBA', tip.size, (200, 150, 40, 36)))
    out.paste(tip, (0, h - 24))

    rng = random.Random(14)
    spark = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    for _ in range(70):
        x = rng.randint(40, w - 40)
        y = rng.randint(h + 24, new_h - 16)
        s = rng.randint(1, 2)
        sd.ellipse(
            [x, y, x + s, y + s],
            fill=(220, 180, 70, rng.randint(40, 120)),
        )
    out = Image.alpha_composite(out, spark)

    ring = extract_ring(base)
    ring_cx = int(w * 0.505)
    ring_cy = h + int(extra * 0.62)
    glow = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [ring_cx - 58, ring_cy - 34, ring_cx + 58, ring_cy + 42],
        fill=(200, 150, 40, 48),
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
    for i, (nx, ny) in enumerate(OLD_MARKERS):
        print(f'    Offset({nx:.3f}, {ny * scale:.3f}), // {i}')
    print(f'    Offset({ring_cx / w:.3f}, {ring_cy / new_h:.3f}), // brass')
    return ring_cx / w, ring_cy / new_h, new_h / w, w, new_h


def main() -> None:
    write_still(
        os.path.join(CUSTOM, 'portraits', 'king.png'),
        os.path.join(CUSTOM, 'portraits', 'brass.png'),
        cool=True,
        darken=0.84,
    )
    write_still(
        os.path.join(CUSTOM, 'ui', 'backdrops', 'king.png'),
        os.path.join(CUSTOM, 'ui', 'backdrops', 'brass.png'),
        cool=True,
        darken=0.80,
    )
    write_still(
        os.path.join(CUSTOM, 'enemies', 'rat.png'),
        os.path.join(CUSTOM, 'enemies', 'brass_mite.png'),
        cool=False,
        darken=0.90,
    )
    write_boss(
        os.path.join(CUSTOM, 'enemies', 'golem.png'),
        os.path.join(CUSTOM, 'enemies', 'boss_brass.png'),
    )
    nx, ny, aspect, w, h = extend_map()
    print('HUB_MARKER', nx, ny, 'aspect', round(aspect, 6), 'size', w, h)


if __name__ == '__main__':
    main()
