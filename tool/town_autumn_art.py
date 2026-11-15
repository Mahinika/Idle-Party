"""Autumn dusk pieces for the town square.

Owner target: `docs/art/TOWN_AUTUMN_DUSK.md` (variant B, misty autumn
dusk). This module owns the cobble square, the autumn plantings, the dusk
sky, the campfire, the round vault door, jack-o-lanterns, and the dusk
grade every sprite goes through. Owned pixels only. Deterministic: no RNG.
"""
from __future__ import annotations

import math

from PIL import Image

import town_life_art as life

INK = (32, 22, 18, 255)
Pix = life.Pix

# Cool dusk cobbles. Dark → light. Light still comes from the upper left.
COBBLE = [
    (30, 25, 32),
    (40, 34, 42),
    (50, 43, 50),
    (60, 52, 58),
    (72, 62, 66),
    (86, 74, 76),
    (102, 88, 88),
]
COBBLE_WARM = [
    (34, 26, 28),
    (46, 35, 36),
    (58, 44, 42),
    (70, 54, 50),
    (84, 64, 58),
    (100, 78, 68),
    (118, 92, 80),
]
MORTAR = (24, 19, 26)

LEAF_RED = [(92, 20, 24), (146, 34, 30), (196, 58, 36), (228, 96, 60)]
LEAF_ORANGE = [(140, 56, 20), (198, 96, 30), (236, 142, 48), (252, 190, 96)]
LEAF_GOLD = [(150, 96, 24), (206, 150, 44), (240, 196, 80), (252, 230, 150)]
LEAF_BROWN = [(70, 40, 28), (104, 62, 36), (140, 90, 50), (176, 124, 70)]
LEAVES = (LEAF_RED, LEAF_ORANGE, LEAF_GOLD, LEAF_BROWN)

PUMPKIN = [(92, 34, 16), (140, 56, 18), (190, 86, 24), (226, 124, 38), (248, 168, 72), (255, 206, 128)]
STEM = [(40, 44, 22), (66, 74, 32), (98, 104, 44)]
GLOW = [(214, 120, 30), (255, 186, 64), (255, 226, 130), (255, 246, 206)]
STRAW = [(110, 74, 30), (150, 108, 42), (190, 146, 60), (222, 184, 92), (244, 218, 140)]
WOOD = [(38, 22, 16), (62, 38, 24), (90, 56, 32), (122, 80, 44), (156, 108, 62)]
IRON = [(22, 22, 30), (40, 40, 50), (62, 62, 74), (92, 92, 106), (132, 132, 146), (184, 184, 194)]
GOLD = [(96, 58, 18), (140, 92, 28), (190, 134, 42), (226, 176, 70), (248, 216, 128), (255, 242, 196)]
FIRE = [(110, 24, 14), (170, 44, 16), (218, 82, 22), (244, 132, 34), (255, 184, 64), (255, 228, 140), (255, 250, 220)]

# Pixels that stay lit when the dusk grade runs. Windows, fire, glowing faces.
EMISSIVE: set[tuple[int, int, int]] = set(GLOW) | set(FIRE[2:]) | set(GOLD[4:])


def add_emissive(colors) -> None:
    for c in colors:
        EMISSIVE.add(tuple(c[:3]))


# --- Dusk grade -------------------------------------------------------------


def dusk_grade(img: Image.Image, strength: float = 1.0) -> Image.Image:
    """Purple shade, warm lights kept. Ink stays ink.

    A per-pixel multiply toward a cool violet, so every sprite sits in the
    same evening light. Emissive colors are not touched.
    """
    src = img.convert("RGBA")
    out = Image.new("RGBA", src.size)
    data = []
    mr, mg, mb = 1 - 0.06 * strength, 1 - 0.13 * strength, 1 - 0.05 * strength
    ar, ag, ab = 2 * strength, 0, 8 * strength
    for r, g, b, a in src.getdata():
        if a == 0:
            data.append((0, 0, 0, 0))
            continue
        rgb = (r, g, b)
        if rgb in EMISSIVE or rgb == INK[:3]:
            data.append((r, g, b, a))
            continue
        data.append(
            (
                min(255, int(r * mr + ar)),
                min(255, int(g * mg + ag)),
                min(255, int(b * mb + ab)),
                a,
            )
        )
    out.putdata(data)
    return out


