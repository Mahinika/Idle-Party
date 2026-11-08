#!/usr/bin/env python3
"""Idle Party town art. Owned daylight pixel town.

The square is painted in the same material language as the heroes and the
hub scene: cut stone, wood grain, tile courses, cloth folds, iron rivets.
Light comes from the upper left. Outlines are one pixel of warm ink.
Nothing here is a foreign sprite. Deterministic: no RNG.

    python3 tool/generate_town_art.py

Folk cells are 40×48. Dart `TownFolkSheet` must match.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image

TOOL_DIR = Path(__file__).resolve().parent
ASSETS_DIR = TOOL_DIR.parent / "assets" / "custom" / "town"
ROOT = TOOL_DIR.parent

INK = (32, 22, 18, 255)

# Ramps run dark → light. Index picks a cluster, not a smooth blend.
STONE = [
    (58, 50, 44),
    (86, 76, 66),
    (118, 106, 92),
    (154, 140, 122),
    (188, 174, 154),
    (220, 208, 188),
]
TIMBER = [
    (48, 28, 16),
    (78, 46, 26),
    (112, 68, 36),
    (148, 96, 52),
    (184, 128, 72),
    (214, 164, 108),
]
PLASTER = [
    (132, 108, 84),
    (168, 146, 116),
    (198, 176, 146),
    (222, 204, 176),
    (238, 226, 204),
    (248, 240, 226),
]
TILE = [
    (92, 36, 32),
    (128, 48, 40),
    (164, 64, 48),
    (192, 88, 60),
    (214, 118, 78),
    (232, 156, 108),
]
SLATE = [
    (48, 56, 64),
    (70, 80, 90),
    (96, 108, 118),
    (126, 138, 148),
    (158, 170, 178),
    (196, 206, 212),
]
LEAF = [
    (22, 52, 28),
    (32, 78, 36),
    (46, 104, 44),
    (64, 132, 52),
    (92, 158, 64),
    (132, 184, 86),
    (176, 206, 112),
]
GRASS = [
    (36, 78, 40),
    (48, 98, 48),
    (62, 118, 54),
    (78, 138, 62),
    (104, 158, 74),
    (138, 176, 92),
]
IRON = [
    (28, 30, 34),
    (48, 52, 58),
    (74, 80, 88),
    (108, 116, 126),
    (156, 164, 174),
    (206, 214, 222),
]
GOLD = [
    (92, 58, 18),
    (132, 88, 28),
    (174, 122, 40),
    (206, 158, 58),
    (230, 192, 96),
    (248, 224, 150),
]
SKIN = [
    (92, 56, 40),
    (132, 82, 56),
    (174, 116, 80),
    (208, 150, 108),
    (230, 182, 142),
    (246, 214, 184),
]
HAIR = [
    (28, 16, 12),
    (58, 32, 20),
    (92, 54, 30),
    (128, 78, 42),
    (166, 112, 62),
]
MOSS_CLOTH = [
    (28, 52, 40),
    (40, 78, 56),
    (54, 104, 70),
    (78, 132, 88),
    (112, 160, 112),
    (156, 188, 140),
]
WOOL = [
    (32, 44, 72),
    (46, 64, 102),
    (64, 88, 132),
    (92, 118, 160),
    (128, 152, 186),
    (176, 196, 214),
]
ROSE = [
    (92, 42, 52),
    (128, 58, 70),
    (164, 82, 96),
    (196, 114, 124),
    (220, 154, 156),
    (238, 196, 188),
]
CREAM = [
    (120, 96, 72),
    (160, 132, 100),
    (196, 168, 132),
    (222, 198, 164),
    (238, 222, 196),
    (248, 240, 224),
]
EMBER = [
    (80, 18, 12),
    (140, 36, 16),
    (190, 64, 20),
    (220, 108, 32),
    (244, 164, 56),
    (255, 214, 120),
    (255, 242, 210),
]
AMBER = [
    (72, 40, 16),
    (120, 68, 24),
    (176, 108, 36),
    (214, 150, 56),
    (236, 190, 100),
    (252, 226, 170),
]
PATH_STONE = [
    (72, 58, 42),
    (104, 84, 60),
    (138, 114, 82),
    (170, 146, 110),
    (198, 176, 140),
    (222, 204, 172),
]
SKY = [
    (118, 168, 196),
    (146, 190, 214),
    (176, 208, 224),
    (206, 222, 214),
    (228, 214, 186),
]
CLOUD = [
    (168, 186, 196),
    (206, 218, 224),
    (236, 242, 244),
    (250, 252, 252),
]

FOLK_CELL_W = 40
FOLK_CELL_H = 48
FOLK_FRAMES = 5
FOLK_PEOPLE = 3


def rgba(rgb: tuple[int, int, int]) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], 255)


def clamp_i(i: int, n: int) -> int:
    if i < 0:
        return 0
    if i >= n:
        return n - 1
    return i


class Pix:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.px: list[tuple[int, int, int, int] | None] = [None] * (w * h)

    def _i(self, x: int, y: int) -> int | None:
        if 0 <= x < self.w and 0 <= y < self.h:
            return y * self.w + x
        return None

    def get(self, x: int, y: int) -> tuple[int, int, int, int] | None:
        i = self._i(x, y)
        if i is None:
            return None
        return self.px[i]

    def put(self, x: int, y: int, c: tuple[int, int, int] | tuple[int, int, int, int] | None) -> None:
        i = self._i(x, y)
        if i is None or c is None:
            return
        self.px[i] = c if len(c) == 4 else (*c, 255)

    def rect(self, x: int, y: int, w: int, h: int, c: tuple[int, int, int]) -> None:
        color = rgba(c)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, color)

    def image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        flat = []
        for p in self.px:
            flat.append(p if p is not None else (0, 0, 0, 0))
        im.putdata(flat)
        return im

    def outline(self, ink: tuple[int, int, int, int] = INK) -> None:
        add: list[tuple[int, int]] = []
        for y in range(self.h):
            row = y * self.w
            for x in range(self.w):
                if self.px[row + x] is not None:
                    continue
                hit = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny * self.w + nx] is not None:
                        hit = True
                        break
                if hit:
                    add.append((x, y))
        for x, y in add:
            self.px[y * self.w + x] = ink


def stone_wall(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0, ramp: list[tuple[int, int, int]] | None = None) -> None:
    """Individual ashlar courses. Mortar is a real gap, not a tinted rectangle."""
    ramp = ramp or STONE
    widths = (8, 11, 7, 10, 6, 9, 12)
    yy = y
    row = 0
    while yy < y + h:
        ch = 5 if yy + 5 <= y + h else y + h - yy
        if ch <= 0:
            break
        shift = 0 if row % 2 == 0 else 5
        xx = x - shift
        i = 0
        while xx < x + w:
            sw = widths[(row + i + seed) % len(widths)]
            x0 = xx if xx > x else x
            x1 = xx + sw if xx + sw < x + w else x + w
            if x1 - x0 >= 2 and ch >= 2:
                tone = 2 + ((row * 3 + i * 2 + seed) % 3)
                body = ramp[tone]
                pix.rect(x0, yy, x1 - x0, ch - 1, body)
                pix.rect(x0, yy, max(1, x1 - x0 - 1), 1, ramp[min(tone + 1, 5)])
                if ch >= 4:
                    pix.put(x0 + 1, yy + 1, ramp[min(tone + 2, 5)])
                # A few stones are chipped.
                if (row + i + seed) % 7 == 0 and x1 - x0 > 4:
                    pix.put(x0 + 2, yy + ch - 2, ramp[1])
                    pix.put(x0 + 3, yy + ch - 2, ramp[0])
                pix.rect(x0, yy + ch - 1, x1 - x0, 1, ramp[0])
                pix.put(x1 - 1, yy, ramp[1])
                if ch > 2:
                    pix.put(x1 - 1, yy + 1, ramp[1])
            xx += sw
            i += 1
        yy += ch
        row += 1


def timber_wall(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 1) -> None:
    pix.rect(x, y, w, h, TIMBER[2])
    plank = 0
    xx = x
    while xx < x + w:
        pw = 5 if plank % 2 == 0 else 4
        x1 = min(x + w, xx + pw)
        tone = 2 + ((plank + seed) % 3)
        pix.rect(xx, y, x1 - xx, h, TIMBER[tone])
        pix.rect(xx, y, 1, h, TIMBER[min(tone + 1, 5)])
        # Grain: a broken dark line, not a stripe every row.
        gx = xx + 2
        for yy in range(y + 2, y + h - 1, 3):
            pix.put(gx, yy, TIMBER[1])
            pix.put(gx + ((yy // 3) % 2), yy + 1, TIMBER[0])
        if (plank + seed) % 4 == 0 and h > 8:
            ky = y + 4 + (plank % 5)
            pix.put(gx, ky, TIMBER[0])
            pix.put(gx + 1, ky, TIMBER[1])
            pix.put(gx, ky + 1, TIMBER[4])
        pix.rect(x1 - 1, y, 1, h, TIMBER[0])
        xx = x1
        plank += 1
    # Nail heads along the top plate.
    for nx in range(x + 3, x + w - 2, 7):
        pix.put(nx, y + 2, IRON[4])
        pix.put(nx, y + 3, IRON[1])


def plaster_wall(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0) -> None:
    pix.rect(x, y, w, h, PLASTER[3])
    # Stain clusters, not noise.
    for i in range(6 + (w // 20)):
        cx = x + 4 + ((i * 17 + seed * 5) % max(1, w - 8))
        cy = y + 3 + ((i * 11 + seed) % max(1, h - 6))
        stain = PLASTER[1] if i % 2 == 0 else PLASTER[2]
        pix.put(cx, cy, stain)
        pix.put(cx + 1, cy, stain)
        pix.put(cx, cy + 1, PLASTER[2])
        if i % 3 == 0:
            pix.put(cx + 2, cy + 1, PLASTER[1])
    # Hairline crack on one wall.
    if w > 24 and h > 16:
        cx = x + w // 3
        for k in range(8):
            pix.put(cx + (k % 3) - 1, y + 4 + k, PLASTER[1])


def beam(pix: Pix, x: int, y: int, w: int, h: int) -> None:
    if w >= h:
        pix.rect(x, y, w, h, TIMBER[2])
        pix.rect(x, y, w, 1, TIMBER[4])
        pix.rect(x, y + h - 1, w, 1, TIMBER[0])
        for xx in range(x + 3, x + w - 2, 6):
            pix.put(xx, y + h // 2, TIMBER[1])
            pix.put(xx + 1, y + h // 2, TIMBER[0])
    else:
        pix.rect(x, y, w, h, TIMBER[2])
        pix.rect(x, y, 1, h, TIMBER[4])
        pix.rect(x + w - 1, y, 1, h, TIMBER[0])


def tile_span(pix: Pix, y: int, x0: int, x1: int, row: int, ramp: list[tuple[int, int, int]]) -> None:
    """One course of overlapping roof tiles between x0 and x1."""
    if x1 <= x0:
        return
    stagger = 3 if row % 2 else 0
    tile_w = 6
    xx = x0 - stagger
    col = 0
    while xx < x1:
        a = max(xx, x0)
        b = min(xx + tile_w, x1)
        if b - a >= 2:
            tone = 3 if (col + row) % 5 else 2
            if (col + row) % 7 == 0:
                tone = 4
            pix.rect(a, y, b - a, 2, ramp[tone])
            pix.rect(a, y, max(1, b - a - 1), 1, ramp[min(tone + 1, 5)])
            pix.put(b - 1, y, ramp[1])
            pix.put(b - 1, y + 1, ramp[0])
            pix.put(a, y + 2, ramp[0])
            if b - a > 3:
                pix.put(a + 1, y + 2, ramp[1])
        xx += tile_w
        col += 1


def gable(pix: Pix, peak: tuple[int, int], left: tuple[int, int], right: tuple[int, int], ramp: list[tuple[int, int, int]]) -> None:
    """Tile courses that follow a gable. Each tile is its own block."""
    y0 = min(peak[1], left[1], right[1])
    y1 = max(left[1], right[1])
    row = 0
    y = y1 - 3
    while y > y0:
        # Interpolate the gable edges at this y.
        def edge(p_top: tuple[int, int], p_bot: tuple[int, int]) -> int:
            span = p_bot[1] - p_top[1]
            if span == 0:
                return p_bot[0]
            t = (y - p_top[1]) / span
            if t < 0:
                t = 0
            if t > 1:
                t = 1
            return int(p_top[0] + (p_bot[0] - p_top[0]) * t)

        xl = edge(peak, left) + 1
        xr = edge(peak, right) - 1
        if xr > xl:
            tile_span(pix, y, xl, xr, row, ramp)
        y -= 3
        row += 1
    # Ridge cap.
    pix.rect(peak[0] - 1, peak[1], 3, 2, ramp[5])
    pix.put(peak[0], peak[1] + 2, ramp[4])


def window(pix: Pix, x: int, y: int, w: int = 11, h: int = 13, curtains: bool = False) -> None:
    pix.rect(x, y, w, h, TIMBER[1])
    pix.rect(x + 1, y + 1, w - 2, h - 2, AMBER[2])
    # Glass is a few hard clusters, upper-left catchlight.
    pix.rect(x + 2, y + 2, max(1, w // 2 - 2), max(1, h // 2 - 2), AMBER[5])
    pix.put(x + 2, y + 2, AMBER[5])
    pix.put(x + 3, y + 3, EMBER[6])
    pix.rect(x + w // 2, y + 1, 1, h - 2, TIMBER[2])
    pix.rect(x + 1, y + h // 2, w - 2, 1, TIMBER[2])
    # Sill
    pix.rect(x - 1, y + h, w + 2, 2, STONE[3])
    pix.rect(x - 1, y + h + 1, w + 2, 1, STONE[1])
    if curtains:
        pix.rect(x + 1, y + 1, 2, h // 2, ROSE[3])
        pix.rect(x + w - 3, y + 1, 2, h // 2 + 1, ROSE[2])
        pix.put(x + 1, y + 2, ROSE[5])


def door(pix: Pix, x: int, y: int, w: int = 14, h: int = 22, arch: bool = False) -> None:
    pix.rect(x, y, w, h, TIMBER[1])
    pix.rect(x + 2, y + 2, w - 4, h - 2, TIMBER[3])
    # Two planks.
    pix.rect(x + w // 2, y + 2, 1, h - 2, TIMBER[1])
    pix.rect(x + 3, y + 3, 2, h - 6, TIMBER[4])
    # Iron strap and ring handle.
    pix.rect(x + 2, y + 6, w - 4, 2, IRON[2])
    pix.rect(x + 2, y + h - 8, w - 4, 2, IRON[2])
    for sx in (x + 3, x + w - 4):
        pix.put(sx, y + 6, IRON[5])
        pix.put(sx, y + h - 8, IRON[4])
    hx = x + w - 5
    hy = y + h // 2
    pix.put(hx, hy, GOLD[4])
    pix.put(hx + 1, hy, GOLD[2])
    pix.put(hx, hy + 1, GOLD[1])
    if arch:
        # Stone voussoirs over the head.
        pix.rect(x - 2, y - 3, w + 4, 3, STONE[3])
        pix.rect(x, y - 2, w, 2, STONE[4])
        pix.put(x + w // 2, y - 3, STONE[5])
        pix.put(x - 1, y - 1, STONE[1])
        pix.put(x + w, y - 1, STONE[1])


def flame(pix: Pix, x: int, y: int) -> None:
    # y is the base. Flame climbs upward.
    shape = (
        (0, 0, 2),
        (-1, -1, 3),
        (0, -2, 4),
        (1, -3, 5),
        (0, -4, 6),
        (-1, -5, 4),
        (0, -6, 5),
        (1, -7, 3),
        (0, -8, 2),
    )
    for dx, dy, tone in shape:
        pix.put(x + dx, y + dy, EMBER[tone])
        if tone >= 5:
            pix.put(x + dx + 1, y + dy, EMBER[tone - 2])
    pix.put(x, y, EMBER[1])
    pix.put(x - 1, y, EMBER[0])
    pix.put(x + 1, y, EMBER[0])


def anvil(pix: Pix, x: int, y: int) -> None:
    # Horn, flat face, waist, wooden stump. The face is wider than the waist.
    pix.put(x, y + 3, IRON[2])
    pix.put(x + 1, y + 2, IRON[3])
    pix.put(x + 2, y + 2, IRON[4])
    pix.rect(x + 3, y, 14, 6, IRON[3])
    pix.rect(x + 3, y, 13, 1, IRON[5])
    pix.rect(x + 3, y + 5, 14, 1, IRON[1])
    pix.put(x + 6, y + 1, IRON[5])
    pix.put(x + 16, y + 1, IRON[2])
    pix.rect(x + 7, y + 6, 6, 3, IRON[2])
    pix.rect(x + 4, y + 9, 12, 2, IRON[1])
    pix.rect(x + 5, y + 11, 10, 5, TIMBER[2])
    pix.rect(x + 5, y + 11, 1, 5, TIMBER[4])
    pix.rect(x + 14, y + 11, 1, 5, TIMBER[0])


def barrel(pix: Pix, x: int, y: int) -> None:
    for row, inset in ((0, 2), (1, 1), (2, 0), (3, 0), (4, 0), (5, 0), (6, 1), (7, 2)):
        pix.rect(x + inset, y + row * 2, 12 - inset * 2, 2, TIMBER[3 if row % 2 == 0 else 2])
        pix.put(x + inset, y + row * 2, TIMBER[4])
        pix.put(x + 11 - inset, y + row * 2, TIMBER[0])
    pix.rect(x + 1, y + 3, 10, 1, IRON[2])
    pix.rect(x + 1, y + 10, 10, 1, IRON[2])
    pix.put(x + 2, y + 3, IRON[5])
    pix.put(x + 2, y + 10, IRON[4])


def apple(pix: Pix, x: int, y: int, red: bool = True) -> None:
    body = (168, 48, 44) if red else (72, 140, 56)
    hi = (214, 96, 78) if red else (140, 186, 96)
    lo = (110, 28, 32) if red else (36, 86, 36)
    pix.rect(x + 1, y + 1, 3, 3, body)
    pix.put(x, y + 2, body)
    pix.put(x + 4, y + 2, lo)
    pix.put(x + 1, y + 1, hi)
    pix.put(x + 2, y, LEAF[4])
    pix.put(x + 2, y - 1, TIMBER[1])


def loaf(pix: Pix, x: int, y: int) -> None:
    pix.rect(x, y + 2, 8, 4, (168, 112, 58))
    pix.rect(x + 1, y + 1, 6, 2, (206, 154, 86))
    pix.put(x + 1, y + 1, (230, 190, 120))
    for sx in range(x + 2, x + 7, 2):
        pix.put(sx, y + 3, (120, 72, 36))


def banner(pix: Pix, x: int, y: int, h: int, cloth: list[tuple[int, int, int]], mark: str) -> None:
    pix.rect(x, y, 12, 3, TIMBER[1])
    pix.rect(x, y, 12, 1, TIMBER[4])
    for yy in range(3, h):
        taper = 0
        if yy > h - 5:
            taper = yy - (h - 5)
        for xx in range(taper, 12 - taper):
            fold = cloth[4] if xx < 3 else cloth[3] if xx < 8 else cloth[1]
            if (yy // 3) % 2 == 0 and xx % 5 == 0:
                fold = cloth[2]
            pix.put(x + xx, y + yy, fold)
        # Fringe on the swallowtail.
        if yy > h - 4 and taper < 5:
            pix.put(x + 6, y + yy, GOLD[3])
    # Device.
    if mark == "anvil":
        pix.rect(x + 3, y + 8, 6, 2, IRON[4])
        pix.rect(x + 5, y + 10, 2, 3, IRON[2])
    elif mark == "mug":
        pix.rect(x + 4, y + 7, 4, 5, CREAM[5])
        pix.put(x + 8, y + 8, CREAM[4])
        pix.put(x + 8, y + 9, CREAM[3])
    else:
        pix.rect(x + 5, y + 7, 2, 6, GOLD[4])
        pix.rect(x + 3, y + 9, 6, 2, GOLD[3])


def flower_box(pix: Pix, x: int, y: int) -> None:
    pix.rect(x, y, 16, 5, TIMBER[2])
    pix.rect(x, y, 16, 1, TIMBER[4])
    pix.rect(x, y + 4, 16, 1, TIMBER[0])
    blooms = (
        (2, (196, 72, 78)),
        (6, (232, 186, 72)),
        (9, (236, 236, 220)),
        (12, (186, 96, 150)),
    )
    for bx, col in blooms:
        pix.put(x + bx, y - 1, col)
        pix.put(x + bx, y - 2, col)
        pix.put(x + bx - 1, y - 1, LEAF[3])
        pix.put(x + bx + 1, y - 2, LEAF[5])


def chimney(pix: Pix, x: int, y: int, h: int) -> None:
    stone_wall(pix, x, y + 8, 10, h - 8, seed=3)
    pix.rect(x - 1, y + h - 4, 12, 3, STONE[2])
    pix.rect(x - 1, y + h - 4, 12, 1, STONE[5])
    # Soot under the lip.
    pix.put(x + 3, y + h - 5, STONE[0])
    pix.put(x + 4, y + h - 6, (42, 36, 34))
    pix.put(x + 5, y + h - 5, (42, 36, 34))
    # Smoke clusters, painted by the caller after outline so they stay soft.


def smoke(pix: Pix, x: int, y: int) -> None:
    puffs = ((0, 0, 3), (2, -3, 2), (1, -4, 3), (4, -7, 2), (3, -8, 3), (6, -12, 1), (5, -13, 2))
    for dx, dy, n in puffs:
        for k in range(n):
            pix.put(x + dx + (k % 2), y + dy, CLOUD[2 if k == 0 else 3])
            pix.put(x + dx + 1, y + dy + 1, CLOUD[1])


def step(pix: Pix, x: int, y: int, w: int, h: int) -> None:
    stone_wall(pix, x, y, w, h, seed=4)
    # A worn lighter tread on the top course.
    pix.rect(x + 2, y, w - 4, 1, STONE[5])


def awning(pix: Pix, x: int, y: int, w: int, h: int, a: tuple[int, int, int], b: tuple[int, int, int]) -> None:
    """Scalloped cloth with vertical folds. Stripes follow the folds."""
    fold = 6
    cloth_h = h - 5
    pix.rect(x, y, w, 3, TIMBER[2])
    pix.rect(x, y, w, 1, TIMBER[5])
    for yy in range(3, cloth_h):
        for xx in range(w):
            f = xx // fold
            local = xx % fold
            base = a if f % 2 == 0 else b
            if local == 0:
                col = tuple(max(0, c - 28) for c in base)
            elif local <= 2:
                col = tuple(min(255, c + 22) for c in base)
            else:
                col = base
            pix.put(x + xx, y + yy, col)
    # Scallops.
    for xx in range(w):
        local = xx % fold
        drop = 4 if 1 <= local <= 4 else 2 if local in (0, 5) else 1
        base = a if (xx // fold) % 2 == 0 else b
        for d in range(drop):
            shade = tuple(max(0, c - 18 - d * 8) for c in base)
            pix.put(x + xx, y + cloth_h + d, shade)
    # Wooden finial posts are the caller's job.


def crates_and_goods(pix: Pix, x: int, y: int) -> None:
    # Crate.
    pix.rect(x, y, 14, 12, TIMBER[2])
    pix.rect(x, y, 14, 1, TIMBER[4])
    pix.rect(x, y + 11, 14, 1, TIMBER[0])
    pix.rect(x, y, 1, 12, TIMBER[4])
    pix.rect(x + 13, y, 1, 12, TIMBER[0])
    pix.put(x + 3, y + 3, TIMBER[0])
    pix.put(x + 10, y + 8, TIMBER[1])
    # Apples spilling.
    apple(pix, x + 2, y - 6, True)
    apple(pix, x + 7, y - 5, True)
    apple(pix, x + 5, y - 8, False)


def sign_mug(pix: Pix, x: int, y: int) -> None:
    pix.rect(x, y, 1, 8, TIMBER[1])
    pix.rect(x - 1, y, 12, 10, TIMBER[2])
    pix.rect(x - 1, y, 12, 1, TIMBER[4])
    pix.rect(x - 1, y + 9, 12, 1, TIMBER[0])
    pix.rect(x + 2, y + 2, 5, 6, CREAM[4])
    pix.rect(x + 6, y + 3, 2, 3, CREAM[3])
    pix.put(x + 3, y + 3, CREAM[5])


def battlement(pix: Pix, x: int, y: int, w: int, ramp: list[tuple[int, int, int]] | None = None) -> None:
    ramp = ramp or STONE
    merlon = 8
    gap = 5
    xx = x
    while xx < x + w - 2:
        mw = merlon if xx + merlon < x + w else x + w - xx
        stone_wall(pix, xx, y, mw, 8, seed=xx, ramp=ramp)
        pix.rect(xx, y, mw, 1, ramp[5])
        xx += merlon + gap


def torch(pix: Pix, x: int, y: int) -> None:
    pix.rect(x, y, 3, 6, IRON[2])
    pix.put(x, y, IRON[4])
    flame(pix, x + 1, y)


def generate_forge(tier: int) -> Image.Image:
    pix = Pix(120, 156)
    step(pix, 18, 132, 84, 16)
    if tier == 0:
        timber_wall(pix, 28, 78, 64, 56, seed=2)
        beam(pix, 28, 78, 64, 4)
    else:
        plaster_wall(pix, 28, 78, 64, 56, seed=tier)
        beam(pix, 26, 78, 68, 4)
        beam(pix, 26, 130, 68, 4)
        beam(pix, 26, 78, 4, 56)
        beam(pix, 90, 78, 4, 56)
        if tier == 1:
            beam(pix, 56, 82, 3, 48)
    gable(pix, (60, 34), (16, 84), (104, 82), TILE)
    chimney(pix, 86, 16, 58)
    # Forge mouth: brick reveal, coals, flame.
    pix.rect(40, 96, 28, 34, (92, 42, 32))
    stone_wall(pix, 40, 96, 28, 34, seed=6, ramp=[
        (62, 28, 24),
        (96, 44, 34),
        (132, 64, 46),
        (164, 88, 60),
        (196, 120, 84),
        (220, 156, 116),
    ])
    pix.rect(46, 108, 16, 20, (28, 16, 14))
    for cx, cy in ((48, 122), (54, 124), (60, 121), (52, 118)):
        pix.put(cx, cy, EMBER[3])
        pix.put(cx + 1, cy, EMBER[1])
    flame(pix, 54, 116)
    pix.put(50, 112, EMBER[5])
    pix.put(58, 110, EMBER[4])
    # Warm spill on the jamb.
    pix.put(45, 112, (176, 110, 64))
    pix.put(62, 114, (150, 86, 48))
    anvil(pix, 70, 112)
    barrel(pix, 16, 114)
    # Tongs on the wall.
    pix.rect(78, 88, 1, 10, IRON[3])
    pix.put(76, 88, IRON[4])
    pix.put(80, 88, IRON[2])
    pix.put(77, 98, TIMBER[3])
    window(pix, 66, 88, 10, 12, curtains=False)
    flower_box(pix, 18, 126)
    if tier >= 2:
        banner(pix, 34, 48, 26, ROSE, "anvil")
        pix.rect(20, 80, 80, 2, GOLD[3])
        pix.rect(20, 80, 80, 1, GOLD[5])
    pix.outline()
    smoke(pix, 90, 18)
    return pix.image()


def generate_market(tier: int) -> Image.Image:
    pix = Pix(120, 140)
    step(pix, 14, 118, 92, 14)
    # Stall posts.
    beam(pix, 22, 70, 5, 52)
    beam(pix, 92, 74, 5, 48)
    # Counter.
    pix.rect(18, 104, 86, 16, TIMBER[2])
    pix.rect(18, 104, 86, 2, TIMBER[5])
    pix.rect(18, 118, 86, 2, TIMBER[0])
    for gx in range(24, 96, 8):
        pix.put(gx, 112, TIMBER[1])
        pix.put(gx + 1, 114, TIMBER[0])
    stripe_a = (150, 52, 48) if tier else (46, 104, 64)
    stripe_b = (236, 214, 180) if tier else (168, 196, 140)
    awning(pix, 16, 48, 88, 40, stripe_a, stripe_b)
    # Goods.
    apple(pix, 28, 96, True)
    apple(pix, 36, 98, True)
    apple(pix, 44, 96, False)
    loaf(pix, 54, 96)
    loaf(pix, 64, 98)
    # Cloth bolts standing.
    pix.rect(76, 92, 5, 12, WOOL[3])
    pix.rect(76, 92, 5, 2, WOOL[5])
    pix.rect(82, 94, 5, 10, ROSE[3])
    pix.rect(82, 94, 1, 10, ROSE[5])
    # Scale.
    pix.rect(48, 78, 1, 16, IRON[2])
    pix.rect(44, 80, 9, 1, IRON[4])
    pix.put(44, 82, IRON[3])
    pix.put(52, 82, IRON[3])
    pix.rect(42, 86, 4, 2, TIMBER[3])
    pix.rect(51, 88, 4, 2, TIMBER[2])
    crates_and_goods(pix, 96, 104)
    # Sack.
    pix.rect(24, 108, 8, 8, CREAM[2])
    pix.rect(25, 108, 6, 2, CREAM[4])
    pix.put(27, 107, TIMBER[1])
    if tier >= 1:
        pix.rect(36, 64, 3, 12, GOLD[3])
        pix.put(37, 66, GOLD[5])
    if tier >= 2:
        banner(pix, 98, 28, 22, MOSS_CLOTH, "sword")
        # Bunting under the awning bar.
        for bx in range(22, 96, 8):
            pix.put(bx, 52, ROSE[4] if (bx // 8) % 2 == 0 else GOLD[4])
            pix.put(bx + 1, 53, ROSE[2] if (bx // 8) % 2 == 0 else GOLD[2])
    pix.outline()
    return pix.image()


def generate_inn(tier: int) -> Image.Image:
    pix = Pix(120, 160)
    step(pix, 36, 138, 48, 14)
    # Ground floor stone, upper floor jetties out.
    stone_wall(pix, 34, 100, 52, 42, seed=2)
    if tier == 0:
        timber_wall(pix, 22, 64, 78, 40, seed=3)
    else:
        plaster_wall(pix, 22, 64, 78, 40, seed=tier)
        beam(pix, 22, 64, 78, 4)
        beam(pix, 22, 100, 78, 4)
        beam(pix, 22, 64, 4, 40)
        beam(pix, 96, 64, 4, 40)
        beam(pix, 58, 68, 3, 32)
    # Jetty shadow on the stone.
    pix.rect(34, 100, 52, 2, STONE[0])
    gable(pix, (60, 22), (12, 70), (110, 66), TILE)
    chimney(pix, 88, 8, 52)
    door(pix, 52, 112, 16, 28, arch=True)
    window(pix, 30, 74, 12, 14, curtains=True)
    window(pix, 78, 74, 12, 14, curtains=True)
    window(pix, 40, 110, 9, 10, curtains=False)
    flower_box(pix, 26, 92)
    flower_box(pix, 74, 92)
    sign_mug(pix, 18, 108)
    # Bench.
    pix.rect(78, 132, 18, 3, TIMBER[3])
    pix.rect(78, 132, 18, 1, TIMBER[5])
    pix.rect(80, 135, 2, 6, TIMBER[1])
    pix.rect(94, 135, 2, 6, TIMBER[1])
    # Lantern by the door.
    pix.rect(70, 116, 4, 5, IRON[2])
    pix.put(71, 117, AMBER[5])
    pix.put(72, 118, EMBER[5])
    if tier >= 2:
        banner(pix, 48, 36, 24, ROSE, "mug")
        pix.rect(16, 66, 90, 2, GOLD[3])
    pix.outline()
    smoke(pix, 92, 10)
    return pix.image()


def generate_guild(tier: int) -> Image.Image:
    pix = Pix(156, 176)
    step(pix, 48, 150, 60, 16)
    # Side turrets and a lower hall, so it is not another house.
    stone_wall(pix, 18, 70, 28, 90, seed=1)
    stone_wall(pix, 110, 78, 28, 82, seed=5)
    wall_ramp = STONE
    if tier == 0:
        timber_wall(pix, 42, 96, 72, 58, seed=4)
        beam(pix, 42, 96, 72, 4)
    else:
        stone_wall(pix, 42, 88, 72, 66, seed=2, ramp=wall_ramp)
    # Merlons sit on the turret tops. A gap here reads as floating blocks.
    battlement(pix, 16, 62, 32)
    battlement(pix, 108, 70, 32)
    if tier == 0:
        gable(pix, (78, 40), (40, 100), (116, 96), TILE)
    else:
        # Slate roof between the turrets.
        gable(pix, (78, 36), (40, 92), (116, 90), SLATE)
        pix.rect(40, 88, 76, 3, STONE[2])
    door(pix, 68, 124, 18, 30, arch=True)
    # Arrow slits on the turrets.
    for sx, sy in ((28, 88), (28, 112), (122, 96), (122, 120)):
        pix.rect(sx, sy, 3, 8, (28, 24, 22))
        pix.put(sx + 1, sy, STONE[5])
    window(pix, 52, 108, 10, 12, curtains=False)
    window(pix, 94, 108, 10, 12, curtains=False)
    # Shield over the arch.
    pix.rect(72, 112, 10, 12, WOOL[2])
    pix.rect(73, 113, 8, 3, WOOL[4])
    pix.rect(76, 116, 2, 6, GOLD[4])
    pix.rect(74, 118, 6, 2, GOLD[3])
    pix.put(74, 122, WOOL[0])
    pix.put(79, 122, WOOL[0])
    torch(pix, 48, 132)
    torch(pix, 100, 132)
    # Moss at the wet base of the left turret.
    for mx, my in ((20, 150), (22, 152), (24, 149), (19, 146)):
        pix.put(mx, my, LEAF[2])
        pix.put(mx + 1, my, LEAF[3])
    if tier >= 2:
        banner(pix, 22, 78, 32, ROSE, "sword")
        banner(pix, 118, 86, 28, WOOL, "sword")
        pix.rect(44, 92, 68, 2, GOLD[3])
    pix.outline()
    return pix.image()


def chest(pix: Pix, x: int, y: int, open_lid: bool) -> None:
    # Body planks.
    pix.rect(x, y + 16, 52, 28, TIMBER[2])
    for row in range(4):
        yy = y + 16 + row * 7
        pix.rect(x, yy, 52, 6, TIMBER[3 if row % 2 == 0 else 2])
        pix.rect(x, yy, 52, 1, TIMBER[4])
        pix.rect(x, yy + 5, 52, 1, TIMBER[0])
        pix.put(x + 8, yy + 2, TIMBER[1])
        pix.put(x + 30, yy + 3, TIMBER[0])
    # Iron bands.
    for bx in (x + 6, x + 24, x + 40):
        pix.rect(bx, y + 16, 4, 28, IRON[2])
        pix.rect(bx, y + 16, 1, 28, IRON[4])
        for ry in (y + 20, y + 30, y + 40):
            pix.put(bx + 1, ry, IRON[5])
            pix.put(bx + 2, ry + 1, IRON[1])
    # Lock plate.
    pix.rect(x + 22, y + 26, 10, 12, IRON[3])
    pix.rect(x + 22, y + 26, 10, 1, IRON[5])
    pix.rect(x + 25, y + 30, 4, 5, (20, 16, 14))
    pix.put(x + 26, y + 31, GOLD[4])
    if open_lid:
        # Raised lid, seen from the front, interior gold.
        pix.rect(x + 2, y, 48, 8, TIMBER[3])
        pix.rect(x + 2, y, 48, 2, TIMBER[5])
        pix.rect(x + 4, y + 8, 44, 8, (36, 22, 16))
        # Coins.
        for i, cx in enumerate(range(x + 10, x + 40, 6)):
            pix.rect(cx, y + 12, 5, 3, GOLD[3 + (i % 2)])
            pix.put(cx + 1, y + 12, GOLD[5])
        pix.put(x + 28, y + 11, (196, 48, 56))
        pix.put(x + 29, y + 11, (240, 120, 120))
        pix.put(x + 16, y + 10, (64, 140, 120))
    else:
        # Domed lid as plank courses with a curve.
        for row, inset in ((0, 10), (1, 6), (2, 3), (3, 1), (4, 0)):
            pix.rect(x + inset, y + row * 4, 52 - inset * 2, 4, TIMBER[3 if row % 2 else 4])
            pix.rect(x + inset, y + row * 4, 52 - inset * 2, 1, TIMBER[5])
            pix.rect(x + inset, y + row * 4 + 3, 52 - inset * 2, 1, TIMBER[1])
        for bx in (x + 6, x + 24, x + 40):
            pix.rect(bx, y + 4, 4, 14, IRON[2])
            pix.put(bx, y + 6, IRON[5])
            pix.put(bx + 1, y + 12, IRON[4])
        pix.rect(x + 22, y + 8, 8, 8, IRON[3])
        pix.put(x + 25, y + 11, GOLD[5])


def generate_vault(opened: bool) -> Image.Image:
    pix = Pix(88, 104)
    stone_wall(pix, 10, 78, 68, 18, seed=2)
    pix.rect(8, 76, 72, 3, STONE[4])
    pix.rect(8, 78, 72, 1, STONE[1])
    chest(pix, 18, 28, opened)
    # Corner boots of the plinth.
    pix.rect(6, 92, 6, 6, STONE[1])
    pix.rect(76, 92, 6, 6, STONE[1])
    pix.outline()
    return pix.image()


def generate_well() -> Image.Image:
    pix = Pix(56, 68)
    # Stone drum.
    for row, inset in ((0, 6), (1, 3), (2, 1), (3, 0), (4, 0), (5, 1)):
        stone_y = 28 + row * 5
        stone_wall(pix, 8 + inset, stone_y, 40 - inset * 2, 5, seed=row + 1)
    # Water.
    pix.rect(16, 34, 24, 8, (36, 78, 96))
    pix.rect(18, 35, 10, 2, (150, 196, 204))
    pix.put(20, 36, (220, 240, 236))
    pix.put(30, 38, (70, 120, 130))
    # Posts and a little roof.
    beam(pix, 12, 16, 4, 28)
    beam(pix, 40, 16, 4, 28)
    gable(pix, (28, 4), (8, 22), (48, 22), TILE)
    # Rope and bucket.
    pix.rect(26, 18, 1, 14, TIMBER[1])
    pix.rect(22, 32, 8, 6, TIMBER[3])
    pix.rect(22, 32, 8, 1, IRON[4])
    pix.rect(22, 36, 8, 1, IRON[2])
    # Moss.
    pix.put(10, 48, LEAF[3])
    pix.put(11, 50, LEAF[2])
    pix.put(44, 52, LEAF[4])
    pix.outline()
    return pix.image()


def canopy_cluster(pix: Pix, cx: int, cy: int, rx: int, ry: int, ramp: list[tuple[int, int, int]], bias: int = 3) -> None:
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            nx = (x - cx) / max(1, rx)
            ny = (y - cy) / max(1, ry)
            wobble = 0.18 * math.sin(x * 1.3 + y * 0.7) + 0.08 * math.sin(x * 0.4 - y)
            if nx * nx + ny * ny > 1.0 + wobble:
                continue
            light = bias / 5 - 0.55 * nx - 0.35 * ny
            if light > 0.85:
                tone = 5
            elif light > 0.55:
                tone = 4
            elif light > 0.3:
                tone = 3
            elif light > 0.05:
                tone = 2
            else:
                tone = 1
            # Keep a hard step. Overlapping clusters replace, they do not blend.
            pix.put(x, y, ramp[clamp_i(tone, len(ramp))])


def trunk(pix: Pix, x: int, y: int, w: int, h: int) -> None:
    pix.rect(x, y, w, h, TIMBER[2])
    pix.rect(x, y, 1, h, TIMBER[4])
    pix.rect(x + w - 1, y, 1, h, TIMBER[0])
    for yy in range(y + 2, y + h - 2, 4):
        pix.put(x + 1, yy, TIMBER[1])
        pix.put(x + w // 2, yy + 1, TIMBER[0])
        pix.put(x + w // 2 + 1, yy + 2, TIMBER[1])
    # Knot.
    kx = x + w // 2
    ky = y + h // 2
    pix.put(kx, ky, TIMBER[0])
    pix.put(kx + 1, ky, TIMBER[4])
    pix.put(kx, ky + 1, TIMBER[1])
    # Roots.
    pix.rect(x - 3, y + h - 2, 3, 2, TIMBER[1])
    pix.rect(x + w, y + h - 3, 4, 2, TIMBER[2])
    pix.put(x - 3, y + h - 1, TIMBER[0])
    pix.put(x + w + 3, y + h - 2, TIMBER[0])


def generate_tree_round() -> Image.Image:
    pix = Pix(80, 100)
    trunk(pix, 36, 62, 8, 30)
    # Back masses first, then a lit front mass. Irregular, not one disc.
    specs = (
        (40, 40, 26, 20, 2),
        (24, 46, 16, 14, 2),
        (58, 44, 16, 13, 3),
        (32, 28, 14, 12, 4),
        (50, 26, 15, 12, 4),
        (40, 48, 18, 12, 3),
        (18, 36, 10, 9, 3),
        (64, 38, 9, 8, 2),
    )
    for cx, cy, rx, ry, bias in specs:
        canopy_cluster(pix, cx, cy, rx, ry, LEAF, bias)
    # Break the ellipse bands into leaf clumps, and sink a few pockets.
    chips = (
        (22, 34, 5), (26, 32, 6), (34, 22, 5), (46, 20, 6),
        (58, 28, 5), (62, 40, 4), (18, 48, 3), (50, 50, 2),
        (40, 36, 4), (30, 44, 2), (54, 36, 3), (36, 30, 6),
    )
    for hx, hy, tone in chips:
        pix.put(hx, hy, LEAF[tone])
        pix.put(hx + 1, hy, LEAF[min(tone + 1, 6)])
        pix.put(hx, hy + 1, LEAF[max(tone - 1, 1)])
    for hx, hy in ((30, 38), (48, 44), (38, 26), (56, 32), (24, 28)):
        pix.put(hx, hy, LEAF[0])
        pix.put(hx + 1, hy, LEAF[1])
        pix.put(hx, hy + 1, LEAF[0])
        pix.put(hx + 1, hy + 1, LEAF[1])
    # A few leaves that break the silhouette.
    for lx, ly, tone in (
        (8, 40, 4),
        (6, 34, 3),
        (72, 36, 5),
        (74, 44, 3),
        (40, 8, 5),
        (28, 12, 4),
        (54, 10, 4),
        (16, 22, 5),
    ):
        pix.put(lx, ly, LEAF[tone])
    pix.outline()
    return pix.image()


def generate_tree_tall() -> Image.Image:
    pix = Pix(48, 112)
    trunk(pix, 21, 78, 6, 26)
    # Layered conifer masses with broken edges.
    layers = (
        (24, 86, 16, 8, 2),
        (24, 74, 14, 8, 3),
        (24, 62, 12, 8, 3),
        (24, 50, 10, 7, 4),
        (24, 38, 8, 7, 4),
        (24, 26, 6, 6, 5),
        (24, 16, 3, 5, 5),
    )
    for cx, cy, rx, ry, bias in layers:
        canopy_cluster(pix, cx, cy, rx, ry, LEAF, bias)
    for lx, ly in ((8, 70), (40, 64), (10, 48), (38, 40), (24, 8), (16, 20)):
        pix.put(lx, ly, LEAF[5])
    pix.outline()
    return pix.image()


def generate_flowers() -> Image.Image:
    pix = Pix(32, 20)
    stems = (4, 11, 18, 25)
    colors = ((196, 64, 72), (230, 186, 70), (236, 228, 210), (176, 86, 150))
    for i, sx in enumerate(stems):
        pix.rect(sx, 8, 1, 8, LEAF[2])
        pix.put(sx - 1, 12, LEAF[4])
        pix.put(sx + 1, 14, LEAF[3])
        col = colors[i]
        pix.put(sx, 6, col)
        pix.put(sx - 1, 7, col)
        pix.put(sx + 1, 7, col)
        pix.put(sx, 8, (255, 230, 140) if i != 2 else GOLD[5])
        pix.put(sx, 5, col)
    pix.outline()
    return pix.image()


def generate_ground() -> Image.Image:
    pix = Pix(48, 48)
    pix.rect(0, 0, 48, 48, GRASS[2])
    # Low-contrast irregular shade. One step off the base, so the repeat
    # does not turn into a field of bubbles.
    shade = (
        (3, 5), (4, 5), (5, 5), (4, 6), (5, 6), (6, 6), (5, 7),
        (18, 12), (19, 12), (20, 12), (18, 13), (19, 13), (17, 13), (19, 14),
        (33, 7), (34, 7), (34, 8), (35, 8), (35, 9),
        (8, 27), (9, 27), (10, 27), (9, 28), (10, 28), (11, 28), (10, 29),
        (26, 34), (27, 34), (28, 34), (27, 35), (26, 35),
        (40, 22), (41, 22), (41, 23), (42, 23),
        (14, 40), (15, 40), (15, 41),
    )
    lit = (
        (12, 18), (13, 18), (13, 19), (14, 19),
        (28, 20), (29, 20), (30, 20), (29, 21),
        (6, 16), (7, 16), (7, 17),
        (36, 38), (37, 38), (37, 39), (38, 39),
        (22, 8), (23, 8), (23, 9),
    )
    for x, y in shade:
        pix.put(x, y, GRASS[1])
    for x, y in lit:
        pix.put(x, y, GRASS[3])
    tufts = (
        (6, 14, 5),
        (14, 8, 4),
        (24, 16, 6),
        (38, 12, 4),
        (10, 28, 5),
        (28, 32, 4),
        (40, 36, 5),
        (18, 40, 3),
        (44, 22, 4),
        (8, 44, 3),
    )
    for cx, cy, h in tufts:
        for i in range(h):
            pix.put(cx, cy - i, GRASS[4 if i < 2 else 5])
            if i % 2 == 0:
                pix.put(cx + 1, cy - i, GRASS[3])
        pix.put(cx - 1, cy, GRASS[1])
    # Daisy and a pebble. Kept off the tile edge so the repeat stays quiet.
    pix.put(22, 26, (240, 236, 220))
    pix.put(23, 25, (236, 200, 90))
    pix.put(21, 26, (236, 200, 90))
    pix.put(22, 27, LEAF[3])
    pix.put(22, 24, LEAF[4])
    pix.rect(33, 18, 3, 2, PATH_STONE[3])
    pix.put(34, 18, PATH_STONE[5])
    return pix.image()


def generate_path() -> Image.Image:
    """A wrapping cobble course. The widget repeats it; it is not stretched."""
    pix = Pix(64, 28)
    # Soil bed.
    pix.rect(0, 0, 64, 28, (96, 72, 46))
    stones = (
        (1, 2, 10, 8),
        (12, 1, 8, 9),
        (21, 3, 12, 7),
        (34, 2, 9, 8),
        (44, 1, 8, 9),
        (53, 3, 10, 7),
        (2, 12, 9, 8),
        (12, 13, 11, 7),
        (24, 12, 8, 9),
        (33, 14, 10, 7),
        (44, 12, 9, 8),
        (54, 13, 8, 8),
        (0, 22, 14, 6),
        (16, 22, 12, 6),
        (30, 21, 10, 7),
        (42, 22, 12, 6),
        (56, 21, 8, 7),
    )
    for i, (x, y, w, h) in enumerate(stones):
        tone = 2 + (i % 3)
        pix.rect(x, y, w, h, PATH_STONE[tone])
        pix.rect(x, y, w - 1, 1, PATH_STONE[min(tone + 1, 5)])
        pix.rect(x, y + h - 1, w, 1, PATH_STONE[0])
        pix.put(x + w - 1, y + 1, PATH_STONE[1])
        if i % 4 == 0:
            pix.put(x + 2, y + 2, PATH_STONE[5])
        if i % 5 == 0:
            pix.put(x + w // 2, y + h // 2, PATH_STONE[1])
    # Grass in a crack, and a loose chip.
    pix.put(18, 11, GRASS[3])
    pix.put(19, 11, GRASS[4])
    pix.put(40, 20, PATH_STONE[4])
    pix.put(41, 20, PATH_STONE[2])
    return pix.image()


def generate_backdrop() -> Image.Image:
    pix = Pix(360, 200)
    # Banded sky, warm toward the horizon. Bands are several pixels, not a ramp per row.
    bands = (
        (0, 36, SKY[0]),
        (36, 78, SKY[1]),
        (78, 120, SKY[2]),
        (120, 150, SKY[3]),
        (150, 168, SKY[4]),
    )
    for y0, y1, col in bands:
        pix.rect(0, y0, 360, y1 - y0, col)
    # Sun with a hard core and a few ray pixels.
    for y in range(16, 40):
        for x in range(24, 48):
            if (x - 36) ** 2 + (y - 28) ** 2 <= 100:
                pix.put(x, y, (255, 206, 96))
            if (x - 36) ** 2 + (y - 28) ** 2 <= 36:
                pix.put(x, y, (255, 236, 180))
    for rx, ry in ((18, 28), (54, 28), (36, 10), (36, 46), (22, 16), (50, 40)):
        pix.put(rx, ry, (255, 220, 140))
    # Clouds as lumpy clusters with shaded undersides.
    # Lumpy clouds: stacked runs, flat shaded bottoms, not one oval.
    clouds = (
        (78, 22, (10, 18, 26, 22, 14)),
        (160, 14, (8, 16, 20, 12)),
        (230, 28, (12, 22, 30, 24, 16, 8)),
        (306, 16, (8, 14, 18, 10)),
    )
    for cx, cy, runs in clouds:
        for i, rw in enumerate(runs):
            y = cy + i * 2
            tone = CLOUD[3] if i < 2 else CLOUD[2] if i < len(runs) - 1 else CLOUD[1]
            pix.rect(cx, y, rw, 2, tone)
            pix.put(cx, y, CLOUD[2])
            pix.put(cx + rw - 1, y + 1, CLOUD[0])
    # Distant ridge with tree bumps.
    for x in range(360):
        ridge = 150 + int(6 * math.sin(x * 0.05) + 3 * math.sin(x * 0.13))
        if 150 < x < 230:
            ridge -= 8
        for y in range(ridge, 176):
            pix.put(x, y, LEAF[4] if y < ridge + 2 else LEAF[2])
    for tx in (30, 70, 120, 190, 250, 300, 340):
        pix.rect(tx, 146, 2, 10, TIMBER[1])
        canopy_cluster(pix, tx + 1, 142, 6, 5, LEAF, bias=3)
    # A far roof, so the ridge is a place.
    pix.rect(200, 140, 10, 6, STONE[3])
    gable(pix, (205, 132), (198, 142), (214, 142), TILE)
    for bx, by in ((120, 70), (210, 58), (280, 80)):
        pix.put(bx, by, STONE[1])
        pix.put(bx + 2, by - 1, STONE[1])
        pix.put(bx - 2, by - 1, STONE[1])
        pix.put(bx + 3, by, STONE[1])
        pix.put(bx - 3, by, STONE[1])
    pix.rect(0, 176, 360, 24, GRASS[2])
    return pix.image()


def _head(pix: Pix, cx: int, top: int, hair: list[tuple[int, int, int]], style: str) -> None:
    # Cel-shaded skull.
    for y in range(top, top + 12):
        for x in range(cx - 6, cx + 7):
            nx = (x - cx) / 6
            ny = (y - (top + 5)) / 6
            if nx * nx + ny * ny > 1.05:
                continue
            light = 0.2 - 0.5 * nx - 0.35 * ny
            tone = 4 if light > 0.35 else 3 if light > 0 else 2 if light > -0.35 else 1
            pix.put(x, y, SKIN[tone])
    # Ears.
    pix.put(cx - 7, top + 6, SKIN[2])
    pix.put(cx + 7, top + 6, SKIN[1])
    # Eyes large enough to read beside a 42px hero.
    for ex in (cx - 3, cx + 2):
        pix.put(ex, top + 6, (24, 14, 12))
        pix.put(ex + 1, top + 6, (24, 14, 12))
        pix.put(ex, top + 7, (24, 14, 12))
        pix.put(ex + 1, top + 5, (255, 248, 236))
    pix.put(cx - 1, top + 9, (168, 92, 82))
    pix.put(cx, top + 9, (120, 60, 54))
    # Hair.
    if style == "cap":
        pix.rect(cx - 7, top - 1, 15, 4, hair[2])
        pix.rect(cx - 8, top + 1, 3, 3, hair[1])
        pix.rect(cx + 6, top + 1, 3, 3, hair[1])
        pix.rect(cx - 6, top - 1, 8, 1, hair[4])
        pix.put(cx - 8, top + 3, hair[3])
    elif style == "bun":
        for y in range(top, top + 5):
            pix.rect(cx - 6, y, 13, 1, hair[2 if y % 2 else 3])
        pix.rect(cx - 7, top + 2, 2, 6, hair[2])
        pix.rect(cx + 6, top + 2, 2, 5, hair[1])
        pix.rect(cx + 4, top - 3, 5, 5, hair[3])
        pix.put(cx + 5, top - 3, hair[4])
        pix.put(cx + 7, top - 1, hair[1])
    else:
        for y in range(top, top + 4):
            pix.rect(cx - 6, y, 13, 1, hair[2 if y != top else 3])
        pix.rect(cx - 7, top + 2, 2, 4, hair[1])
        pix.rect(cx + 6, top + 3, 2, 3, hair[1])
        pix.put(cx - 2, top, hair[4])
        pix.put(cx - 5, top + 1, hair[4])


def _boot(pix: Pix, x: int, y: int, w: int = 4) -> None:
    pix.rect(x, y, w, 3, (42, 30, 24))
    pix.rect(x, y + 2, w + 1, 2, (28, 20, 16))
    pix.put(x, y, (86, 64, 48))


def _person(pix: Pix, ox: int, oy: int, frame: int, kind: int) -> None:
    """Chibi townsfolk. Frame 0 is idle. Frames 1–4 are a walk cycle facing right."""
    if kind == 0:
        cloth, hair, style = MOSS_CLOTH, HAIR, "short"
    elif kind == 1:
        cloth, hair, style = WOOL, HAIR, "cap"
    else:
        cloth, hair, style = ROSE, [
            (72, 36, 24),
            (110, 58, 36),
            (150, 84, 52),
            (186, 116, 72),
            (214, 156, 110),
        ], "bun"

    bob = -1 if frame in (2, 4) else 0
    top = oy + 6 + bob
    cx = ox + 18

    def torso(y0: int, y1: int, wide: int = 0) -> None:
        for y in range(y0, y1):
            inset = 0 if y < y0 + 3 else wide
            for x in range(cx - 6 - inset, cx + 7 + inset):
                local = x - (cx - 6)
                if local < 2:
                    col = cloth[1]
                elif local < 5:
                    col = cloth[4]
                elif local > 10:
                    col = cloth[1]
                else:
                    col = cloth[3]
                pix.put(x, y, col)
        # Belt.
        pix.rect(cx - 6, y0 + 6, 13, 2, TIMBER[1])
        pix.put(cx + 2, y0 + 6, GOLD[4])
        pix.put(cx + 3, y0 + 7, GOLD[2])

    _head(pix, cx, top, hair, style)
    torso(top + 11, top + 22, wide=1 if kind == 0 else 0)

    if kind == 0:
        # Leather apron over the tunic.
        pix.rect(cx - 4, top + 13, 9, 12, TIMBER[2])
        pix.rect(cx - 4, top + 13, 9, 1, TIMBER[4])
        pix.rect(cx - 1, top + 12, 2, 3, TIMBER[3])
        pix.put(cx - 2, top + 18, TIMBER[1])
        pix.put(cx + 2, top + 20, TIMBER[0])
    elif kind == 1:
        # Satchel on the left hip.
        pix.rect(cx - 10, top + 16, 5, 7, TIMBER[2])
        pix.rect(cx - 10, top + 16, 5, 1, TIMBER[4])
        pix.put(cx - 8, top + 15, TIMBER[1])
        pix.rect(cx - 9, top + 12, 1, 5, TIMBER[1])
    else:
        # Shawl.
        pix.rect(cx - 7, top + 11, 15, 3, CREAM[3])
        pix.rect(cx - 7, top + 11, 15, 1, CREAM[5])
        pix.put(cx - 6, top + 14, CREAM[2])
        pix.put(cx + 6, top + 14, CREAM[1])

    # Arms. Opposite the leading leg.
    swing = (0, -2, -1, 2, 1)[frame]
    arm_y0 = top + 13
    # Near arm (right, screen-right) and far arm.
    for side, shift in ((-1, -swing), (1, swing)):
        ax = cx + side * 7
        pix.rect(ax, arm_y0, 3, 6, cloth[2] if side < 0 else cloth[4])
        hand_y = arm_y0 + 6 + (1 if shift > 0 else 0)
        pix.put(ax + 1, hand_y, SKIN[4])
        pix.put(ax, hand_y, SKIN[2])
        pix.put(ax + 1, hand_y + 1, SKIN[3])
        if shift:
            pix.put(ax + (1 if side > 0 else 0), hand_y - 1, cloth[3])

    if kind == 0:
        # Hammer held in the right hand: short haft, wide iron head.
        hx = cx + 8
        hy = top + 20 + (0 if swing <= 0 else 1)
        pix.rect(hx + 1, hy, 2, 6, TIMBER[2])
        pix.put(hx + 1, hy + 5, TIMBER[4])
        pix.rect(hx - 1, hy - 1, 6, 3, IRON[3])
        pix.rect(hx - 1, hy - 1, 6, 1, IRON[5])
        pix.rect(hx - 1, hy + 1, 6, 1, IRON[1])

    # Legs or skirt. Feet stay under the hips so a stride does not detach them.
    if kind == 2:
        sway = (0, -2, -1, 2, 1)[frame]
        hem = top + 34
        for y in range(top + 21, hem):
            flare = 1 if y > top + 28 else 0
            for x in range(cx - 7 - flare + sway, cx + 8 + flare + sway):
                col = ROSE[2] if x < cx else ROSE[3]
                if y > hem - 3:
                    col = ROSE[1]
                pix.put(x, y, col)
        pix.put(cx - 6 + sway, hem, (42, 30, 24))
        pix.put(cx + 4 + sway, hem, (42, 30, 24))
        pix.put(cx - 5 + sway, hem + 1, (28, 20, 16))
        pix.put(cx + 5 + sway, hem + 1, (28, 20, 16))
        # Basket on the left.
        bx = cx - 12
        by = top + 22
        pix.rect(bx, by, 6, 5, TIMBER[3])
        pix.rect(bx, by, 6, 1, TIMBER[5])
        apple(pix, bx + 1, by - 3, True)
    else:
        # (dx from cx, hip drop, foot reach). Both legs start in the torso.
        cycles = {
            0: ((-4, 0, 12), (1, 0, 12)),
            1: ((-5, 0, 13), (2, 1, 10)),
            2: ((-3, 0, 11), (1, 0, 11)),
            3: ((-2, 1, 10), (3, 0, 13)),
            4: ((-2, 0, 11), (1, 0, 11)),
        }
        trouser = TIMBER[1] if kind == 0 else cloth[1]
        trouser_hi = TIMBER[3] if kind == 0 else cloth[3]
        hip = top + 18
        for dx, drop, reach in cycles[frame]:
            x = cx + dx
            y0 = hip + drop
            pix.rect(x, y0, 3, reach, trouser)
            pix.rect(x, y0, 1, reach, trouser_hi)
            _boot(pix, x, y0 + reach - 2, 3)

    if kind == 1 and frame == 0:
        # Idle weight: the cap brim already separates him.
        pass


def generate_folk() -> Image.Image:
    pix = Pix(FOLK_CELL_W * FOLK_FRAMES, FOLK_CELL_H * FOLK_PEOPLE)
    for person in range(FOLK_PEOPLE):
        for frame in range(FOLK_FRAMES):
            _person(
                pix,
                frame * FOLK_CELL_W,
                person * FOLK_CELL_H,
                frame,
                person,
            )
    pix.outline()
    return pix.image()


def generate_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (680, 640), (186, 206, 196, 255))
    kinds = (
        ("FORGE", generate_forge),
        ("MARKET", generate_market),
        ("INN", generate_inn),
        ("GUILD", generate_guild),
    )
    for col, (_name, fn) in enumerate(kinds):
        for tier in range(3):
            sprite = fn(tier)
            sheet.paste(sprite, (12 + col * 166, 16 + tier * 188), sprite)
    sheet.paste(generate_vault(False), (12, 560), generate_vault(False))
    sheet.paste(generate_well(), (110, 560), generate_well())
    return sheet


README = """# Town assets

