#!/usr/bin/env python3
"""Idle Party town art — owned pixel town in the Sandy Caverns palette.

Measured from shipped art (not a new style):

- Ink: tool/gear_style.py INK (32, 22, 18). Heroes sit near (30, 20, 13).
- Sand floor: assets/custom/dungeon/sandy/tiles/floor_a.png
  (58, 44, 24), (90, 68, 40), (122, 90, 52), (200, 136, 64)
- Sand wall: assets/custom/dungeon/sandy/tiles/wall_a.png
  (23, 17, 11), (42, 34, 24), (74, 58, 36)
- Leather / wood ramps: tool/gear_style.py MATERIAL_RAMPS
- Iron: assets/custom/dungeon/fallback/props/anvil.png
- Cave mouth: assets/custom/ui/backdrops/sandy.png and ui/hub_scene.png

Rules: 1 px warm ink on the outer silhouette only, upper-left light,
chunky stones (not a grey brick grid), amber windows (not blue glass).
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

# Named steps. Every fill below is one of these, then snapped.
C = {
    "void": (23, 17, 11),
    "wall_lo": (42, 34, 24),
    "wall": (74, 58, 36),
    "floor_lo": (58, 44, 24),
    "floor": (90, 68, 40),
    "floor_hi": (122, 90, 52),
    "sand": (161, 126, 88),
    "sand_hi": (200, 136, 64),
    "dust": (224, 176, 104),
    "wood_lo": (72, 44, 24),
    "wood": (112, 72, 36),
    "wood_hi": (148, 102, 52),
    "wood_top": (176, 132, 76),
    "iron_lo": (34, 30, 26),
    "iron": (68, 58, 48),
    "iron_hi": (92, 78, 62),
    "iron_top": (140, 124, 100),
    "gold_lo": (92, 62, 22),
    "gold": (148, 104, 36),
    "gold_hi": (196, 152, 52),
    "gold_top": (232, 196, 96),
    "ember_lo": (140, 56, 32),
    "ember": (188, 96, 40),
    "ember_hi": (232, 148, 48),
    "flame": (252, 204, 96),
    "cloth_lo": (92, 36, 24),
    "cloth": (140, 56, 32),
    "cloth_hi": (176, 88, 48),
    "plaster_lo": (140, 108, 72),
    "plaster": (176, 140, 96),
    "plaster_hi": (200, 168, 120),
}

ALLOWED = [INK[:3]] + list(C.values())


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
    for y in range(y0, y1):
        if y < 0 or y >= img.height:
            continue
        for x in range(x0, x1):
            if 0 <= x < img.width:
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
    """Upper-left light. Bands, not a gradient."""
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


def mortar_courses(
    img: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    lo: str,
    mid: str,
    hi: str,
    mortar: str,
) -> None:
    """Irregular sandstone courses. Mortar is dark sand, not a grey grid."""
    y = y0
    row = 0
    while y < y1:
        h = 4 + ((row * 3) % 2)
        if y + h > y1:
            h = y1 - y
        shade_rect(img, x0, y, x1, y + h - 1, lo, mid, hi)
        if y + h - 1 < y1:
            for x in range(x0, x1):
                put(img, x, y + h - 1, mortar)
        x = x0 + (0 if row % 2 == 0 else 3)
        while x < x1 - 1:
            w = 5 + ((x * 3 + row * 7) % 4)
            put(img, x, y, mortar)
            for yy in range(y, min(y1, y + h - 1)):
                put(img, x, yy, mortar)
            x += w
        y += h
        row += 1


def timber_wall(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    shade_rect(img, x0, y0, x1, y1, "wood_lo", "wood", "wood_hi")
    for y in range(y0 + 4, y1, 5):
        for x in range(x0, x1):
            put(img, x, y, "wood_lo")
    for x in (x0, x0 + 1, x1 - 2, x1 - 1):
        for y in range(y0, y1):
            put(img, x, y, "floor_lo")


def plaster_wall(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    shade_rect(img, x0, y0, x1, y1, "plaster_lo", "plaster", "plaster_hi")
    # A few cracks, not noise.
    for i, (x, y, n) in enumerate(
        ((x0 + 6, y0 + 8, 7), (x1 - 10, y0 + 14, 5), (x0 + 12, y1 - 8, 6))
    ):
        name = "plaster_lo" if i % 2 == 0 else "floor"
        for k in range(n):
            put(img, x + k, y + (k // 3), name)


def roof_slope(
    img: Image.Image,
    peak: tuple[int, int],
    left: tuple[int, int],
    right: tuple[int, int],
    tile: str,
    tile_hi: str,
    tile_lo: str,
) -> None:
    d = ImageDraw.Draw(img)
    d.polygon([left, peak, right], fill=rgba(tile))
    # Tile courses follow the eave.
    for i in range(1, 14):
        y = left[1] - i * 3
        if y <= peak[1] + 2:
            break
        span = right[0] - left[0]
        drop = (left[1] - peak[1]) or 1
        t = (left[1] - y) / drop
        inset = int((span * 0.5) * t)
        name = tile_hi if i % 3 == 1 else tile_lo
        for x in range(left[0] + inset, right[0] - inset):
            put(img, x, y, name)
    # Left eave highlight.
    for i in range(8):
        y = peak[1] + i * 3
        x = peak[0] - int((peak[0] - left[0]) * (i / 8))
        put(img, x, y, tile_hi)
        put(img, x + 1, y, tile_hi)


def window(img: Image.Image, x: int, y: int, w: int = 8, h: int = 9, lit: bool = True) -> None:
    fill_rect(img, x, y, x + w, y + h, "void")
    if lit:
        fill_rect(img, x + 1, y + 1, x + w - 1, y + h - 1, "gold_lo")
        fill_rect(img, x + 2, y + 2, x + w // 2, y + h // 2, "flame")
    else:
        fill_rect(img, x + 1, y + 1, x + w - 1, y + h - 1, "wall_lo")
    for yy in range(y, y + h):
        put(img, x + w // 2, yy, "floor_lo")
    for xx in range(x, x + w):
        put(img, xx, y + h // 2, "floor_lo")


def door(img: Image.Image, x: int, y: int, w: int = 14, h: int = 24, arch: bool = False) -> None:
    fill_rect(img, x, y, x + w, y + h, "floor_lo")
    fill_rect(img, x + 1, y + 1, x + w - 3, y + h, "wood_lo")
    fill_rect(img, x + 2, y + 2, x + 4, y + h - 1, "wood")
    if arch:
        for i in range(w // 2):
            put(img, x + i, y - 1 - (i // 2), "floor_lo")
            put(img, x + w - 1 - i, y - 1 - (i // 2), "floor_lo")
    put(img, x + w - 4, y + h // 2, "gold")


def lantern(img: Image.Image, x: int, y: int) -> None:
    fill_rect(img, x + 2, y, x + 4, y + 4, "wood_lo")
    fill_rect(img, x, y + 4, x + 6, y + 11, "iron")
    fill_rect(img, x + 1, y + 5, x + 5, y + 10, "ember")
    put(img, x + 2, y + 6, "flame")


def banner(img: Image.Image, x: int, y: int, h: int = 22) -> None:
    fill_rect(img, x, y, x + 10, y + 3, "wood")
    for yy in range(3, h):
        inset = 0 if yy < h - 4 else (yy - (h - 4))
        for xx in range(inset, 10 - inset):
            name = "cloth_hi" if xx < 3 else "cloth" if xx < 7 else "cloth_lo"
            put(img, x + xx, y + yy, name)
    put(img, x + 4, y + 8, "gold_hi")
    put(img, x + 5, y + 9, "gold")
    put(img, x + 4, y + 10, "gold_lo")


def chimney(img: Image.Image, x: int, y: int, h: int) -> None:
    mortar_courses(img, x, y + 4, x + 12, y + h, "wall_lo", "wall", "floor", "void")
    fill_rect(img, x - 1, y + h - 4, x + 13, y + h, "floor_lo")
    fill_rect(img, x + 3, y, x + 9, y + 5, "void")
    put(img, x + 4, y + 1, "iron")
    put(img, x + 6, y - 1, "iron_hi")
    put(img, x + 7, y - 3, "iron")


def contact_shadow(img: Image.Image, y: int, x0: int, x1: int) -> None:
    for x in range(x0, x1):
        if (x + y) % 2 == 0:
            put(img, x, y, "void")
        put(img, x, y + 1, "void")


def snap_and_outline(img: Image.Image) -> Image.Image:
    """Kill any Draw fringe, then a 1 px warm ink contour."""
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


def _wall(img: Image.Image, tier: int, x0: int, y0: int, x1: int, y1: int) -> None:
    if tier <= 0:
        timber_wall(img, x0, y0, x1, y1)
    else:
        mortar_courses(img, x0, y0, x1, y1, "wall_lo", "floor", "floor_hi", "floor_lo")


def generate_forge(tier: int) -> Image.Image:
    img = blank(120, 156)
    contact_shadow(img, 148, 14, 104)
    # Plinth breaks the box: wider than the shed.
    mortar_courses(img, 10, 124, 108, 148, "wall_lo", "floor", "floor_hi", "void")
    _wall(img, tier, 22, 78, 86, 128)
    roof_slope(
        img,
        (54, 40),
        (12, 86),
        (96, 82),
        "cloth_lo" if tier == 0 else "ember_lo",
        "wood_hi" if tier == 0 else "ember",
        "wood_lo" if tier == 0 else "cloth_lo",
    )
    # Chimney on the right, away from the guild on the left of the square.
    chimney(img, 92, 22, 64)
    # Open forge bay.
    fill_rect(img, 34, 96, 64, 126, "void")
    fill_rect(img, 38, 108, 58, 124, "ember_lo")
    fill_rect(img, 42, 112, 54, 122, "ember")
    put(img, 46, 114, "flame")
    put(img, 48, 116, "gold_top")
    # Anvil in front of the bay, iron ramp.
    # Horned anvil, same iron family as fallback/props/anvil.png.
    fill_rect(img, 58, 114, 90, 120, "iron_hi")
    fill_rect(img, 64, 110, 72, 116, "iron_top")
    fill_rect(img, 70, 118, 84, 128, "iron")
    fill_rect(img, 74, 126, 80, 132, "iron_lo")
    put(img, 60, 112, "iron_top")
    # Bellows.
    fill_rect(img, 18, 108, 32, 122, "wood")
    fill_rect(img, 20, 110, 30, 118, "cloth")
    window(img, 70, 88, 8, 8, lit=True)
    lantern(img, 24, 86)
    if tier >= 2:
        banner(img, 28, 48, 18)
        fill_rect(img, 14, 78, 98, 81, "gold")
    return snap_and_outline(img)


def generate_market(tier: int) -> Image.Image:
    img = blank(120, 140)
    contact_shadow(img, 132, 16, 108)
    mortar_courses(img, 14, 112, 106, 134, "wall_lo", "floor", "floor_hi", "void")
    # Posts and counter. Stall, not a house.
    fill_rect(img, 22, 70, 28, 116, "wood_lo")
    fill_rect(img, 86, 74, 92, 116, "wood_lo")
    shade_rect(img, 20, 100, 100, 116, "wood_lo", "wood", "wood_hi")
    # Sagging awning.
    d = ImageDraw.Draw(img)
    d.polygon(
        [(16, 62), (100, 58), (96, 86), (58, 96), (18, 84)],
        fill=rgba("cloth" if tier else "wood"),
    )
    cloth = "cloth" if tier else "wood"
    hi = "cloth_hi" if tier else "wood_hi"
    lo = "cloth_lo" if tier else "wood_lo"
    for y in range(60, 94):
        for x in range(16, 100):
            p = img.getpixel((x, y))
            if p[3] == 0:
                continue
            if (y // 3) % 2 == 0:
                put(img, x, y, hi if x < 50 else cloth)
            elif x > 70:
                put(img, x, y, lo)
    # Crates sticking out on the right.
    shade_rect(img, 92, 96, 112, 112, "wood_lo", "wood", "wood_hi")
    shade_rect(img, 96, 84, 114, 98, "floor_lo", "wood", "wood_top")
    # Hanging flasks.
    fill_rect(img, 36, 88, 40, 98, "gold")
    fill_rect(img, 44, 90, 48, 100, "sand_hi")
    fill_rect(img, 52, 88, 57, 99, "iron_hi")
    put(img, 37, 89, "gold_top")
    # Sign board.
    shade_rect(img, 58, 66, 82, 80, "wood_lo", "wood", "wood_hi")
    put(img, 64, 70, "gold_hi")
    put(img, 68, 74, "gold")
    if tier >= 1:
        lantern(img, 26, 84)
    if tier >= 2:
        banner(img, 8, 40, 20)
        fill_rect(img, 16, 56, 100, 59, "gold")
    return snap_and_outline(img)


def generate_inn(tier: int) -> Image.Image:
    img = blank(120, 160)
    contact_shadow(img, 152, 22, 100)
    mortar_courses(img, 28, 118, 92, 154, "wall_lo", "floor", "floor_hi", "void")
    # Ground floor narrower than the jetty above it.
    _wall(img, tier, 32, 96, 88, 140)
    if tier == 0:
        timber_wall(img, 18, 58, 102, 100)
    else:
        plaster_wall(img, 18, 58, 102, 100)
        # Timber frame on the jetty.
        for x in (18, 19, 100, 101, 58, 59):
            for y in range(58, 100):
                put(img, x, y, "wood_lo")
        for y in (58, 78, 98):
            for x in range(18, 102):
                put(img, x, y, "wood")
    roof_slope(
        img,
        (60, 22),
        (10, 66),
        (110, 62),
        "wood_lo" if tier == 0 else "ember_lo",
        "wood_hi" if tier == 0 else "sand_hi",
        "floor_lo" if tier == 0 else "cloth_lo",
    )
    door(img, 48, 112, 14, 28)
    window(img, 36, 70, 10, 12, lit=True)
    window(img, 72, 70, 10, 12, lit=True)
    window(img, 54, 108, 8, 8, lit=False)
    # Hanging sign on the right, clear of the market.
    fill_rect(img, 96, 78, 98, 96, "wood_lo")
    shade_rect(img, 90, 90, 114, 108, "wood_lo", "wood", "wood_hi")
    put(img, 98, 96, "gold_hi")
    put(img, 104, 100, "gold")
    lantern(img, 34, 104)
    if tier >= 1:
        chimney(img, 96, 28, 36)
    if tier >= 2:
        banner(img, 22, 36, 18)
        fill_rect(img, 12, 60, 108, 63, "gold")
    return snap_and_outline(img)


def generate_guild(tier: int) -> Image.Image:
    """Gatehouse, kin to ui/hub_scene.png. Crenellations, not a house roof."""
    img = blank(156, 176)
    contact_shadow(img, 168, 12, 144)
    mortar_courses(img, 8, 148, 148, 170, "wall_lo", "floor", "floor_hi", "void")
    # Side towers.
    mortar_courses(img, 10, 36, 48, 152, "wall_lo", "floor", "floor_hi", "floor_lo")
    mortar_courses(img, 108, 52, 146, 152, "wall_lo", "wall", "floor", "floor_lo")
    # Curtain wall between them, slightly lower.
    mortar_courses(img, 44, 70, 112, 152, "wall_lo", "floor", "floor_hi", "void")
    # Merlons sit on top of the towers (drawn after the courses).
    for x in range(12, 46, 10):
        fill_rect(img, x, 22, x + 6, 40, "floor")
        fill_rect(img, x, 22, x + 6, 25, "floor_hi")
        fill_rect(img, x + 6, 30, x + 10, 40, "void")
    for x in range(110, 144, 10):
        fill_rect(img, x, 38, x + 6, 56, "floor")
        fill_rect(img, x, 38, x + 6, 41, "floor_hi")
        fill_rect(img, x + 6, 46, x + 10, 56, "void")
    # Arch: a real half-round, not a rectangle with two pixels.
    door(img, 66, 116, 20, 34, arch=False)
    for i in range(12):
        y = 116 - int((12 * 12 - i * i) ** 0.5)
        put(img, 66 + i, y, "floor_lo")
        put(img, 86 - i, y, "floor_lo")
        for xx in range(66 + i, 86 - i):
            if y + 1 < 116:
                put(img, xx, y + 1, "void")
    window(img, 22, 70, 10, 14, lit=True)
    window(img, 120, 78, 8, 10, lit=True)
    window(img, 22, 100, 8, 8, lit=tier > 0)
    if tier == 0:
        # Timber hoarding on the left tower only.
        timber_wall(img, 14, 48, 44, 78)
    banner(img, 30, 78, 28 if tier >= 2 else 16)
    if tier >= 1:
        lantern(img, 96, 100)
        lantern(img, 54, 108)
    if tier >= 2:
        banner(img, 112, 60, 26)
        fill_rect(img, 10, 34, 48, 37, "gold")
        fill_rect(img, 108, 50, 146, 53, "gold")
    return snap_and_outline(img)


def generate_vault(open_lid: bool) -> Image.Image:
    """Iron-bound chest on a step. Same family as sandy/props/chest.png."""
    img = blank(88, 104)
    contact_shadow(img, 96, 14, 74)
    mortar_courses(img, 10, 78, 78, 98, "wall_lo", "floor", "floor_hi", "void")
    # Body bulges: narrower at the bottom, wider at the lid line.
    shade_rect(img, 22, 58, 66, 86, "wood_lo", "wood", "wood_hi")
    shade_rect(img, 16, 50, 72, 64, "wood_lo", "wood", "wood_top")
    for y in (58, 74):
        fill_rect(img, 16, y, 72, y + 3, "iron")
        put(img, 18, y, "iron_top")
    fill_rect(img, 40, 52, 48, 82, "iron_hi")
    fill_rect(img, 41, 66, 47, 72, "gold")
    put(img, 43, 68, "gold_top")
    if open_lid:
        shade_rect(img, 14, 28, 74, 48, "wood", "wood_hi", "wood_top")
        fill_rect(img, 22, 50, 66, 60, "gold_lo")
        fill_rect(img, 28, 52, 60, 58, "gold_hi")
        put(img, 40, 53, "gold_top")
        put(img, 48, 55, "flame")
    else:
        shade_rect(img, 18, 34, 70, 52, "wood_lo", "wood", "wood_hi")
        fill_rect(img, 18, 48, 70, 52, "iron")
        put(img, 22, 36, "wood_top")
        put(img, 64, 38, "sand_hi")
    return snap_and_outline(img)


def generate_well() -> Image.Image:
    img = blank(56, 68)
    contact_shadow(img, 62, 8, 48)
    # Stone ring.
    shade_rect(img, 10, 36, 46, 62, "wall_lo", "floor", "floor_hi")
    fill_rect(img, 18, 40, 38, 56, "void")
    fill_rect(img, 22, 44, 34, 52, "iron")
    # Beam and bucket.
    fill_rect(img, 16, 18, 20, 40, "wood_lo")
    fill_rect(img, 36, 18, 40, 40, "wood_lo")
    fill_rect(img, 14, 16, 42, 22, "wood")
    fill_rect(img, 26, 22, 30, 36, "wood_hi")
    fill_rect(img, 24, 34, 32, 40, "iron_hi")
    roof_slope(img, (28, 4), (8, 20), (48, 20), "wood_lo", "wood_hi", "floor_lo")
    return snap_and_outline(img)


def generate_ground() -> Image.Image:
    """360×48 repeat tile. Irregular sand flags, 1:1 with the phone."""
    img = blank(360, 48)
    fill_rect(img, 0, 0, 360, 48, "floor_lo")
    y = 0
    row = 0
    while y < 48:
        h = 7 + (row % 3)
        x = 0 if row % 2 == 0 else -4
        col = 0
        while x < 360:
            w = 9 + ((row * 5 + col * 3) % 6)
            names = ("floor_lo", "floor", "floor_hi", "sand")
            name = names[(row + col) % 3]
            if (row + col) % 11 == 0:
                name = "sand"
            fill_rect(img, x, y, min(360, x + w - 1), min(48, y + h - 1), name)
            for yy in range(y, min(48, y + h)):
                put(img, x, yy, "void")
            for xx in range(max(0, x), min(360, x + w)):
                put(img, xx, y, "floor_lo")
            # Upper-left chip on each stone.
            put(img, x + 2, y + 2, "sand_hi" if name == "sand" else "floor_hi")
            x += w
            col += 1
        y += h
        row += 1
    # A worn path of lighter flags, not a dither hole.
    for y in range(6, 42, 8):
        for x in range(156, 204, 10):
            fill_rect(img, x + 1, y + 1, x + 8, y + 6, "sand")
            put(img, x + 2, y + 2, "sand_hi")
    return snap_and_outline(img)


def generate_backdrop() -> Image.Image:
    """Ochre sky, dithered ridges, one cave arch. Kin to sandy.png."""
    img = Image.new("RGBA", (360, 400), rgba("dust"))
    fill_rect(img, 0, 0, 360, 96, "dust")
    fill_rect(img, 0, 96, 360, 168, "sand_hi")
    fill_rect(img, 0, 168, 360, 230, "sand")
    fill_rect(img, 0, 230, 360, 400, "floor")
    # Ridge line, pixel steps, then dithered rock below it.
    ridge = []
    for x in range(360):
        n = (x * 3) % 17
        base = 200 + (40 if x < 80 or x > 280 else 0)
        ridge.append(base - (n % 9) * 2)
    for x, top in enumerate(ridge):
        for y in range(top, 400):
            put(img, x, y, "wall" if ((x // 4) + (y // 4)) % 2 == 0 else "wall_lo")
    # Arched cave mouth. Wider at the floor, round at the crown.
    cx, crown, rx, ry = 180, 168, 46, 70
    for y in range(crown, 340):
        dy = (y - (crown + ry)) / ry
        half = rx if y > crown + ry else int(rx * (1 - dy * dy) ** 0.5)
        for x in range(cx - half, cx + half):
            put(img, x, y, "void")
            if y < crown + 18 and (x + y) % 4 == 0:
                put(img, x, y, "wall_lo")
    # Stalactites on the crown.
    for x in (158, 170, 182, 194, 206):
        length = 6 + (x % 5)
        for k in range(length):
            put(img, x, crown + 8 + k, "wall")
            put(img, x + 1, crown + 10 + k, "void")
    # Two torches, same job as the sandy backdrop.
    for tx in (118, 232):
        fill_rect(img, tx, 230, tx + 3, 248, "iron")
        fill_rect(img, tx - 1, 222, tx + 4, 232, "ember")
        put(img, tx, 220, "flame")
        put(img, tx + 1, 224, "gold_top")
    # Small warm sun. Hard pixels, no disc fringe.
    for y in range(16, 36):
        for x in range(24, 44):
            if (x - 34) ** 2 + (y - 26) ** 2 < 70:
                put(img, x, y, "gold_top" if (x + y) % 2 == 0 else "flame")
    return snap_and_outline(img)


def generate_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (560, 560), rgba("void"))
    d = ImageDraw.Draw(sheet)
    d.text((8, 4), "town tiers  t0 timber   t1 stone   t2 banners", fill=rgba("dust"))
    kinds = (
        ("FORGE", generate_forge),
        ("MARKET", generate_market),
        ("INN", generate_inn),
        ("GUILD", generate_guild),
    )
    for col, (name, fn) in enumerate(kinds):
        for tier in range(3):
            sprite = fn(tier)
            x = 8 + col * 140
            y = 28 + tier * 170
            sheet.paste(sprite, (x, y), sprite)
        d.text((8 + col * 140, 540), name, fill=rgba("dust"))
    return sheet


README = """# Town assets

