"""Rebuild world_path_map with a Rimeglass footer sampled from the map's own art."""

from __future__ import annotations

import os
import random

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'assets', 'custom', 'ui', 'world_path_map.png')
BAK = os.path.join(ROOT, 'assets', 'custom', 'ui', 'world_path_map_11zone_bak.png')


def ice_recolor(im: Image.Image) -> Image.Image:
    """Pull crystal blues toward colder cyan and mute purple."""
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            # gold rings — leave alone
            if r > 180 and g > 140 and b < 120:
                continue
            # shift purple-ish toward teal
            if b > r and b > g:
                nb = min(255, int(b * 0.92 + 20))
                ng = min(255, int(g * 1.15 + 18))
                nr = max(0, int(r * 0.55))
                px[x, y] = (nr, ng, nb, a)
            elif g > 40 and b > 40:
                nb = min(255, int(b * 1.08 + 10))
                ng = min(255, int(g * 1.05 + 8))
                nr = max(0, int(r * 0.7))
                px[x, y] = (nr, ng, nb, a)
    return im


def extract_ring(base: Image.Image) -> Image.Image:
    """Crop the bottom storm ring as a template (approx)."""
    w, h = base.size
    # storm ring near bottom-center on 11-zone map
    cx, cy = int(w * 0.488), int(h * 0.945)
    r = 46
    box = (cx - r, cy - r, cx + r, cy + r)
    ring = base.crop(box).convert('RGBA')
    # punch soft circle alpha so we can paste cleanly
    mask = Image.new('L', ring.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([2, 2, ring.size[0] - 3, ring.size[1] - 3], fill=255)
    ring.putalpha(mask)
    return ring


def main() -> None:
    if not os.path.exists(BAK):
        cur = Image.open(SRC)
        if cur.size[1] > 1600:
            raise SystemExit('Need world_path_map_11zone_bak.png')
        cur.save(BAK)

    base = Image.open(BAK).convert('RGBA')
    w, h = base.size
    print('base', w, h)

    extra = 276
    new_h = h + extra

    # Sample crystal peaks band (~0.52–0.62 of original) as ice plate material.
    band = base.crop((0, int(h * 0.52), w, int(h * 0.64))).resize(
        (w, extra + 40),
        Image.NEAREST,
    )
    band = ice_recolor(band)
    band = ImageEnhance.Brightness(band).enhance(0.78)
    band = ImageEnhance.Color(band).enhance(1.15)
    # Flip vertically so peaks read as hanging rime / descent into rift
    band = ImageOps.flip(band)

    out = Image.new('RGBA', (w, new_h), (4, 14, 22, 255))
    out.paste(base, (0, 0))

    # Dark underpaint
    dark = Image.new('RGBA', (w, extra), (3, 10, 18, 255))
    out.paste(dark, (0, h))

    # Soft-top alpha for band
    piece = band.crop((0, 20, w, 20 + extra)).convert('RGBA')
    fade = Image.new('L', (w, extra), 255)
    fd = ImageDraw.Draw(fade)
    for y in range(48):
        fd.line([(0, y), (w, y)], fill=int(255 * (y / 47)))
    piece.putalpha(fade)
    out.paste(piece, (0, h), piece)

    # Bridge path from storm into ice using pixels near storm path
    path_src = base.crop((int(w * 0.42), int(h * 0.90), int(w * 0.58), int(h * 0.98)))
    path_src = ice_recolor(path_src)
    for i, y0 in enumerate(range(h - 8, h + int(extra * 0.62), 6)):
        tile = path_src.resize((int(w * 0.16), 10), Image.NEAREST)
        x = int(w * 0.42) + (2 if i % 2 == 0 else -2)
        out.paste(tile, (x, y0), tile if tile.mode == 'RGBA' else None)

    # Ice-tint last storm rows
    tip = out.crop((0, h - 28, w, h)).convert('RGBA')
    tip = Image.alpha_composite(tip, Image.new('RGBA', tip.size, (50, 170, 200, 45)))
    out.paste(tip, (0, h - 28))

    # Mist
    rng = random.Random(3)
    mist = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for _ in range(90):
        x = rng.randint(40, w - 40)
        y = rng.randint(h + 30, new_h - 20)
        s = rng.randint(1, 2)
        md.ellipse([x, y, x + s, y + s], fill=(170, 220, 235, rng.randint(40, 120)))
    out = Image.alpha_composite(out, mist)

    # Paste storm-style gold ring for zone 12
    ring = extract_ring(base)
    ring_cx = int(w * 0.50)
    ring_cy = h + int(extra * 0.68)
    # mild cyan glow under ring
    glow = Image.new('RGBA', (w, new_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [ring_cx - 60, ring_cy - 36, ring_cx + 60, ring_cy + 44],
        fill=(60, 200, 220, 55),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    out = Image.alpha_composite(out, glow)
    rw, rh = ring.size
    out.paste(ring, (ring_cx - rw // 2, ring_cy - rh // 2), ring)

    final = out.convert('RGB')
    final.save(SRC)
    print('wrote', SRC, final.size)
    print('ring_norm', round(ring_cx / w, 4), round(ring_cy / new_h, 4))
    print('mapAspect', new_h, '/', w)


if __name__ == '__main__':
    main()
