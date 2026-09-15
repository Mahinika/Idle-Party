#!/usr/bin/env py
"""Owned generic cave tiles, props, chrome (no Kenney).

Run: py tool/generate_owned_replacements.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
CUSTOM = ROOT / "assets" / "custom"
FALL = CUSTOM / "dungeon" / "fallback"

INK = (14, 11, 9, 255)
STONE = (52, 46, 40, 255)
STONE_M = (68, 58, 48, 255)
STONE_H = (92, 78, 62, 255)
STONE_L = (34, 30, 26, 255)
DIRT = (64, 46, 30, 255)
DIRT_M = (82, 58, 36, 255)
DIRT_H = (108, 78, 48, 255)
SAND = (148, 112, 64, 255)
SAND_M = (168, 128, 74, 255)
SAND_H = (196, 156, 92, 255)
SAND_L = (118, 88, 50, 255)
WOOD = (92, 60, 36, 255)
WOOD_H = (122, 82, 48, 255)
WOOD_L = (62, 40, 24, 255)
GOLD = (212, 164, 64, 255)
GOLD_H = (236, 200, 96, 255)
RED = (168, 52, 40, 255)
WET = (48, 92, 108, 255)
WET_H = (88, 160, 176, 255)
LAVA = (212, 72, 28, 255)
LAVA_H = (255, 148, 48, 255)
BONE = (228, 216, 196, 255)
MOSS = (72, 108, 48, 255)


def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)} ({path.stat().st_size} B)")


def _px(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        if len(c) == 3:
            c = (*c, 255)
        img.putpixel((x, y), c)


def _rim(img: Image.Image) -> None:
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
        px[x, y] = (
            (a[0] * 2 + INK[0]) // 3,
            (a[1] * 2 + INK[1]) // 3,
            (a[2] * 2 + INK[2]) // 3,
            255,
        )


def _speckle(img: Image.Image, colors, seed: int) -> None:
    w, h = img.size
    for i in range(w * h // 5):
        n = (seed * 1103515245 + i * 12345) & 0x7FFFFFFF
        x, y = n % w, (n // w) % h
        c = colors[n % len(colors)]
        if img.mode == "RGBA" and img.getpixel((x, y))[3] < 20:
            continue
        _px(img, x, y, c)


def floor_dirt(detail: bool) -> Image.Image:
    img = Image.new("RGB", (16, 16), DIRT[:3])
    _speckle(img, (DIRT_M[:3], DIRT_H[:3], STONE_L[:3]), 3 if detail else 1)
    d = ImageDraw.Draw(img)
    for x, y in ((2, 4), (9, 7), (13, 12), (5, 14)):
        d.ellipse([x, y, x + 2, y + 1], fill=STONE_M[:3])
    if detail:
        for x, y in ((4, 9), (11, 3), (7, 1)):
            _px(img, x, y, MOSS[:3])
    for x, y in ((0, 0), (15, 0), (0, 15), (15, 15)):
        _px(img, x, y, STONE_L[:3])
    return img


def floor_sand(worn: bool) -> Image.Image:
    base = SAND_H[:3] if worn else SAND[:3]
    img = Image.new("RGB", (16, 16), base)
    d = ImageDraw.Draw(img)
    for y in range(1, 16, 3):
        d.line([(0, y), (15, y + (1 if worn else 0))], fill=SAND_L[:3])
    _speckle(img, (SAND_M[:3], SAND_H[:3], GOLD[:3]), 9 if worn else 4)
    for x, y in ((3, 5), (12, 10)):
        _px(img, x, y, GOLD_H[:3] if worn else STONE[:3])
    return img


def floor_stone() -> Image.Image:
    img = Image.new("RGB", (16, 16), STONE[:3])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 7, 7], fill=STONE_M[:3])
    d.rectangle([8, 0, 15, 7], fill=STONE[:3])
    d.rectangle([0, 8, 7, 15], fill=STONE[:3])
    d.rectangle([8, 8, 15, 15], fill=STONE_H[:3])
    d.line([(0, 7), (15, 7)], fill=STONE_L[:3])
    d.line([(7, 0), (7, 15)], fill=STONE_L[:3])
    _px(img, 2, 2, STONE_H[:3])
    _px(img, 11, 11, GOLD[:3])
    return img


def wall_stone(banner: bool) -> Image.Image:
    img = Image.new("RGB", (16, 16), STONE[:3])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 1], fill=STONE_H[:3])
    d.rectangle([0, 14, 15, 15], fill=INK[:3])
    for y in (4, 8, 12):
        d.line([(0, y), (15, y)], fill=STONE_L[:3])
    for x in (0, 8):
        d.line([(x, 2), (x, 13)], fill=STONE_L[:3])
    _px(img, 3, 6, STONE_H[:3])
    _px(img, 12, 10, STONE_M[:3])
    if banner:
        d.rectangle([5, 2, 10, 11], fill=RED[:3])
        d.rectangle([6, 3, 9, 9], fill=(196, 72, 52, 255)[:3])
        _px(img, 7, 5, GOLD_H[:3])
        d.polygon([(5, 11), (10, 11), (7, 14)], fill=RED[:3])
    return img


def stairs(boss: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 12, 14, 15], fill=WET)
    for i, y in enumerate((10, 8, 6, 4)):
        left, right = 2 + i, 13 - i
        fill = STONE_H if i % 2 == 0 else STONE_M
        d.rectangle([left, y, right, y + 1], fill=fill)
        d.line([(left, y), (right, y)], fill=STONE_L)
    cap = GOLD if boss else WET_H
    d.rectangle([5, 1, 10, 3], fill=cap)
    if boss:
        d.rectangle([0, 0, 15, 0], fill=GOLD)
        _px(img, 7, 2, GOLD_H)
    _rim(img)
    return img


def door(open_gate: bool, arch: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 1, 13, 14], fill=STONE_L)
    d.rectangle([3, 2, 12, 13], fill=WOOD)
    if arch:
        d.arc([2, 0, 13, 10], 200, 340, fill=INK, width=1)
    if open_gate:
        d.rectangle([5, 4, 10, 12], fill=(*WET[:3], 255))
        _px(img, 7, 6, WET_H)
        _px(img, 8, 9, GOLD)
    else:
        for y in range(4, 12):
            for x in (5, 8, 10):
                _px(img, x, y, WOOD_L if y % 2 == 0 else GOLD)
        d.rectangle([7, 7, 8, 8], fill=GOLD_H)
    _rim(img)
    return img


def fx(kind: str) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "target":
        d.ellipse([3, 3, 12, 12], outline=GOLD, width=1)
        d.point((7, 7), fill=GOLD_H)
        d.point((8, 8), fill=GOLD_H)
    elif kind == "idle":
        d.rectangle([5, 5, 10, 10], fill=(*STONE_M[:3], 180))
    elif kind == "slash":
        d.line([(2, 13), (13, 2)], fill=BONE, width=2)
        d.line([(3, 13), (13, 3)], fill=GOLD_H, width=1)
    else:
        d.line([(4, 12), (5, 3)], fill=BONE, width=1)
        d.line([(8, 13), (8, 2)], fill=BONE, width=1)
        d.line([(12, 12), (11, 3)], fill=BONE, width=1)
    return img


def prop_barrel() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 10, 26, 30], fill=WOOD)
    d.ellipse([8, 12, 24, 20], fill=WOOD_H)
    d.arc([6, 10, 26, 30], 200, 340, fill=WOOD_L, width=1)
    for y in (18, 24):
        d.arc([7, y - 6, 25, y + 8], 10, 170, fill=GOLD, width=1)
    _px(img, 11, 15, GOLD_H)
    _rim(img)
    return img


def prop_crate() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(8, 14), (16, 10), (24, 14), (24, 26), (16, 30), (8, 26)], fill=WOOD)
    d.line([(8, 14), (16, 18), (24, 14)], fill=WOOD_L)
    d.line([(16, 18), (16, 30)], fill=WOOD_L)
    d.line([(10, 16), (22, 16)], fill=GOLD)
    _rim(img)
    return img


def prop_table() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([5, 12, 27, 20], fill=WOOD_H)
    d.ellipse([7, 13, 25, 18], fill=WOOD)
    for x in (9, 21):
        d.rectangle([x, 18, x + 3, 28], fill=WOOD_L)
    _px(img, 16, 15, GOLD)
    _rim(img)
    return img


def prop_stool() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 14, 22, 22], fill=WOOD_H)
    d.ellipse([12, 15, 20, 20], fill=WOOD)
    d.rectangle([14, 21, 17, 29], fill=WOOD_L)
    _rim(img)
    return img


def prop_torch(alt: bool) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([14, 16, 17, 28], fill=WOOD)
    flame = LAVA_H if alt else GOLD_H
    core = GOLD_H if alt else (255, 240, 180, 255)
    d.polygon([(16, 4), (22, 16), (10, 16)], fill=flame)
    d.polygon([(16, 8), (19, 16), (13, 16)], fill=core)
    _px(img, 16, 10, (255, 255, 220, 255))
    _rim(img)
    return img


def prop_gravestone() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 12, 22, 28], fill=STONE_M)
    d.pieslice([10, 4, 22, 20], 180, 0, fill=STONE_H)
    d.line([(16, 14), (16, 20)], fill=GOLD)
    d.line([(13, 17), (19, 17)], fill=GOLD)
    _rim(img)
    return img


def prop_fountain() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 20, 28, 31], fill=WET)
    d.ellipse([8, 22, 24, 30], fill=WET_H)
    d.rectangle([13, 10, 19, 22], fill=STONE_H)
    d.ellipse([10, 5, 22, 14], fill=WET_H)
    _px(img, 16, 3, GOLD_H)
    _px(img, 12, 24, (200, 230, 240, 255))
    _rim(img)
    return img


def prop_trap() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([5, 20, 27, 28], fill=STONE_L)
    for x in range(8, 26, 5):
        d.polygon([(x, 26), (x + 2, 12), (x + 4, 26)], fill=STONE_H)
        _px(img, x + 2, 12, GOLD_H)
    _rim(img)
    return img


def prop_pot() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 12, 24, 28], fill=RED)
    d.ellipse([10, 14, 22, 24], fill=(196, 80, 56, 255))
    d.rectangle([12, 8, 20, 13], fill=STONE_H)
    _px(img, 14, 16, GOLD_H)
    _rim(img)
    return img


def prop_bones() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(6, 24), (26, 12)], fill=BONE, width=3)
    d.ellipse([4, 20, 12, 28], fill=BONE)
    d.ellipse([22, 8, 30, 16], fill=BONE)
    _rim(img)
    return img


def prop_skull() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, 24, 26], fill=BONE)
    d.ellipse([11, 13, 15, 17], fill=INK)
    d.ellipse([17, 13, 21, 17], fill=INK)
    d.rectangle([14, 20, 18, 23], fill=INK)
    _rim(img)
    return img


def prop_hatch() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 12, 28, 30], fill=STONE_L)
    for x in range(8, 25, 4):
        d.line([(x, 14), (x, 28)], fill=WOOD_H)
    d.ellipse([10, 18, 22, 26], fill=(*WET[:3], 200))
    _rim(img)
    return img


def prop_water() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 10, 30, 28], fill=WET)
    d.ellipse([8, 14, 24, 24], fill=WET_H)
    d.arc([6, 12, 26, 22], 20, 160, fill=(200, 240, 255, 255), width=1)
    _rim(img)
    return img


def prop_lava() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 12, 29, 29], fill=LAVA)
    d.ellipse([9, 16, 23, 26], fill=LAVA_H)
    _px(img, 16, 18, (255, 230, 140, 255))
    _rim(img)
    return img


def prop_anvil() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 22, 22, 29], fill=STONE_L)
    d.polygon([(6, 14), (26, 14), (22, 22), (10, 22)], fill=STONE_H)
    d.rectangle([16, 10, 26, 14], fill=STONE_M)
    _px(img, 20, 12, GOLD_H)
    _rim(img)
    return img


def prop_shelf() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 10, 26, 13], fill=WOOD_H)
    d.rectangle([6, 18, 26, 21], fill=WOOD_H)
    d.rectangle([8, 6, 12, 10], fill=RED)
    d.rectangle([18, 14, 24, 18], fill=STONE_M)
    _rim(img)
    return img


def prop_fence() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in (8, 16, 24):
        d.rectangle([x, 10, x + 3, 28], fill=WOOD)
    d.rectangle([6, 14, 28, 17], fill=WOOD_H)
    _rim(img)
    return img


def prop_pillar() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([11, 6, 21, 28], fill=STONE_M)
    d.rectangle([9, 4, 23, 8], fill=STONE_H)
    d.rectangle([9, 26, 23, 30], fill=STONE_L)
    _px(img, 13, 12, GOLD)
    _rim(img)
    return img


def prop_rubble() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 26), (14, 16), (20, 26)], fill=STONE)
    d.polygon([(14, 28), (24, 18), (30, 28)], fill=STONE_M)
    d.polygon([(10, 28), (16, 22), (22, 28)], fill=STONE_H)
    _rim(img)
    return img


def prop_chest(open_lid: bool, mimic: bool) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 16, 26, 28], fill=WOOD)
    d.rectangle([6, 16, 26, 20], fill=WOOD_H)
    d.rectangle([15, 18, 17, 22], fill=GOLD_H)
    if open_lid:
        d.polygon([(6, 16), (8, 8), (24, 8), (26, 16)], fill=WOOD_H)
        d.rectangle([12, 12, 20, 16], fill=GOLD)
    if mimic:
        d.rectangle([10, 22, 22, 26], fill=RED)
        _px(img, 12, 24, INK)
        _px(img, 20, 24, INK)
    _rim(img)
    return img


def hub_icon() -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 6, 24, 28], fill=STONE)
    d.polygon([(8, 6), (16, 1), (24, 6)], fill=STONE_H)
    d.rectangle([13, 16, 19, 28], fill=WOOD_L)
    _px(img, 16, 22, GOLD_H)
    _rim(img)
    return img


def snake() -> Image.Image:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    body, hi, lo = (56, 120, 48, 255), (96, 168, 64, 255), (28, 64, 28, 255)
    import math

    pts = []
    for i in range(40):
        t = i / 39
        ang = t * 5.4
        r = 20 - t * 11
        x = int(32 + r * math.cos(ang))
        y = int(38 + r * math.sin(ang) * 0.82)
        pts.append((x, y))
    for i, (x, y) in enumerate(pts):
        rad = 5 if i < 30 else 4
        col = hi if i % 3 == 0 else body
        for dx in range(-rad, rad + 1):
            for dy in range(-rad, rad + 1):
                if dx * dx + dy * dy <= rad * rad:
                    c = lo if dx * dx + dy * dy >= rad * rad - 2 else col
                    _px(img, x + dx, y + dy, c)
    hx, hy = pts[-1]
    for dx in range(-6, 7):
        for dy in range(-6, 7):
            if dx * dx + dy * dy <= 28:
                _px(img, hx + dx, hy + dy - 2, hi if dy < 0 else body)
    _px(img, hx - 2, hy - 3, GOLD_H)
    _px(img, hx + 2, hy - 3, GOLD_H)
    _px(img, hx, hy + 4, RED)
    _rim(img)
    return img


def flask_grey() -> Image.Image:
    src = Image.open(CUSTOM / "icons/flask.png").convert("RGBA")
    grey = ImageEnhance.Color(src).enhance(0.08)
    grey = ImageEnhance.Brightness(grey).enhance(1.08)
    return grey


def _panel(w: int, h: int, fill, edge, hi, inset=False) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=3, fill=edge)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius=2, fill=fill)
    d.line([(2, 2), (w - 3, 2)], fill=hi)
    if inset:
        d.rounded_rectangle((3, 3, w - 4, h - 4), radius=2, outline=edge)
    return img


def ui_chrome() -> None:
    chrome = CUSTOM / "ui/chrome"
    brown = (90, 62, 34, 255)
    brown_d = (42, 28, 16, 255)
    brown_h = (140, 102, 58, 255)
    beige = (200, 176, 120, 255)
    grey = (96, 90, 80, 255)
    red = (140, 40, 32, 255)
    _save(_panel(48, 48, brown, brown_d, brown_h), chrome / "panel_brown.png")
    _save(_panel(48, 48, beige, brown_d, (236, 220, 170, 255)), chrome / "panel_beige.png")
    _save(_panel(48, 48, brown, brown_d, brown_h, True), chrome / "panel_inset_brown.png")
    border = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle((0, 0, 47, 47), radius=3, outline=INK, width=2)
    ImageDraw.Draw(border).rounded_rectangle((2, 2, 45, 45), radius=2, outline=brown_h)
    _save(border, chrome / "panel_border.png")
    _save(_panel(48, 20, brown, brown_d, brown_h), chrome / "button_brown.png")
    _save(_panel(48, 20, grey, INK, (160, 154, 140, 255)), chrome / "button_grey.png")
    _save(_panel(48, 20, red, INK, (200, 80, 64, 255)), chrome / "button_red.png")

    def hexagon(fill) -> Image.Image:
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        ImageDraw.Draw(img).polygon(
            [(16, 1), (29, 8), (29, 23), (16, 30), (3, 23), (3, 8)],
            fill=fill,
            outline=INK,
        )
        return img

    _save(hexagon(brown), chrome / "hexagon_brown.png")
    _save(hexagon(brown_d), chrome / "hexagon_brown_dark.png")

    def bar(fill, name: str, h=8) -> None:
        img = Image.new("RGBA", (24, h), (0, 0, 0, 0))
        ImageDraw.Draw(img).rounded_rectangle((0, 0, 23, h - 1), radius=2, fill=fill)
        ImageDraw.Draw(img).line([(2, 1), (21, 1)], fill=(255, 255, 255, 70))
        _save(img, chrome / name)

    bar((56, 176, 72, 255), "progress_green.png")
    bar((28, 96, 40, 255), "progress_green_border.png")
    bar((196, 52, 44, 255), "progress_red.png")
    bar((96, 24, 20, 255), "progress_red_border.png")
    bar((64, 124, 196, 255), "progress_blue.png")
    bar((28, 64, 112, 255), "progress_blue_border.png")
    bar((232, 220, 196, 255), "progress_white.png")

    def seg(fill, name: str) -> None:
        img = Image.new("RGBA", (12, 8), fill)
        ImageDraw.Draw(img).line([(0, 1), (11, 1)], fill=(255, 255, 255, 50))
        _save(img, chrome / name)

    for color, tag in (
        ((36, 28, 20, 255), "back"),
        ((56, 176, 72, 255), "green"),
        ((196, 52, 44, 255), "red"),
        ((212, 176, 48, 255), "yellow"),
    ):
        seg(color, f"bar_{tag}_left.png")
        seg(color, f"bar_{tag}_mid.png")
        seg(color, f"bar_{tag}_right.png")


def dungeon() -> None:
    _save(floor_dirt(False), FALL / "tiles/floor_dirt.png")
    _save(floor_dirt(True), FALL / "tiles/floor_dirt_detail.png")
    _save(floor_sand(False), FALL / "tiles/floor_sand.png")
    _save(floor_sand(True), FALL / "tiles/floor_sand_worn.png")
    _save(floor_stone(), FALL / "tiles/floor_stone.png")
    _save(wall_stone(False), FALL / "tiles/wall_stone.png")
    _save(wall_stone(True), FALL / "tiles/wall_banner.png")
    _save(stairs(False), FALL / "tiles/stairs.png")
    _save(stairs(True), FALL / "tiles/stairs_boss.png")
    _save(door(False, False), FALL / "tiles/door_closed.png")
    _save(door(True, False), FALL / "tiles/door_open.png")
    _save(door(True, True), FALL / "tiles/door_arch.png")
    _save(fx("target"), FALL / "tiles/fx_target.png")
    _save(fx("idle"), FALL / "tiles/fx_idle.png")
    _save(fx("slash"), FALL / "tiles/fx_slash.png")
    _save(fx("claw"), FALL / "tiles/fx_claw.png")
    _save(prop_barrel(), FALL / "props/barrel.png")
    _save(prop_crate(), FALL / "props/crate.png")
    _save(prop_table(), FALL / "props/table.png")
    _save(prop_stool(), FALL / "props/stool.png")
    _save(prop_torch(False), FALL / "props/torch.png")
    _save(prop_torch(True), FALL / "props/torch_alt.png")
    _save(prop_gravestone(), FALL / "props/gravestone.png")
    _save(prop_fountain(), FALL / "props/fountain.png")
    _save(prop_trap(), FALL / "props/trap.png")
    _save(prop_pot(), FALL / "props/pot.png")
    _save(prop_bones(), FALL / "props/bones.png")
    _save(prop_skull(), FALL / "props/skull.png")
    _save(prop_hatch(), FALL / "props/hatch.png")
    _save(prop_water(), FALL / "props/water.png")
    _save(prop_lava(), FALL / "props/lava.png")
    _save(prop_anvil(), FALL / "props/anvil.png")
    _save(prop_shelf(), FALL / "props/shelf.png")
    _save(prop_fence(), FALL / "props/fence.png")
    _save(prop_pillar(), FALL / "props/pillar.png")
    _save(prop_rubble(), FALL / "props/rubble.png")
    _save(prop_chest(False, False), FALL / "props/chest.png")
    _save(prop_chest(True, False), FALL / "props/chest_open.png")
    _save(prop_chest(False, True), FALL / "props/chest_mimic.png")
    _save(hub_icon(), FALL / "hub_icon.png")


def main() -> None:
    print("Polishing owned fallback art…")
    dungeon()
    _save(snake(), CUSTOM / "enemies/snake.png")
    _save(flask_grey(), CUSTOM / "icons/flask_grey.png")
    ui_chrome()
    print("Done.")


if __name__ == "__main__":
    main()