# --- Small props -------------------------------------------------------------


def leaf(pix: Pix, x: int, y: int, kind: int, wrap: bool = False) -> None:
    """A three-tone fallen leaf, 3-4 px. kind picks color and pose."""
    ramp = LEAVES[kind % len(LEAVES)]
    put = pix.put_wrap if wrap else pix.put
    pose = kind % 3
    if pose == 0:
        cells = ((0, 0, 2), (1, 0, 3), (1, 1, 1), (2, 1, 2), (0, 1, 1))
    elif pose == 1:
        cells = ((1, 0, 3), (0, 1, 2), (1, 1, 2), (2, 1, 1), (1, 2, 0))
    else:
        cells = ((0, 0, 3), (1, 0, 2), (2, 0, 2), (1, 1, 1), (3, 1, 0))
    for dx, dy, tone in cells:
        put(x + dx, y + dy, ramp[tone])


def pumpkin(pix: Pix, x: int, y: int, w: int = 12, h: int = 9, lit: bool = False) -> None:
    """Ribbed pumpkin. (x, y) is the top-left. lit carves a glowing face."""
    cx = x + w / 2 - 0.5
    cy = y + h / 2
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            nx = (xx - cx) / (w / 2)
            ny = (yy - cy) / (h / 2)
            if nx * nx + ny * ny > 1.02:
                continue
            light = -0.6 * nx - 0.5 * ny
            tone = 2 + (1 if light > 0.15 else 0) + (1 if light > 0.6 else 0) - (1 if ny > 0.55 else 0)
            # Ribs: darker columns at even spacing.
            rib = int((xx - x) * 4 / max(1, w))
            if abs((xx - x) - rib * w / 4) < 0.6 and 0 < xx - x < w - 1:
                tone -= 1
            pix.put(xx, yy, PUMPKIN[max(0, min(5, tone))])
    sx = int(cx)
    pix.put(sx, y - 1, STEM[1])
    pix.put(sx + 1, y - 2, STEM[2])
    pix.put(sx, y - 2, STEM[0])
    pix.put(sx - 1, y, STEM[2])
    if lit:
        ey = y + h // 3
        # Triangle eyes, a toothy grin. Hard glow pixels.
        for ex in (x + w // 4, x + w - w // 4 - 2):
            pix.put(ex, ey, GLOW[1])
            pix.put(ex + 1, ey, GLOW[2])
            pix.put(ex, ey + 1, GLOW[2])
            pix.put(ex + 1, ey + 1, GLOW[3])
        my = y + h - h // 3 - 1
        for mx in range(x + 2, x + w - 2):
            pix.put(mx, my, GLOW[2] if mx % 2 else GLOW[1])
            if mx % 2 == 0:
                pix.put(mx, my + 1, GLOW[1])
        pix.put(int(cx), ey + 2, GLOW[1])


def lantern_post(pix: Pix, x: int, base: int, h: int) -> None:
    """Iron lamp post with a lit lantern on top. (x, base) is the foot."""
    pix.rect(x, base - h, 2, h, IRON[2])
    pix.rect(x, base - h, 1, h, IRON[3])
    pix.rect(x - 2, base - 2, 6, 2, IRON[1])
    top = base - h
    pix.rect(x - 3, top - 2, 8, 1, IRON[3])
    pix.rect(x - 3, top - 11, 8, 9, IRON[1])
    pix.rect(x - 2, top - 10, 6, 7, GLOW[1])
    pix.rect(x - 1, top - 9, 4, 5, GLOW[2])
    pix.put(x, top - 8, GLOW[3])
    pix.put(x + 1, top - 7, GLOW[3])
    pix.rect(x - 4, top - 13, 10, 2, IRON[2])
    pix.put(x, top - 14, IRON[3])
    pix.put(x + 1, top - 14, IRON[3])


def basket(pix: Pix, x: int, y: int) -> None:
    for row in range(6):
        inset = 0 if row < 4 else row - 3
        for xx in range(x + inset, x + 12 - inset):
            tone = 3 if (xx + row) % 2 == 0 else 2
            if row == 0:
                tone = 4
            pix.put(xx, y + row, STRAW[tone])
    for ax, ay, red in ((x + 2, y - 3, True), (x + 5, y - 4, False), (x + 8, y - 3, True)):
        body = (168, 40, 40) if red else (196, 150, 50)
        pix.rect(ax, ay, 3, 3, body)
        pix.put(ax, ay, (220, 110, 90) if red else (240, 210, 110))
        pix.put(ax + 2, ay + 2, (100, 24, 28) if red else (130, 90, 30))
    pix.rect(x + 1, y - 6, 1, 5, STRAW[1])
    pix.rect(x + 10, y - 6, 1, 5, STRAW[1])
    pix.rect(x + 1, y - 7, 10, 1, STRAW[2])


def leaf_pile(pix: Pix, cx: int, cy: int, rx: int, ry: int, seed: int = 0) -> None:
    """A mound of separate leaves, stamped back to front. Not a smear."""
    # Dark bed first so gaps read as shade inside the pile.
    for y in range(cy - ry // 2, cy + ry // 2 + 1):
        for x in range(cx - rx + 2, cx + rx - 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / (ry / 2)) ** 2 <= 1:
                pix.put(x, y, LEAF_BROWN[0])
    k = 0
    for y in range(cy - ry, cy + ry // 2 + 1, 2):
        for x in range(cx - rx, cx + rx, 3):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            if nx * nx + ny * ny * 1.6 > 1:
                continue
            h = life._hash(x + seed, y)
            if h % 4 == 0:
                continue
            leaf(pix, x + (h % 2), y, h % 11)
            k += 1


def hay_bale(pix: Pix, x: int, y: int, w: int = 22, h: int = 14) -> None:
    for yy in range(h):
        for xx in range(w):
            tone = 2 + (1 if yy < 3 else 0) - (1 if yy > h - 4 else 0)
            if (xx * 3 + yy) % 5 == 0:
                tone += 1
            if (xx + yy * 2) % 7 == 0:
                tone -= 1
            pix.put(x + xx, y + yy, STRAW[max(0, min(4, tone))])
    for bx in (x + w // 4, x + w - w // 4):
        pix.rect(bx, y, 1, h, WOOD[1])


# --- Ground ------------------------------------------------------------------


GROUND_TILE = 64
# Rows are short so the square reads as ground seen from above at a slant,
# not as a wall. Widths sum to 64 per row so each row wraps.
_ROW_W = (7, 6, 8, 5, 7, 6, 8, 6, 5, 6)


def _stone(pix: Pix, x: int, y: int, w: int, h: int, tone: int, ramp, wrap: bool = True) -> None:
    put = pix.put_wrap if wrap else pix.put
    for yy in range(h):
        for xx in range(w):
            corner = (xx in (0, w - 1)) and (yy in (0, h - 1))
            if corner:
                continue
            t = tone
            if yy == 0 and 0 < xx < w - 2:
                t += 1
            if yy == h - 1:
                t -= 1
            put(x + xx, y + yy, ramp[max(0, min(len(ramp) - 1, t))])
    if w > 4:
        put(x + 1, y, ramp[min(len(ramp) - 1, tone + 2)])


def ground() -> Image.Image:
    """Seamless 64 px dusk cobbles with fallen leaves. Every mark wraps.

    Low contrast on purpose: the buildings, fire, and people carry the
    picture. The square is a dark bed for them, like the target.
    """
    w = h = GROUND_TILE
    pix = Pix(w, h)
    for y in range(h):
        for x in range(w):
            pix.put(x, y, MORTAR)
    rows = h // 5 + 1
    row_h = h / rows
    for row in range(rows):
        y = int(round(row * row_h)) + 2
        hh_row = int(round((row + 1) * row_h)) - int(round(row * row_h))
        x = (row * 29) % w
        widths = [_ROW_W[(i + row * 3) % len(_ROW_W)] for i in range(len(_ROW_W))]
        for i, sw in enumerate(widths):
            hh = life._hash(row * 11 + i, 5)
            tone = 2 + (hh % 3 == 0)
            ramp = COBBLE_WARM if hh % 4 == 0 else COBBLE
            _stone(pix, x, y, sw - 1, hh_row - 1, tone, ramp)
            x += sw
    spots = (
        (6, 5), (40, 13), (22, 30), (55, 38), (12, 50), (34, 58), (50, 22),
        (28, 4), (60, 54), (2, 26), (44, 46), (18, 16),
    )
    for k, (lx, ly) in enumerate(spots):
        leaf(pix, lx, ly, (0, 1, 3, 0, 1, 2)[k % 6] + 4 * (k % 2), wrap=True)
    return pix.image()


def assert_ground(img: Image.Image) -> None:
    n, top = life.opaque_stats(img)
    if n < 8 or top > 0.6:
        raise SystemExit(f"ground.png is too flat colors={n} top={top:.3f}")
    if img.size != (GROUND_TILE, GROUND_TILE):
        raise SystemExit("ground tile size changed")


def contact() -> Image.Image:
    """Shade on cobbles under a wall. Gapped, so the stones show through."""
    pix = Pix(64, 16)
    for x0, bw in ((2, 12), (16, 14), (32, 10), (46, 16)):
        for i in range(bw):
            if i % 4 == 3:
                continue
            pix.put(x0 + i, 12, (26, 20, 30))
            if i % 2 == 0:
                pix.put(x0 + i, 13, (20, 16, 24))
            if i % 3 == 0:
                pix.put(x0 + i, 11, (40, 32, 44))
    for k, (lx, ly) in enumerate(((6, 9), (24, 8), (40, 10), (54, 8))):
        leaf(pix, lx, ly, k + 1)
    return pix.image()


# --- Plantings (64×52 unless noted) ------------------------------------------


def pumpkin_patch() -> Image.Image:
    """flowers.png: a pumpkin patch with one jack-o-lantern."""
    pix = Pix(life.PLANT_W, life.PLANT_H)
    # Vines.
    for x in range(6, 58):
        y = 44 + int(2 * math.sin(x * 0.35))
        pix.put(x, y, STEM[1])
        if x % 6 == 0:
            pix.rect(x - 1, y - 3, 3, 2, STEM[2])
            pix.put(x, y - 1, STEM[0])
    pumpkin(pix, 6, 32, 16, 12)
    pumpkin(pix, 38, 34, 14, 10)
    pumpkin(pix, 20, 26, 20, 16, lit=True)
    leaf(pix, 4, 46, 0)
    leaf(pix, 54, 45, 2)
    pix.outline()
    return pix.image()


def autumn_bush() -> Image.Image:
    """shrub.png: rust and red leaves, a few gold catchlights."""
    pix = Pix(life.PLANT_W, life.PLANT_H)
    ramp = [(56, 18, 22), (90, 26, 26), (130, 40, 30), (172, 62, 34), (210, 96, 44), (238, 140, 60), (252, 188, 96)]
    clumps = ((32, 28, 17, 13, 3), (17, 33, 10, 9, 2), (47, 33, 11, 8, 4), (32, 19, 9, 7, 5))
    for cx, cy, rx, ry, bias in clumps:
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                nx = (x - cx) / max(1, rx)
                ny = (y - cy) / max(1, ry)
                if nx * nx + ny * ny > 1:
                    continue
                if (x * 5 + y * 3) % 13 == 0:
                    continue
                tone = bias + (1 if nx < -0.2 and ny < 0 else 0) - (1 if ny > 0.4 else 0)
                if (x + y * 2) % 9 == 0:
                    tone += 1
                pix.put(x, y, ramp[max(0, min(6, tone))])
    for bx, by in ((22, 26), (34, 16), (44, 26), (28, 34)):
        pix.put(bx, by, LEAF_GOLD[3])
        pix.put(bx + 1, by + 1, LEAF_GOLD[1])
    pix.outline()
    return pix.image()


def corn_sheaf() -> Image.Image:
    """wild.png: a tied sheaf of dry corn stalks."""
    pix = Pix(life.PLANT_W, life.PLANT_H)
    for i, sx in enumerate(range(18, 46, 3)):
        lean = (sx - 32) // 5
        top = 6 + (i * 5) % 9
        for y in range(top, 48):
            t = (y - top) / max(1, 48 - top)
            x = sx + int(lean * (1 - t) * 2)
            pix.put(x, y, STRAW[2 + (i % 2)])
            if y % 5 == i % 5 and y < 36:
                pix.put(x + (1 if i % 2 else -1), y, STRAW[4])
                pix.put(x + (2 if i % 2 else -2), y + 1, STRAW[3])
        pix.put(sx + lean * 2, top, STRAW[4])
    # Tie.
    pix.rect(22, 30, 22, 3, WOOD[2])
    pix.rect(22, 30, 22, 1, WOOD[4])
    pumpkin(pix, 40, 40, 12, 8)
    pix.outline()
    return pix.image()


def hay_and_basket() -> Image.Image:
    """herbs.png: a hay bale and a basket of apples."""
    pix = Pix(life.PLANT_W, life.PLANT_H)
    hay_bale(pix, 6, 30, 26, 16)
    basket(pix, 36, 38)
    pumpkin(pix, 14, 22, 10, 8)
    leaf(pix, 50, 46, 0)
    pix.outline()
    return pix.image()


def harvest_pile() -> Image.Image:
    """meadow.png (112×64): a leaf pile, pumpkins, and a basket."""
    pix = Pix(112, 64)
    leaf_pile(pix, 56, 50, 40, 12, seed=3)
    pumpkin(pix, 18, 38, 18, 13)
    pumpkin(pix, 70, 36, 22, 16, lit=True)
    basket(pix, 44, 44)
    for k, (lx, ly) in enumerate(((8, 56), (98, 54), (30, 58), (86, 58))):
        leaf(pix, lx, ly, k)
    pix.outline()
    return pix.image()


def lamp_and_bramble() -> Image.Image:
    """thicket.png (88×56): an iron lamp post in a red bramble."""
    pix = Pix(88, 56)
    ramp = [(48, 16, 22), (80, 24, 26), (118, 38, 30), (160, 56, 34), (204, 90, 44)]
    for cx, cy, rx, ry in ((30, 42, 16, 9), (54, 44, 12, 7), (16, 46, 9, 6)):
        for y in range(cy - ry, cy + ry):
            for x in range(cx - rx, cx + rx):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1:
                    continue
                tone = 2 + (x + y) % 3 - (1 if y > cy + ry // 2 else 0)
                pix.put(x, y, ramp[max(0, min(4, tone))])
    lantern_post(pix, 66, 54, 30)
    pumpkin(pix, 70, 44, 12, 9, lit=True)
    pix.outline()
    return pix.image()


def leaf_scatter() -> Image.Image:
    """scuff.png (72×36): leaves blown across the stones."""
    pix = Pix(72, 36)
    spots = ((6, 10), (16, 18), (26, 8), (34, 22), (44, 14), (54, 24), (62, 12), (20, 28), (48, 30), (10, 24))
    for k, (x, y) in enumerate(spots):
        leaf(pix, x, y, k)
    return pix.image()


# --- Campfire ----------------------------------------------------------------


def campfire() -> Image.Image:
    """56×68: stone ring, crossed logs, a tall flame. Same rect as the old well."""
    pix = Pix(56, 68)
    # Ring stones, an ellipse of separate rocks.
    for i in range(14):
        a = i / 14 * math.tau
        sx = int(28 + 22 * math.cos(a)) - 3
        sy = int(56 + 7 * math.sin(a)) - 2
        tone = 3 if math.sin(a) < 0 else 2
        _stone(pix, sx, sy, 7, 5, tone, COBBLE, wrap=False)
    # Ash bed.
    for y in range(52, 61):
        for x in range(10, 47):
            if ((x - 28) / 17) ** 2 + ((y - 56) / 4.5) ** 2 <= 1:
                pix.put(x, y, (52, 36, 36) if (x + y) % 3 else (86, 44, 30))
    # Logs, crossed.
    for k in range(20):
        pix.rect(14 + k, 54 - k // 4, 2, 3, WOOD[2 + (k % 2)])
        pix.rect(40 - k, 54 - k // 4, 2, 3, WOOD[1 + (k % 2)])
    pix.put(14, 54, WOOD[4])
    pix.put(41, 54, WOOD[4])
    # Flame: stacked lobes, hottest in the middle.
    for y in range(14, 54):
        t = (54 - y) / 40
        half = int(13 * (1 - t) ** 0.8 * (0.75 + 0.25 * math.sin(y * 0.9)))
        lean = int(2 * math.sin(y * 0.3))
        for x in range(28 - half + lean, 28 + half + lean + 1):
            d = abs(x - 28 - lean) / max(1, half)
            heat = (1 - d) * (1 - t * 0.6)
            tone = 2 + int(heat * 4.6)
            pix.put(x, y, FIRE[max(1, min(6, tone))])
    for sx, sy in ((20, 10), (34, 6), (26, 2), (38, 14), (16, 18)):
        pix.put(sx, sy, FIRE[5])
        pix.put(sx, sy + 1, FIRE[3])
    pix.outline()
    # Flame edge stays unoutlined at the tips for a soft lick.
    return pix.image()


# --- Vault: round iron door --------------------------------------------------


def vault_door(opened: bool) -> Image.Image:
    """88×104: a round banded iron door in a stone arch."""
    import generate_town_art as g

    pix = Pix(88, 104)
    # Arched stone frame.
    g.stone_wall(pix, 6, 30, 76, 64, seed=3)
    for y in range(6, 34):
        for x in range(6, 82):
            if ((x - 44) / 38) ** 2 + ((y - 34) / 28) ** 2 <= 1:
                pix.put(x, y, g.STONE[2 + ((x // 7 + y // 5) % 3)])
                if (x * 3 + y) % 11 == 0:
                    pix.put(x, y, g.STONE[1])
    # Keystone.
    pix.rect(40, 4, 9, 9, g.STONE[4])
    pix.rect(40, 4, 9, 1, g.STONE[5])
    pix.put(44, 8, GOLD[3])
    cx, cy, r = 44, 56, 26
    # Dark recess.
    for y in range(cy - r - 2, cy + r + 3):
        for x in range(cx - r - 2, cx + r + 3):
            if (x - cx) ** 2 + (y - cy) ** 2 <= (r + 2) ** 2:
                pix.put(x, y, (18, 14, 20))
    if opened:
        # Gold glow inside, door swung right as a thin ellipse.
        for y in range(cy - r + 4, cy + r - 3):
            for x in range(cx - r + 4, cx + r - 6):
                if (x - cx) ** 2 + (y - cy) ** 2 <= (r - 4) ** 2:
                    pix.put(x, y, (44, 28, 22))
        for i, (px_, py_) in enumerate(((30, 70), (36, 72), (42, 70), (48, 72), (54, 70), (34, 66), (40, 66), (46, 66), (52, 66), (38, 62), (44, 62), (50, 62))):
            pix.rect(px_, py_, 5, 3, GOLD[3 + (i % 2)])
            pix.put(px_ + 1, py_, GOLD[5])
        pix.put(42, 56, (200, 50, 60))
        pix.put(43, 56, (250, 130, 130))
        pix.put(50, 58, (60, 150, 130))
        for y in range(cy - r, cy + r + 1):
            for x in range(72, 82):
                if ((x - 77) / 5) ** 2 + ((y - cy) / r) ** 2 <= 1:
                    pix.put(x, y, IRON[3] if x < 77 else IRON[2])
        pix.rect(76, cy - 2, 3, 4, GOLD[3])
    else:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 > r * r:
                    continue
                d = math.sqrt(d2) / r
                light = -0.55 * (x - cx) / r - 0.55 * (y - cy) / r
                tone = 2 + (1 if light > 0.1 else 0) + (1 if light > 0.5 else 0) - (1 if light < -0.5 else 0)
                if 0.78 < d < 0.9:
                    tone += 1  # raised outer band
                if 0.9 <= d:
                    tone = 1
                pix.put(x, y, IRON[max(0, min(5, tone))])
        # Rivets on the band.
        for i in range(16):
            a = i / 16 * math.tau
            rx = int(round(cx + (r - 4) * math.cos(a)))
            ry = int(round(cy + (r - 4) * math.sin(a)))
            pix.put(rx, ry, IRON[5])
            pix.put(rx + 1, ry + 1, IRON[0])
        # Wheel: hub and six spokes.
        for i in range(6):
            a = i / 6 * math.tau + 0.3
            for k in range(4, 14):
                x = int(round(cx + k * math.cos(a)))
                y = int(round(cy + k * math.sin(a)))
                pix.put(x, y, GOLD[2])
                pix.put(x, y - 1, GOLD[3])
            ex = int(round(cx + 14 * math.cos(a)))
            ey = int(round(cy + 14 * math.sin(a)))
            pix.rect(ex - 1, ey - 1, 3, 3, GOLD[3])
            pix.put(ex - 1, ey - 1, GOLD[5])
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 4, cx + 5):
                if (x - cx) ** 2 + (y - cy) ** 2 <= 16:
                    pix.put(x, y, GOLD[3] if (x - cx) + (y - cy) < 0 else GOLD[2])
        pix.put(cx - 1, cy - 2, GOLD[5])
    # Threshold step and two torches.
    g.stone_wall(pix, 2, 90, 84, 10, seed=5)
    pix.rect(2, 90, 84, 1, g.STONE[5])
    for tx in (10, 74):
        pix.rect(tx, 40, 3, 7, IRON[2])
        pix.put(tx, 40, IRON[4])
        g.flame(pix, tx + 1, 40)
    pumpkin(pix, 70, 80, 12, 10, lit=True)
    pix.outline()
    return pix.image()


# --- Sky ---------------------------------------------------------------------

SKY = [
    (34, 22, 54),
    (48, 28, 68),
    (70, 34, 82),
    (98, 40, 88),
    (132, 48, 84),
    (168, 62, 74),
    (204, 88, 62),
    (232, 128, 66),
    (246, 168, 86),
]
CLOUD_DARK = [(42, 28, 60), (60, 36, 74), (84, 44, 84)]
CLOUD_RIM = [(170, 70, 80), (220, 110, 84), (246, 160, 104)]
RIDGE = [(40, 20, 34), (62, 26, 36), (92, 34, 34), (130, 48, 34), (170, 70, 38)]


def backdrop() -> Image.Image:
    """360×200 dusk sky. The viewport pins the bottom edge to the square,
    so the skyline lives in the bottom rows and the sky grows upward on a
    taller screen."""
    import generate_town_art as g

    pix = Pix(360, 200)
    edges = (0, 100, 140, 156, 164, 171, 177, 183, 189, 200)
    for i in range(len(SKY)):
        pix.rect(0, edges[i], 360, edges[i + 1] - edges[i], SKY[i])
        if i > 0:
            for x in range(0, 360, 4):
                if life._hash(x, i) % 3 == 0:
                    pix.rect(x, edges[i], 2, 1, SKY[i - 1])
    for sx, sy in ((14, 26), (52, 61), (96, 34), (148, 79), (190, 13), (232, 92), (286, 46), (330, 110), (120, 120), (262, 134), (70, 140), (310, 150)):
        pix.put(sx, sy, (236, 220, 240))
        pix.put(sx + 1, sy, (150, 120, 170))
    clouds = ((14, 144, (22, 38, 52, 40, 22)), (150, 136, (16, 30, 38, 24)), (238, 150, (24, 44, 60, 50, 30)), (90, 162, (14, 28, 34, 20)), (300, 166, (12, 22, 28, 16)))
    for cx, cy, runs in clouds:
        for i, rw in enumerate(runs):
            y = cy + i * 2
            x = cx + (runs[0] - rw) // 2 + (i % 2) * 3
            pix.rect(x, y, rw, 2, CLOUD_DARK[min(2, i)])
            pix.rect(x + 2, y + 1, max(1, rw - 4), 1, CLOUD_RIM[0])
        last = runs[-1]
        y = cy + len(runs) * 2
        pix.rect(cx + (runs[0] - last) // 2 + 2, y, max(1, last - 4), 1, CLOUD_RIM[1])
        pix.rect(cx + (runs[0] - last) // 2 + 4, y + 1, max(1, last - 8), 1, CLOUD_RIM[2])
    # Far town silhouette: a keep with a spire, gables, chimneys, lit windows.
    sil = (34, 20, 38)
    sil_lit = (56, 28, 46)
    lit = (255, 186, 64)
    tx = 220
    pix.rect(tx, 164, 22, 36, sil)
    pix.rect(tx, 164, 2, 36, sil_lit)
    for y in range(146, 164):
        half = (y - 146) * 12 // 18
        pix.rect(tx + 11 - half, y, half * 2 + 1, 1, sil)
    for y in range(141, 146):
        pix.put(tx + 11, y, sil)
    pix.rect(tx + 9, 172, 3, 4, lit)
    pix.rect(tx + 9, 184, 3, 4, lit)
    for gx, gw, gy in ((150, 34, 180), (182, 30, 174), (246, 40, 178), (290, 32, 182), (40, 30, 184), (70, 36, 180)):
        for y in range(gy - gw // 2, gy):
            half = y - (gy - gw // 2)
            pix.rect(gx + gw // 2 - half, y, half * 2, 1, sil)
        pix.rect(gx, gy, gw, 200 - gy, sil)
        pix.rect(gx + gw // 3, gy + 4, 2, 3, lit)
        if gw > 31:
            pix.rect(gx + gw - 8, gy - gw // 2 + 2, 4, 8, sil)
    # Autumn tree crowns at the edge of the square.
    for x in range(360):
        ridge = 188 + int(3 * math.sin(x * 0.09) + 2 * math.sin(x * 0.23 + 1))
        for y in range(ridge, 200):
            c = RIDGE[3] if y < ridge + 1 else RIDGE[2] if y < ridge + 4 else RIDGE[1]
            pix.put(x, y, c)
    for tcx, rad in ((8, 10), (34, 8), (118, 9), (140, 7), (210, 8), (276, 9), (330, 10), (352, 8)):
        g.canopy_cluster(pix, tcx, 188, rad, rad - 2, RIDGE, bias=3)
    for bx, by in ((112, 118), (126, 112), (204, 128)):
        for dx, dy in ((0, 0), (-1, -1), (1, -1), (-2, -1), (2, -1)):
            pix.put(bx + dx, by + dy, (20, 14, 26))
    return pix.image()


def leaf_pennants() -> Image.Image:
    """pennants.png (320×24): bunting on a rope, autumn colors."""
    pix = Pix(320, 24)
    colors = ((150, 42, 48), (220, 140, 50), (70, 96, 60), (110, 60, 120), (200, 80, 40), (210, 170, 64))
    for x in range(320):
        y = 2 + int(5 * math.sin(x / 320 * math.pi))
        pix.put(x, y, (48, 36, 24))
    for i in range(18):
        x = 6 + i * 18
        y = 3 + int(5 * math.sin((x + 5) / 320 * math.pi))
        col = colors[i % len(colors)]
        for row in range(10):
            half = 5 - row // 2
            pix.rect(x + 5 - half, y + row, half * 2, 1, col if row else tuple(min(255, c + 40) for c in col))
    return pix.image()
