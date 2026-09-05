#!/usr/bin/env py
"""Handcrafted Tidehold interiors + late-zone elites + spec/pet art.

Replaces thin PIL stubs with denser pixel paint (same paths).
Run: py tool/craft_asset_batch.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom"


def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT.parent)} ({path.stat().st_size} B)")


def _px(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        if len(c) == 3:
            c = (*c, 255)
        img.putpixel((x, y), c)


def _fill(img: Image.Image, pts, c) -> None:
    for x, y in pts:
        _px(img, x, y, c)


def _outline_rgba(img: Image.Image, rim=(8, 12, 16, 255)) -> None:
    """Dark rim on non-transparent pixels that border alpha."""
    w, h = img.size
    px = img.load()
    mark = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 20:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] < 20:
                    mark.append((x, y))
                    break
    for x, y in mark:
        a = px[x, y]
        # Keep a bit of original color under rim for softer edge
        px[x, y] = (
            (a[0] * 2 + rim[0]) // 3,
            (a[1] * 2 + rim[1]) // 3,
            (a[2] * 2 + rim[2]) // 3,
            255,
        )


# —— Tide palette (docs/DUNGEON_ART.md) ——
S0 = (0x1A, 0x3A, 0x42)
S1 = (0x24, 0x58, 0x60)
S2 = (0x2D, 0x78, 0x88)
S3 = (0x3A, 0x90, 0xA0)
W0 = (0x0C, 0x22, 0x28)
W1 = (0x14, 0x30, 0x38)
W2 = (0x1E, 0x48, 0x50)
W3 = (0x2A, 0x60, 0x68)
AQ0 = (0x1A, 0x58, 0x70)
AQ1 = (0x28, 0xA0, 0xB8)
AQ2 = (0x48, 0xD0, 0xE8)
AQ3 = (0x78, 0xE8, 0xF0)
CR0 = (0xC8, 0x78, 0x58)
CR1 = (0xE8, 0xA8, 0x78)
CR2 = (0xFF, 0xE8, 0xC8)
WD0 = (0x5A, 0x40, 0x30)
WD1 = (0x80, 0x60, 0x40)
WD2 = (0xA0, 0x78, 0x50)
GL = (0x38, 0xD0, 0xB8)
GL2 = (0x60, 0xF0, 0xD8)
OUT = (0x08, 0x10, 0x14)


def craft_tide_floor(variant: int) -> Image.Image:
    img = Image.new("RGB", (16, 16), S0)
    # Base silt grain
    for y in range(16):
        for x in range(16):
            n = (x * 7 + y * 5 + variant * 11) % 13
            if n == 0:
                _px(img, x, y, S1)
            elif n == 1:
                _px(img, x, y, S2 if variant else S1)
            elif n == 2:
                _px(img, x, y, (0x16, 0x32, 0x38))
            elif n == 3 and (x + y) % 2 == 0:
                _px(img, x, y, (0x20, 0x4A, 0x52))
    # Wet ripple bands
    if variant == 0:
        for x in range(16):
            y = 4 + (x % 5)
            _px(img, x, y, S2)
            if x % 3 == 0:
                _px(img, x, y + 1, AQ0)
        # barnacle flecks
        for x, y in ((2, 11), (9, 3), (13, 12), (6, 8), (14, 6)):
            _px(img, x, y, CR0)
            _px(img, x + 1, y, CR1)
    else:
        for x in range(16):
            y = 7 + ((x + 2) % 4)
            _px(img, x, y, S1)
            _px(img, x, min(15, y + 1), S3 if x % 2 else S2)
        for x, y in ((1, 2), (8, 14), (12, 5), (4, 9)):
            _px(img, x, y, AQ1)
            _px(img, x, y + 1, AQ0)
        _px(img, 10, 10, CR1)
        _px(img, 11, 10, CR2)
    return img


def craft_tide_wall(variant: int) -> Image.Image:
    img = Image.new("RGB", (16, 16), W0)
    for y in range(16):
        for x in range(16):
            # stone blocks 4x4-ish
            bx, by = x // 4, y // 4
            base = W1 if (bx + by + variant) % 2 == 0 else W2
            _px(img, x, y, base)
            if y % 4 == 0:
                _px(img, x, y, W0)
            if x % 4 == 0:
                _px(img, x, y, W0)
    # top highlight rim
    for x in range(16):
        _px(img, x, 0, W3)
        _px(img, x, 1, W2)
    if variant == 0:
        # barnacles
        for x, y in ((3, 5), (10, 8), (6, 12), (13, 4), (1, 10)):
            _px(img, x, y, CR0)
            _px(img, x + 1, y, CR1)
            _px(img, x, y + 1, CR1)
        # algae seep
        for y in range(8, 16):
            _px(img, 7, y, (0x18, 0x50, 0x48))
            if y % 2:
                _px(img, 8, y, GL)
    else:
        # dark seep streak
        for y in range(2, 15):
            _px(img, 4 + (y % 2), y, (0x0A, 0x18, 0x1C))
        for x, y in ((12, 6), (2, 13), (9, 3)):
            _px(img, x, y, AQ0)
            _px(img, x, y + 1, AQ1)
        _px(img, 14, 11, CR0)
        _px(img, 15, 11, CR1)
    return img


def craft_tide_stairs(boss: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # water base
    for y in range(10, 16):
        for x in range(16):
            _px(img, x, y, (*AQ0, 255) if (x + y) % 2 else (*AQ1, 220))
    steps = 5 if boss else 4
    for i in range(steps):
        y0 = 12 - i * 2
        x0 = 2 - (1 if boss else 0)
        x1 = 13 + (1 if boss else 0)
        for x in range(x0, x1 + 1):
            _px(img, x, y0, (*W2, 255))
            _px(img, x, y0 + 1, (*W1, 255))
            if x == x0 or x == x1:
                _px(img, x, y0, (*W0, 255))
        # riser highlight
        for x in range(x0 + 1, x1):
            _px(img, x, y0, (*W3, 255))
    if boss:
        for x, y in ((1, 3), (2, 4), (13, 3), (14, 4), (1, 8), (14, 8)):
            _px(img, x, y, (*CR0, 255))
            _px(img, x, y + 1, (*CR1, 255))
        _px(img, 7, 2, (*GL, 255))
        _px(img, 8, 2, (*GL2, 255))
    else:
        _px(img, 3, 5, (*AQ2, 200))
        _px(img, 12, 6, (*AQ1, 200))
    _outline_rgba(img, (*OUT, 255))
    return img


def craft_tide_door(open_: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # frame
    for y in range(1, 15):
        _px(img, 2, y, (*CR0, 255))
        _px(img, 13, y, (*CR0, 255))
        _px(img, 3, y, (*W1, 255))
        _px(img, 12, y, (*W1, 255))
    for x in range(2, 14):
        _px(img, x, 1, (*CR1, 255))
        _px(img, x, 14, (*W0, 255))
    if open_:
        # open grate — water trickle
        for y in range(3, 13):
            for x in range(5, 11):
                if (x + y) % 3 == 0:
                    _px(img, x, y, (*AQ2, 180))
                elif (x + y) % 3 == 1:
                    _px(img, x, y, (*AQ1, 120))
        for x in (4, 11):
            for y in range(3, 13):
                _px(img, x, y, (*CR0, 200))
    else:
        # closed coral grate
        for y in range(3, 13):
            for x in range(4, 12):
                _px(img, x, y, (*W2, 255))
                if (x + y) % 2 == 0:
                    _px(img, x, y, (*CR0, 255))
                if x in (5, 8, 10) or y in (5, 8, 11):
                    _px(img, x, y, (*W0, 255))
        _px(img, 7, 7, (*GL, 255))
        _px(img, 8, 7, (*GL2, 255))
    _outline_rgba(img, (*OUT, 255))
    return img


def craft_tide_prop_water() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(18, 30):
        for x in range(4, 28):
            d = abs(x - 16) / 12 + abs(y - 24) / 8
            if d < 1.0:
                c = AQ2 if (x + y) % 3 == 0 else (AQ1 if d < 0.6 else AQ0)
                a = 220 if d < 0.7 else 140
                _px(img, x, y, (*c, a))
    for x, y in ((10, 20), (18, 22), (14, 26), (22, 24)):
        _px(img, x, y, (*AQ3, 255))
    _outline_rgba(img)
    return img


def craft_tide_prop_fountain() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    # coral base
    for y in range(20, 28):
        for x in range(8, 24):
            _px(img, x, y, (*CR0, 255) if (x + y) % 2 else (*W1, 255))
    for x in range(10, 22):
        _px(img, x, 19, (*CR1, 255))
    # spring column
    for y in range(8, 20):
        for x in range(13, 19):
            _px(img, x, y, (*AQ1, 255))
            if x in (13, 18):
                _px(img, x, y, (*W2, 255))
    # bubbles
    for x, y in ((12, 6), (16, 4), (19, 7), (14, 3), (17, 9)):
        _px(img, x, y, (*GL2, 255))
        _px(img, x + 1, y, (*GL, 200))
    _px(img, 15, 10, (*AQ3, 255))
    _px(img, 16, 11, (*AQ2, 255))
    _outline_rgba(img)
    return img


def craft_tide_prop_barrel() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(10, 26):
        for x in range(10, 22):
            c = WD1 if (y - 10) % 4 < 3 else WD0
            _px(img, x, y, (*c, 255))
            if x in (10, 21):
                _px(img, x, y, (*OUT, 255))
    for y in (12, 16, 20, 24):
        for x in range(11, 21):
            _px(img, x, y, (*WD0, 255))
    # wet sheen + barnacle
    _px(img, 12, 14, (*AQ1, 180))
    _px(img, 18, 18, (*CR0, 255))
    _px(img, 19, 18, (*CR1, 255))
    _outline_rgba(img)
    return img


def craft_tide_prop_hatch() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(12, 24):
        for x in range(8, 24):
            _px(img, x, y, (*W1, 255))
    for y in range(13, 23):
        for x in range(9, 23):
            if (x + y) % 2 == 0:
                _px(img, x, y, (*W0, 255))
            else:
                _px(img, x, y, (*AQ0, 200))
    for x in range(8, 24):
        _px(img, x, 12, (*WD1, 255))
        _px(img, x, 23, (*WD0, 255))
    for y in range(12, 24):
        _px(img, 8, y, (*WD1, 255))
        _px(img, 23, y, (*WD0, 255))
    _px(img, 15, 17, (*GL, 255))
    _outline_rgba(img)
    return img


def craft_tide_prop_pot() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(12, 26):
        w = 4 + (y - 12) // 3
        for x in range(16 - w, 16 + w):
            _px(img, x, y, (*CR0, 255) if y < 16 else (*W2, 255))
    for x in range(13, 19):
        _px(img, x, 10, (*CR1, 255))
        _px(img, x, 11, (*CR0, 255))
    _px(img, 14, 14, (*CR2, 255))
    _px(img, 18, 20, (*AQ1, 180))
    _outline_rgba(img)
    return img


def craft_tide_prop_pillar() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(4, 28):
        for x in range(12, 20):
            _px(img, x, y, (*W2, 255))
            if x in (12, 19):
                _px(img, x, y, (*W0, 255))
            if (x + y) % 5 == 0:
                _px(img, x, y, (*CR0, 255))
    for x in range(10, 22):
        _px(img, x, 4, (*CR1, 255))
        _px(img, x, 5, (*CR0, 255))
        _px(img, x, 26, (*W1, 255))
        _px(img, x, 27, (*W0, 255))
    _px(img, 15, 12, (*GL, 200))
    _outline_rgba(img)
    return img


def craft_tide_prop_chest() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(14, 26):
        for x in range(8, 24):
            _px(img, x, y, (*WD1, 255))
    for y in range(14, 18):
        for x in range(8, 24):
            _px(img, x, y, (*WD2, 255))
    for x in range(8, 24):
        _px(img, x, 18, (*WD0, 255))
    # coral lock + barnacles
    _px(img, 15, 19, (*GL, 255))
    _px(img, 16, 19, (*GL2, 255))
    for x, y in ((9, 15), (21, 22), (11, 24)):
        _px(img, x, y, (*CR0, 255))
        _px(img, x + 1, y, (*CR1, 255))
    _outline_rgba(img)
    return img


def craft_tide_hub() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    # coral shell / anchor silhouette
    for y in range(6, 26):
        for x in range(8, 24):
            dx, dy = x - 16, y - 16
            if dx * dx + dy * dy < 90:
                _px(img, x, y, (*CR0, 255))
            if dx * dx + dy * dy < 40:
                _px(img, x, y, (*AQ1, 255))
    for y in range(10, 22):
        _px(img, 16, y, (*GL, 255))
        _px(img, 15, y, (*W1, 255))
        _px(img, 17, y, (*W1, 255))
    for x in range(12, 21):
        _px(img, x, 18, (*WD1, 255))
    _px(img, 16, 8, (*GL2, 255))
    _outline_rgba(img)
    return img


def craft_tide_prop_generic(kind: str) -> Image.Image:
    """Extra props so full set stays Tide-themed (not stub-thin)."""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "crate":
        d.rectangle([10, 12, 22, 24], fill=(*WD1, 255), outline=(*OUT, 255))
        d.line([(10, 18), (22, 18)], fill=(*WD0, 255))
        _px(img, 12, 14, (*AQ1, 160))
    elif kind == "torch" or kind == "torch_alt":
        d.rectangle([14, 16, 17, 26], fill=(*WD0, 255))
        flame = GL2 if kind == "torch_alt" else CR1
        d.ellipse([12, 8, 19, 16], fill=(*flame, 255))
        _px(img, 15, 10, (*AQ3, 255))
    elif kind == "fence":
        for x in (10, 16, 22):
            d.rectangle([x, 10, x + 2, 26], fill=(*WD1, 255))
        d.rectangle([8, 14, 24, 16], fill=(*CR0, 255))
        d.rectangle([8, 20, 24, 22], fill=(*WD0, 255))
    elif kind == "rubble":
        for pts, c in (
            ([(12, 20), (18, 18), (20, 24), (10, 24)], W1),
            ([(16, 16), (22, 18), (21, 22)], CR0),
        ):
            d.polygon(pts, fill=(*c, 255))
    elif kind == "trap":
        d.ellipse([10, 14, 22, 26], fill=(*W0, 255), outline=(*CR0, 255))
        _px(img, 15, 18, (*GL, 255))
        _px(img, 16, 19, (*AQ2, 255))
    elif kind == "bones" or kind == "skull":
        d.ellipse([12, 12, 20, 20], fill=(0xE0, 0xD8, 0xC8, 255))
        _px(img, 14, 15, (*OUT, 255))
        _px(img, 17, 15, (*OUT, 255))
        if kind == "bones":
            d.line([(10, 22), (22, 24)], fill=(0xD0, 0xC8, 0xB0, 255), width=2)
    elif kind == "shelf":
        d.rectangle([8, 12, 24, 14], fill=(*WD1, 255))
        d.rectangle([8, 18, 24, 20], fill=(*WD0, 255))
        d.rectangle([10, 14, 14, 18], fill=(*CR0, 255))
        d.rectangle([18, 14, 22, 18], fill=(*AQ1, 255))
    elif kind == "table":
        d.rectangle([8, 14, 24, 18], fill=(*WD1, 255))
        d.rectangle([10, 18, 12, 26], fill=(*WD0, 255))
        d.rectangle([20, 18, 22, 26], fill=(*WD0, 255))
    elif kind == "stool":
        d.ellipse([12, 14, 20, 20], fill=(*WD1, 255))
        d.rectangle([14, 20, 17, 26], fill=(*WD0, 255))
    elif kind == "gravestone":
        d.rectangle([12, 10, 20, 26], fill=(*W2, 255), outline=(*OUT, 255))
        d.ellipse([12, 6, 20, 14], fill=(*W2, 255))
        _px(img, 15, 14, (*GL, 180))
    elif kind == "lava":
        # Tide has no lava — keep as dark geothermal seep so path exists
        d.ellipse([8, 14, 24, 26], fill=(*W0, 255))
        for x, y in ((12, 18), (16, 20), (20, 17)):
            _px(img, x, y, (*AQ0, 255))
    elif kind == "anvil":
        d.rectangle([10, 16, 22, 22], fill=(*W1, 255))
        d.rectangle([14, 22, 18, 26], fill=(*W0, 255))
        _px(img, 12, 17, (*CR1, 200))
    else:
        d.rectangle([12, 12, 20, 24], fill=(*W2, 255), outline=(*OUT, 255))
    _outline_rgba(img)
    return img


def craft_tide_all() -> None:
    print("=== Tidehold interior ===")
    tdir = ROOT / "dungeon" / "tide"
    _save(craft_tide_floor(0), tdir / "tiles" / "floor_a.png")
    _save(craft_tide_floor(1), tdir / "tiles" / "floor_b.png")
    _save(craft_tide_wall(0), tdir / "tiles" / "wall_a.png")
    _save(craft_tide_wall(1), tdir / "tiles" / "wall_b.png")
    _save(craft_tide_stairs(False), tdir / "tiles" / "stairs.png")
    _save(craft_tide_stairs(True), tdir / "tiles" / "stairs_boss.png")
    _save(craft_tide_door(False), tdir / "tiles" / "door_closed.png")
    _save(craft_tide_door(True), tdir / "tiles" / "door_open.png")
    props = {
        "water": craft_tide_prop_water,
        "fountain": craft_tide_prop_fountain,
        "barrel": craft_tide_prop_barrel,
        "hatch": craft_tide_prop_hatch,
        "pot": craft_tide_prop_pot,
        "pillar": craft_tide_prop_pillar,
        "chest": craft_tide_prop_chest,
    }
    for name, fn in props.items():
        _save(fn(), tdir / "props" / f"{name}.png")
    for name in (
        "crate",
        "table",
        "stool",
        "torch",
        "torch_alt",
        "gravestone",
        "trap",
        "bones",
        "skull",
        "lava",
        "anvil",
        "shelf",
        "fence",
        "rubble",
    ):
        _save(craft_tide_prop_generic(name), tdir / "props" / f"{name}.png")
    _save(craft_tide_hub(), tdir / "hub_icon.png")


# —— Creature painter (96×96) ——


def _creature_base(bg_a=0) -> Image.Image:
    return Image.new("RGBA", (96, 96), (0, 0, 0, bg_a))


def _blob(img, cx, cy, rx, ry, color, hole=None):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            dx = (x - cx) / max(1, rx)
            dy = (y - cy) / max(1, ry)
            if dx * dx + dy * dy <= 1.0:
                if hole:
                    hx, hy, hr = hole
                    if (x - hx) ** 2 + (y - hy) ** 2 < hr * hr:
                        continue
                _px(img, x, y, color if len(color) == 4 else (*color, 255))


def craft_elite(name: str) -> Image.Image:
    """Distinct silhouettes so late zones stop sharing golem/wraith."""
    img = _creature_base()
    if name == "tide_brute":
        # Coral colossus
        _blob(img, 48, 58, 28, 30, (*W2, 255))
        _blob(img, 48, 32, 18, 16, (*CR0, 255))
        for x, y in ((30, 40), (66, 42), (40, 70), (56, 72)):
            _blob(img, x, y, 8, 10, (*CR1, 255))
        _blob(img, 42, 30, 3, 3, (*AQ3, 255))
        _blob(img, 54, 30, 3, 3, (*AQ3, 255))
        _blob(img, 48, 50, 6, 8, (*GL, 255))
    elif name == "ember_elite":
        # Forge elemental — amber core, slag shell
        _blob(img, 48, 55, 26, 28, (0x50, 0x28, 0x10, 255))
        _blob(img, 48, 50, 16, 18, (0xF0, 0x98, 0x28, 255))
        _blob(img, 48, 48, 8, 10, (0xFF, 0xE0, 0x60, 255))
        _blob(img, 48, 22, 14, 12, (0x80, 0x30, 0x10, 255))
        _blob(img, 40, 20, 3, 3, (0xFF, 0xC0, 0x40, 255))
        _blob(img, 56, 20, 3, 3, (0xFF, 0xC0, 0x40, 255))
        for y in range(30, 80, 6):
            _px(img, 30, y, (0xFF, 0x60, 0x20, 255))
            _px(img, 66, y, (0xFF, 0x60, 0x20, 255))
    elif name == "ember_brute":
        _blob(img, 48, 58, 30, 28, (0x40, 0x20, 0x0C, 255))
        _blob(img, 48, 40, 22, 18, (0xC0, 0x50, 0x18, 255))
        _blob(img, 28, 50, 10, 14, (0x90, 0x40, 0x10, 255))
        _blob(img, 68, 50, 10, 14, (0x90, 0x40, 0x10, 255))
        _blob(img, 48, 28, 12, 10, (0xFF, 0xA0, 0x30, 255))
        _blob(img, 42, 26, 2, 2, (0xFF, 0xE8, 0x80, 255))
        _blob(img, 54, 26, 2, 2, (0xFF, 0xE8, 0x80, 255))
    elif name == "storm_wraith":
        _blob(img, 48, 50, 20, 32, (0x40, 0x28, 0x70, 200))
        _blob(img, 48, 36, 14, 14, (0xA8, 0x70, 0xE8, 230))
        for x in range(30, 66, 4):
            _px(img, x, 70 + (x % 5), (0xD0, 0xC0, 0xFF, 255))
        _blob(img, 42, 34, 2, 2, (0xFF, 0xFF, 0xFF, 255))
        _blob(img, 54, 34, 2, 2, (0xFF, 0xFF, 0xFF, 255))
        # lightning fork
        for x, y in ((48, 20), (50, 28), (46, 36), (52, 44), (48, 52)):
            _px(img, x, y, (0xF0, 0xE8, 0xFF, 255))
            _px(img, x + 1, y, (0xC0, 0xA0, 0xFF, 255))
    elif name == "storm_brute":
        _blob(img, 48, 56, 28, 28, (0x28, 0x18, 0x40, 255))
        _blob(img, 48, 40, 20, 16, (0x60, 0x40, 0x90, 255))
        _blob(img, 48, 24, 14, 12, (0x90, 0x60, 0xD0, 255))
        _blob(img, 40, 22, 3, 3, (0xE0, 0xE8, 0xFF, 255))
        _blob(img, 56, 22, 3, 3, (0xE0, 0xE8, 0xFF, 255))
        for y in (45, 55, 65):
            for x in range(35, 62):
                if (x + y) % 7 == 0:
                    _px(img, x, y, (0xC0, 0xB0, 0xFF, 255))
    elif name == "rime_wraith":
        _blob(img, 48, 52, 18, 30, (0x60, 0xC0, 0xD8, 180))
        _blob(img, 48, 34, 14, 14, (0xA0, 0xE8, 0xF8, 220))
        _blob(img, 48, 20, 10, 8, (0xE0, 0xF8, 0xFF, 255))
        _blob(img, 40, 32, 2, 2, (0x20, 0x40, 0x60, 255))
        _blob(img, 56, 32, 2, 2, (0x20, 0x40, 0x60, 255))
        for x, y in ((32, 48), (64, 50), (40, 70), (56, 72)):
            _blob(img, x, y, 5, 8, (0x88, 0xE0, 0xF0, 200))
    elif name == "rime_brute":
        _blob(img, 48, 58, 30, 28, (0x30, 0x50, 0x68, 255))
        _blob(img, 48, 42, 22, 16, (0x70, 0xC0, 0xD8, 255))
        _blob(img, 48, 26, 14, 12, (0xB0, 0xE8, 0xF8, 255))
        _blob(img, 28, 48, 8, 12, (0x50, 0x90, 0xA8, 255))
        _blob(img, 68, 48, 8, 12, (0x50, 0x90, 0xA8, 255))
        _blob(img, 42, 24, 2, 2, (0x20, 0x30, 0x40, 255))
        _blob(img, 54, 24, 2, 2, (0x20, 0x30, 0x40, 255))
        # ice spikes
        for x in (36, 48, 60):
            for y in range(8, 18):
                _px(img, x, y, (0xD0, 0xF0, 0xFF, 255))
    elif name == "fen_elite":
        # Bog stalker — spiny toad-crab
        _blob(img, 48, 58, 26, 20, (0x40, 0x58, 0x18, 255))
        _blob(img, 48, 42, 18, 14, (0x70, 0x90, 0x28, 255))
        _blob(img, 48, 30, 12, 10, (0x90, 0xB0, 0x30, 255))
        _blob(img, 40, 28, 2, 2, (0xE0, 0xF0, 0x40, 255))
        _blob(img, 56, 28, 2, 2, (0xE0, 0xF0, 0x40, 255))
        for x, y in ((22, 50), (74, 50), (28, 64), (68, 64)):
            _blob(img, x, y, 6, 4, (0x50, 0x70, 0x20, 255))
        _blob(img, 48, 48, 4, 4, (0xC0, 0xE0, 0x40, 255))
    elif name == "fen_brute":
        _blob(img, 48, 56, 30, 28, (0x28, 0x38, 0x10, 255))
        _blob(img, 48, 40, 20, 16, (0x58, 0x70, 0x20, 255))
        _blob(img, 48, 24, 14, 12, (0x78, 0x98, 0x28, 255))
        _blob(img, 42, 22, 2, 2, (0xE8, 0xF0, 0x60, 255))
        _blob(img, 54, 22, 2, 2, (0xE8, 0xF0, 0x60, 255))
        for y in range(50, 80, 3):
            _px(img, 48, y, (0xA0, 0xC0, 0x30, 255))
    elif name == "brass_elite":
        # Clockwork knight
        _blob(img, 48, 56, 24, 26, (0x80, 0x60, 0x20, 255))
        _blob(img, 48, 36, 16, 14, (0xC0, 0x98, 0x30, 255))
        _blob(img, 48, 22, 12, 10, (0xE0, 0xC0, 0x50, 255))
        _blob(img, 42, 20, 2, 2, (0x20, 0x18, 0x08, 255))
        _blob(img, 54, 20, 2, 2, (0x20, 0x18, 0x08, 255))
        # gear teeth
        for a in range(0, 360, 45):
            import math

            x = int(48 + 22 * math.cos(math.radians(a)))
            y = int(50 + 22 * math.sin(math.radians(a)))
            _blob(img, x, y, 3, 3, (0xA0, 0x80, 0x28, 255))
        _blob(img, 48, 50, 5, 5, (0xFF, 0xE0, 0x80, 255))
    elif name == "brass_brute":
        _blob(img, 48, 58, 30, 28, (0x60, 0x48, 0x18, 255))
        _blob(img, 48, 42, 22, 16, (0xA0, 0x78, 0x28, 255))
        _blob(img, 48, 26, 14, 12, (0xD0, 0xA8, 0x40, 255))
        _blob(img, 28, 50, 10, 12, (0x80, 0x60, 0x20, 255))
        _blob(img, 68, 50, 10, 12, (0x80, 0x60, 0x20, 255))
        _blob(img, 42, 24, 2, 2, (0x20, 0x10, 0x08, 255))
        _blob(img, 54, 24, 2, 2, (0x20, 0x10, 0x08, 255))
        _blob(img, 48, 48, 6, 6, (0xFF, 0xD0, 0x60, 255))
    elif name == "veil_elite":
        # Moth wraith
        _blob(img, 48, 50, 16, 24, (0x60, 0x40, 0x70, 220))
        _blob(img, 30, 40, 14, 18, (0xE8, 0xC8, 0xF0, 180))
        _blob(img, 66, 40, 14, 18, (0xE8, 0xC8, 0xF0, 180))
        _blob(img, 48, 28, 10, 10, (0xC0, 0xA0, 0xD0, 255))
        _blob(img, 44, 26, 2, 2, (0xFF, 0xE0, 0xFF, 255))
        _blob(img, 52, 26, 2, 2, (0xFF, 0xE0, 0xFF, 255))
        for x in range(20, 76, 3):
            _px(img, x, 55 + (x % 4), (0xF0, 0xD8, 0xF8, 160))
    elif name == "veil_brute":
        _blob(img, 48, 56, 28, 28, (0x40, 0x28, 0x48, 255))
        _blob(img, 48, 40, 20, 16, (0x80, 0x58, 0x90, 255))
        _blob(img, 48, 24, 14, 12, (0xC0, 0x90, 0xD0, 255))
        _blob(img, 42, 22, 2, 2, (0xFF, 0xE8, 0xFF, 255))
        _blob(img, 54, 22, 2, 2, (0xFF, 0xE8, 0xFF, 255))
        # silk wrap
        for y in range(35, 75, 4):
            for x in range(30, 66):
                if (x + y) % 9 == 0:
                    _px(img, x, y, (0xF0, 0xD0, 0xF8, 255))
    else:
        _blob(img, 48, 48, 20, 24, (0x80, 0x80, 0x80, 255))
    _outline_rgba(img, (10, 8, 12, 255))
    return img


def craft_elites_all() -> None:
    print("=== Late-zone elites ===")
    names = [
        "tide_brute",
        "ember_elite",
        "ember_brute",
        "storm_wraith",
        "storm_brute",
        "rime_wraith",
        "rime_brute",
        "fen_elite",
        "fen_brute",
        "brass_elite",
        "brass_brute",
        "veil_elite",
        "veil_brute",
    ]
    for n in names:
        _save(craft_elite(n), ROOT / "enemies" / f"{n}.png")


# —— Spec heroes (96×96) ——


def craft_hero_shadow() -> Image.Image:
    img = _creature_base()
    # Void priest — purple robes, shadow orb staff
    _blob(img, 48, 62, 18, 22, (0x40, 0x28, 0x58, 255))  # robe
    _blob(img, 48, 48, 14, 12, (0x70, 0x40, 0x90, 255))
    _blob(img, 48, 28, 12, 12, (0xE0, 0xC0, 0xB0, 255))  # face
    _blob(img, 48, 18, 14, 8, (0x30, 0x18, 0x48, 255))  # hood
    _blob(img, 44, 26, 2, 2, (0xC0, 0x60, 0xE8, 255))
    _blob(img, 52, 26, 2, 2, (0xC0, 0x60, 0xE8, 255))
    # staff + void orb
    for y in range(20, 80):
        _px(img, 68, y, (0x50, 0x38, 0x60, 255))
        _px(img, 69, y, (0x70, 0x50, 0x88, 255))
    _blob(img, 68, 16, 8, 8, (0xA0, 0x50, 0xE0, 255))
    _blob(img, 68, 16, 4, 4, (0xE0, 0xB0, 0xFF, 255))
    # shadow tendrils
    for x, y in ((28, 55), (30, 65), (26, 70)):
        _blob(img, x, y, 4, 6, (0x50, 0x30, 0x70, 200))
    _outline_rgba(img)
    return img


def craft_hero_feral() -> Image.Image:
    img = _creature_base()
    # Cat-form lean — orange/brown, ear tufts
    _blob(img, 48, 58, 22, 18, (0xC0, 0x70, 0x30, 255))  # body
    _blob(img, 48, 38, 16, 14, (0xE0, 0x90, 0x40, 255))  # chest
    _blob(img, 48, 24, 12, 10, (0xD0, 0x80, 0x38, 255))  # head
    _blob(img, 38, 14, 5, 6, (0xA0, 0x50, 0x20, 255))  # ear
    _blob(img, 58, 14, 5, 6, (0xA0, 0x50, 0x20, 255))
    _blob(img, 44, 22, 2, 2, (0x40, 0xE0, 0x60, 255))  # eyes
    _blob(img, 52, 22, 2, 2, (0x40, 0xE0, 0x60, 255))
    # claws / legs
    for x in (32, 40, 56, 64):
        _blob(img, x, 72, 5, 8, (0x90, 0x50, 0x20, 255))
    # tail
    for i, (x, y) in enumerate(((70, 50), (74, 42), (76, 34), (72, 28))):
        _blob(img, x, y, 4, 4, (0xC0, 0x70, 0x30, 255))
    _outline_rgba(img)
    return img


def craft_hero_guardian() -> Image.Image:
    img = _creature_base()
    # Bear form — bulky brown
    _blob(img, 48, 56, 28, 24, (0x70, 0x48, 0x28, 255))
    _blob(img, 48, 40, 22, 16, (0x90, 0x60, 0x38, 255))
    _blob(img, 48, 24, 16, 14, (0x80, 0x55, 0x30, 255))
    _blob(img, 34, 16, 6, 7, (0x60, 0x40, 0x20, 255))
    _blob(img, 62, 16, 6, 7, (0x60, 0x40, 0x20, 255))
    _blob(img, 42, 22, 3, 3, (0x20, 0x18, 0x10, 255))
    _blob(img, 54, 22, 3, 3, (0x20, 0x18, 0x10, 255))
    _blob(img, 48, 28, 4, 3, (0x20, 0x18, 0x10, 255))  # snout
    for x in (28, 40, 56, 68):
        _blob(img, x, 74, 6, 8, (0x50, 0x35, 0x18, 255))
    _outline_rgba(img)
    return img


def craft_heroes_all() -> None:
    print("=== Spec heroes ===")
    _save(craft_hero_shadow(), ROOT / "heroes" / "shadow.png")
    _save(craft_hero_feral(), ROOT / "heroes" / "feral.png")
    _save(craft_hero_guardian(), ROOT / "heroes" / "guardian.png")


# —— Combat pets (64×64) ——


def craft_pet(name: str) -> Image.Image:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    if name == "combat_water_elemental":
        _blob(img, 32, 36, 18, 20, (*AQ1, 220))
        _blob(img, 32, 28, 12, 12, (*AQ2, 255))
        _blob(img, 26, 26, 2, 2, (0xFF, 0xFF, 0xFF, 255))
        _blob(img, 38, 26, 2, 2, (0xFF, 0xFF, 0xFF, 255))
        for x, y in ((20, 48), (32, 52), (44, 48)):
            _blob(img, x, y, 5, 6, (*AQ0, 200))
    elif name == "combat_ghoul":
        _blob(img, 32, 38, 16, 18, (0x60, 0x80, 0x58, 255))
        _blob(img, 32, 22, 12, 12, (0x80, 0xA0, 0x70, 255))
        _blob(img, 28, 20, 2, 2, (0xE0, 0x40, 0x40, 255))
        _blob(img, 36, 20, 2, 2, (0xE0, 0x40, 0x40, 255))
        _blob(img, 32, 28, 4, 2, (0x20, 0x30, 0x20, 255))
        for x in (22, 42):
            _blob(img, x, 44, 5, 10, (0x50, 0x70, 0x48, 255))
    elif name == "combat_felguard":
        _blob(img, 32, 38, 16, 18, (0x80, 0x30, 0x20, 255))
        _blob(img, 32, 22, 12, 12, (0xA0, 0x40, 0x28, 255))
        _blob(img, 24, 12, 4, 8, (0x60, 0x20, 0x10, 255))  # horn
        _blob(img, 40, 12, 4, 8, (0x60, 0x20, 0x10, 255))
        _blob(img, 28, 20, 2, 2, (0xFF, 0xE0, 0x40, 255))
        _blob(img, 36, 20, 2, 2, (0xFF, 0xE0, 0x40, 255))
        _blob(img, 48, 36, 6, 14, (0x50, 0x50, 0x58, 255))  # axe
    elif name == "combat_hunter_beast":
        _blob(img, 32, 40, 18, 14, (0x70, 0x58, 0x38, 255))
        _blob(img, 40, 28, 12, 10, (0x88, 0x68, 0x40, 255))
        _blob(img, 48, 24, 8, 6, (0x70, 0x58, 0x38, 255))  # snout
        _blob(img, 44, 22, 2, 2, (0xFF, 0xE0, 0x60, 255))
        for x in (22, 30, 38, 46):
            _blob(img, x, 52, 4, 6, (0x50, 0x40, 0x28, 255))
        # ear
        _blob(img, 34, 16, 4, 5, (0x60, 0x48, 0x30, 255))
    elif name == "combat_totem":
        for y in range(16, 52):
            for x in range(26, 38):
                _px(img, x, y, (*WD1, 255) if (y // 4) % 2 else (*WD0, 255))
        _blob(img, 32, 14, 10, 8, (*GL, 255))
        _blob(img, 32, 12, 4, 4, (*GL2, 255))
        _blob(img, 32, 52, 12, 4, (*W1, 255))
    elif name == "combat_spirit_wolf":
        _blob(img, 32, 40, 16, 14, (0x70, 0xB0, 0xE0, 200))
        _blob(img, 40, 28, 12, 10, (0x90, 0xD0, 0xF0, 220))
        _blob(img, 48, 24, 7, 5, (0xA0, 0xE0, 0xFF, 255))
        _blob(img, 44, 22, 2, 2, (0xFF, 0xFF, 0xFF, 255))
        for x in (22, 30, 38, 44):
            _blob(img, x, 50, 4, 6, (0x50, 0x90, 0xC0, 200))
        _blob(img, 34, 16, 4, 5, (0x60, 0xA0, 0xD0, 220))
    else:
        _blob(img, 32, 32, 12, 14, (0x80, 0x80, 0x80, 255))
    _outline_rgba(img)
    return img


def craft_pets_all() -> None:
    print("=== Combat pets ===")
    for n in (
        "combat_water_elemental",
        "combat_ghoul",
        "combat_felguard",
        "combat_hunter_beast",
        "combat_totem",
        "combat_spirit_wolf",
    ):
        _save(craft_pet(n), ROOT / "pets" / f"{n}.png")


def main() -> None:
    craft_tide_all()
    craft_elites_all()
    craft_heroes_all()
    craft_pets_all()
    print("Done.")


if __name__ == "__main__":
    main()
