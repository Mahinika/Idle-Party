#!/usr/bin/env py
"""Handcraft Sandy Caverns tiles + signature props.

Locked against generate_dungeon_art.py (HANDCRAFTED_ZONES).
Style: docs/DUNGEON_ART.md — 16×16 tiles, 32×32 props, 1 px outline, nearest.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom" / "dungeon" / "sandy"

# Material anchors — cracked sandstone cave (docs/DUNGEON_ART.md).
SAND = (0x5A, 0x44, 0x28)
SAND_M = (0x7A, 0x5A, 0x34)
SAND_HI = (0xC8, 0x88, 0x40)
SAND_PALE = (0xE0, 0xB0, 0x68)
SAND_LO = (0x3A, 0x2C, 0x18)
WALL = (0x1A, 0x14, 0x10)
WALL_M = (0x2A, 0x22, 0x18)
WALL_HI = (0x4A, 0x3A, 0x24)
WALL_LO = (0x0C, 0x0A, 0x08)
WOOD = (0x5A, 0x40, 0x28)
WOOD_M = (0x70, 0x50, 0x30)
WOOD_HI = (0x8A, 0x64, 0x3A)
ROPE = (0xC0, 0x98, 0x58)
FLAME = (0xF0, 0xB0, 0x38)
FLAME_CORE = (0xFF, 0xF0, 0xC0)
OUT = (0x18, 0x10, 0x0A)


def _save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def _px(img: Image.Image, x: int, y: int, c: tuple[int, ...]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def _floor(variant: int) -> Image.Image:
    img = Image.new("RGB", (16, 16), SAND)
    d = ImageDraw.Draw(img)
    # Subtle grain — no outer rim so tiles stitch.
    for y in range(16):
        for x in range(16):
            n = (x * 7 + y * 5 + variant * 11) % 13
            if n == 0:
                _px(img, x, y, SAND_M)
            elif n == 1:
                _px(img, x, y, SAND_LO)
            elif n == 2 and variant == 0:
                _px(img, x, y, SAND_HI)
    # Cracks: sandstone slabs, offset per variant.
    if variant == 0:
        d.line([(0, 5), (6, 5), (8, 8), (15, 8)], fill=SAND_LO)
        d.line([(3, 0), (3, 5)], fill=SAND_LO)
        d.line([(11, 8), (11, 15)], fill=SAND_LO)
        _px(img, 2, 11, SAND_PALE)
        _px(img, 9, 3, SAND_HI)
        _px(img, 14, 13, SAND_M)
    else:
        d.line([(0, 10), (5, 10), (7, 7), (15, 7)], fill=SAND_LO)
        d.line([(5, 10), (5, 15)], fill=SAND_LO)
        d.line([(12, 0), (12, 7)], fill=SAND_LO)
        _px(img, 1, 3, SAND_HI)
        _px(img, 8, 13, SAND_PALE)
        _px(img, 13, 4, SAND_M)
    return img


def _wall(variant: int) -> Image.Image:
    img = Image.new("RGB", (16, 16), WALL)
    d = ImageDraw.Draw(img)
    for x in range(16):
        _px(img, x, 0, WALL_HI)
        _px(img, x, 1, WALL_M)
        _px(img, x, 14, WALL_LO)
        _px(img, x, 15, OUT)
    # Block courses, top-left light.
    for y in range(3, 13, 4):
        d.line([(0, y), (15, y)], fill=WALL_LO)
    for x in (0, 8):
        d.line([(x, 2), (x, 13)], fill=WALL_LO)
    if variant == 0:
        _px(img, 3, 5, SAND_M)
        _px(img, 4, 5, SAND)
        _px(img, 11, 9, WALL_HI)
    else:
        _px(img, 2, 8, SAND_LO)
        _px(img, 12, 5, SAND_M)
        _px(img, 7, 11, WALL_HI)
    return img


def _stairs(boss: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Dug pit at the foot.
    d.rectangle([1, 12, 14, 15], fill=(*SAND_LO, 255))
    for i, y in enumerate(range(11, 2, -2)):
        inset = 1 if boss else 2 + i // 2
        left, right = inset, 15 - inset
        shade = SAND_HI if i % 2 == 0 else SAND_M
        d.rectangle([left, y, right, y + 1], fill=(*shade, 255))
        _px(img, left, y, OUT)
        _px(img, right, y, OUT)
    if boss:
        d.rectangle([0, 0, 15, 2], fill=(*SAND_HI, 255), outline=OUT)
        _px(img, 2, 1, SAND_PALE)
        _px(img, 13, 1, SAND_PALE)
        _px(img, 8, 1, FLAME)
    else:
        d.rectangle([5, 1, 10, 3], fill=(*SAND, 255), outline=OUT)
    return img


def _door(open_gate: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Stone jamb.
    d.rectangle([1, 1, 14, 15], fill=(*WALL_M, 255), outline=OUT)
    d.rectangle([3, 2, 12, 14], fill=(*WOOD, 255))
    if open_gate:
        d.rectangle([5, 3, 10, 13], fill=(*SAND_LO, 255))
        _px(img, 6, 6, SAND)
        # Rope loops on the jambs.
        d.line([(3, 4), (3, 12)], fill=ROPE)
        d.line([(12, 4), (12, 12)], fill=ROPE)
    else:
        for y in range(3, 14, 3):
            d.line([(3, y), (12, y)], fill=WOOD_M)
        d.line([(4, 3), (4, 13)], fill=ROPE)
        d.line([(11, 3), (11, 13)], fill=ROPE)
        d.rectangle([7, 7, 8, 9], fill=WOOD_HI)
    return img


def _outline_blob(img: Image.Image) -> None:
    w, h = img.size
    extra: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] == 0:
                    extra.append((nx, ny))
    for x, y in extra:
        if img.getpixel((x, y))[3] == 0:
            img.putpixel((x, y), (*OUT, 255))


def _hatch() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([5, 12, 27, 28], fill=SAND_LO)
    d.rectangle([7, 14, 25, 26], fill=WOOD)
    for x in range(9, 25, 4):
        d.line([(x, 15), (x, 25)], fill=WOOD_HI)
    d.line([(8, 20), (24, 20)], fill=WOOD_M)
    d.rectangle([12, 18, 15, 21], fill=ROPE)
    _outline_blob(img)
    return img


def _rubble() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    blocks = (
        (7, 20, 14, 27, SAND_M),
        (13, 18, 22, 26, SAND),
        (18, 21, 26, 28, SAND_LO),
        (10, 16, 16, 21, SAND_HI),
        (20, 16, 25, 21, SAND_M),
    )
    for x0, y0, x1, y1, c in blocks:
        d.rectangle([x0, y0, x1, y1], fill=c)
    _px(img, 12, 17, SAND_PALE)
    _outline_blob(img)
    return img


def _torch(alt: bool) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([14, 16, 17, 28], fill=WOOD_M)
    flame = FLAME if not alt else (0xF0, 0x88, 0x28)
    d.polygon([(16, 5), (21, 16), (11, 16)], fill=flame)
    _px(img, 16, 10, FLAME_CORE)
    _px(img, 15, 12, FLAME_CORE)
    _outline_blob(img)
    return img


def _hub() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Cave mouth: dark oval + sand lip, reads at atlas size.
    d.ellipse([4, 8, 28, 28], fill=SAND)
    d.ellipse([8, 11, 24, 26], fill=WALL_LO)
    d.polygon([(6, 20), (16, 6), (26, 20)], fill=SAND_HI)
    d.ellipse([10, 13, 22, 24], fill=WALL)
    _px(img, 16, 16, SAND_PALE)
    _outline_blob(img)
    return img


def _barrel() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([7, 11, 25, 29], fill=WOOD)
    d.line([(7, 18), (25, 18)], fill=WOOD_M)
    d.line([(7, 23), (25, 23)], fill=WOOD_M)
    _px(img, 10, 14, SAND_M)
    _outline_blob(img)
    return img


def _crate() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([7, 12, 25, 28], fill=WOOD)
    d.line([(7, 20), (25, 20)], fill=WOOD_M)
    d.line([(16, 12), (16, 28)], fill=WOOD_M)
    _outline_blob(img)
    return img


def _table() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 14, 26, 18], fill=WOOD_HI)
    for x in (9, 23):
        d.rectangle([x, 18, x + 2, 27], fill=WOOD_M)
    _outline_blob(img)
    return img


def _stool() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 16, 22, 22], fill=WOOD_HI)
    d.rectangle([15, 22, 17, 28], fill=WOOD_M)
    _outline_blob(img)
    return img


def _shelf() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 12, 24, 14], fill=WOOD_HI)
    d.rectangle([8, 18, 24, 20], fill=WOOD_HI)
    d.rectangle([9, 14, 14, 18], fill=WOOD_M)
    d.rectangle([18, 14, 23, 18], fill=SAND_M)
    _outline_blob(img)
    return img


def _chest() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([5, 15, 27, 27], fill=WOOD)
    d.rectangle([5, 10, 27, 17], fill=WOOD_HI)
    d.rectangle([14, 11, 18, 26], fill=SAND_HI)
    _px(img, 16, 12, SAND_PALE)
    _outline_blob(img)
    return img


def _pot() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(9, 13), (23, 13), (25, 27), (7, 27)], fill=SAND_M)
    d.rectangle([11, 8, 21, 13], fill=SAND_HI)
    _outline_blob(img)
    return img


def _water() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wet = (0x58, 0x70, 0x78)
    d.ellipse([3, 14, 29, 28], fill=wet)
    _px(img, 14, 18, (0x90, 0xB0, 0xB8))
    _outline_blob(img)
    return img


def _lava() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 14, 28, 28], fill=(0xC0, 0x58, 0x20))
    _px(img, 15, 19, FLAME)
    _outline_blob(img)
    return img


def _fountain() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 20, 26, 30], fill=SAND_LO)
    d.rectangle([13, 10, 19, 22], fill=SAND_M)
    d.ellipse([11, 6, 21, 14], fill=SAND_HI)
    _outline_blob(img)
    return img


def _gravestone() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([11, 10, 21, 28], fill=WALL_M)
    d.polygon([(11, 10), (16, 4), (21, 10)], fill=WALL_HI)
    _outline_blob(img)
    return img


def _trap() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 18, 26, 26], fill=WALL_LO)
    for x in range(8, 25, 4):
        d.polygon([(x, 26), (x + 2, 14), (x + 4, 26)], fill=SAND_HI)
    _outline_blob(img)
    return img


def _bones() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bone = (0xE0, 0xD4, 0xB8)
    d.line([(8, 22), (24, 14)], fill=bone, width=2)
    d.ellipse([6, 20, 12, 26], fill=bone)
    _outline_blob(img)
    return img


def _skull() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bone = (0xE0, 0xD4, 0xB8)
    d.ellipse([10, 10, 22, 24], fill=bone)
    d.ellipse([12, 14, 15, 17], fill=OUT)
    d.ellipse([17, 14, 20, 17], fill=OUT)
    _outline_blob(img)
    return img


def _anvil() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 20, 24, 28], fill=WALL_M)
    d.polygon([(10, 20), (22, 20), (20, 14), (12, 14)], fill=WALL_HI)
    _outline_blob(img)
    return img


def _fence() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 12, 26, 14], fill=WOOD_M)
    for x in range(8, 25, 5):
        d.rectangle([x, 8, x + 2, 24], fill=WOOD)
    _outline_blob(img)
    return img


def _pillar() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([11, 5, 21, 28], fill=SAND_M)
    d.rectangle([9, 3, 23, 7], fill=SAND_HI)
    d.rectangle([10, 27, 22, 30], fill=SAND_LO)
    _outline_blob(img)
    return img


def main() -> None:
    _save(_floor(0), "tiles/floor_a.png")
    _save(_floor(1), "tiles/floor_b.png")
    _save(_wall(0), "tiles/wall_a.png")
    _save(_wall(1), "tiles/wall_b.png")
    _save(_stairs(False), "tiles/stairs.png")
    _save(_stairs(True), "tiles/stairs_boss.png")
    _save(_door(False), "tiles/door_closed.png")
    _save(_door(True), "tiles/door_open.png")
    props = {
        "hatch": _hatch,
        "rubble": _rubble,
        "torch": lambda: _torch(False),
        "torch_alt": lambda: _torch(True),
        "barrel": _barrel,
        "crate": _crate,
        "table": _table,
        "stool": _stool,
        "shelf": _shelf,
        "chest": _chest,
        "pot": _pot,
        "water": _water,
        "lava": _lava,
        "fountain": _fountain,
        "gravestone": _gravestone,
        "trap": _trap,
        "bones": _bones,
        "skull": _skull,
        "anvil": _anvil,
        "fence": _fence,
        "pillar": _pillar,
    }
    for name, fn in props.items():
        _save(fn(), f"props/{name}.png")
    _save(_hub(), "hub_icon.png")
    print("Sandy handcraft written.")


if __name__ == "__main__":
    main()