Owned Idle Party pixel art for the out-of-dungeon town.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-placed pixel materials (stone courses, tile rows, cloth folds, chibi townsfolk). No foreign packs. |
| External packs | None |
| License | Same as the rest of `assets/custom/` — original game art |

Three painted facade tiers (timber / plaster or ashlar / banners). AL10
pennants and AL20 lanterns are Flutter overlays. Townsfolk frames share
one sheet. `TownFolkSheet` in Dart uses the same 40×48 cells.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same warm ink as the heroes |
| Light | Upper-left, in clusters on each stone, tile, and fold |
| Ground | Grass clumps and a repeating cobble, not a flat wash |
| Roofs | Individual tiles. Guild slate, houses terracotta, market a folded awning |
| Windows | Amber glass, wood mullions |
| People | Three chibi figures at hero scale, idle + 4 walk frames |
| Scale | `FilterQuality.none`. Folk draw at native size and only shrink to fit a short yard |

## Files

| File | Use |
|------|-----|
| backdrop.png | Banded sky, clouds, ridge, distant roof |
| ground.png | Repeating grass tile |
| path.png | Repeating cobble tile |
| tree_round.png / tree_tall.png | Clumped canopies |
| flowers.png | Flower cluster |
| folk.png | 3 people × 5 frames, 40×48 cells |
| well.png | Stone well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Ironbound chest on a plinth |
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

    by_name = {name: img for name, img in assets}

    def paste(dst: Image.Image, img: Image.Image, xy: tuple[int, int]) -> None:
        dst.paste(img, xy, img)

    preview = by_name["backdrop.png"].resize((360, 520), Image.Resampling.NEAREST)
    grass = by_name["ground.png"]
    for y in range(168, 520, grass.height):
        for x in range(0, 360, grass.width):
            preview.paste(grass, (x, y))
    path = by_name["path.png"]
    for x in range(0, 360, path.width):
        preview.paste(path, (x, 300))
        preview.paste(path, (x, 430))
    paste(preview, by_name["tree_round.png"], (0, 200))
    paste(preview, by_name["tree_tall.png"], (312, 188))
    paste(preview, by_name["guild_t1.png"], (8, 210))
    paste(preview, by_name["vault_shut.png"], (262, 250))
    paste(preview, by_name["well.png"], (156, 292))
    paste(preview, by_name["forge_t1.png"], (4, 360))
    paste(preview, by_name["market_t1.png"], (120, 376))
    paste(preview, by_name["inn_t1.png"], (236, 356))
    folk = by_name["folk.png"]
    for person, fx in ((0, 40), (1, 250), (2, 150)):
        cell = folk.crop(
            (
                0,
                person * FOLK_CELL_H,
                FOLK_CELL_W,
                person * FOLK_CELL_H + FOLK_CELL_H,
            )
        )
        paste(preview, cell, (fx, 330))
    assets.append(("preview_a56.png", preview))

    for name, img in assets:
        path_out = ASSETS_DIR / name
        img.save(path_out)
        print(f"Wrote {path_out} {img.size}")
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
