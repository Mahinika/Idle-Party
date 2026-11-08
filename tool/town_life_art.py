"""Ground and townsfolk for the town square.

Buildings stay in generate_town_art.py. This file is the lived-in ground
and the hero-resolution villagers. Source cells are 96×112. The game draws
them with nearest-neighbor down to about the party hero's height.

Owned pixels only. Deterministic.
"""
from __future__ import annotations

import math

from PIL import Image

INK = (32, 22, 18, 255)

CELL_W = 96
CELL_H = 112
FRAMES = 5
PEOPLE = 3

PLANT_W = 64
PLANT_H = 52


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


def band(light: float, n: int) -> int:
    # Hard steps. Upper-left is light.
    t = (light + 1.05) / 2.15
    return clamp(int(t * n), n)


def disc(pix: Pix, cx: int, cy: int, rx: int, ry: int, ramp: list[tuple[int, int, int]], y0: int | None = None, y1: int | None = None) -> None:
    for y in range(cy - ry, cy + ry + 1):
        if y0 is not None and y < y0:
            continue
        if y1 is not None and y >= y1:
            continue
        for x in range(cx - rx - 1, cx + rx + 2):
            nx = (x - cx) / max(1, rx)
            ny = (y - cy) / max(1, ry)
            wob = 0.06 * math.sin(x * 0.9 + y * 0.4)
            if nx * nx + ny * ny > 1.0 + wob:
                continue
            tone = band(0.05 - 0.72 * nx - 0.55 * ny, len(ramp))
            pix.put(x, y, ramp[tone])


def column(pix: Pix, x: int, y: int, w: int, h: int, ramp: list[tuple[int, int, int]]) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            nx = (xx - x) / max(1, w - 1) * 2 - 1
            ny = (yy - y) / max(1, h - 1)
            pix.put(xx, yy, ramp[band(0.15 - 0.8 * nx - 0.35 * ny, len(ramp))])


# Ramps, dark to light. Close to the hero paint: warm skin, wool, leather, iron.
SKIN = [
    (78, 46, 34),
    (112, 68, 48),
    (148, 96, 68),
    (186, 128, 92),
    (214, 160, 122),
    (236, 196, 162),
    (250, 226, 204),
]
HAIR_D = [
    (22, 12, 10),
    (42, 24, 16),
    (68, 38, 24),
    (98, 58, 34),
    (132, 82, 48),
    (168, 112, 68),
]
HAIR_L = [
    (62, 36, 18),
    (98, 58, 28),
    (138, 86, 40),
    (176, 118, 58),
    (208, 154, 86),
    (232, 190, 128),
]
HAIR_R = [
    (72, 28, 24),
    (112, 48, 36),
    (150, 72, 52),
    (186, 104, 74),
    (214, 140, 108),
    (236, 176, 148),
]
MOSS = [
    (22, 40, 32),
    (32, 62, 46),
    (44, 86, 60),
    (62, 112, 76),
    (88, 140, 96),
    (122, 168, 122),
    (164, 196, 154),
]
LEATHER = [
    (48, 28, 16),
    (78, 46, 26),
    (112, 68, 36),
    (146, 96, 52),
    (178, 128, 74),
    (210, 164, 108),
]
WOOL = [
    (28, 40, 68),
    (40, 58, 96),
    (56, 80, 124),
    (78, 106, 150),
    (108, 136, 176),
    (146, 170, 200),
    (186, 206, 220),
]
ROSE = [
    (78, 36, 48),
    (112, 52, 66),
    (148, 74, 90),
    (180, 104, 116),
    (206, 140, 146),
    (228, 178, 176),
    (244, 214, 206),
]
CREAM = [
    (120, 96, 72),
    (156, 128, 98),
    (190, 162, 128),
    (216, 192, 160),
    (234, 216, 190),
    (248, 238, 222),
]
IRON = [
    (24, 26, 30),
    (44, 48, 54),
    (70, 76, 84),
    (104, 112, 122),
    (148, 156, 166),
    (196, 204, 212),
    (230, 234, 236),
]
BOOT = [
    (18, 12, 10),
    (36, 24, 18),
    (58, 38, 28),
    (86, 58, 40),
    (120, 84, 58),
]
GRASS = [
    (42, 86, 46),
    (54, 104, 52),
    (68, 122, 58),
    (86, 140, 68),
    (112, 160, 82),
]
LEAF = [
    (18, 48, 26),
    (28, 74, 34),
    (42, 104, 44),
    (64, 132, 56),
    (96, 160, 72),
    (140, 186, 98),
]
STONE = [
    (70, 58, 44),
    (102, 84, 62),
    (136, 114, 84),
    (168, 146, 112),
    (198, 178, 144),
    (224, 208, 180),
]