Owned Idle Party pixel art for the out-of-dungeon town hub.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL). Palette measured from Sandy floor/wall, `gear_style.py` ramps, and `ui/hub_scene.png` |
| External packs | None. No Kenney, no marketplace, no paid downloads |
| License | Same as the rest of `assets/custom/` — original game art |

Three **painted** facade tiers (timber / stone / banners). AL10 pennants and
AL20 lantern arcade are drawn in Flutter on top of these sprites.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style rules (same game)

| Rule | Source |
|------|--------|
| Warm ink (32, 22, 18), 1 px outer contour | `tool/gear_style.py` |
| Upper-left light | `LIGHT_DIR` in `gear_style.py` |
| Sand stone, not grey brick | `dungeon/sandy/tiles/floor_a.png`, `wall_a.png` |
| Amber windows, torch light | Sandy backdrop + chest highlight |
| Gatehouse guild | `ui/hub_scene.png` arch and banners |
| Nearest-neighbor only | `FilterQuality.none` |

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×400 | Ochre sky, ridges, cave mouth |
| ground.png | 360×48 | Repeating sand flags (paint 1:1, no cover-scale) |
| well.png | 56×68 | Well (non-interactive) |
| forge_t0/t1/t2.png | 120×156 | Smithy. Chimney on the right |
| market_t0/t1/t2.png | 120×140 | Stall, not a house |
| inn_t0/t1/t2.png | 120×160 | Jetty inn |
| guild_t0/t1/t2.png | 156×176 | Crenellated gatehouse |
| vault_shut.png / vault_open.png | 88×104 | Bound chest |
| buildings_sheet.png | tier strip for review |

