#!/usr/bin/env python3
"""Idle Party town art — owned daylight pixel town.

Robert asked for a brighter, greener square after seeing the cave-brown
plaza: grass, a path, trees, flowers, and a few townsfolk. Ink and
upper-left light still match the heroes. The cave palette stays in the
dungeons.

Deterministic. No foreign packs. Run from the repo root:

    python3 tool/generate_town_art.py
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

TOOL_DIR = Path(__file__).resolve().parent
ASSETS_DIR = TOOL_DIR.parent / "assets" / "custom" / "town"

INK = (32, 22, 18, 255)

# Every fill is one of these. Snap kills Draw fringe; it does not invent hues.
C = {
    "sky_hi": (168, 220, 240),
    "sky": (110, 186, 224),
    "sky_lo": (236, 206, 156),
    "cloud": (246, 250, 252),
    "sun": (255, 210, 86),
    "sun_hi": (255, 244, 196),
    "hill": (58, 132, 74),
    "hill_hi": (104, 174, 90),
    "hill_lo": (36, 96, 58),
    "grass": (78, 164, 72),
    "grass_hi": (132, 198, 92),
    "grass_lo": (46, 122, 54),
    "flower_r": (214, 72, 84),
    "flower_y": (244, 196, 64),
    "flower_w": (246, 238, 220),
    "flower_p": (228, 112, 156),
    "path": (198, 156, 98),
    "path_hi": (230, 198, 142),
    "path_lo": (146, 106, 64),
    "pebble": (176, 148, 108),
    "stone": (196, 170, 128),
    "stone_hi": (230, 210, 170),
    "stone_lo": (140, 110, 78),
    "plaster": (240, 226, 196),
    "plaster_hi": (252, 244, 224),
    "plaster_lo": (198, 170, 132),
    "wood": (156, 96, 48),
    "wood_hi": (196, 132, 68),
    "wood_lo": (96, 58, 32),
    "roof": (184, 62, 52),
    "roof_hi": (222, 104, 72),
    "roof_lo": (122, 36, 40),
    "leaf": (42, 128, 62),
    "leaf_hi": (118, 190, 78),
    "leaf_lo": (24, 86, 46),
    "cloth": (176, 48, 56),
    "cloth_hi": (214, 86, 74),
    "cloth_g": (46, 128, 86),
    "cloth_g_hi": (96, 176, 112),
    "gold": (214, 164, 52),
    "gold_hi": (246, 216, 112),
    "gold_lo": (148, 100, 32),
    "iron": (90, 96, 110),
    "iron_hi": (164, 172, 184),
    "iron_lo": (48, 52, 62),
    "ember": (232, 112, 48),
    "flame": (255, 196, 72),
    "trunk": (112, 72, 40),
    "skin": (236, 180, 132),
    "skin_hi": (252, 214, 172),
    "hair": (64, 42, 28),
    "hair_b": (196, 140, 56),
    "tunic": (52, 104, 172),
    "tunic_g": (42, 132, 78),
    "dress": (184, 64, 96),
}

ALLOWED = [INK[:3]] + [tuple(v) for v in C.values()]

# Folk sheet. Dart TownFolkSheet uses the same cell size.
FOLK_CELL_W = 18
FOLK_CELL_H = 26
FOLK_FRAMES = 5
FOLK_PEOPLE = 3


def rgba(name: str) -> tuple[int, int, int, int]:
    r, g, b = C[name]
    return (r, g, b, 255)


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img: Image.Image, x: int, y: int, name: str) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(name))


def fill_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, name: str) -> None:
    color = rgba(name)
    for y in range(max(0, y0), min(img.height, y1)):
        for x in range(max(0, x0), min(img.width, x1)):
            img.putpixel((x, y), color)


def shade_rect(
    img: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    lo: str,
    mid: str,
    hi: str,
) -> None:
    """Upper-left light in bands, not a gradient."""
    span = max(1, x1 - x0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = (x - x0) + (y - y0) * 0.35
            if t < span * 0.38:
                name = hi
            elif t > span * 0.85:
                name = lo
            else:
                name = mid
            put(img, x, y, name)


def courses(img: Image.Image, x0: int, y0: int, x1: int, y1: int, lo: str, mid: str, hi: str) -> None:
    y = y0
    row = 0
    while y < y1:
        h = 5
        if y + h > y1:
            h = y1 - y
        shade_rect(img, x0, y, x1, y + h, lo, mid, hi)
        if h > 1:
            for x in range(x0, x1):
                put(img, x, y + h - 1, lo)
        x = x0 + (0 if row % 2 == 0 else 4)
        while x < x1:
            for yy in range(y, min(y1, y + h - 1)):
                put(img, x, yy, lo)
            x += 8 + ((row + x) % 3)
        y += h
        row += 1


def timber(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    shade_rect(img, x0, y0, x1, y1, "wood_lo", "wood", "wood_hi")
    for y in range(y0 + 5, y1, 6):
        for x in range(x0, x1):
            put(img, x, y, "wood_lo")
    for x in (x0, x0 + 1, x1 - 2, x1 - 1):
        for y in range(y0, y1):
            put(img, x, y, "wood_lo")


def plaster(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    shade_rect(img, x0, y0, x1, y1, "plaster_lo", "plaster", "plaster_hi")


def wall(img: Image.Image, tier: int, x0: int, y0: int, x1: int, y1: int) -> None:
    if tier <= 0:
        timber(img, x0, y0, x1, y1)
    else:
        plaster(img, x0, y0, x1, y1)
        if tier >= 1:
            for x in (x0, x0 + 1, x1 - 2, x1 - 1):
                for y in range(y0, y1):
                    put(img, x, y, "wood")


def roof(img: Image.Image, peak: tuple[int, int], left: tuple[int, int], right: tuple[int, int]) -> None:
    d = ImageDraw.Draw(img)
    d.polygon([left, peak, right], fill=rgba("roof"))
    for i in range(1, 18):
        y = left[1] - i * 3
        if y <= peak[1] + 1:
            break
        drop = (left[1] - peak[1]) or 1
        t = (left[1] - y) / drop
        span = right[0] - left[0]
        inset = int((span * 0.5) * t)
        name = "roof_hi" if i % 2 == 0 else "roof_lo"
        for x in range(left[0] + inset, right[0] - inset):
            put(img, x, y, name)
    for i in range(10):
        y = peak[1] + i * 2
        x = peak[0] - int((peak[0] - left[0]) * (i / 10))
        put(img, x, y, "roof_hi")
        put(img, x + 1, y, "roof_hi")


def window(img: Image.Image, x: int, y: int, w: int = 10, h: int = 12) -> None:
    fill_rect(img, x, y, x + w, y + h, "wood_lo")
    fill_rect(img, x + 1, y + 1, x + w - 1, y + h - 1, "gold_lo")
    fill_rect(img, x + 2, y + 2, x + w // 2, y + h // 2, "flame")
    for yy in range(y, y + h):
        put(img, x + w // 2, yy, "wood")
    for xx in range(x, x + w):
        put(img, xx, y + h // 2, "wood")


def door(img: Image.Image, x: int, y: int, w: int = 14, h: int = 22) -> None:
    fill_rect(img, x, y, x + w, y + h, "wood_lo")
    fill_rect(img, x + 2, y + 2, x + w - 3, y + h, "wood")
    fill_rect(img, x + 3, y + 3, x + 6, y + h - 1, "wood_hi")
    put(img, x + w - 5, y + h // 2, "gold_hi")


def flower_box(img: Image.Image, x: int, y: int) -> None:
    fill_rect(img, x, y, x + 14, y + 5, "wood")
    fill_rect(img, x + 1, y + 1, x + 13, y + 4, "wood_hi")
    for i, name in enumerate(("flower_r", "flower_y", "flower_w", "flower_p", "leaf_hi")):
        put(img, x + 2 + i * 2, y - 1, name)
        put(img, x + 2 + i * 2, y - 2, "leaf" if i % 2 else name)


def banner(img: Image.Image, x: int, y: int, h: int, cloth: str, hi: str) -> None:
    fill_rect(img, x, y, x + 11, y + 3, "wood")
    for yy in range(3, h):
        inset = 0 if yy < h - 4 else (yy - (h - 4))
        for xx in range(inset, 11 - inset):
            put(img, x + xx, y + yy, hi if xx < 3 else cloth)
    put(img, x + 5, y + 8, "gold_hi")


def chimney(img: Image.Image, x: int, y: int, h: int) -> None:
    courses(img, x, y + 6, x + 12, y + h, "stone_lo", "stone", "stone_hi")
    fill_rect(img, x - 1, y + h - 4, x + 13, y + h, "stone_lo")
    # Static smoke puffs. Motion lives on the townsfolk, not here.
    put(img, x + 4, y + 2, "cloud")
    put(img, x + 5, y + 1, "cloud")
    put(img, x + 6, y, "cloud")
    put(img, x + 8, y - 3, "cloud")
    put(img, x + 9, y - 4, "cloud")


def step(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    courses(img, x0, y0, x1, y1, "stone_lo", "stone", "stone_hi")


def snap_and_outline(img: Image.Image) -> Image.Image:
    w, h = img.size
    src = img.load()
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] < 16:
                src[x, y] = (0, 0, 0, 0)
                continue
            rgb = p[:3]
            best = ALLOWED[0]
            best_d = 10**9
            for c in ALLOWED:
                d = max(abs(rgb[0] - c[0]), abs(rgb[1] - c[1]), abs(rgb[2] - c[2]))
                if d < best_d:
                    best_d = d
                    best = c
            src[x, y] = (*best, 255)
    out = img.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    op[x, y] = INK
                    break
    return out


def generate_forge(tier: int) -> Image.Image:
    img = blank(120, 156)
    step(img, 12, 128, 108, 150)
    wall(img, tier, 24, 78, 96, 132)
    roof(img, (58, 36), (14, 84), (106, 80))
    chimney(img, 90, 18, 62)
    fill_rect(img, 36, 100, 68, 130, "wood_lo")
    fill_rect(img, 40, 112, 62, 128, "ember")
    fill_rect(img, 44, 116, 56, 126, "flame")
    put(img, 48, 118, "sun_hi")
    # Anvil.
    fill_rect(img, 70, 116, 100, 122, "iron_hi")
    fill_rect(img, 76, 112, 86, 118, "iron")
    fill_rect(img, 80, 120, 92, 132, "iron_lo")
    flower_box(img, 16, 122)
    window(img, 74, 90, 10, 10)
    if tier >= 2:
        banner(img, 28, 44, 22, "cloth", "cloth_hi")
        fill_rect(img, 16, 78, 104, 81, "gold")
    return snap_and_outline(img)


def generate_market(tier: int) -> Image.Image:
    img = blank(120, 140)
    step(img, 16, 118, 104, 136)
    fill_rect(img, 22, 72, 28, 122, "wood_lo")
    fill_rect(img, 90, 76, 96, 122, "wood")
    shade_rect(img, 18, 104, 102, 122, "wood_lo", "wood", "wood_hi")
    # Striped awning. Tier 0 is leaf-green, later red and cream.
    awning_a = "cloth_g" if tier == 0 else "roof"
    awning_b = "cloth_g_hi" if tier == 0 else "plaster_hi"
    for y in range(52, 96):
        sag = 0 if y < 70 else (y - 70) // 3
        for x in range(16 + sag, 104 - sag):
            band = ((x + y) // 4) % 2 == 0
            put(img, x, y, awning_a if band else awning_b)
    # Produce on the counter.
    for i, name in enumerate(("flower_r", "flower_r", "leaf_hi", "leaf", "gold", "flower_y")):
        fill_rect(img, 32 + i * 8, 98, 38 + i * 8, 106, name)
    shade_rect(img, 96, 96, 114, 112, "wood_lo", "wood", "wood_hi")
    flower_box(img, 8, 112)
    if tier >= 1:
        fill_rect(img, 24, 64, 28, 78, "gold")
    if tier >= 2:
        banner(img, 100, 36, 20, "cloth_g", "cloth_g_hi")
        fill_rect(img, 16, 50, 104, 53, "gold")
    return snap_and_outline(img)


def generate_inn(tier: int) -> Image.Image:
    img = blank(120, 160)
    step(img, 28, 136, 96, 156)
    wall(img, tier, 32, 100, 92, 142)
    if tier == 0:
        timber(img, 18, 62, 104, 104)
    else:
        plaster(img, 18, 62, 104, 104)
        for x in (18, 19, 102, 103, 58, 59):
            for y in range(62, 104):
                put(img, x, y, "wood")
        for y in (62, 82, 102):
            for x in range(18, 104):
                put(img, x, y, "wood")
    roof(img, (60, 20), (8, 68), (112, 64))
    door(img, 50, 114, 16, 26)
    window(img, 30, 74, 12, 14)
    window(img, 76, 74, 12, 14)
    flower_box(img, 28, 90)
    flower_box(img, 74, 90)
    fill_rect(img, 98, 86, 100, 108, "wood_lo")
    shade_rect(img, 92, 96, 116, 112, "wood_lo", "wood", "wood_hi")
    put(img, 100, 102, "gold_hi")
    if tier >= 1:
        chimney(img, 96, 24, 40)
    if tier >= 2:
        banner(img, 20, 34, 20, "cloth", "cloth_hi")
        fill_rect(img, 10, 60, 110, 63, "gold")
    return snap_and_outline(img)


def generate_guild(tier: int) -> Image.Image:
    img = blank(156, 176)
    step(img, 8, 152, 148, 172)
    courses(img, 12, 40, 52, 156, "stone_lo", "stone", "stone_hi")
    courses(img, 104, 56, 144, 156, "stone_lo", "stone", "stone_hi")
    courses(img, 48, 78, 108, 156, "stone_lo", "stone", "stone_hi")
    for x in range(14, 50, 12):
        fill_rect(img, x, 26, x + 7, 44, "stone_hi")
        fill_rect(img, x, 26, x + 7, 29, "plaster_hi")
    for x in range(106, 142, 12):
        fill_rect(img, x, 42, x + 7, 60, "stone_hi")
        fill_rect(img, x, 42, x + 7, 45, "plaster_hi")
    door(img, 68, 120, 20, 34)
    for i in range(11):
        y = 120 - int((11 * 11 - i * i) ** 0.5)
        put(img, 68 + i, y, "stone_lo")
        put(img, 88 - i, y, "stone_lo")
    window(img, 22, 72, 12, 16)
    window(img, 118, 84, 10, 12)
    # Flower bed along the step, in the sprite so it stays with the hall.
    for i, name in enumerate(("flower_r", "flower_y", "flower_w", "leaf_hi", "flower_p", "flower_y")):
        put(img, 18 + i * 4, 148, name)
        put(img, 18 + i * 4, 147, "leaf")
        put(img, 112 + (i % 4) * 4, 148, name)
    banner(img, 28, 78, 30 if tier >= 2 else 18, "cloth", "cloth_hi")
    if tier == 0:
        timber(img, 16, 52, 48, 84)
    if tier >= 1:
        fill_rect(img, 58, 108, 64, 122, "gold")
    if tier >= 2:
        banner(img, 112, 64, 28, "cloth_g", "cloth_g_hi")
        fill_rect(img, 12, 38, 52, 41, "gold")
        fill_rect(img, 104, 54, 144, 57, "gold")
    return snap_and_outline(img)


def generate_vault(open_lid: bool) -> Image.Image:
    img = blank(88, 104)
    step(img, 8, 86, 80, 102)
    # Body, wider than the lid so it reads as a chest even when small.
    shade_rect(img, 14, 52, 74, 88, "wood_lo", "wood", "wood_hi")
    fill_rect(img, 14, 60, 74, 64, "gold")
    fill_rect(img, 14, 76, 74, 80, "gold_lo")
    fill_rect(img, 40, 58, 48, 82, "gold_hi")
    fill_rect(img, 42, 66, 46, 72, "wood_lo")
    for i, name in enumerate(("flower_r", "leaf_hi", "flower_y")):
        put(img, 8 + i * 3, 84, name)
        put(img, 70 + i * 3, 84, name)
    if open_lid:
        shade_rect(img, 12, 18, 76, 40, "wood_hi", "plaster", "plaster_hi")
        fill_rect(img, 20, 42, 68, 54, "gold_lo")
        fill_rect(img, 28, 44, 60, 52, "gold_hi")
        put(img, 40, 46, "sun_hi")
        put(img, 48, 48, "flame")
    else:
        shade_rect(img, 18, 28, 70, 54, "wood_lo", "wood", "wood_hi")
        # Arch the lid. Pixels above the curve go transparent before the ink pass.
        for x in range(18, 70):
            dx = abs(x - 44)
            cut = 0 if dx < 10 else (dx - 10) // 2
            for y in range(28, 28 + cut):
                if 0 <= y < img.height:
                    img.putpixel((x, y), (0, 0, 0, 0))
        fill_rect(img, 18, 50, 70, 54, "gold")
        put(img, 22, 32, "wood_hi")
        put(img, 24, 34, "plaster_hi")
    return snap_and_outline(img)


def generate_well() -> Image.Image:
    img = blank(56, 68)
    shade_rect(img, 10, 40, 46, 64, "stone_lo", "stone", "stone_hi")
    fill_rect(img, 18, 44, 38, 58, "sky")
    fill_rect(img, 22, 48, 34, 56, "sky_hi")
    fill_rect(img, 16, 18, 20, 44, "wood")
    fill_rect(img, 36, 18, 40, 44, "wood")
    fill_rect(img, 14, 16, 42, 22, "wood_hi")
    roof(img, (28, 2), (6, 20), (50, 20))
    put(img, 8, 60, "flower_r")
    put(img, 12, 61, "leaf_hi")
    put(img, 44, 60, "flower_y")
    return snap_and_outline(img)


def _canopy(img: Image.Image, cx: int, cy: int, rx: int, ry: int) -> None:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            if nx * nx + ny * ny > 1:
                continue
            if nx < -0.25 and ny < -0.15:
                name = "leaf_hi"
            elif nx > 0.45 or ny > 0.45:
                name = "leaf_lo"
            else:
                name = "leaf"
            put(img, x, y, name)
    # Blossoms, fixed spots.
    for dx, dy, name in (
        (-rx // 2, -ry // 3, "flower_w"),
        (rx // 3, -ry // 4, "flower_p"),
        (0, ry // 5, "flower_y"),
        (-rx // 3, ry // 3, "flower_r"),
    ):
        put(img, cx + dx, cy + dy, name)
        put(img, cx + dx + 1, cy + dy, name)


def generate_tree_round() -> Image.Image:
    img = blank(64, 84)
    fill_rect(img, 28, 48, 36, 80, "trunk")
    fill_rect(img, 30, 50, 34, 78, "wood_hi")
    _canopy(img, 32, 36, 26, 24)
    _canopy(img, 22, 44, 14, 12)
    _canopy(img, 44, 42, 14, 12)
    return snap_and_outline(img)


def generate_tree_tall() -> Image.Image:
    img = blank(44, 96)
    fill_rect(img, 18, 58, 26, 92, "trunk")
    fill_rect(img, 20, 60, 24, 90, "wood")
    _canopy(img, 22, 28, 16, 18)
    _canopy(img, 22, 46, 18, 14)
    _canopy(img, 22, 62, 14, 10)
    return snap_and_outline(img)


def generate_flowers() -> Image.Image:
    img = blank(28, 18)
    for x, name in (
        (4, "flower_r"),
        (8, "flower_y"),
        (12, "flower_w"),
        (16, "flower_p"),
        (20, "flower_r"),
        (24, "flower_y"),
    ):
        put(img, x, 8, "leaf")
        put(img, x, 9, "leaf_hi")
        put(img, x, 6, name)
        put(img, x, 5, name)
        put(img, x - 1, 7, "leaf_lo")
        put(img, x + 1, 7, "grass_hi")
    return snap_and_outline(img)


def generate_ground() -> Image.Image:
    """32×32 grass that repeats. Flowers sit inside the tile, off the seam."""
    img = blank(32, 32)
    fill_rect(img, 0, 0, 32, 32, "grass")
    clumps = (
        (2, 4, 8, 9, "grass_hi"),
        (14, 2, 22, 8, "grass_lo"),
        (24, 12, 30, 18, "grass_hi"),
        (6, 18, 14, 26, "grass_lo"),
        (18, 20, 26, 28, "grass_hi"),
    )
    for x0, y0, x1, y1, name in clumps:
        fill_rect(img, x0, y0, x1, y1, name)
    for x, y, name in (
        (10, 12, "flower_y"),
        (11, 12, "flower_r"),
        (21, 16, "flower_w"),
        (5, 22, "flower_p"),
    ):
        put(img, x, y, name)
        put(img, x, y + 1, "leaf_lo")
    return snap_and_outline(img)


def generate_path() -> Image.Image:
    img = blank(360, 40)
    fill_rect(img, 0, 0, 360, 40, "path")
    for y in range(0, 40, 8):
        for x in range(0, 360, 14):
            name = "path_hi" if (x // 14 + y // 8) % 2 == 0 else "path_lo"
            fill_rect(img, x + 1, y + 1, x + 12, y + 7, name)
            put(img, x + 2, y + 2, "pebble")
    for x in range(0, 360, 10):
        put(img, x, 1, "grass_hi")
        put(img, x + 3, 0, "grass")
        put(img, x + 2, 38, "grass_lo")
        put(img, x + 6, 39, "flower_y" if x % 30 == 0 else "grass_hi")
    return snap_and_outline(img)


def generate_backdrop() -> Image.Image:
    img = Image.new("RGBA", (360, 200), rgba("sky"))
    for y in range(0, 120, 8):
        name = "sky_hi" if y < 40 else "sky" if y < 88 else "sky_lo"
        fill_rect(img, 0, y, 360, y + 8, name)
    # Block sun. Hard pixels, no disc fringe from Draw.
    for y in range(18, 42):
        for x in range(28, 52):
            if max(abs(x - 40), abs(y - 30)) <= 10 and abs(x - 40) + abs(y - 30) <= 16:
                put(img, x, y, "sun_hi" if (x + y) % 3 == 0 else "sun")
    # Clouds as 4px clusters.
    for cx, cy in ((90, 28), (150, 18), (230, 34), (300, 22)):
        for dy in range(0, 8, 2):
            for dx in range(0, 28, 2):
                if (dx + dy) % 6 == 4:
                    continue
                fill_rect(img, cx + dx, cy + dy, cx + dx + 2, cy + dy + 2, "cloud")
    # Distant birds.
    for bx, by in ((120, 48), (200, 40), (260, 56)):
        put(img, bx, by, "hill_lo")
        put(img, bx + 1, by - 1, "hill_lo")
        put(img, bx + 2, by, "hill_lo")
        put(img, bx - 2, by, "hill_lo")
        put(img, bx - 1, by - 1, "hill_lo")
    # Hills.
    for x in range(360):
        n = (x * 5) % 13
        top = 132 + (n % 7) - (10 if 140 < x < 220 else 0)
        for y in range(top, 168):
            put(img, x, y, "hill_hi" if y < top + 3 else "hill" if (x // 6 + y) % 3 else "hill_lo")
    # Tiny trees on the ridge.
    for tx in (48, 96, 180, 250, 310):
        fill_rect(img, tx, 124, tx + 3, 136, "trunk")
        _canopy(img, tx + 1, 118, 7, 8)
    fill_rect(img, 0, 168, 360, 200, "grass")
    for x in range(4, 360, 18):
        put(img, x, 176, "flower_y" if x % 36 == 0 else "grass_hi")
        put(img, x + 6, 184, "flower_w" if x % 54 == 0 else "grass_lo")
    return snap_and_outline(img)


def _person(img: Image.Image, ox: int, oy: int, frame: int, kind: int) -> None:
    """One 16×24 figure inside a padded cell. frame 0 idle, 1–4 walk."""
    tunic = ("tunic_g", "dress", "tunic")[kind]
    hair = ("hair", "hair_b", "hair")[kind]
    skin = "skin_hi" if kind == 1 else "skin"

    def p(x: int, y: int, name: str) -> None:
        put(img, ox + x, oy + y, name)

    # Head.
    for y in range(2, 8):
        for x in range(5, 11):
            p(x, y, skin)
    for x in range(5, 11):
        p(x, 2, hair)
        p(x, 3, hair)
    p(6, 5, "hair")
    p(9, 5, "hair")
    if kind == 2:
        for x in range(4, 12):
            p(x, 1, "gold")
        p(3, 2, "gold_hi")
        p(12, 2, "gold_lo")
    # Body.
    for y in range(8, 16):
        for x in range(4, 12):
            p(x, y, tunic)
    p(4, 8, "gold_hi" if kind != 1 else "flower_w")
    # Arms swing on the walk frames.
    swing = (0, -1, 0, 1, 0)[frame]
    for y in range(9, 14):
        p(3, y + (swing if y > 11 else 0), skin)
        p(12, y - (swing if y > 11 else 0), skin)
    # Legs.
    if frame == 0:
        pairs = ((5, 16, 8, 23), (9, 16, 12, 23))
    elif frame == 1:
        pairs = ((4, 16, 7, 21), (9, 17, 12, 23))
    elif frame == 2:
        pairs = ((6, 16, 9, 22), (8, 16, 11, 23))
    elif frame == 3:
        pairs = ((5, 17, 8, 23), (9, 16, 13, 21))
    else:
        pairs = ((5, 16, 8, 22), (10, 16, 13, 22))
    for x0, y0, x1, y1 in pairs:
        for y in range(y0, y1):
            for x in range(x0, x1):
                p(x, y, "wood_lo" if kind != 1 else "cloth")
        p(x0, y1 - 1, "wood")
        p(x1 - 1, y1 - 1, "wood")


def generate_folk() -> Image.Image:
    img = blank(FOLK_CELL_W * FOLK_FRAMES, FOLK_CELL_H * FOLK_PEOPLE)
    for person in range(FOLK_PEOPLE):
        for frame in range(FOLK_FRAMES):
            _person(
                img,
                frame * FOLK_CELL_W + 1,
                person * FOLK_CELL_H + 1,
                frame,
                person,
            )
    return snap_and_outline(img)


def generate_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (620, 620), rgba("sky_lo"))
    d = ImageDraw.Draw(sheet)
    d.text((8, 4), "daylight town  t0 timber  t1 plaster  t2 banners", fill=rgba("wood_lo"))
    kinds = (
        ("FORGE", generate_forge),
        ("MARKET", generate_market),
        ("INN", generate_inn),
        ("GUILD", generate_guild),
    )
    for col, (name, fn) in enumerate(kinds):
        for tier in range(3):
            sprite = fn(tier)
            sheet.paste(sprite, (8 + col * 150, 28 + tier * 180), sprite)
        d.text((8 + col * 150, 580), name, fill=rgba("wood_lo"))
    return sheet


README = """# Town assets