def _eye(pix: Pix, x: int, y: int) -> None:
    pix.rect(x, y, 5, 3, (250, 244, 236))
    pix.rect(x + 2, y + 1, 2, 2, (36, 22, 28))
    pix.put(x + 1, y, (255, 255, 250))
    pix.put(x, y, SKIN[2])
    pix.rect(x, y - 1, 5, 1, SKIN[1])


def _head(pix: Pix, cx: int, top: int, hair: list[tuple[int, int, int]], style: str) -> None:
    disc(pix, cx, top + 16, 16, 15, SKIN)
    # Ears.
    column(pix, cx - 18, top + 14, 4, 6, SKIN)
    column(pix, cx + 15, top + 14, 4, 6, SKIN)
    pix.put(cx - 17, top + 16, SKIN[2])
    pix.put(cx + 17, top + 16, SKIN[1])
    # Neck shadow under the jaw.
    pix.rect(cx - 5, top + 28, 11, 3, SKIN[1])
    _eye(pix, cx - 11, top + 15)
    _eye(pix, cx + 4, top + 15)
    # Nose and mouth.
    pix.put(cx - 1, top + 20, SKIN[2])
    pix.put(cx, top + 21, SKIN[1])
    pix.rect(cx - 3, top + 24, 6, 1, (168, 96, 88))
    pix.put(cx - 2, top + 25, (120, 64, 60))
    pix.put(cx + 1, top + 25, (120, 64, 60))
    # Cheek.
    pix.put(cx - 8, top + 21, SKIN[5])
    pix.put(cx + 7, top + 21, SKIN[4])
    if style == "cap":
        disc(pix, cx, top + 8, 17, 10, hair, y1=top + 14)
        pix.rect(cx - 18, top + 10, 36, 4, hair[2])
        pix.rect(cx - 18, top + 10, 36, 1, hair[4])
        pix.rect(cx - 20, top + 13, 6, 3, hair[1])
        pix.rect(cx + 14, top + 13, 6, 3, hair[1])
        # Brim shadow on the brow.
        pix.rect(cx - 14, top + 13, 28, 2, hair[0])
    elif style == "bun":
        disc(pix, cx, top + 8, 16, 9, hair, y1=top + 16)
        disc(pix, cx + 10, top - 1, 7, 7, hair)
        pix.put(cx + 8, top - 4, hair[4])
        pix.put(cx + 12, top + 2, hair[1])
        # Side locks.
        column(pix, cx - 16, top + 12, 4, 12, hair)
        column(pix, cx + 13, top + 14, 3, 8, hair)
        pix.rect(cx - 8, top + 6, 6, 2, hair[4])
    else:
        disc(pix, cx, top + 7, 17, 10, hair, y1=top + 15)
        column(pix, cx - 17, top + 10, 4, 10, hair)
        column(pix, cx + 14, top + 11, 4, 8, hair)
        pix.rect(cx - 10, top + 4, 8, 2, hair[5] if len(hair) > 5 else hair[4])
        pix.put(cx - 12, top + 8, hair[4])
        # A couple of strands over the brow.
        pix.put(cx - 6, top + 13, hair[2])
        pix.put(cx - 5, top + 14, hair[1])
        pix.put(cx + 4, top + 13, hair[2])


