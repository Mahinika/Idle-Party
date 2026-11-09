"""Ground and townsfolk for the town square.

Buildings stay in generate_town_art.py. This file paints the lawn and the
villagers. Folk cells are 96×112, authored on a 48×56 grid and doubled so
a nearest-neighbor draw at 48×56 keeps a solid 1px outline, a face, and
the clothes. Owned pixels only. Deterministic: no RNG.
"""
from __future__ import annotations

import math

from PIL import Image

INK = (32, 22, 18, 255)

CELL_W = 96
CELL_H = 112
FRAMES = 5
PEOPLE = 3
LOGICAL_W = CELL_W // 2
LOGICAL_H = CELL_H // 2

PLANT_W = 64
PLANT_H = 52

# Spring lawn. Dark to light. Upper-left is the light.
GRASS = [
    (22, 78, 34),
    (34, 112, 40),
    (46, 142, 46),
    (62, 168, 54),
    (86, 186, 64),
    (118, 204, 78),
    (158, 214, 96),
    (198, 220, 118),
]
CLOVER = [
    (28, 96, 62),
    (42, 128, 78),
    (64, 158, 96),
    (96, 184, 120),
]
SUN = [
    (176, 196, 64),
    (198, 210, 78),
    (220, 214, 96),
    (236, 224, 120),
]
DIRT = [
    (96, 62, 36),
    (128, 84, 48),
    (162, 112, 64),
    (196, 146, 90),
    (224, 182, 124),
]
STONE = [
    (78, 68, 56),
    (112, 98, 82),
    (148, 132, 110),
    (182, 166, 142),
    (214, 200, 176),
    (236, 226, 208),
]
STONE_GREY = [
    (72, 78, 82),
    (104, 112, 116),
    (140, 148, 152),
    (176, 184, 186),
    (210, 216, 214),
    (232, 236, 232),
]
MOSS = [
    (24, 72, 44),
    (36, 104, 58),
    (52, 136, 72),
    (78, 164, 90),
]


def rgba(rgb: tuple[int, int, int]) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], 255)


def clamp(i: int, n: int) -> int:
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

    def put(self, x: int, y: int, c: tuple[int, int, int] | tuple[int, int, int, int] | None) -> None:
        if c is None or not (0 <= x < self.w and 0 <= y < self.h):
            return
        self.px[y * self.w + x] = c if len(c) == 4 else (*c, 255)

    def put_wrap(self, x: int, y: int, c: tuple[int, int, int] | tuple[int, int, int, int]) -> None:
        self.put(x % self.w, y % self.h, c)

    def get(self, x: int, y: int) -> tuple[int, int, int, int] | None:
        if not (0 <= x < self.w and 0 <= y < self.h):
            return None
        return self.px[y * self.w + x]

    def rect(self, x: int, y: int, w: int, h: int, c: tuple[int, int, int]) -> None:
        color = rgba(c)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, color)

    def image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        im.putdata([p if p is not None else (0, 0, 0, 0) for p in self.px])
        return im

    def outline(self, ink: tuple[int, int, int, int] = INK) -> None:
        add: list[tuple[int, int]] = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y * self.w + x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny * self.w + nx] is not None:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y * self.w + x] = ink

    def blit(self, src: Pix, ox: int, oy: int) -> None:
        for y in range(src.h):
            for x in range(src.w):
                c = src.px[y * src.w + x]
                if c is not None:
                    self.put(ox + x, oy + y, c)


def band(light: float, n: int) -> int:
    t = (light + 1.05) / 2.15
    return clamp(int(t * n), n)


def _hash(x: int, y: int) -> int:
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return n


