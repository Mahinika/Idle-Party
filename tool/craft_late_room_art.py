#!/usr/bin/env py
"""Handcraft late-zone floors, walls, hub icons, and one landmark prop.

Locked against generate_dungeon_art.py (HANDCRAFTED_ZONES). Tide is the
quality facit and is not rewritten here. 16×16 tiles, 32×32 props, nearest.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom" / "dungeon"

# zone, floor, floor mid, floor hi, floor lo, wall, wall hi, accent, pale, outline
ZONES = {
    "crystal": ((0x14, 0x28, 0x48), (0x28, 0x48, 0x78), (0x70, 0xC8, 0xF0), (0x08, 0x14, 0x28),
                (0x0C, 0x18, 0x30), (0x38, 0x68, 0x98), (0x90, 0xE0, 0xFF), (0xE8, 0xF8, 0xFF), (0x06, 0x0C, 0x18)),
    "ember": ((0x34, 0x1C, 0x0C), (0x58, 0x30, 0x14), (0xF0, 0x88, 0x20), (0x18, 0x0C, 0x06),
              (0x20, 0x10, 0x08), (0x60, 0x30, 0x14), (0xFF, 0xB0, 0x30), (0xFF, 0xE0, 0xA0), (0x10, 0x08, 0x04)),
    "grove": ((0x1A, 0x32, 0x18), (0x2A, 0x48, 0x22), (0x48, 0xA0, 0x38), (0x0C, 0x1C, 0x0C),
              (0x14, 0x24, 0x12), (0x30, 0x48, 0x28), (0x58, 0xB0, 0x40), (0xC0, 0xE0, 0x80), (0x08, 0x14, 0x08)),
    "storm": ((0x1C, 0x22, 0x34), (0x2C, 0x38, 0x50), (0x88, 0xA8, 0xC8), (0x0C, 0x10, 0x1C),
              (0x12, 0x16, 0x28), (0x48, 0x58, 0x78), (0xD0, 0xE8, 0xFF), (0xF8, 0xFC, 0xFF), (0x08, 0x0C, 0x16)),
    "rime": ((0xD8, 0xEC, 0xF4), (0xB8, 0xD8, 0xE8), (0xF4, 0xFC, 0xFF), (0x78, 0xA8, 0xC0),
             (0xC8, 0xE0, 0xEC), (0xF0, 0xF8, 0xFF), (0x70, 0xE8, 0xF8), (0xFF, 0xFF, 0xFF), (0x48, 0x70, 0x88)),
    "fen": ((0x3A, 0x38, 0x14), (0x52, 0x4C, 0x1C), (0xB8, 0xC0, 0x38), (0x22, 0x20, 0x0C),
            (0x2A, 0x28, 0x12), (0x48, 0x44, 0x20), (0xC8, 0xD8, 0x48), (0xE8, 0xF0, 0x80), (0x14, 0x14, 0x08)),
    "brass": ((0x6A, 0x4E, 0x22), (0x8A, 0x68, 0x30), (0xE0, 0xC0, 0x48), (0x3A, 0x2A, 0x12),
              (0x4A, 0x38, 0x18), (0xA0, 0x78, 0x30), (0xF0, 0xD8, 0x60), (0xFF, 0xF0, 0xB0), (0x20, 0x14, 0x08)),
    "veil": ((0x3A, 0x28, 0x40), (0x54, 0x38, 0x58), (0xC8, 0xA0, 0xD8), (0x22, 0x14, 0x28),
             (0x2C, 0x18, 0x34), (0x68, 0x48, 0x70), (0xE8, 0xC8, 0xF0), (0xF8, 0xF0, 0xFF), (0x14, 0x0C, 0x18)),
}


def _save(zone: str, img: Image.Image, rel: str) -> None:
    path = ROOT / zone / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def _px(img: Image.Image, x: int, y: int, c: tuple[int, ...]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def _line(img: Image.Image, pts: list[tuple[int, int]], c: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    if len(pts) >= 2:
        d.line(pts, fill=c)


def _floor_base(p: tuple, variant: int) -> Image.Image:
    floor, mid, hi, lo = p[0], p[1], p[2], p[3]
    img = Image.new("RGB", (16, 16), floor)
    for y in range(16):
        for x in range(16):
            n = (x * 5 + y * 3 + variant * 9) % 17
            if n == 0:
                _px(img, x, y, mid)
            elif n == 1:
                _px(img, x, y, lo)
    return img


def _wall(p: tuple, variant: int) -> Image.Image:
    wall, wall_hi, accent, lo, out = p[4], p[5], p[6], p[3], p[8]
    img = Image.new("RGB", (16, 16), wall)
    for x in range(16):
        _px(img, x, 0, wall_hi)
        _px(img, x, 1, p[5])
        _px(img, x, 15, out)
    if variant == 0:
        for y in (5, 10):
            _line(img, [(0, y), (15, y)], lo)
        _px(img, 4, 7, accent)
        _px(img, 11, 12, accent)
    else:
        for y in (4, 9, 13):
            _line(img, [(0, y), (15, y)], lo)
        _px(img, 8, 6, p[7])
        _px(img, 2, 11, accent)
    return img


def floor_crystal(variant: int) -> Image.Image:
    p = ZONES["crystal"]
    img = _floor_base(p, variant)
    shards = [(3, 3), (11, 5), (7, 12)] if variant == 0 else [(2, 8), (8, 2), (12, 10), (5, 13)]
    for x, y in shards:
        _px(img, x, y, p[7])
        _px(img, x + 1, y, p[2])
        _px(img, x, y + 1, p[6])
        _px(img, x + 1, y + 1, p[1])
    return img


def floor_ember(variant: int) -> Image.Image:
    p = ZONES["ember"]
    img = _floor_base(p, variant)
    cracks = [(0, 8), (4, 7), (8, 9), (12, 8), (15, 7)] if variant == 0 else [
        (0, 4), (3, 6), (7, 8), (11, 10), (15, 12), (6, 3), (10, 14),
    ]
    for x, y in cracks:
        _px(img, x, y, p[2])
        _px(img, x, min(15, y + 1), p[6])
    return img


def floor_grove(variant: int) -> Image.Image:
    p = ZONES["grove"]
    img = _floor_base(p, variant)
    roots = [(1, 10), (4, 9), (7, 11), (10, 10), (13, 12)] if variant == 0 else [
        (0, 5), (3, 6), (6, 4), (9, 7), (12, 5), (15, 6),
    ]
    wood = (0x5A, 0x3A, 0x22)
    for i, (x, y) in enumerate(roots):
        _px(img, x, y, wood)
        if i % 2 == 0:
            _px(img, x, max(0, y - 1), p[2])
    if variant:
        for x, y in ((2, 12), (8, 2), (14, 13)):
            _px(img, x, y, p[7])
    return img


def floor_storm(variant: int) -> Image.Image:
    p = ZONES["storm"]
    img = _floor_base(p, variant)
    # Wet sheen: a bright rim along the top of the slab, plus a diagonal streak.
    for x in range(16):
        _px(img, x, 0, p[5])
        _px(img, x, 1, p[1])
    streak = [(0, 11), (4, 9), (8, 8), (12, 6), (15, 5)] if variant == 0 else [
        (0, 6), (3, 8), (7, 10), (11, 12), (15, 13),
    ]
    for x, y in streak:
        _px(img, x, y, p[7])
    return img


def floor_rime(variant: int) -> Image.Image:
    p = ZONES["rime"]
    img = _floor_base(p, variant)
    # Ice sheets, not blue glass shards.
    d = ImageDraw.Draw(img)
    if variant == 0:
        d.line([(0, 4), (15, 6)], fill=p[7])
        d.line([(2, 12), (14, 10)], fill=p[3])
        _px(img, 8, 8, p[6])
    else:
        d.line([(0, 2), (6, 8), (15, 8)], fill=p[7])
        d.line([(4, 0), (4, 15)], fill=p[3])
        d.line([(11, 0), (11, 15)], fill=p[3])
        _px(img, 4, 8, p[6])
        _px(img, 11, 8, p[6])
    return img


def floor_fen(variant: int) -> Image.Image:
    p = ZONES["fen"]
    img = _floor_base(p, variant)
    mud = (0x2A, 0x24, 0x10)
    reed = p[6]
    pools = [(3, 10, 7, 14), (10, 4, 14, 8)] if variant == 0 else [(2, 3, 8, 8), (9, 9, 14, 14)]
    d = ImageDraw.Draw(img)
    for box in pools:
        d.ellipse(box, fill=mud)
    reeds = [(4, 2), (8, 6), (12, 11)] if variant == 0 else [(3, 12), (7, 1), (13, 6), (10, 13)]
    for x, y in reeds:
        _px(img, x, y, reed)
        _px(img, x, min(15, y + 1), p[2])
        _px(img, x, min(15, y + 2), (0x6A, 0x70, 0x28))
    return img


def floor_brass(variant: int) -> Image.Image:
    p = ZONES["brass"]
    img = _floor_base(p, variant)
    # Rivet grid. Boss plate (variant 1) is tighter.
    step = 5 if variant == 0 else 4
    for y in range(2, 15, step):
        for x in range(2, 15, step):
            _px(img, x, y, p[8])
            _px(img, x, y, p[3])
            _px(img, min(15, x + 1), y, p[7])
    for x in range(16):
        _px(img, x, 0, p[5])
    return img


def floor_veil(variant: int) -> Image.Image:
    p = ZONES["veil"]
    img = _floor_base(p, variant)
    # Silk strands, not grove roots.
    strands = range(2, 15, 4) if variant == 0 else range(1, 15, 3)
    for y in strands:
        _line(img, [(0, y), (15, y + (1 if variant else 0))], p[7])
        _px(img, (y * 3) % 16, y, p[6])
    return img


FLOORS = {
    "crystal": floor_crystal,
    "ember": floor_ember,
    "grove": floor_grove,
    "storm": floor_storm,
    "rime": floor_rime,
    "fen": floor_fen,
    "brass": floor_brass,
    "veil": floor_veil,
}


def _prop() -> Image.Image:
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))


def _rim(img: Image.Image, pts: list[tuple[int, int]], fill, out) -> None:
    d = ImageDraw.Draw(img)
    d.line(pts, fill=out, width=3)
    d.line(pts, fill=fill, width=1)


def landmark_crystal() -> Image.Image:
    p = ZONES["crystal"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 2), (26, 16), (16, 30), (6, 16)], fill=p[8])
    d.polygon([(16, 5), (23, 16), (16, 27), (9, 16)], fill=p[2])
    d.polygon([(16, 8), (20, 16), (16, 24), (12, 16)], fill=p[7])
    return img


def landmark_ember() -> Image.Image:
    p = ZONES["ember"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.rectangle([6, 16, 26, 28], fill=p[4], outline=p[8])
    d.polygon([(8, 16), (24, 16), (20, 8), (12, 8)], fill=p[1], outline=p[8])
    d.rectangle([14, 18, 18, 26], fill=p[2])
    _px(img, 16, 20, p[7])
    _px(img, 15, 22, p[6])
    return img


def landmark_grove() -> Image.Image:
    p = ZONES["grove"]
    img = _prop()
    d = ImageDraw.Draw(img)
    wood = (0x5A, 0x3A, 0x22)
    d.ellipse([8, 14, 24, 28], fill=wood, outline=p[8])
    d.polygon([(16, 4), (24, 16), (8, 16)], fill=p[2], outline=p[8])
    d.line([(10, 22), (4, 28)], fill=wood, width=2)
    d.line([(22, 22), (28, 28)], fill=wood, width=2)
    _px(img, 16, 10, p[7])
    return img


def landmark_storm() -> Image.Image:
    p = ZONES["storm"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.rectangle([13, 6, 19, 28], fill=p[1], outline=p[8])
    d.polygon([(18, 2), (22, 12), (16, 12), (20, 22), (12, 10), (16, 10)], fill=p[7], outline=p[8])
    for y in range(8, 28, 4):
        _px(img, 14, y, p[5])
    return img


def landmark_rime() -> Image.Image:
    p = ZONES["rime"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 2), (20, 16), (16, 30), (12, 16)], fill=p[7], outline=p[8])
    d.polygon([(4, 16), (16, 12), (28, 16), (16, 20)], fill=p[6], outline=p[8])
    _px(img, 16, 16, p[2])
    return img


def landmark_fen() -> Image.Image:
    p = ZONES["fen"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.ellipse([4, 18, 28, 30], fill=(0x2A, 0x24, 0x10), outline=p[8])
    for x in (8, 14, 20, 25):
        d.line([(x, 26), (x - 1, 6)], fill=p[6], width=2)
        _px(img, x - 1, 6, p[7])
    return img


def landmark_brass() -> Image.Image:
    p = ZONES["brass"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.rectangle([10, 4, 22, 28], fill=p[1], outline=p[8])
    d.rectangle([8, 8, 24, 12], fill=p[2], outline=p[8])
    d.rectangle([8, 18, 24, 22], fill=p[2], outline=p[8])
    for x, y in ((12, 6), (18, 6), (12, 15), (18, 15), (12, 25), (18, 25)):
        _px(img, x, y, p[8])
        _px(img, x + 1, y, p[7])
    return img


def landmark_veil() -> Image.Image:
    p = ZONES["veil"]
    img = _prop()
    d = ImageDraw.Draw(img)
    d.line([(4, 6), (28, 10), (6, 18), (28, 22), (8, 28)], fill=p[7], width=1)
    d.polygon([(16, 10), (24, 16), (16, 18), (12, 14)], fill=p[6], outline=p[8])
    d.polygon([(16, 14), (22, 18), (16, 22), (10, 18)], fill=p[2], outline=p[8])
    _px(img, 18, 16, p[7])
    return img


LANDMARKS = {
    "crystal": ("props/pillar.png", landmark_crystal),
    "ember": ("props/anvil.png", landmark_ember),
    "grove": ("props/fountain.png", landmark_grove),
    "storm": ("props/pillar.png", landmark_storm),
    "rime": ("props/fountain.png", landmark_rime),
    "fen": ("props/water.png", landmark_fen),
    "brass": ("props/pillar.png", landmark_brass),
    "veil": ("props/fence.png", landmark_veil),
}


def hub_icon(zone: str) -> Image.Image:
    p = ZONES[zone]
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    out = p[8]
    if zone == "crystal":
        d.polygon([(16, 2), (28, 16), (16, 30), (4, 16)], fill=p[2], outline=out)
        d.polygon([(16, 8), (22, 16), (16, 24), (10, 16)], fill=p[7])
    elif zone == "ember":
        d.ellipse([6, 10, 26, 28], fill=p[4], outline=out)
        d.polygon([(8, 18), (16, 8), (24, 18), (16, 22)], fill=p[2])
        d.line([(10, 16), (22, 20)], fill=p[7], width=1)
    elif zone == "grove":
        d.rectangle([14, 18, 18, 30], fill=(0x5A, 0x3A, 0x22), outline=out)
        d.ellipse([6, 4, 26, 22], fill=p[2], outline=out)
    elif zone == "storm":
        d.polygon([(18, 2), (22, 12), (28, 12), (16, 30), (18, 16), (10, 16)], fill=p[7], outline=out)
    elif zone == "rime":
        d.polygon([(16, 2), (19, 16), (16, 30), (13, 16)], fill=p[7], outline=out)
        d.polygon([(2, 16), (16, 13), (30, 16), (16, 19)], fill=p[6], outline=out)
    elif zone == "fen":
        d.ellipse([6, 20, 26, 30], fill=(0x2A, 0x24, 0x10), outline=out)
        d.line([(10, 26), (8, 4)], fill=p[6], width=2)
        d.line([(16, 26), (16, 6)], fill=p[2], width=2)
        d.line([(22, 26), (24, 8)], fill=p[6], width=2)
    elif zone == "brass":
        d.ellipse([4, 4, 28, 28], fill=p[2], outline=out)
        d.ellipse([12, 12, 20, 20], fill=p[4], outline=out)
        for box in ([14, 2, 18, 8], [14, 24, 18, 30], [2, 14, 8, 18], [24, 14, 30, 18]):
            d.rectangle(box, fill=p[6])
    elif zone == "veil":
        d.polygon([(16, 14), (30, 8), (24, 16), (30, 24), (16, 18), (2, 24), (8, 16), (2, 8)], fill=p[6], outline=out)
        d.ellipse([13, 13, 19, 19], fill=p[7])
    return img


def main() -> None:
    n = 0
    for zone, paint in FLOORS.items():
        p = ZONES[zone]
        _save(zone, paint(0), "tiles/floor_a.png")
        _save(zone, paint(1), "tiles/floor_b.png")
        _save(zone, _wall(p, 0), "tiles/wall_a.png")
        _save(zone, _wall(p, 1), "tiles/wall_b.png")
        _save(zone, hub_icon(zone), "hub_icon.png")
        rel, fn = LANDMARKS[zone]
        _save(zone, fn(), rel)
        n += 1
    print(f"late room art: {n} zones (tide left as facit)")


if __name__ == "__main__":
    main()