def _boot(pix: Pix, x: int, y: int, w: int = 10) -> None:
    column(pix, x, y, w, 8, BOOT)
    pix.rect(x - 1, y + 6, w + 3, 3, BOOT[0])
    pix.rect(x, y + 6, w, 1, BOOT[3])
    pix.put(x + 1, y + 1, BOOT[4])


def _hand(pix: Pix, x: int, y: int) -> None:
    disc(pix, x + 2, y + 2, 3, 3, SKIN)
    pix.put(x + 4, y + 1, SKIN[5])
    pix.put(x, y + 3, SKIN[2])


def _leg(pix: Pix, x: int, hip: int, foot: int, ramp: list[tuple[int, int, int]]) -> None:
    h = max(6, foot - hip)
    # Thigh a little wider than the shin.
    column(pix, x, hip, 8, h // 2, ramp)
    column(pix, x + 1, hip + h // 2, 6, h - h // 2, ramp)
    pix.rect(x + 1, hip + h // 2, 6, 1, ramp[1])
    _boot(pix, x, foot - 2, 8)


def _arm(pix: Pix, x: int, y: int, reach: int, ramp: list[tuple[int, int, int]], forward: bool) -> None:
    # Upper arm, then a forearm that swings.
    column(pix, x, y, 6, 10, ramp)
    fx = x + (3 if forward else -2)
    fy = y + 8
    column(pix, fx, fy, 5, 8 + (1 if forward else 0), ramp)
    pix.rect(fx, fy, 5, 1, ramp[min(4, len(ramp) - 1)])
    _hand(pix, fx, fy + 7)


def _hammer(pix: Pix, x: int, y: int) -> None:
    column(pix, x + 6, y + 8, 4, 20, LEATHER)
    pix.rect(x + 6, y + 8, 4, 1, LEATHER[4])
    pix.rect(x, y, 18, 8, IRON[3])
    pix.rect(x, y, 18, 2, IRON[6])
    pix.rect(x, y + 6, 18, 2, IRON[1])
    pix.rect(x + 16, y, 2, 8, IRON[2])
    pix.put(x + 4, y + 3, IRON[6])
    pix.put(x + 10, y + 4, IRON[2])


def _person(pix: Pix, ox: int, oy: int, frame: int, kind: int) -> None:
    """One villager inside a 96×112 cell. Frame 0 idle, 1–4 walk, facing right."""
    if kind == 0:
        cloth, hair, style = MOSS, HAIR_D, "short"
    elif kind == 1:
        cloth, hair, style = WOOL, HAIR_L, "cap"
    else:
        cloth, hair, style = ROSE, HAIR_R, "bun"

    bob = {0: 0, 1: 0, 2: -2, 3: 0, 4: -1}[frame]
    cx = ox + 48
    top = oy + 10 + bob
    _head(pix, cx, top, hair, style)

    # Torso.
    column(pix, cx - 14, top + 30, 28, 28, cloth)
    # Shoulder light and side shadow already in column. Collar.
    pix.rect(cx - 8, top + 30, 16, 3, cloth[min(5, len(cloth) - 1)])
    pix.rect(cx - 3, top + 32, 6, 4, SKIN[3])
    # A neckerchief. The color break has to survive a 2:1 downsample.
    scarf = (150, 42, 48) if kind != 1 else (48, 72, 120)
    pix.rect(cx - 7, top + 29, 14, 4, scarf)
    pix.rect(cx - 2, top + 32, 4, 5, scarf)
    pix.put(cx - 5, top + 30, (210, 140, 130))
    # Sleeve cuffs happen with the arms.

    if kind == 0:
        # Leather apron, wider at the hem, with a strap and stitching.
        column(pix, cx - 11, top + 36, 22, 26, LEATHER)
        pix.rect(cx - 2, top + 32, 4, 8, LEATHER[3])
        pix.rect(cx - 10, top + 36, 20, 1, LEATHER[5])
        for sy in range(top + 42, top + 58, 4):
            pix.put(cx - 8, sy, LEATHER[1])
            pix.put(cx + 7, sy, LEATHER[0])
        pix.put(cx - 1, top + 48, LEATHER[1])
        pix.put(cx, top + 52, LEATHER[0])
    elif kind == 1:
        # Coat opening and buttons.
        for by in (top + 38, top + 44, top + 50):
            pix.rect(cx - 1, by, 3, 3, IRON[4])
            pix.put(cx, by, IRON[6])
        pix.rect(cx - 12, top + 54, 24, 3, LEATHER[2])
        pix.rect(cx - 3, top + 54, 7, 4, IRON[3])
        pix.rect(cx - 3, top + 54, 7, 1, IRON[6])
        pix.put(cx, top + 56, IRON[1])
        # Satchel.
        column(pix, cx - 24, top + 40, 12, 16, LEATHER)
        pix.rect(cx - 24, top + 40, 12, 2, LEATHER[5])
        pix.rect(cx - 22, top + 46, 6, 4, IRON[3])
        pix.put(cx - 20, top + 47, IRON[6])
        pix.rect(cx - 18, top + 34, 2, 8, LEATHER[1])
    else:
        # Shawl over the shoulders, skirt starts lower.
        column(pix, cx - 16, top + 30, 32, 8, CREAM)
        pix.rect(cx - 16, top + 30, 32, 2, CREAM[5])
        pix.rect(cx - 16, top + 36, 32, 1, CREAM[1])
        pix.put(cx - 6, top + 33, CREAM[4])

    # A fold down the lit side, and a pocket. Two pixels wide so the downsample keeps it.
    pix.rect(cx - 8, top + 36, 2, 16, cloth[1])
    pix.rect(cx + 6, top + 38, 2, 12, cloth[min(5, len(cloth) - 1)])
    pix.rect(cx - 4, top + 46, 8, 6, cloth[2])
    pix.rect(cx - 4, top + 46, 8, 1, cloth[4])
    pix.put(cx - 2, top + 48, cloth[0])

    # Arms. The leading arm is the one away from the front foot.
    lead = {0: False, 1: True, 2: False, 3: False, 4: True}[frame]
    _arm(pix, cx - 20, top + 32, 0, cloth, forward=not lead)
    _arm(pix, cx + 14, top + 32, 0, cloth, forward=lead)

    if kind == 0:
        _hammer(pix, cx + 22, top + 40 + (2 if lead else 0))
    if kind == 2:
        # Basket on the near side, with two apples.
        bx, by = cx - 28, top + 46
        column(pix, bx, by, 16, 12, LEATHER)
        pix.rect(bx, by, 16, 2, LEATHER[5])
        pix.rect(bx + 1, by + 4, 14, 1, LEATHER[1])
        pix.rect(bx + 1, by + 8, 14, 1, LEATHER[1])
        disc(pix, bx + 5, by - 2, 3, 3, [(140, 32, 36), (176, 52, 48), (210, 84, 72), (232, 120, 100)])
        pix.put(bx + 4, by - 4, LEAF[5])
        disc(pix, bx + 11, by - 1, 3, 3, [(150, 40, 40), (190, 64, 56), (220, 100, 80), (240, 140, 110)])

    # Both boots share the ground line. Only the step changes.
    ground = oy + 96 + bob
    steps = {
        0: (-14, 2),
        1: (-20, 10),
        2: (-12, 0),
        3: (-6, 14),
        4: (-10, 4),
    }
    trouser = LEATHER if kind == 0 else WOOL
    if kind == 2:
        sway = {0: 0, 1: -4, 2: -1, 3: 4, 4: 1}[frame]
        for y in range(top + 52, ground - 6):
            flare = (y - (top + 52)) // 5
            half = 13 + flare
            for x in range(cx - half + sway, cx + half + sway + 1):
                nx = (x - cx - sway) / max(1, half)
                pix.put(x, y, ROSE[band(0.15 - 0.7 * nx - 0.25 * ((y - top) / 40), len(ROSE))])
        # Hem fold and a lighter overskirt panel.
        pix.rect(cx - 16 + sway, ground - 8, 32, 2, ROSE[1])
        pix.rect(cx - 6 + sway, top + 56, 4, 18, ROSE[4])
        left, right = steps[frame]
        _boot(pix, cx + left + sway, ground - 8, 10)
        _boot(pix, cx + right + sway, ground - 8, 10)
    else:
        hip = top + 50
        left, right = steps[frame]
        _leg(pix, cx + left, hip, ground, trouser)
        _leg(pix, cx + right, hip, ground, trouser)
        # Belt over the hips so the legs meet the torso.
        pix.rect(cx + left, hip - 2, 22, 3, LEATHER[1])
        pix.rect(cx - 2, hip - 2, 6, 3, IRON[3])
        pix.rect(cx - 2, hip - 2, 6, 1, IRON[6])
        column(pix, cx - 16, hip, 8, 9, LEATHER)
        pix.rect(cx - 16, hip, 8, 2, LEATHER[5])
        pix.put(cx - 13, hip + 3, IRON[4])

    # One dark pixel under each boot. No floating bars.
    pix.put(cx + steps[frame][0] + 3, ground + 2, (30, 48, 32))
    pix.put(cx + steps[frame][1] + 3, ground + 2, (24, 40, 26))


def folk() -> Image.Image:
    pix = Pix(CELL_W * FRAMES, CELL_H * PEOPLE)
    for person in range(PEOPLE):
        for frame in range(FRAMES):
            _person(pix, frame * CELL_W, person * CELL_H, frame, person)
    pix.outline()
    return pix.image()


def ground() -> Image.Image:
    """Quiet meadow. No tuft stamp and no oval spots. Life sits in the plantings."""
    pix = Pix(160, 160)
    pix.rect(0, 0, 160, 160, GRASS[2])
    return pix.image()


def _stone(pix: Pix, x: int, y: int, w: int, h: int, tone: int) -> None:
    ramp = STONE
    pix.rect(x, y, w, h, ramp[tone])
    pix.rect(x, y, max(1, w - 1), 1, ramp[min(tone + 1, 5)])
    pix.rect(x, y + h - 1, w, 1, ramp[0])
    pix.put(x + w - 1, y + 1, ramp[1])
    if w > 6:
        pix.put(x + 2, y + 1, ramp[min(tone + 2, 5)])


def path() -> Image.Image:
    """Stepping stones that widen through the yard. Gaps stay grass. Not a bar."""
    pix = Pix(360, 40)
    stones = (
        (4, 16, 12, 8, 2), (18, 18, 10, 7, 3), (34, 14, 8, 9, 4),
        (58, 18, 14, 8, 3), (74, 16, 9, 7, 2),
        (100, 12, 16, 10, 3), (118, 14, 12, 8, 4), (132, 10, 14, 9, 2),
        (148, 16, 18, 10, 3), (168, 12, 16, 11, 4), (186, 18, 14, 8, 2),
        (204, 14, 12, 9, 3),
        (230, 16, 14, 8, 3), (246, 14, 10, 9, 2), (260, 18, 12, 7, 4),
        (286, 16, 11, 8, 3), (304, 18, 14, 7, 2), (322, 15, 10, 8, 4),
        (340, 17, 12, 8, 3),
        (108, 24, 10, 7, 2), (124, 26, 12, 6, 3), (150, 24, 14, 7, 4),
        (170, 26, 11, 6, 2), (196, 24, 12, 7, 3),
    )
    for x, y, w, h, tone in stones:
        _stone(pix, x, y, w, h, tone)
    for x, y in ((48, 20), (90, 22), (220, 20), (278, 22), (352, 20)):
        pix.put(x, y, STONE[4])
        pix.put(x + 1, y, STONE[2])
    for x, y in ((26, 12), (88, 12), (226, 12), (300, 12), (16, 28), (80, 30), (240, 32), (330, 30)):
        pix.put(x, y, GRASS[4])
        pix.put(x + 1, y, LEAF[3])
    return pix.image()


def worn() -> Image.Image:
    """A small worn patch in front of a door. Not a second full-width strip."""
    pix = Pix(72, 28)
    stones = ((2, 8, 12, 8), (16, 6, 10, 9), (28, 10, 14, 7), (44, 7, 11, 8), (56, 11, 12, 7))
    for i, (x, y, w, h) in enumerate(stones):
        _stone(pix, x, y, w, h, 2 + (i % 3))
    pix.put(8, 6, GRASS[4])
    pix.put(9, 6, GRASS[3])
    pix.put(50, 18, GRASS[3])
    pix.put(22, 18, (96, 72, 48))
    pix.put(23, 18, (120, 90, 60))
    return pix.image()


def _soil(pix: Pix, cx: int, cy: int) -> None:
    disc(pix, cx, cy, 22, 7, [
        GRASS[1],
        (92, 64, 40),
        (120, 84, 52),
        (150, 108, 68),
        (176, 132, 88),
    ])
    pix.put(cx - 16, cy + 2, GRASS[3])
    pix.put(cx + 14, cy + 1, GRASS[2])
    pix.put(cx - 4, cy + 3, (70, 48, 32))


def _bloom(pix: Pix, x: int, y: int, color: tuple[int, int, int], hi: tuple[int, int, int]) -> None:
    pix.put(x, y, color)
    pix.put(x - 1, y + 1, color)
    pix.put(x + 1, y + 1, color)
    pix.put(x, y + 1, hi)
    pix.put(x, y + 2, color)
    pix.put(x - 1, y, hi)


def flowers() -> Image.Image:
    """Rose bed. One of four different plantings."""
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 32, 40)
    stems = ((14, 12), (24, 18), (34, 10), (46, 16))
    colors = ((176, 48, 58), (196, 72, 78), (150, 40, 64), (210, 96, 90))
    his = ((230, 140, 130), (240, 170, 150), (210, 120, 130), (250, 190, 170))
    for i, (sx, bloom_y) in enumerate(stems):
        pix.rect(sx, bloom_y + 6, 2, 28 - bloom_y, LEAF[2])
        pix.put(sx - 3, bloom_y + 12, LEAF[4])
        pix.put(sx + 3, bloom_y + 14, LEAF[5])
        pix.put(sx - 2, bloom_y + 8, LEAF[3])
        _bloom(pix, sx, bloom_y, colors[i], his[i])
        _bloom(pix, sx + 3, bloom_y + 4, colors[(i + 1) % 4], his[i])
    pix.outline()
    return pix.image()


def shrub() -> Image.Image:
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 32, 42)
    disc(pix, 32, 28, 20, 14, LEAF)
    disc(pix, 20, 30, 12, 10, LEAF)
    disc(pix, 44, 32, 10, 8, LEAF)
    for x, y, t in ((18, 22, 5), (30, 16, 5), (42, 20, 4), (26, 34, 1), (38, 30, 2)):
        pix.put(x, y, LEAF[t])
        pix.put(x + 1, y, LEAF[min(t + 1, 5)])
    pix.outline()
    return pix.image()


def wild() -> Image.Image:
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 32, 40)
    specs = (
        (14, (230, 220, 190), (255, 248, 230)),
        (24, (220, 180, 70), (255, 220, 120)),
        (34, (200, 90, 140), (236, 160, 180)),
        (44, (236, 230, 210), (255, 250, 240)),
        (52, (190, 70, 70), (230, 130, 110)),
    )
    for sx, col, hi in specs:
        pix.rect(sx, 24, 1, 14, LEAF[3])
        pix.put(sx - 2, 30, LEAF[4])
        pix.put(sx + 2, 28, LEAF[2])
        _bloom(pix, sx, 18, col, hi)
    pix.outline()
    return pix.image()