Paint with `FilterQuality.none` via `CustomAssets.town*`.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preview",
        default="",
        help="Also copy review PNGs to this directory",
    )
    args = parser.parse_args()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    assets: list[tuple[str, Image.Image]] = [
        ("backdrop.png", generate_backdrop()),
        ("ground.png", generate_ground()),
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
    # preview_a56.png is a layout composite, not the Flutter screenshot.
    # Keep a nearest-neighbor paste so the file still exists for the README.
    preview = generate_backdrop().resize((360, 520), Image.Resampling.NEAREST)
    preview.paste(generate_ground(), (0, 460), generate_ground())
    preview.paste(generate_guild(1), (16, 180), generate_guild(1))
    preview.paste(generate_vault(False), (250, 250), generate_vault(False))
    preview.paste(generate_forge(1), (8, 340), generate_forge(1))
    preview.paste(generate_market(1), (120, 360), generate_market(1))
    preview.paste(generate_inn(1), (230, 340), generate_inn(1))
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
        for name in (
            "buildings_sheet.png",
            "forge_t0.png",
            "forge_t1.png",
            "forge_t2.png",
            "market_t1.png",
            "inn_t1.png",
            "guild_t1.png",
            "vault_shut.png",
            "backdrop.png",
            "ground.png",
        ):
            data = (ASSETS_DIR / name).read_bytes()
            (dest / f"town_{name}").write_bytes(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