def _noise(x: int, y: int, cell: int, w: int = 240, h: int = 240) -> float:
    x %= w
    y %= h
    x0 = (x // cell) * cell
    y0 = (y // cell) * cell
    fx = (x - x0) / cell
    fy = (y - y0) / cell
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1 = (x0 + cell) % w
    y1 = (y0 + cell) % h

    def hv(px: int, py: int) -> float:
        return (_hash(px, py) & 1023) / 1023

    v00 = hv(x0, y0)
    v10 = hv(x1, y0)
    v01 = hv(x0, y1)
    v11 = hv(x1, y1)
    return v00 * (1 - fx) * (1 - fy) + v10 * fx * (1 - fy) + v01 * (1 - fx) * fy + v11 * fx * fy


def _shade_rect(pix: Pix, x: int, y: int, w: int, h: int, ramp: list[tuple[int, int, int]]) -> None:
    for yy in range(h):
        for xx in range(w):
            nx = xx / max(1, w - 1) * 2 - 1
            ny = yy / max(1, h - 1)
            pix.put(x + xx, y + yy, ramp[band(0.2 - 0.85 * nx - 0.45 * ny, len(ramp))])


def _is_grass(c: tuple[int, int, int, int] | None) -> bool:
    if c is None:
        return False
    rgb = c[:3]
    return rgb in GRASS or rgb in CLOVER or rgb in SUN


# --- Lawn -----------------------------------------------------------------


def ground() -> Image.Image:
    """A tiled lawn: mounds, a worn track, stones, and flowers.

    One green must not own the tile. Edges wrap so the repeat is a place.
    """
    w = h = 240
    pix = Pix(w, h)
    for y in range(h):
        for x in range(w):
            n = 0.62 * _noise(x, y, 48, w, h) + 0.38 * _noise(x, y, 18, w, h)
            # Bell-shaped noise piles up in the middle. Split that middle
            # across several greens with a second octave.
            split = _noise(x + 90, y + 40, 24, w, h)
            if n < 0.28:
                tone = 1
            elif n < 0.42:
                tone = 2 if split < 0.5 else 4
            elif n < 0.58:
                tone = 3 if split < 0.45 else 5
            elif n < 0.74:
                tone = 4 if split < 0.55 else 6
            else:
                tone = 6 if split < 0.6 else 7
            north = _noise(x, y - 5, 48, w, h)
            west = _noise(x - 5, y, 48, w, h)
            if n + 0.08 < north and n + 0.05 < west:
                tone = max(0, tone - 2)
            elif n > north + 0.1:
                tone = min(7, tone + 1)
            pix.put(x, y, GRASS[tone])

    # Clover patches. A different green, not another grass recolor blob.
    for cy in range(0, h, 40):
        for cx in range(20, w, 40):
            jx = _hash(cx, cy) % 14 - 7
            jy = _hash(cy, cx) % 10 - 5
            if _hash(cx, cy + 3) % 3 == 0:
                continue
            _clover_patch(pix, cx + jx, cy + jy)

    # Sunlit mounds. A yellow-green, so the lawn is not one green family.
    for cx, cy, rx, ry in (
        (36, 28, 22, 14),
        (128, 18, 18, 12),
        (200, 48, 26, 16),
        (70, 100, 20, 12),
        (168, 130, 24, 14),
        (24, 188, 18, 12),
        (210, 200, 22, 14),
        (110, 210, 16, 10),
    ):
        _soft_blob(pix, cx, cy, rx, ry, SUN, rim=(48, 110, 40))

    # Dirt clearings. Separate patches, not a line that reads as a fence.
    for cx, cy, rx, ry in (
        (58, 64, 16, 9),
        (150, 78, 14, 8),
        (230, 150, 18, 10),
        (40, 150, 12, 8),
        (96, 168, 15, 8),
    ):
        _soft_blob(pix, cx, cy, rx, ry, DIRT, rim=GRASS[1])

    # Flagstones on the track and a few in the grass. Different shapes.
    stones = (
        (18, 150, 0), (46, 176, 1), (78, 158, 2), (112, 188, 0),
        (148, 164, 1), (186, 196, 2), (214, 170, 0), (8, 196, 1),
        (64, 40, 2), (132, 28, 0), (200, 70, 1), (36, 96, 2),
        (170, 100, 0), (230, 40, 1), (100, 120, 2),
    )
    for sx, sy, kind in stones:
        _pebble(pix, sx, sy, kind)

    flowers = (
        (16, 18, 0), (48, 36, 1), (84, 14, 2), (120, 44, 3),
        (156, 22, 4), (196, 48, 5), (228, 16, 0), (28, 72, 2),
        (70, 88, 4), (108, 64, 1), (154, 80, 5), (188, 96, 3),
        (220, 78, 1), (12, 118, 4), (52, 132, 0), (96, 108, 5),
        (140, 128, 2), (176, 112, 0), (214, 136, 4), (40, 210, 3),
        (88, 220, 1), (130, 206, 5), (168, 224, 2), (208, 208, 0),
        (232, 228, 4), (24, 160, 5), (200, 150, 3),
    )
    for fx, fy, kind in flowers:
        if _hash(fx, fy) % 5 == 0:
            continue
        _flower(pix, fx, fy, kind)

    # Blades in clumps, on grass only, so the lawn has a nap.
    for cy in range(6, h, 14):
        for cx in range(4, w, 11):
            if _hash(cx, cy) % 4 != 0:
                continue
            for i, dx in enumerate((-2, 0, 3)):
                if not _is_grass(pix.get(cx + dx, cy)):
                    continue
                height = 3 + (i + _hash(cx, cy) % 2)
                tip = GRASS[7] if i != 1 else GRASS[6]
                for k in range(height):
                    yy = cy - k
                    if _is_grass(pix.get((cx + dx) % w, yy % h)):
                        pix.put_wrap(cx + dx, yy, tip if k == height - 1 else GRASS[5])
    return pix.image()


def _soft_blob(
    pix: Pix,
    cx: int,
    cy: int,
    rx: int,
    ry: int,
    ramp: tuple[tuple[int, int, int], ...] | list[tuple[int, int, int]],
    rim: tuple[int, int, int],
) -> None:
    for y in range(-ry, ry + 1):
        for x in range(-rx, rx + 1):
            nx = x / max(1, rx)
            ny = y / max(1, ry)
            wob = 0.18 * math.sin((cx + x) * 0.9 + (cy + y) * 0.4)
            if nx * nx + ny * ny > 1.0 + wob:
                continue
            if ny > 0.55:
                pix.put_wrap(cx + x, cy + y, rim)
            else:
                tone = 0 if nx > 0.35 or ny > 0.2 else len(ramp) - 1 if nx < -0.25 and ny < -0.2 else len(ramp) // 2
                pix.put_wrap(cx + x, cy + y, ramp[tone])


def _clover_patch(pix: Pix, cx: int, cy: int) -> None:
    for y in range(-6, 7):
        for x in range(-7, 8):
            if x * x + y * y > 36:
                continue
            pix.put_wrap(cx + x, cy + y, CLOVER[1 + (x + y) % 3])
    for dx, dy in ((-3, -1), (0, -3), (3, 0), (-1, 2)):
        pix.put_wrap(cx + dx, cy + dy, CLOVER[3])
        pix.put_wrap(cx + dx + 1, cy + dy, CLOVER[2])
        pix.put_wrap(cx + dx, cy + dy + 1, CLOVER[0])


def _pebble(pix: Pix, cx: int, cy: int, kind: int) -> None:
    ramp = (STONE, STONE_GREY, STONE)[kind]
    if kind == 0:
        cells = ((0, 0, 8, 5), (1, 1, 6, 3))
    elif kind == 1:
        cells = ((0, 1, 6, 6), (5, 2, 4, 4))
    else:
        cells = ((1, 0, 9, 4), (0, 3, 5, 3))
    for ox, oy, w, h in cells:
        for y in range(h):
            for x in range(w):
                if (x == 0 or x == w - 1) and (y == 0 or y == h - 1):
                    continue
                tone = 4 if y == 0 or x == 0 else 1 if y == h - 1 else 3
                pix.put_wrap(cx + ox + x, cy + oy + y, ramp[tone])
    pix.put_wrap(cx + 2, cy + 1, ramp[5])
    pix.put_wrap(cx + 1, cy + 2, MOSS[2] if kind == 2 else ramp[5])
    # Contact shadow, south-east, so the stone sits in the grass.
    pix.put_wrap(cx + 3, cy + 6, GRASS[0])
    pix.put_wrap(cx + 4, cy + 6, GRASS[1])
    pix.put_wrap(cx + 5, cy + 7, GRASS[0])


def _flower(pix: Pix, x: int, y: int, kind: int) -> None:
    """A small bloom with a stem. Slides off dirt. Empty pixels are fine."""
    under = pix.get(x % pix.w, y % pix.h)
    if under is not None and not _is_grass(under):
        y -= 14
        under = pix.get(x % pix.w, y % pix.h)
        if under is not None and not _is_grass(under):
            return
    stems = (
        ((196, 48, 58), (236, 150, 140), (255, 214, 200)),  # poppy
        ((230, 186, 48), (255, 230, 140), (255, 248, 210)),  # buttercup
        ((236, 236, 228), (255, 250, 236), (255, 214, 80)),  # daisy
        ((132, 72, 186), (196, 150, 220), (236, 210, 246)),  # violet
        ((64, 112, 196), (140, 176, 230), (220, 232, 255)),  # cornflower
        ((220, 112, 48), (255, 176, 96), (255, 220, 170)),  # marigold
    )
    petal, hi, core = stems[kind % 6]
    pix.put_wrap(x, y + 3, GRASS[2])
    pix.put_wrap(x, y + 4, GRASS[1])
    pix.put_wrap(x - 2, y + 4, GRASS[5])
    pix.put_wrap(x + 2, y + 5, GRASS[4])
    for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        pix.put_wrap(x + dx, y + dy, petal)
    pix.put_wrap(x, y, core)
    pix.put_wrap(x - 1, y - 1, hi)
    pix.put_wrap(x, y + 3, GRASS[0])


def path() -> Image.Image:
    """Cobbles under the yard. Gaps stay transparent so the lawn shows."""
    pix = Pix(360, 52)
    course = (
        (2, 16, 18, 12, 0), (22, 20, 16, 11, 1), (40, 14, 20, 14, 2),
        (62, 22, 14, 10, 0), (78, 16, 18, 13, 1),
        (100, 18, 22, 14, 2), (124, 14, 16, 12, 0), (142, 20, 20, 13, 1),
        (164, 16, 18, 14, 2), (184, 22, 16, 11, 0), (202, 15, 22, 15, 1),
        (226, 20, 18, 12, 2), (246, 14, 16, 13, 0), (264, 18, 20, 14, 1),
        (286, 22, 14, 11, 2), (302, 16, 18, 13, 0), (322, 20, 20, 14, 1),
        (344, 15, 14, 12, 2),
        (14, 32, 12, 8, 1), (48, 34, 14, 9, 0), (110, 34, 16, 10, 2),
        (168, 36, 12, 8, 1), (230, 34, 14, 9, 0), (300, 36, 16, 8, 2),
    )
    for x, y, bw, bh, kind in course:
        _cobble(pix, x, y, bw, bh, kind)
    # Grass and a few blooms in the joints.
    for x, y, kind in (
        (36, 8, 1), (96, 6, 0), (160, 8, 4), (250, 6, 3), (330, 8, 5),
        (70, 42, 2), (200, 44, 1), (280, 42, 0),
    ):
        _flower(pix, x, y, kind)
    return pix.image()


def _cobble(pix: Pix, x: int, y: int, w: int, h: int, kind: int) -> None:
    ramp = (STONE, STONE_GREY, DIRT)[kind % 3]
    # DIRT is shorter; cobbles of kind 2 use the warm dirt ramp as sandstone.
    if kind % 3 == 2:
        ramp = (
            (120, 86, 52),
            (156, 116, 72),
            (188, 148, 100),
            (214, 178, 132),
            (232, 204, 164),
            (246, 226, 196),
        )
    for yy in range(h):
        inset = 1 if yy == 0 or yy == h - 1 else 0
        if kind == 1 and yy < 2:
            inset = 2
        for xx in range(inset, w - inset):
            if (xx < 2 or xx > w - 3) and (yy < 2 or yy > h - 3) and (xx + yy + kind) % 2 == 0:
                continue
            tone = 4 if yy < 2 or xx < 2 else 1 if yy > h - 3 else 3
            if (xx * 3 + yy * 5 + kind) % 17 == 0:
                tone = 5 if tone >= 3 else 0
            pix.put(x + xx, y + yy, ramp[min(tone, len(ramp) - 1)])
    pix.put(x + 2, y + 2, ramp[min(5, len(ramp) - 1)])
    pix.put(x + w - 3, y + h - 3, ramp[0])
    if w > 12 and h > 8:
        pix.put(x + w // 2, y + 3, ramp[1])
        pix.put(x + w // 2, y + 4, ramp[0])
        pix.put(x + 4, y + h // 2, MOSS[1])
        pix.put(x + 5, y + h // 2, MOSS[3])
    pix.put(x + 2, y + h, GRASS[0])
    pix.put(x + w // 2, y + h, GRASS[1])


def worn() -> Image.Image:
    """Flagstones in front of a door. Not a second full-width strip."""
    pix = Pix(72, 28)
    stones = ((1, 8, 14, 10, 0), (16, 6, 12, 11, 1), (30, 10, 16, 10, 2), (48, 7, 12, 11, 0), (60, 12, 10, 8, 1))
    for x, y, w, h, kind in stones:
        _cobble(pix, x, y, w, h, kind)
    pix.put(8, 4, GRASS[5])
    pix.put(9, 5, GRASS[6])
    pix.put(40, 20, GRASS[4])
    pix.put(22, 18, (150, 48, 52))
    pix.put(23, 18, (220, 160, 150))
    return pix.image()


def _soil(pix: Pix, cx: int, cy: int, rx: int = 22, ry: int = 7) -> None:
    ramp = [GRASS[1], DIRT[0], DIRT[1], DIRT[2], DIRT[3], GRASS[3]]
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            nx = (x - cx) / max(1, rx)
            ny = (y - cy) / max(1, ry)
            if nx * nx + ny * ny > 1:
                continue
            tone = 4 if ny < -0.2 and nx < 0 else 1 if ny > 0.45 else 3
            pix.put(x, y, ramp[tone])
    pix.put(cx - rx + 4, cy + 1, GRASS[4])
    pix.put(cx + 6, cy + 2, STONE[3])
    pix.put(cx + 7, cy + 2, STONE[5])


def flowers() -> Image.Image:
    """Rose bed. Layered blooms, not four dots on a stem."""
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 32, 42)
    blooms = (
        (12, 14, (120, 28, 40), (168, 48, 58), (210, 86, 90), (245, 170, 160)),
        (28, 8, (150, 36, 52), (196, 70, 80), (230, 120, 120), (255, 200, 186)),
        (44, 16, (100, 24, 40), (160, 48, 60), (200, 90, 96), (240, 160, 150)),
    )
    for sx, top, dark, mid, light, hi in blooms:
        pix.rect(sx + 2, top + 8, 2, 40 - top, (28, 96, 44))
        pix.put(sx + 1, top + 8, (20, 72, 36))
        for lx, ly in ((-4, 12), (-3, 13), (5, 14), (6, 15), (-2, 18), (4, 20)):
            pix.put(sx + lx, top + ly, GRASS[5] if lx < 0 else GRASS[3])
            pix.put(sx + lx, top + ly + 1, GRASS[6] if lx < 0 else GRASS[4])
        for dy in range(-2, 5):
            for dx in range(-3, 5):
                if dx * dx + (dy * 2) * (dy * 2) > 18:
                    continue
                if abs(dx) + abs(dy) <= 1:
                    col = hi
                elif dx < 0 and dy < 1:
                    col = light
                elif dy > 2:
                    col = dark
                else:
                    col = mid
                pix.put(sx + dx, top + dy, col)
        pix.put(sx, top + 1, (255, 214, 70))
        pix.put(sx + 1, top + 1, (255, 236, 140))
    pix.outline()
    return pix.image()


def shrub() -> Image.Image:
    """Berry bush. Blue fruit, so it is not a second round tree."""
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 32, 44, 20, 6)
    clumps = (
        (32, 26, 16, 12, 3),
        (18, 30, 10, 9, 2),
        (46, 30, 11, 8, 4),
        (32, 18, 8, 7, 5),
    )
    leaf = [
        (16, 58, 36),
        (28, 86, 48),
        (40, 118, 58),
        (64, 150, 70),
        (96, 176, 88),
        (140, 200, 112),
        (186, 214, 140),
    ]
    for cx, cy, rx, ry, bias in clumps:
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                nx = (x - cx) / max(1, rx)
                ny = (y - cy) / max(1, ry)
                if nx * nx + ny * ny > 1:
                    continue
                tone = clamp(bias + (1 if nx < -0.2 and ny < 0 else 0) - (1 if ny > 0.4 else 0), len(leaf))
                if (x * 5 + y * 3) % 11 == 0:
                    continue
                pix.put(x, y, leaf[tone])
    berries = ((22, 24), (30, 18), (38, 22), (44, 28), (26, 32), (36, 30))
    for bx, by in berries:
        pix.put(bx, by, (180, 200, 240))
        pix.put(bx + 1, by, (70, 96, 190))
        pix.put(bx, by + 1, (36, 52, 140))
        pix.put(bx + 1, by + 1, (24, 36, 100))
    pix.outline()
    return pix.image()


def wild() -> Image.Image:
    """Mixed wildflowers. Tall stems, no shared soil disc."""
    pix = Pix(PLANT_W, PLANT_H)
    specs = (
        (10, 30, 0), (20, 22, 1), (30, 28, 2), (40, 18, 4), (50, 26, 3),
    )
    for sx, top, kind in specs:
        pix.rect(sx, top + 6, 1, 44 - top, GRASS[3])
        pix.put(sx - 2, top + 12, GRASS[6])
        pix.put(sx + 2, top + 14, GRASS[5])
        _flower(pix, sx, top, kind)
    pix.outline()
    return pix.image()


def herbs() -> Image.Image:
    """Lavender wands beside one stone."""
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 28, 42, 16, 6)
    for sx, h in ((16, 22), (22, 26), (28, 18), (34, 24)):
        for i in range(h):
            col = (120, 90, 170) if i < 8 else (150, 120, 196) if i < 14 else GRASS[3]
            pix.put(sx, 40 - i, col)
            if i < 8 and i % 2 == 0:
                pix.put(sx - 1, 40 - i, (186, 160, 214))
                pix.put(sx + 1, 40 - i, (96, 70, 150))
        pix.put(sx, 40 - h, (210, 190, 230))
    _pebble(pix, 46, 36, 1)
    pix.outline()
    return pix.image()


def meadow() -> Image.Image:
    """A stand of grass and mixed blooms. Dirt is only a root line."""
    pix = Pix(112, 64)
    for x in range(16, 100):
        pix.put(x, 54, GRASS[1])
        if x % 4 == 0:
            pix.put(x, 55, DIRT[1])
    blades = (
        (14, 18, 34), (22, 8, 44), (30, 16, 36), (38, 6, 46),
        (48, 12, 40), (56, 4, 48), (66, 14, 38), (76, 8, 44),
        (86, 16, 36), (96, 10, 42),
    )
    tones = (GRASS[2], GRASS[4], GRASS[5], GRASS[6], CLOVER[2], GRASS[7])
    for i, (x, top, bh) in enumerate(blades):
        pix.rect(x, top, 2, bh, tones[i % len(tones)])
        pix.put(x, top, GRASS[7])
        pix.put(x - 1, top + 4, tones[(i + 2) % len(tones)])
        pix.put(x + 2, top + 8, GRASS[3])
    for fx, fy, kind in ((24, 10, 0), (46, 6, 1), (68, 12, 3), (88, 16, 2), (58, 20, 5)):
        _flower(pix, fx, fy, kind)
    pix.outline()
    return pix.image()


def thicket() -> Image.Image:
    """Bramble, red berries, and one stone. Not a second shrub ball."""
    pix = Pix(88, 56)
    leaf = [
        (40, 24, 28),
        (72, 36, 32),
        (96, 56, 40),
        (64, 110, 52),
        (96, 146, 64),
        (140, 176, 90),
    ]
    for cx, cy, rx, ry in ((36, 34, 18, 12), (54, 38, 12, 8), (22, 40, 10, 7)):
        for y in range(cy - ry, cy + ry):
            for x in range(cx - rx, cx + rx):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1:
                    continue
                pix.put(x, y, leaf[2 + (x + y) % 3])
    for x, y in ((24, 28), (34, 24), (48, 30), (58, 36), (30, 36)):
        pix.put(x, y, (160, 32, 40))
        pix.put(x + 1, y, (200, 64, 64))
        pix.put(x, y + 1, (110, 24, 32))
    for x, bh in ((8, 24), (12, 32), (16, 18)):
        pix.rect(x, 48 - bh, 2, bh, GRASS[5])
        pix.put(x, 48 - bh, GRASS[7])
    _pebble(pix, 64, 40, 0)
    pix.outline()
    return pix.image()


def scuff() -> Image.Image:
    """A boot-scuffed patch. Two stones, not a brown oval."""
    pix = Pix(72, 36)
    for y in range(10, 30):
        for x in range(8, 64):
            nx = (x - 36) / 28
            ny = (y - 20) / 12
            if nx * nx + ny * ny > 1:
                continue
            pix.put(x, y, DIRT[1 + (x + y) % 3])
    # Two boot prints.
    for bx in (22, 40):
        pix.rect(bx, 16, 8, 4, DIRT[0])
        pix.rect(bx + 1, 20, 6, 6, DIRT[0])
        pix.put(bx + 2, 17, DIRT[3])
    _pebble(pix, 12, 18, 1)
    _pebble(pix, 52, 20, 0)
    pix.put(18, 12, GRASS[5])
    pix.put(48, 12, GRASS[6])
    pix.outline()
    return pix.image()


def contact() -> Image.Image:
    """A short darker grass shadow. Buildings sit on it."""
    pix = Pix(96, 12)
    runs = ((6, 22, 4), (30, 28, 3), (62, 24, 5), (18, 14, 6), (48, 16, 5))
    for x, bw, y in runs:
        for i in range(bw):
            pix.put(x + i, y, (28, 58, 32, 170))
            if i % 3 != 0:
                pix.put(x + i, y + 1, (40, 74, 42, 120))
    return pix.image()


def nameplate() -> Image.Image:
    """A wood plaque the building name sits on. Not a rounded pill."""
    pix = Pix(88, 18)
    pix.rect(0, 0, 88, 18, (72, 48, 28))
    pix.rect(1, 1, 86, 16, (112, 74, 42))
    pix.rect(2, 2, 84, 14, (148, 102, 62))
    pix.rect(2, 2, 84, 1, (196, 150, 96))
    pix.rect(2, 15, 84, 1, (64, 40, 22))
    pix.put(4, 4, (210, 170, 110))
    pix.put(82, 4, (90, 58, 32))
    return pix.image()


def pennants() -> Image.Image:
    """Swallowtail flags for AL10. Pixels, not theme rectangles."""
    pix = Pix(320, 24)
    colors = (
        (150, 42, 48),
        (210, 170, 64),
        (48, 110, 64),
        (48, 72, 140),
        (150, 42, 48),
        (210, 170, 64),
        (48, 110, 64),
    )
    for i, col in enumerate(colors):
        x = 16 + i * 42
        pix.rect(x, 0, 2, 22, (48, 36, 24))
        pix.rect(x + 2, 2, 16, 8, col)
        pix.rect(x + 6, 10, 8, 6, col)
        pix.rect(x + 8, 16, 4, 4, col)
        pix.put(x + 4, 3, (240, 220, 180))
    return pix.image()


def lanterns() -> Image.Image:
    """Five hanging lanterns for AL20."""
    pix = Pix(200, 18)
    for i in range(5):
        x = 12 + i * 38
        pix.rect(x + 6, 0, 2, 4, (48, 36, 24))
        pix.rect(x, 4, 14, 10, (196, 120, 36))
        pix.rect(x + 2, 6, 10, 6, (255, 196, 72))
        pix.rect(x + 5, 8, 4, 2, (255, 236, 160))
        pix.rect(x + 4, 14, 6, 3, (120, 64, 24))
    return pix.image()


def alert() -> Image.Image:
    """A claim spark for guild and vault. A flame, not a UI circle."""
    pix = Pix(16, 16)
    rows = (
        "......ii......",
        ".....igyi.....",
        "....igywi.....",
        "...igyywyi....",
        "..igywwwwyi...",
        "..igywowygi...",
        "...igyyygi....",
        "....iooogi....",
        ".....irri.....",
        "....irrrri....",
        ".....irri.....",
        "......bb......",
        "......bb......",
        ".....bbbb.....",
        "......bb......",
        "..............",
    )
    cmap = {
        "i": (32, 22, 18),
        "g": (176, 96, 28),
        "y": (244, 176, 48),
        "w": (255, 236, 170),
        "o": (214, 84, 28),
        "r": (168, 40, 32),
        "b": (92, 58, 32),
    }
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in cmap:
                pix.put(x, y, cmap[ch])
    return pix.image()


# --- Villagers ------------------------------------------------------------

# Ramps, dark to light. Enough steps that a sleeve is not one flat color.
SKIN_TAN = [(92, 56, 36), (128, 80, 52), (166, 110, 72), (198, 142, 100), (226, 176, 136), (248, 214, 180)]
SKIN_LIGHT = [(120, 86, 64), (160, 116, 88), (196, 150, 118), (222, 180, 148), (240, 206, 178), (255, 230, 210)]
SKIN_WARM = [(104, 62, 48), (146, 90, 68), (180, 118, 90), (210, 150, 118), (232, 180, 150), (250, 214, 186)]
HAIR_D = [(28, 16, 12), (52, 30, 20), (78, 46, 30), (108, 68, 42), (142, 96, 60), (176, 128, 84)]
HAIR_GOLD = [(92, 58, 24), (132, 88, 36), (176, 124, 48), (208, 160, 72), (232, 196, 112), (250, 224, 160)]
HAIR_RED = [(78, 28, 24), (120, 48, 36), (160, 72, 52), (196, 110, 78), (220, 150, 112), (240, 190, 156)]
MOSS_CLOTH = [(22, 64, 48), (32, 96, 64), (44, 128, 78), (64, 156, 96), (96, 180, 118), (140, 204, 148), (186, 220, 176)]
WOOL = [(28, 48, 96), (40, 68, 132), (56, 92, 164), (78, 118, 188), (108, 148, 206), (150, 180, 220), (196, 214, 232)]
ROSE = [(96, 36, 56), (140, 52, 76), (176, 78, 102), (204, 112, 132), (224, 150, 164), (240, 190, 196), (252, 220, 216)]
CREAM = [(120, 96, 72), (160, 132, 100), (196, 168, 132), (220, 196, 164), (238, 220, 196), (250, 240, 224)]
LEATHER = [(48, 28, 16), (78, 46, 26), (112, 68, 36), (148, 96, 52), (184, 132, 78), (214, 168, 112), (236, 200, 150)]
BOOT = [(18, 12, 10), (36, 24, 18), (58, 40, 28), (92, 64, 44), (132, 96, 68)]
IRON = [(28, 30, 34), (52, 56, 62), (86, 92, 100), (128, 136, 146), (176, 184, 192), (220, 226, 230)]
APRON = [(72, 44, 28), (104, 64, 40), (140, 92, 58), (176, 124, 82), (206, 160, 114)]


def _stamp(pix: Pix, x: int, y: int, rows: tuple[str, ...], cmap: dict[str, tuple[int, int, int]]) -> None:
    for yy, row in enumerate(rows):
        for xx, ch in enumerate(row):
            if ch in cmap:
                pix.put(x + xx, y + yy, cmap[ch])


def _limb(pix: Pix, x0: int, y0: int, x1: int, y1: int, ramp: list[tuple[int, int, int]], thick: int = 3) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = x0 + (x1 - x0) * i // steps
        y = y0 + (y1 - y0) * i // steps
        for k in range(thick):
            tone = 5 if k == 0 else 1 if k == thick - 1 else 3
            pix.put(x, y + k - 1, ramp[min(tone, len(ramp) - 1)])


def _hand(pix: Pix, x: int, y: int, skin: list[tuple[int, int, int]]) -> None:
    pix.rect(x, y, 3, 3, skin[3])
    pix.put(x, y, skin[5])
    pix.put(x + 2, y + 2, skin[1])
    pix.put(x + 1, y + 1, skin[4])


def _boot(pix: Pix, x: int, y: int) -> None:
    _shade_rect(pix, x, y, 5, 4, BOOT)
    pix.rect(x - 1, y + 3, 7, 1, BOOT[0])
    pix.put(x + 1, y, BOOT[4])
    pix.put(x, y + 1, BOOT[3])


def _torso(pix: Pix, x: int, y: int, w: int, h: int, ramp: list[tuple[int, int, int]]) -> None:
    _shade_rect(pix, x, y, w, h, ramp)
    # Center fold and a side shadow, two pixels so they survive as shape.
    pix.rect(x + w // 2 - 1, y + 2, 1, h - 3, ramp[1])
    pix.rect(x + w - 2, y + 2, 1, h - 2, ramp[0])
    pix.rect(x, y, w, 1, ramp[min(5, len(ramp) - 1)])


def _head_pixels(style: str) -> tuple[tuple[str, ...], dict[str, tuple[int, int, int]]]:
    skin = {"smith": SKIN_TAN, "courier": SKIN_LIGHT, "gardener": SKIN_WARM}[style]
    hair = {"smith": HAIR_D, "courier": HAIR_GOLD, "gardener": HAIR_RED}[style]
    cmap = {
        "h": hair[3],
        "H": hair[5],
        "d": hair[1],
        "s": skin[3],
        "S": skin[5],
        "a": skin[1],
        "w": (250, 246, 240),
        "k": (28, 18, 16),
        "n": skin[2],
        "m": (168, 72, 72),
        "b": hair[2],
        "B": hair[0],
        "c": (36, 64, 120),
        "C": (120, 160, 210),
        "p": (255, 176, 176),
        "e": hair[4],
    }
    if style == "smith":
        rows = (
            "..ddhhhhhhdd.",
            ".dhhHHHHHHhd.",
            "dhhsssssssshd",
            "hssSwksswkSsh",
            "hssaksssakssh",
            "hhsssnnnssshh",
            "hhsssmmmssshh",
            "hssbbbbbbbbss",
            ".hsBBBBBBBBsh",
            "..sBBBBBBBBs.",
            "...BBBBBBB...",
        )
    elif style == "courier":
        rows = (
            "...ccccccc...",
            "..ccCCCCCcc..",
            ".cccchhhhccc.",
            "ccccssssssccc",
            "hhssSwksswkss",
            "hsssakkssaksh",
            "hhsssnnnssshh",
            "hhssmmmmmsshh",
            ".hhssssssshh.",
            "..hssssssssh.",
        )
    else:
        rows = (
            "....eeeee....",
            "..ddhhhhhdd..",
            ".dhhHHHHHHhd.",
            "dhhsssssssshd",
            "hssSwksswkSsh",
            "hssaksssakssh",
            "hhsssnnnssshh",
            "hhsspmmmmpshh",
            ".hhssssssshh.",
            "..hssssssssh.",
            ".....eee.....",
        )
    return rows, cmap


def _draw_head(pix: Pix, x: int, y: int, style: str) -> None:
    rows, cmap = _head_pixels(style)
    _stamp(pix, x, y, rows, cmap)
    skin = {"smith": SKIN_TAN, "courier": SKIN_LIGHT, "gardener": SKIN_WARM}[style]
    # Ears.
    pix.rect(x - 1, y + 4, 2, 3, skin[2])
    pix.rect(x + len(rows[0]) - 1, y + 4, 2, 3, skin[3])
    pix.put(x - 1, y + 5, skin[4])
    pix.put(x + len(rows[0]), y + 5, skin[5])
    if style == "gardener":
        # Bun on the crown, a different silhouette from the cap and the beard.
        pix.rect(x + 8, y - 3, 5, 4, HAIR_RED[2])
        pix.rect(x + 9, y - 4, 3, 2, HAIR_RED[4])
        pix.put(x + 10, y - 4, HAIR_RED[5])
        pix.put(x + 8, y - 2, HAIR_RED[0])


def _shadow_feet(pix: Pix, xs: list[int]) -> None:
    for x in xs:
        pix.put(x + 1, 53, (24, 56, 30))
        pix.put(x + 2, 53, (20, 44, 26))
        pix.put(x + 3, 53, (24, 56, 30))


def _up2(src: Pix) -> Pix:
    dst = Pix(src.w * 2, src.h * 2)
    for y in range(src.h):
        row = y * src.w
        for x in range(src.w):
            c = src.px[row + x]
            if c is None:
                continue
            dx, dy = x * 2, y * 2
            dst.put(dx, dy, c)
            dst.put(dx + 1, dy, c)
            dst.put(dx, dy + 1, c)
            dst.put(dx + 1, dy + 1, c)
    return dst


def _person(kind: int, frame: int) -> Pix:
    """One villager on the yard grid. Frame 0 idle, 1–4 a walk, facing right."""
    pix = Pix(LOGICAL_W, LOGICAL_H)
    bob = (0, 0, -1, 0, -1)[frame]
    # (left foot dx, right foot dx) from the body center. Facing right.
    steps = {
        0: (-3, 4),
        1: (-8, 8),
        2: (-2, 2),
        3: (7, -8),
        4: (2, -2),
    }[frame]
    # Hand offsets from each shoulder. Opposite the front foot.
    hands = {
        0: ((-1, 11), (2, 11)),
        1: ((-2, 6), (5, 13)),
        2: ((0, 8), (3, 9)),
        3: ((3, 13), (0, 5)),
        4: ((1, 9), (2, 8)),
    }[frame]
    sway = (0, -2, -1, 2, 1)[frame]

    if kind == 0:
        _smith(pix, bob, steps, hands)
    elif kind == 1:
        _courier(pix, bob, steps, hands, sway)
    else:
        _gardener(pix, bob, steps, sway)
    pix.outline()
    _shadow_feet(pix, [20 + steps[0], 22 + steps[1]] if kind != 2 else [18 + sway, 26 + sway])
    return _up2(pix)


def _smith(
    pix: Pix,
    bob: int,
    steps: tuple[int, int],
    hands: tuple[tuple[int, int], tuple[int, int]],
) -> None:
    cx = 20
    hy = 30 + bob
    sy = 18 + bob
    # Far arm, then legs, torso, near arm, head, hammer.
    _limb(pix, cx - 6, sy, cx - 6 + hands[0][0], sy + hands[0][1], MOSS_CLOTH, 3)
    _hand(pix, cx - 7 + hands[0][0], sy + hands[0][1], SKIN_TAN)
    _limb(pix, cx - 4, hy, cx + steps[0], 48 + bob, LEATHER, 4)
    _limb(pix, cx + 2, hy, cx + steps[1], 48 + bob, LEATHER, 4)
    _boot(pix, cx + steps[0], 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _torso(pix, cx - 7, 17 + bob, 15, 14, MOSS_CLOTH)
    # Apron over the tunic, with a strap and stitches.
    _shade_rect(pix, cx - 5, 22 + bob, 11, 12, APRON)
    pix.rect(cx - 1, 17 + bob, 3, 6, APRON[2])
    pix.rect(cx - 5, 22 + bob, 11, 1, APRON[4])
    for syy in range(24 + bob, 32 + bob, 3):
        pix.put(cx - 4, syy, APRON[0])
        pix.put(cx + 4, syy, APRON[1])
    pix.rect(cx - 2, 28 + bob, 4, 3, APRON[1])
    pix.put(cx - 1, 29 + bob, APRON[4])
    # Belt.
    pix.rect(cx - 6, hy - 1, 13, 2, LEATHER[1])
    pix.rect(cx - 1, hy - 1, 3, 2, IRON[3])
    pix.put(cx, hy - 1, IRON[5])
    # Neckerchief.
    pix.rect(cx - 3, 16 + bob, 7, 2, (164, 36, 44))
    pix.put(cx - 2, 16 + bob, (220, 140, 130))
    _limb(pix, cx + 6, sy, cx + 6 + hands[1][0], sy + hands[1][1], MOSS_CLOTH, 3)
    hx = cx + 6 + hands[1][0]
    hyh = sy + hands[1][1]
    _hand(pix, hx, hyh, SKIN_TAN)
    # Hammer in the near hand. Head is iron, handle is wood.
    _limb(pix, hx + 2, hyh + 2, hx + 3, hyh + 10, LEATHER, 2)
    pix.rect(hx - 1, hyh - 2, 10, 5, IRON[2])
    pix.rect(hx - 1, hyh - 2, 10, 1, IRON[5])
    pix.rect(hx - 1, hyh + 2, 10, 1, IRON[0])
    pix.put(hx + 1, hyh - 1, IRON[5])
    pix.put(hx + 6, hyh, IRON[1])
    _draw_head(pix, cx - 6, 4 + bob, "smith")


def _courier(
    pix: Pix,
    bob: int,
    steps: tuple[int, int],
    hands: tuple[tuple[int, int], tuple[int, int]],
    sway: int,
) -> None:
    cx = 22
    hy = 31 + bob
    sy = 18 + bob
    _limb(pix, cx - 5, sy, cx - 5 + hands[0][0], sy + hands[0][1], WOOL, 3)
    _hand(pix, cx - 6 + hands[0][0], sy + hands[0][1], SKIN_LIGHT)
    _limb(pix, cx - 3, hy, cx + steps[0], 48 + bob, WOOL, 3)
    _limb(pix, cx + 2, hy, cx + steps[1], 48 + bob, WOOL, 3)
    _boot(pix, cx + steps[0], 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _torso(pix, cx - 6, 17 + bob, 12, 15, WOOL)
    # Shirt and a row of buttons. The coat opening is a light wedge.
    pix.rect(cx - 2, 18 + bob, 4, 6, CREAM[4])
    pix.put(cx - 1, 19 + bob, CREAM[5])
    for by in (24, 27, 30):
        pix.rect(cx - 1, by + bob, 2, 2, (212, 168, 48))
        pix.put(cx - 1, by + bob, (255, 220, 120))
    pix.rect(cx - 6, hy - 1, 12, 2, LEATHER[2])
    pix.rect(cx - 1, hy - 1, 3, 2, IRON[4])
    # Satchel on the trailing hip. It sways against the stride.
    sx = cx - 12 + sway
    _shade_rect(pix, sx, 24 + bob, 7, 9, LEATHER)
    pix.rect(sx, 24 + bob, 7, 1, LEATHER[5])
    pix.rect(sx + 2, 27 + bob, 3, 3, IRON[3])
    pix.put(sx + 3, 28 + bob, IRON[5])
    pix.rect(sx + 5, 20 + bob, 1, 6, LEATHER[1])
    _limb(pix, cx + 5, sy, cx + 5 + hands[1][0], sy + hands[1][1], WOOL, 3)
    _hand(pix, cx + 5 + hands[1][0], sy + hands[1][1], SKIN_LIGHT)
    # A folded letter in the near hand on the passing frames.
    if frame_letter(hands):
        hx = cx + 5 + hands[1][0]
        hyh = sy + hands[1][1] + 2
        pix.rect(hx, hyh, 5, 4, CREAM[5])
        pix.rect(hx, hyh + 3, 5, 1, CREAM[2])
        pix.put(hx + 1, hyh, (180, 60, 60))
    _draw_head(pix, cx - 6, 5 + bob, "courier")


def frame_letter(hands: tuple[tuple[int, int], tuple[int, int]]) -> bool:
    return hands[1][1] < 11


def _gardener(pix: Pix, bob: int, steps: tuple[int, int], sway: int) -> None:
    cx = 24
    sy = 18 + bob
    # Basket arm (far / screen left) and the near arm, then the skirt hides the legs.
    _limb(pix, cx - 6, sy, cx - 10 + sway, sy + 12, ROSE, 3)
    _hand(pix, cx - 12 + sway, sy + 12, SKIN_WARM)
    _basket(pix, cx - 16 + sway, sy + 14)
    _torso(pix, cx - 6, 17 + bob, 12, 10, ROSE)
    # Shawl over the shoulders.
    _shade_rect(pix, cx - 8, 17 + bob, 16, 5, CREAM)
    pix.rect(cx - 8, 17 + bob, 16, 1, CREAM[5])
    pix.rect(cx - 8, 21 + bob, 16, 1, CREAM[1])
    pix.put(cx - 4, 19 + bob, CREAM[4])
    # Skirt flares, and it sways with the step.
    top = 26 + bob
    hem = 49 + bob
    for y in range(top, hem):
        t = (y - top) / max(1, hem - top)
        half = 5 + int(t * 7)
        shift = int(sway * t)
        for x in range(cx - half + shift, cx + half + shift + 1):
            nx = (x - cx - shift) / max(1, half)
            tone = 5 if nx < -0.4 and t < 0.3 else 1 if nx > 0.55 else 3
            if abs(x - (cx + shift)) <= 1:
                tone = min(6, tone + 2)
            pix.put(x, y, ROSE[tone])
    pix.rect(cx - 10 + sway, hem - 2, 20, 2, ROSE[0])
    pix.put(cx - 8 + sway, hem - 1, ROSE[4])
    # Shoes under the hem.
    _boot(pix, cx + steps[0] - 2, 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _limb(pix, cx + 5, sy, cx + 8, sy + 11, ROSE, 3)
    _hand(pix, cx + 7, sy + 11, SKIN_WARM)
    _draw_head(pix, cx - 6, 4 + bob, "gardener")


def _basket(pix: Pix, x: int, y: int) -> None:
    _shade_rect(pix, x, y, 10, 7, LEATHER)
    pix.rect(x, y, 10, 1, LEATHER[5])
    pix.rect(x + 1, y + 3, 8, 1, LEATHER[1])
    pix.rect(x, y + 6, 10, 1, LEATHER[0])
    # Three different blooms, so the basket is not a brown box.
    pix.put(x + 2, y - 1, (196, 48, 58))
    pix.put(x + 3, y - 2, (236, 150, 140))
    pix.put(x + 3, y - 1, (255, 210, 90))
    pix.put(x + 5, y - 2, (230, 190, 48))
    pix.put(x + 6, y - 1, (255, 236, 160))
    pix.put(x + 7, y - 2, (236, 236, 228))
    pix.put(x + 8, y - 1, (255, 214, 80))
    pix.put(x + 4, y - 3, GRASS[5])
    pix.put(x + 6, y - 3, GRASS[6])


def folk() -> Image.Image:
    sheet = Pix(CELL_W * FRAMES, CELL_H * PEOPLE)
    for person in range(PEOPLE):
        for frame in range(FRAMES):
            sheet.blit(_person(person, frame), frame * CELL_W, person * CELL_H)
    return sheet.image()


def opaque_stats(im: Image.Image) -> tuple[int, float]:
    """Unique opaque colors, and the share of the most common one."""
    counts: dict[tuple[int, int, int], int] = {}
    total = 0
    for px in im.getdata():
        if px[3] == 0:
            continue
        total += 1
        key = (px[0], px[1], px[2])
        counts[key] = counts.get(key, 0) + 1
    if total == 0:
        return 0, 0.0
    return len(counts), max(counts.values()) / total