Owned Idle Party pixel art for the out-of-dungeon town.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL). Daylight palette, warm ink from `gear_style.py` |
| External packs | None |
| License | Same as the rest of `assets/custom/` — original game art |

Three painted facade tiers (timber / plaster / banners). AL10 pennants and
AL20 lanterns are Flutter overlays. Townsfolk frames share one sheet.
`TownFolkSheet` in Dart uses the same 18×26 cells.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same ink as the heroes |
| Light | Upper-left bands, not a gradient |
| Square | Grass, dirt path, trees, flowers, daylight sky |
| Roofs | Red tile, green or cream awnings |
| Windows | Warm amber, not blue glass |
| People | Three original figures, idle + 4 walk frames |
| Scale | `FilterQuality.none` |

The cave-brown paving pass was replaced after the owner saw it on device
and asked for a lighter, living town. Dungeon art is unchanged.

## Files

| File | Use |
|------|-----|
| backdrop.png | Sky, clouds, sun, hills, distant trees |
| ground.png | Repeating grass tile |
| path.png | Dirt path strip |
| tree_round.png / tree_tall.png | Plaza trees |
| flowers.png | Flower cluster |
| folk.png | 3 people × 5 frames (idle, walk×4), 18×26 cells |
| well.png | Well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Daily chest |
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", default="", help="Also copy review PNGs here")
    args = parser.parse_args()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    assets: list[tuple[str, Image.Image]] = [
        ("backdrop.png", generate_backdrop()),
        ("ground.png", generate_ground()),
        ("path.png", generate_path()),
        ("tree_round.png", generate_tree_round()),
        ("tree_tall.png", generate_tree_tall()),
        ("flowers.png", generate_flowers()),
        ("folk.png", generate_folk()),
        ("well.png", generate_well()),
        ("vault_shut.png", generate_vault(False)),
        ("vault_open.png", generate_vault(True)),
        ("buildings_sheet.png", generate_sheet()),
    ]
    for t in range(3):
        assets.extend(
            [
                (f"forge_t{t}.png", generate_forge(t)),
                (f"market_t{t}.png", generate_market(t)),
                (f"inn_t{t}.png", generate_inn(t)),
                (f"guild_t{t}.png", generate_guild(t)),
            ]
        )
    preview = generate_backdrop().resize((360, 520), Image.Resampling.NEAREST)
    grass = generate_ground()
    for y in range(300, 520, 32):
        for x in range(0, 360, 32):
            preview.paste(grass, (x, y), grass)
    preview.paste(generate_path(), (0, 430), generate_path())
    preview.paste(generate_tree_round(), (4, 250), generate_tree_round())
    preview.paste(generate_tree_tall(), (310, 230), generate_tree_tall())
    preview.paste(generate_guild(1), (16, 250), generate_guild(1))
    preview.paste(generate_vault(False), (260, 300), generate_vault(False))
    preview.paste(generate_well(), (160, 340), generate_well())
    preview.paste(generate_forge(1), (8, 360), generate_forge(1))
    preview.paste(generate_market(1), (120, 376), generate_market(1))
    preview.paste(generate_inn(1), (232, 356), generate_inn(1))
    assets.append(("preview_a56.png", preview))

    for name, img in assets:
        path = ASSETS_DIR / name
        img.save(path)
        print(f"Wrote {path} {img.size}")
    (ASSETS_DIR / "README.md").write_text(README)
    print(f"Wrote {ASSETS_DIR / 'README.md'}")
    if args.preview:
        dest = Path(args.preview)
        dest.mkdir(parents=True, exist_ok=True)
        for name, _img in assets:
            (dest / f"town_{name}").write_bytes((ASSETS_DIR / name).read_bytes())
    return 0


if __name__ == "__main__":
    sys.exit(main())