def contact() -> Image.Image:
    """A short darker grass shadow. Buildings sit on it."""
    pix = Pix(96, 12)
    runs = ((6, 22, 4), (30, 28, 3), (62, 24, 5), (18, 14, 6), (48, 16, 5))
    for x, w, y in runs:
        for i in range(w):
            pix.put(x + i, y, (28, 58, 32, 170))
            if i % 3 != 0:
                pix.put(x + i, y + 1, (40, 74, 42, 120))
    return pix.image()


def meadow() -> Image.Image:
    """One clump for the upper lawn. Not a tile."""
    pix = Pix(112, 64)
    disc(pix, 58, 46, 40, 12, [
        GRASS[1],
        (78, 58, 34),
        (108, 78, 46),
        (86, 120, 58),
        GRASS[3],
    ])
    blades = (
        (16, 18, 28), (24, 8, 36), (34, 22, 20), (44, 12, 30),
        (70, 6, 34), (80, 16, 24), (92, 10, 32), (52, 20, 18),
    )
    tones = (LEAF[2], LEAF[3], LEAF[4], LEAF[5], GRASS[4])
    for i, (x, top, h) in enumerate(blades):
        pix.rect(x, top, 2, h, tones[i % len(tones)])
        pix.put(x, top, LEAF[5])
        pix.put(x - 1, top + 4, LEAF[4])
    _bloom(pix, 30, 14, (190, 60, 70), (236, 150, 140))
    _bloom(pix, 74, 8, (230, 200, 90), (255, 236, 160))
    _bloom(pix, 88, 20, (210, 90, 140), (245, 170, 190))
    _stone(pix, 46, 40, 12, 7, 3)
    pix.outline()
    return pix.image()


