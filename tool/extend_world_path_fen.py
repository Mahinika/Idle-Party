"""Blightfen art: bile recolors + World Path mire strip under Rimeglass."""

from __future__ import annotations

import os
import random
import shutil

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
CUSTOM = os.path.join(ROOT, 'assets', 'custom')
MAP_SRC = os.path.join(CUSTOM, 'ui', 'world_path_map.png')
MAP_BAK = os.path.join(CUSTOM, 'ui', 'world_path_map_12zone_bak.png')


def bile_recolor(im: Image.Image, *, ice_to_mire: bool = False) -> Image.Image:
    """Shift toward sickly yellow-green (not grove-healthy, not rime-cyan)."""
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
            if ice_to_mire and b > g + 12:
                # cyan ice → olive muck
                nr = max(0, min(255, int(r * 0.55 + 28)))
                ng = max(0, min(255, int(g * 0.85 + 40)))
                nb = max(0, min(255, int(b * 0.22)))
                px[x, y] = (nr, ng, nb, a)
                continue
            if g > r + 8 and g > b:
                # healthy grove green → bile yellow-green
                nr = max(0, min(255, int(r * 0.9 + 36)))
                ng = max(0, min(255, int(g * 0.78 + 18)))
                nb = max(0, min(255, int(b * 0.35)))
                px[x, y] = (nr, ng, nb, a)
            elif b > r and abs(g - b) < 40:
                nr = max(0, min(255, int(r * 0.7 + 20)))
                ng = max(0, min(255, int(g * 1.05 + 24)))
                nb = max(0, min(255, int(b * 0.28)))
                px[x, y] = (nr, ng, nb, a)
            else:
                nr = max(0, min(255, int(r * 0.72 + 18)))
                ng = max(0, min(255, int(g * 0.95 + 22)))
                nb = max(0, min(255, int(b * 0.45)))
                px[x, y] = (nr, ng, nb, a)
    return im


def extract_ring(base: Image.Image) -> Image.Image:
    w, h = base.size
    cx, cy = int(w * 0.50), int(h * 0.951)
    r = 46
    box = (cx - r, cy - r, cx + r, cy + r)
    ring = base.crop(box).convert('RGBA')
    mask = Image.new('L', ring.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([2, 2, ring.size[0] - 3, ring.size[1] - 3], fill=255)
    ring.putalpha(mask)
    return ring


def write_still(src: str, dest: str, *, ice: bool = False, darken: float = 0.88) -> None:
    im = Image.open(src)
    out = bile_recolor(im, ice_to_mire=ice)
    out = ImageEnhance.Color(out).enhance(1.12)
    out = ImageEnhance.Brightness(out).enhance(darken)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print('wrote', dest, out.size)


def write_boss(src: str, dest: str) -> None:
    im = Image.open(src).convert('RGBA')
    out = bile_recolor(im, ice_to_mire=False)
    out = ImageEnhance.Brightness(out).enhance(0.72)
    out = ImageEnhance.Color(out).enhance(1.2)
    # Keep native pixel size — combat sprites stay small.
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print('wrote', dest, out.size)


def extend_map() -> tuple[float, float, float]:
    if not os.path.exists(MAP_BAK):
        shutil.copy2(MAP_SRC, MAP_BAK)
    base = Image.open(MAP_BAK).convert('RGBA')
    w, h = base.size
    print('base', w, h)
    extra = 240
    new_h = h + extra

    # Grove/forest band as swamp plate; flip so it reads as descent.
    band = base.crop((0, int(h * 0.64), w, int(h * 0.76))).resize(
        (w, extra + 36),
        Image.NEAREST,
    )
    band = bile_recolor(band, ice_to_mire=False)
    band = ImageEnhance.Brightness(band).enhance(0.7)
    band = ImageEnhance.Color(band).enhance(1.18)
    band = ImageOps.flip(band)

    out = Image.new('RGBA', (w, new_h), (10, 16, 6, 255))
    out.paste(base, (0, 0))
    dark = Image.new('RGBA', (w, extra), (8, 14, 4, 255))
    out.paste(dark, (0, h))

    piece = band.crop((0, 16, w, 16 + extra)).convert('RGBA')
    fade = Image.new('L', (w, extra), 255)
    fd = ImageDraw.Draw(fade)
    for y in range(40):
        fd.line([(0, y), (w, y)], fill=int(255 * (y / 39)))
    piece.putalpha(fade)
    out.paste(piece, (0, h), piece)

    path_src = base.crop((int(w * 0.42), int(h * 0.92), int(w * 0.58), int(h * 0.99)))
    path_src = bile_recolor(path_src, ice_to_mire=True)
    for i, y0 in enumerate(range(h - 10, h + int(extra * 0.58), 6)):
        tile = path_src.resize((int(w * 0.16), 10), Image.NEAREST)
        x = int(w * 0.43) + (3 if i % 2 == 0 else -3)
        out.paste(tile, (x, y0), tile if tile.mode == 'RGBA' else None)

    tip = out.crop((0, h - 24, w, h)).convert('RGBA')
    tip = Image.alpha_composite(tip, Image.new('RGBA', tip.size, (140, 180, 30, 40)))
    out.paste(tip, (0, h - 24))

    rng = random.Random(13)
    mist = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for _ in range(80):
        x = rng.randint(40, w - 40)
        y = rng.randint(h + 24, new_h - 16)
        s = rng.randint(1, 3)
        md.ellipse(
            [x, y, x + s, y + s],
            fill=(180, 210, 40, rng.randint(35, 110)),
        )
    out = Image.alpha_composite(out, mist)

    ring = extract_ring(base)
    ring_cx = int(w * 0.49)
    ring_cy = h + int(extra * 0.62)
    glow = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [ring_cx - 58, ring_cy - 34, ring_cx + 58, ring_cy + 42],
        fill=(150, 190, 30, 50),
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
    return ring_cx / w, ring_cy / new_h, new_h / w


def main() -> None:
    write_still(
        os.path.join(CUSTOM, 'portraits', 'grove.png'),
        os.path.join(CUSTOM, 'portraits', 'fen.png'),
        darken=0.82,
    )
    write_still(
        os.path.join(CUSTOM, 'ui', 'backdrops', 'grove.png'),
        os.path.join(CUSTOM, 'ui', 'backdrops', 'fen.png'),
        darken=0.78,
    )
    write_still(
        os.path.join(CUSTOM, 'enemies', 'slime.png'),
        os.path.join(CUSTOM, 'enemies', 'fen_mite.png'),
        darken=0.92,
    )
    write_boss(
        os.path.join(CUSTOM, 'enemies', 'slime.png'),
        os.path.join(CUSTOM, 'enemies', 'boss_fen.png'),
    )
    nx, ny, aspect = extend_map()
    print('HUB_MARKER', nx, ny, 'aspect', round(aspect, 6))


if __name__ == '__main__':
    main()