def thicket() -> Image.Image:
    pix = Pix(88, 56)
    disc(pix, 40, 36, 28, 14, LEAF)
    disc(pix, 58, 40, 16, 10, LEAF)
    for x, y, t in ((22, 24, 5), (36, 16, 5), (50, 22, 4), (64, 30, 5), (30, 34, 1)):
        pix.put(x, y, LEAF[t])
        pix.put(x + 1, y, LEAF[min(t + 1, 5)])
    # Tall grass on one side only, so it is not a second shrub ball.
    for x, h in ((8, 22), (12, 30), (16, 16)):
        pix.rect(x, 40 - h, 2, h, GRASS[4])
        pix.put(x, 40 - h, LEAF[5])
    _stone(pix, 62, 42, 10, 6, 2)
    pix.outline()
    return pix.image()


def scuff() -> Image.Image:
    """Bare earth and two loose stones. A worn spot, not a path."""
    pix = Pix(72, 36)
    disc(pix, 34, 20, 26, 10, [
        GRASS[2],
        (96, 72, 44),
        (128, 96, 60),
        (160, 122, 78),
        GRASS[3],
    ])
    _stone(pix, 14, 14, 10, 7, 3)
    _stone(pix, 44, 18, 14, 8, 4)
    pix.put(22, 12, GRASS[4])
    pix.put(40, 10, LEAF[3])
    pix.outline()
    return pix.image()


def herbs() -> Image.Image:
    pix = Pix(PLANT_W, PLANT_H)
    _soil(pix, 30, 40)
    for sx, h in ((18, 16), (26, 20), (34, 14), (42, 18)):
        pix.rect(sx, 36 - h, 2, h, LEAF[3])
        pix.put(sx - 1, 36 - h + 2, LEAF[5])
        pix.put(sx + 2, 36 - h + 4, LEAF[4])
        pix.put(sx, 36 - h, LEAF[5])
    _stone(pix, 46, 36, 10, 7, 3)
    pix.outline()
    return pix.image()
