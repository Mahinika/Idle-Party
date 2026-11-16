"""Round 2 town buildings: larger facades in the autumn-dusk look.

Half-timbering, shaded red tile roofs, lit windows that spill warm light on
the wall, wall lanterns, chimneys, a real market stall, a forge with a fire
mouth and an anvil, and a stone vault with the round iron door.

Every sprite is authored at its A56 display size (1:1 at 360 dp), so the
nearest-neighbor draw does not drop pixel rows. Deterministic, no RNG.
Called from `tool/generate_town_art.py`.
"""

from __future__ import annotations

import math

import generate_town_art as g
import town_autumn_art as autumn

Pix = g.Pix

# Sprite pixel sizes. Mirror these in `TownSpriteSize` (Dart).
FORGE = (108, 150)
MARKET = (108, 132)
INN = (108, 156)
GUILD = (172, 184)
VAULT = (112, 116)

# --- Palette (dark to light) ------------------------------------------------

STONE = [(26, 28, 42), (38, 42, 60), (52, 58, 78), (68, 74, 96), (90, 96, 118), (118, 122, 142)]
STONE_WARM = [(40, 30, 36), (58, 44, 48), (78, 60, 60), (100, 80, 74), (126, 104, 92), (156, 132, 112)]
BRICK = [(52, 24, 24), (82, 36, 30), (112, 52, 38), (144, 72, 50), (174, 98, 66), (204, 130, 88)]
PLASTER = [(92, 74, 72), (118, 96, 88), (146, 122, 106), (170, 146, 122), (192, 168, 140), (212, 192, 160)]
TIMBER = [(24, 14, 14), (40, 24, 20), (60, 36, 26), (84, 52, 34), (110, 72, 44), (138, 96, 60)]
TILE = [(48, 16, 20), (72, 24, 26), (100, 34, 30), (130, 48, 36), (160, 66, 44), (190, 92, 58), (216, 124, 78)]
SHINGLE = [(36, 22, 20), (54, 34, 26), (76, 48, 32), (100, 64, 40), (124, 84, 50), (150, 106, 64), (174, 130, 82)]
IRON = autumn.IRON
GOLD = autumn.GOLD
FIRE = autumn.FIRE
# Lit glass. Registered as emissive so the dusk grade keeps it bright.
GLASS = [(120, 52, 22), (178, 88, 30), (226, 136, 44), (250, 182, 76), (255, 222, 132), (255, 244, 196)]
WARM = (255, 168, 78)

autumn.add_emissive(GLASS)
autumn.add_emissive(FIRE[2:])


def _h(*a: int) -> int:
    v = 2166136261
    for n in a:
        v ^= (n & 0xFFFFFFFF)
        v = (v * 16777619) & 0xFFFFFFFF
    return v


class Sprite(Pix):
    """Pix plus a list of baked warm lights."""

    def __init__(self, w: int, h: int) -> None:
        super().__init__(w, h)
        self.lights: list[tuple[float, float, float, float]] = []

    def light(self, x: float, y: float, r: float, k: float) -> None:
        self.lights.append((x, y, r, k))

    def bake(self) -> None:
        """Tint opaque, non-lit pixels toward warm light near each source."""
        if not self.lights:
            return
        for y in range(self.h):
            for x in range(self.w):
                i = y * self.w + x
                c = self.px[i]
                if c is None or c[:3] in autumn.EMISSIVE or c[:3] == g.INK[:3]:
                    continue
                k = 0.0
                for lx, ly, r, s in self.lights:
                    d = math.hypot(x - lx, (y - ly) * 1.1)
                    if d < r:
                        f = 1 - d / r
                        k += s * f * f
                if k <= 0.01:
                    continue
                k = min(0.75, k)
                # Light multiplies the surface color, so dark timber stays dark.
                r0, g0, b0 = c[0], c[1], c[2]
                lum = (r0 + g0 + b0) / 3
                add = (WARM[0] * k * (0.35 + lum / 255), WARM[1] * k * (0.25 + lum / 300), WARM[2] * k * 0.15)
                self.px[i] = (
                    min(255, int(r0 * (1 - k * 0.35) + add[0])),
                    min(255, int(g0 * (1 - k * 0.35) + add[1])),
                    min(255, int(b0 * (1 - k * 0.3) + add[2])),
                    c[3],
                )


# --- Materials ---------------------------------------------------------------


def stone(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0, ramp=STONE) -> None:
    g.stone_wall(pix, x, y, w, h, seed=seed, ramp=ramp)


def plaster(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            n = _h(xx, yy, seed) % 23
            tone = 3
            if n == 0:
                tone = 2
            elif n == 1:
                tone = 4
            if yy >= y + h - 3:
                tone -= 1  # damp, dirt at the foot
            pix.put(xx, yy, PLASTER[max(0, tone)])
    # Two worn patches showing the wattle.
    for k in range(max(1, w // 30)):
        px = x + 4 + (_h(seed, k) % max(1, w - 10))
        py = y + 3 + (_h(k, seed) % max(1, h - 8))
        pix.rect(px, py, 3, 2, PLASTER[1])
        pix.put(px + 1, py, PLASTER[0])


def planks(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0) -> None:
    xx = x
    k = 0
    while xx < x + w:
        pw = 4 if k % 3 else 5
        tone = 2 + (_h(k, seed) % 2)
        x1 = min(x + w, xx + pw)
        pix.rect(xx, y, x1 - xx, h, TIMBER[tone])
        pix.rect(xx, y, 1, h, TIMBER[tone + 1])
        pix.rect(x1 - 1, y, 1, h, TIMBER[1])
        for yy in range(y + 2, y + h - 1, 5):
            pix.put(xx + 2, yy + (k % 3), TIMBER[1])
        xx = x1
        k += 1


def post(pix: Pix, x: int, y: int, h: int, w: int = 3) -> None:
    pix.rect(x, y, w, h, TIMBER[2])
    pix.rect(x, y, 1, h, TIMBER[4])
    pix.rect(x + w - 1, y, 1, h, TIMBER[1])
    for yy in range(y + 3, y + h - 1, 7):
        pix.put(x + 1, yy, TIMBER[1])


def rail(pix: Pix, x: int, y: int, w: int, h: int = 3) -> None:
    pix.rect(x, y, w, h, TIMBER[2])
    pix.rect(x, y, w, 1, TIMBER[4])
    pix.rect(x, y + h - 1, w, 1, TIMBER[0])
    for xx in range(x + 4, x + w - 1, 9):
        pix.put(xx, y + 1, TIMBER[1])
    # Shadow on the plaster under the rail.
    for xx in range(x, x + w):
        c = pix.get(xx, y + h)
        if c is not None and c[:3] in PLASTER:
            pix.put(xx, y + h, PLASTER[max(0, PLASTER.index(c[:3]) - 2)])


def brace(pix: Pix, x0: int, y0: int, x1: int, y1: int) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for s in range(steps + 1):
        t = s / max(1, steps)
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        pix.put(x, y, TIMBER[4])
        pix.put(x + 1, y, TIMBER[2])
        pix.put(x + 2, y, TIMBER[1])


def half_timber(pix: Pix, x: int, y: int, w: int, h: int, posts: list[int], braces: str = "x", seed: int = 0, mid: int | None = None) -> None:
    """Plaster panels in a timber frame. posts are x offsets of inner posts."""
    plaster(pix, x, y, w, h, seed)
    cols = [0, *posts, w - 3]
    rows = [0, h - 3] if mid is None else [0, mid, h - 3]
    for i in range(len(cols) - 1):
        for j in range(len(rows) - 1):
            ax, bx = x + cols[i] + 3, x + cols[i + 1] - 1
            ay, by = y + rows[j] + 3, y + rows[j + 1] - 1
            if bx - ax < 6 or by - ay < 6:
                continue
            kind = braces[(i + j) % len(braces)]
            if kind == "x":
                brace(pix, ax, ay, bx - 2, by)
                brace(pix, bx - 2, ay, ax, by)
            elif kind == "/":
                brace(pix, ax, by, bx - 2, ay)
            elif kind == "\\":
                brace(pix, ax, ay, bx - 2, by)
    for c in cols:
        post(pix, x + c, y, h)
    for r_ in rows:
        rail(pix, x, y + r_, w)


def roof(pix: Pix, y0: int, y1: int, lt: int, rt: int, lb: int, rb: int, ramp=TILE, split: int | None = None, seed: int = 0) -> None:
    """Tile courses on a trapezoid roof plane. split: x of a hip line;
    the right of it is in shade. Courses are 4 px, tiles 6 px, staggered."""
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        t = (y - y0) / span
        xl = round(lt + (lb - lt) * t)
        xr = round(rt + (rb - rt) * t)
        row = (y - y0) // 4
        v = (y - y0) % 4
        for x in range(xl, xr):
            off = 3 if row % 2 else 0
            u = (x - xl + off) % 6
            col = (x - xl + off) // 6
            tone = 3
            if v == 0:
                tone += 1
            elif v == 3:
                tone -= 2
            if u == 5:
                tone -= 1
            elif u == 0 and v in (1, 2):
                tone += 1
            var = _h(col, row, seed) % 6
            if var == 0:
                tone -= 1
            elif var == 1:
                tone += 1
            if t < 0.2:
                tone += 1  # sky catches the upper courses
            if t > 0.86:
                tone -= 1  # eave in shade
            if split is not None and x >= split:
                tone -= 2
            elif x - xl < 2:
                tone += 1
            pix.put(x, y, ramp[max(0, min(len(ramp) - 1, tone))])
        # Bargeboard edges.
        pix.put(xl, y, ramp[1])
        pix.put(xr - 1, y, ramp[0])
    # Ridge cap.
    pix.rect(lt, y0, max(1, rt - lt), 2, ramp[5])
    pix.rect(lt, y0 + 1, max(1, rt - lt), 1, ramp[3])
    for x in range(lt, rt, 5):
        pix.put(x, y0, ramp[6] if len(ramp) > 6 else ramp[5])
    # Eave board and the shadow it throws on the wall.
    pix.rect(lb, y1, rb - lb, 2, TIMBER[1])
    pix.rect(lb, y1, rb - lb, 1, TIMBER[3])


def eave_shadow(pix: Pix, x: int, y: int, w: int, rows: int = 3) -> None:
    for yy in range(y, y + rows):
        for xx in range(x, x + w):
            c = pix.get(xx, yy)
            if c is None:
                continue
            k = 0.55 + 0.12 * (yy - y)
            pix.put(xx, yy, (int(c[0] * k), int(c[1] * k), int(c[2] * k * 1.05)))


def gable_front(pix: Pix, ax: int, ay: int, by: int, half: int, posts: int = 2, band: int = 6, ramp=TILE) -> None:
    """A gable end facing us: timbered triangle and two tiled roof bands."""
    hgt = by - ay
    for y in range(ay, by):
        t = (y - ay) / hgt
        hw = int(half * t)
        for x in range(ax - hw, ax + hw + 1):
            n = _h(x, y) % 19
            pix.put(x, y, PLASTER[3] if n else PLASTER[2])
    # King post and struts.
    post(pix, ax - 1, ay + 6, hgt - 6)
    for k in range(1, posts + 1):
        dx = half * k // (posts + 1)
        top = ay + int(hgt * dx / half) + 2
        post(pix, ax - dx - 1, top, by - top)
        post(pix, ax + dx - 1, top, by - top)
    rail(pix, ax - half, by - 3, half * 2 + 1)
    mid = ay + hgt * 6 // 10
    hw = int(half * 0.6)
    rail(pix, ax - hw, mid, hw * 2 + 1)
    # Roof bands, tiles across the slope. Left lit, right in shade.
    for y in range(ay - band, by + 2):
        t = (y - ay) / hgt
        cx = half * t
        for side in (-1, 1):
            edge = ax + side * cx
            for k in range(band + 2):
                x = round(edge + side * (k - 2))
                if y < ay - 2 and abs(x - ax) > (y - ay + band) * 2:
                    continue
                v = (k + (y // 3)) % 4
                tone = 4 if side < 0 else 2
                if v == 0:
                    tone += 1
                elif v == 3:
                    tone -= 1
                if k <= 1:
                    tone = 1  # bargeboard
                if k >= band:
                    tone -= 1
                if _h(int(x), y) % 9 == 0:
                    tone -= 1
                pix.put(x, y, ramp[max(0, min(len(ramp) - 1, tone))])
    pix.rect(ax - 1, ay - band - 1, 3, 3, ramp[5])


# --- Fixtures ----------------------------------------------------------------


def window(pix: Sprite, x: int, y: int, w: int, h: int, lattice: bool = False, arch: bool = False, shutters: bool = False, box: bool = False, glow: float = 0.32) -> None:
    pix.rect(x - 1, y - 1, w + 2, h + 2, TIMBER[1])
    cx = x + w / 2
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if arch and yy < y + w / 2:
                dy = (y + w / 2) - yy
                if (xx + 0.5 - cx) ** 2 + dy * dy > (w / 2) ** 2:
                    pix.put(xx, yy, TIMBER[1])
                    continue
            d = math.hypot((xx + 0.5 - cx) / max(1, w), (yy - (y + h * 0.65)) / max(1, h))
            tone = 4 if d < 0.22 else 3 if d < 0.42 else 2
            if yy == y:
                tone -= 1
            pix.put(xx, yy, GLASS[tone])
    if lattice:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if (xx - x + yy - y) % 4 == 0 or (xx - x - (yy - y)) % 4 == 0:
                    c = pix.get(xx, yy)
                    if c is not None and c[:3] in GLASS:
                        pix.put(xx, yy, GLASS[max(0, GLASS.index(c[:3]) - 2)])
    else:
        pix.rect(x + w // 2, y, 1, h, TIMBER[2])
        pix.rect(x, y + h // 2 - (1 if arch else 0), w, 1, TIMBER[2])
    # A small silhouette in some panes: a pot, a candle.
    pix.put(x + 1, y + h - 2, GLASS[5])
    # Sill.
    pix.rect(x - 2, y + h + 1, w + 4, 2, TIMBER[3])
    pix.rect(x - 2, y + h + 2, w + 4, 1, TIMBER[1])
    if shutters:
        for sx in (x - 5, x + w + 1):
            pix.rect(sx, y - 1, 4, h + 2, TIMBER[3])
            pix.rect(sx, y - 1, 4, 1, TIMBER[5])
            pix.rect(sx + 3 if sx < x else sx, y - 1, 1, h + 2, TIMBER[1])
            for yy in range(y + 1, y + h, 3):
                pix.rect(sx + 1, yy, 2, 1, TIMBER[2])
    if box:
        flower_box(pix, x - 2, y + h + 3, w + 4)
    pix.light(cx, y + h * 0.6, max(w, h) * 1.7, glow)


def flower_box(pix: Pix, x: int, y: int, w: int) -> None:
    pix.rect(x, y, w, 4, TIMBER[2])
    pix.rect(x, y, w, 1, TIMBER[4])
    pix.rect(x, y + 3, w, 1, TIMBER[0])
    bloom = ((214, 96, 34), (236, 172, 60), (176, 44, 36))
    for k, bx in enumerate(range(x + 1, x + w - 1, 2)):
        pix.put(bx, y - 1, (70, 74, 34) if k % 2 else (96, 98, 42))
        if k % 3 != 2:
            pix.put(bx, y - 2, bloom[k % 3])


def lantern(pix: Sprite, x: int, y: int, side: int = 1) -> None:
    """Wall lantern on an iron bracket. (x, y) is where the arm meets the
    wall; side=1 hangs it to the right."""
    for k in range(6):
        pix.put(x + side * k, y, IRON[2])
    pix.put(x + side * 1, y + 1, IRON[2])
    pix.put(x + side * 2, y + 2, IRON[1])
    lx = x + side * 5 - 2
    pix.rect(lx, y + 1, 5, 1, IRON[1])
    pix.rect(lx + 1, y + 2, 3, 1, IRON[3])
    pix.rect(lx, y + 3, 5, 7, IRON[1])
    pix.rect(lx + 1, y + 4, 3, 5, GLASS[3])
    pix.put(lx + 2, y + 5, GLASS[5])
    pix.put(lx + 2, y + 6, GLASS[4])
    pix.rect(lx, y + 10, 5, 1, IRON[2])
    pix.put(lx + 2, y + 11, IRON[1])
    pix.light(lx + 2.5, y + 6, 22, 0.55)


def chimney(pix: Pix, x: int, y: int, h: int, w: int = 10, ramp=STONE) -> None:
    stone(pix, x, y + 3, w, h - 3, seed=x, ramp=ramp)
    pix.rect(x - 1, y, w + 2, 3, ramp[3])
    pix.rect(x - 1, y, w + 2, 1, ramp[5])
    pix.rect(x + 2, y, w - 4, 1, (20, 16, 18))
    pix.rect(x + w - 2, y + 3, 2, h - 3, ramp[0])


def smoke(pix: Pix, x: int, y: int) -> None:
    puff = [(70, 60, 84), (96, 84, 106), (124, 112, 132)]
    for k in range(6):
        cx = x + int(3 * math.sin(k * 1.1)) + k
        cy = y - k * 4
        r = 2 + k // 2
        for yy in range(cy - r, cy + r + 1):
            for xx in range(cx - r, cx + r + 1):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r and _h(xx, yy) % 3:
                    if pix.get(xx, yy) is None:
                        pix.put(xx, yy, puff[min(2, (yy - cy + r) // max(1, r))])


def door(pix: Sprite, x: int, y: int, w: int, h: int, lit: bool = False, ramp=STONE) -> None:
    """Arched plank door in a stone surround. lit: ajar, warm inside."""
    r = w // 2
    for yy in range(y - 3, y + h):
        for xx in range(x - 3, x + w + 3):
            ty = y + r
            if yy < ty and (xx + 0.5 - (x + w / 2)) ** 2 + (yy - ty) ** 2 > (r + 3) ** 2:
                continue
            inner = not (yy < ty and (xx + 0.5 - (x + w / 2)) ** 2 + (yy - ty) ** 2 > r * r) and x <= xx < x + w
            if inner:
                continue
            ang = math.atan2(yy - ty, xx - (x + w / 2))
            tone = 3 + (_h(int(ang * 4), 1) % 2)
            if yy >= ty:
                tone = 3 + ((yy // 5) % 2)
            pix.put(xx, yy, ramp[tone])
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            ty = y + r
            if yy < ty and (xx + 0.5 - (x + w / 2)) ** 2 + (yy - ty) ** 2 > r * r:
                continue
            k = (xx - x) // 3
            tone = 2 + (k % 2)
            if (xx - x) % 3 == 2:
                tone = 1
            pix.put(xx, yy, TIMBER[tone])
    for sy in (y + r + 2, y + h - 5):
        pix.rect(x + 1, sy, w - 2, 1, IRON[2])
        pix.put(x + 1, sy, IRON[4])
    pix.put(x + w - 3, y + h // 2 + 2, GOLD[4])
    pix.put(x + w - 3, y + h // 2 + 3, GOLD[2])
    if lit:
        # Ajar: a bright wedge on the hinge side.
        for yy in range(y + 2, y + h):
            for xx in range(x, x + max(2, w // 3)):
                ty = y + r
                if yy < ty and (xx + 0.5 - (x + w / 2)) ** 2 + (yy - ty) ** 2 > (r - 1) ** 2:
                    continue
                pix.put(xx, yy, GLASS[4 if xx < x + w // 6 else 3])
        pix.light(x + w * 0.3, y + h * 0.7, w * 2.2, 0.5)


def banner(pix: Pix, x: int, y: int, w: int, h: int, cloth, sigil: str) -> None:
    pix.rect(x - 2, y, w + 4, 2, TIMBER[3])
    pix.put(x - 2, y, GOLD[4])
    pix.put(x + w + 1, y, GOLD[4])
    for yy in range(y + 2, y + h):
        cut = max(0, yy - (y + h - 5))
        for xx in range(x, x + w):
            if cut and abs(xx - (x + w / 2 - 0.5)) < cut:
                continue
            lx = (xx - x) / max(1, w - 1)
            tone = 3 if lx < 0.3 else 2 if lx < 0.75 else 1
            pix.put(xx, yy, cloth[tone])
        pix.put(x, yy, GOLD[3])
        pix.put(x + w - 1, yy, GOLD[2])
    cx = x + w // 2
    cy = y + h // 2
    if sigil == "anvil":
        pix.rect(cx - 3, cy - 1, 7, 2, GOLD[4])
        pix.rect(cx - 1, cy + 1, 3, 3, GOLD[3])
    elif sigil == "mug":
        pix.rect(cx - 2, cy - 2, 4, 5, GOLD[4])
        pix.put(cx + 2, cy - 1, GOLD[3])
        pix.put(cx + 2, cy + 1, GOLD[3])
    elif sigil == "wheat":
        pix.rect(cx, cy - 4, 1, 9, GOLD[3])
        for k in range(4):
            pix.put(cx - 1, cy - 3 + k * 2, GOLD[4])
            pix.put(cx + 1, cy - 3 + k * 2, GOLD[4])
    else:
        pix.rect(cx, cy - 4, 1, 8, GOLD[4])
        pix.rect(cx - 2, cy - 1, 5, 1, GOLD[3])


CLOTH_RED = [(70, 20, 24), (110, 32, 32), (150, 48, 40), (186, 70, 52)]
CLOTH_GREEN = [(30, 42, 30), (46, 64, 40), (66, 88, 50), (92, 112, 64)]
CLOTH_BLUE = [(26, 30, 56), (38, 46, 82), (56, 66, 110), (80, 92, 140)]


def foundation(pix: Pix, x: int, y: int, w: int, h: int, seed: int = 0) -> None:
    stone(pix, x, y, w, h, seed=seed, ramp=STONE_WARM)
    pix.rect(x, y, w, 1, STONE_WARM[5])


def pumpkin(pix: Pix, x: int, y: int, w: int, h: int, lit: bool = False) -> None:
    autumn.pumpkin(pix, x, y, w, h, lit=lit)
    if lit and isinstance(pix, Sprite):
        pix.light(x + w / 2, y + h / 2, w * 1.6, 0.35)


def finish(pix: Sprite, smoke_at: list[tuple[int, int]] = ()) -> Sprite:
    pix.bake()
    pix.outline()
    for sx, sy in smoke_at:
        smoke(pix, sx, sy)
    return pix


# --- Forge -------------------------------------------------------------------


def forge(tier: int) -> "Image":
    w, h = FORGE
    p = Sprite(w, h)
    ground = 132
    # House on the right.
    hx, hy, hw = 40, 74, 64
    if tier == 0:
        planks(p, hx, hy, hw, ground - hy, seed=2)
        rail(p, hx, hy, hw)
        rail(p, hx, 102, hw)
    else:
        half_timber(p, hx, hy, hw, ground - hy, posts=[20, 41], braces="x/\\", seed=3, mid=28)
    # Roof plane with the chimney poking through.
    chimney(p, 86, 24, 30, 11, ramp=BRICK)
    roof(p, 44, 76, 50, 100, 36, 108, ramp=SHINGLE if tier == 0 else TILE, split=96, seed=1)
    eave_shadow(p, hx, 78, hw)
    # Workshop windows and an open door with fire light.
    window(p, 66, 82, 12, 14, lattice=True, box=tier > 0)
    window(p, 86, 82, 12, 14, lattice=True)
    door(p, 64, 106, 14, ground - 106, lit=True, ramp=STONE_WARM)
    # Tool rack: tongs and hammers on a peg board.
    rail(p, 82, 108, 20, 2)
    for k, tx in enumerate(range(84, 101, 5)):
        p.rect(tx, 110, 1, 9 + (k % 2) * 3, IRON[3])
        p.rect(tx - 1, 119 + (k % 2) * 3, 3, 2, IRON[2] if k % 2 else TIMBER[3])
    lantern(p, hx + 21, 104, side=-1)
    # Stone hearth on the left: shoulders, stack, fire mouth.
    stone(p, 2, 82, 40, ground - 82, seed=5)
    keep = {(x, y): p.get(x, y) for x in range(0, 44) for y in range(56, 84)}
    stone(p, 2, 56, 40, 28, seed=6)
    for (x, y), c in keep.items():
        t = (y - 56) / 28
        half = 9 + 11 * t
        if abs(x + 0.5 - 22) > half:
            p.px[y * p.w + x] = c
    stone(p, 13, 16, 18, 42, seed=7)
    p.rect(11, 12, 22, 4, STONE[3])
    p.rect(11, 12, 22, 1, STONE[5])
    p.rect(14, 12, 16, 1, (20, 14, 16))
    # Fire mouth: brick voussoirs, black throat, coals, flames.
    mx, my, mw, mh = 8, 100, 28, ground - 100
    r = mw // 2
    for yy in range(my - 4, my + mh):
        for xx in range(mx - 4, mx + mw + 4):
            ty = my + r
            d = math.hypot(xx + 0.5 - (mx + mw / 2), yy - ty) if yy < ty else abs(xx + 0.5 - (mx + mw / 2)) * (r / (mw / 2))
            if d <= r + 4:
                p.put(xx, yy, BRICK[3 + ((xx // 3 + yy // 3) % 2)] if d > r else (20, 10, 10))
    for yy in range(my + 10, my + mh):
        for xx in range(mx + 2, mx + mw - 2):
            t = (yy - (my + 10)) / max(1, mh - 10)
            wob = math.sin(xx * 0.9) * 3
            if yy > my + mh - 7:
                p.put(xx, yy, FIRE[3 + (_h(xx, yy) % 3)])
            elif t * 18 + wob > 7 - abs(xx - (mx + mw / 2)) * 0.3:
                tone = 2 + int(t * 4) + (1 if abs(xx - (mx + mw / 2)) < 5 else 0)
                p.put(xx, yy, FIRE[max(1, min(6, tone))])
    p.rect(mx - 4, ground - 2, mw + 8, 4, STONE_WARM[3])
    p.rect(mx - 4, ground - 2, mw + 8, 1, STONE_WARM[5])
    p.light(mx + mw / 2, ground - 8, 46, 0.8)
    # Anvil with a hot bar, on a stump, in front of the hearth.
    ax, ay = 40, 110
    p.rect(ax + 5, ay + 11, 10, 11, TIMBER[3])
    p.rect(ax + 5, ay + 11, 1, 11, TIMBER[5])
    p.rect(ax + 14, ay + 11, 1, 11, TIMBER[1])
    p.rect(ax + 6, ay + 11, 8, 1, TIMBER[4])
    # Horn tapering to the left, flat face, heel on the right.
    for k in range(5):
        p.rect(ax - 4 + k, ay + 1 + (4 - k) // 2, 1, 2 + k // 2, IRON[2])
    p.rect(ax + 1, ay, 19, 5, IRON[2])
    p.rect(ax + 1, ay, 19, 1, IRON[4])
    p.rect(ax - 1, ay + 1, 2, 1, IRON[4])
    p.rect(ax + 1, ay + 4, 19, 1, IRON[0])
    p.rect(ax + 7, ay + 5, 7, 3, IRON[1])
    p.rect(ax + 4, ay + 8, 13, 3, IRON[2])
    p.rect(ax + 4, ay + 8, 13, 1, IRON[3])
    # Glowing bar on the face, and two sparks.
    p.rect(ax + 4, ay - 2, 12, 2, FIRE[3])
    p.rect(ax + 7, ay - 2, 6, 1, FIRE[5])
    p.put(ax + 9, ay - 2, FIRE[6])
    p.put(ax + 12, ay - 6, FIRE[5])
    p.put(ax + 6, ay - 8, FIRE[4])
    p.light(ax + 10, ay - 1, 18, 0.55)
    # Quench barrel and a coal sack.
    g.barrel(p, 92, 120)
    p.rect(93, 119, 10, 1, (40, 60, 80))
    p.rect(0, 124, 8, 8, (54, 46, 46))
    p.rect(1, 123, 6, 2, (70, 60, 58))
    if tier >= 2:
        banner(p, 23 - 6, 64, 12, 18, CLOTH_RED, "anvil")
        p.rect(hx, hy + 1, hw, 1, GOLD[3])
    pumpkin(p, 96, 138, 11, 8, lit=True)
    pumpkin(p, 2, 140, 10, 7)
    return finish(p, [(91, 22)]).image()


# --- Market ------------------------------------------------------------------


def market(tier: int) -> "Image":
    w, h = MARKET
    p = Sprite(w, h)
    ground = 112
    a, b = ((46, 96, 58), (196, 186, 150)) if tier == 0 else ((160, 44, 40), (220, 196, 160))
    if tier >= 2:
        b = (228, 182, 88)
    # Back wall inside the stall: dark planks, two shelves of goods.
    planks(p, 12, 34, 84, 56, seed=4)
    for yy in range(34, 90):
        for xx in range(12, 96):
            c = p.get(xx, yy)
            if c is not None:
                p.put(xx, yy, (int(c[0] * 0.7), int(c[1] * 0.68), int(c[2] * 0.75)))
    jars = ((150, 60, 40), (90, 120, 70), (200, 160, 70), (120, 80, 140), (170, 90, 40))
    for sy in (52, 70):
        rail(p, 14, sy, 80, 2)
        for k, jx in enumerate(range(16, 92, 6)):
            col = jars[(k + sy) % len(jars)]
            jh = 5 + (k % 2) * 2
            p.rect(jx, sy - jh, 4, jh, col)
            p.put(jx, sy - jh, tuple(min(255, c + 50) for c in col))
            p.rect(jx + 3, sy - jh, 1, jh, tuple(c // 2 for c in col))
    # Posts.
    post(p, 6, 30, ground - 28, 4)
    post(p, 98, 30, ground - 28, 4)
    # Awning: sloped striped cloth, top at the back, scallops at the front.
    top, bot = 8, 38
    for y in range(top, bot):
        t = (y - top) / (bot - top)
        xl = round(16 - 14 * t)
        xr = round(92 + 14 * t)
        for x in range(xl, xr):
            u = (x - 54) / ((xr - xl) / 2)  # -1..1 across
            stripe = int((u + 1) * 5.5) % 2
            base = a if stripe == 0 else b
            k = 0.62 + 0.38 * t  # back of the awning is in shade
            if abs((u + 1) * 5.5 % 1 - 0.5) > 0.42:
                k -= 0.12  # fold line
            if x - xl < 2:
                k += 0.1
            p.put(x, y, tuple(min(255, int(c * k)) for c in base))
    p.rect(14, top - 2, 80, 2, TIMBER[3])
    p.rect(14, top - 2, 80, 1, TIMBER[5])
    # Valance with scallops.
    for x in range(2, 106):
        u = (x - 54) / 52
        stripe = int((u + 1) * 5.5) % 2
        base = a if stripe == 0 else b
        local = (x - 2) % 8
        drop = 7 if 2 <= local <= 5 else 6 if local in (1, 6) else 4
        for d in range(drop):
            k = 0.95 - d * 0.06
            p.put(x, bot + d, tuple(min(255, int(c * k)) for c in base))
    p.rect(2, bot, 104, 1, TIMBER[2])
    eave_shadow(p, 12, bot + 7, 84, 4)
    # Hanging goods under the valance: garlic, herbs, a lantern.
    for k, hx in enumerate(range(22, 90, 11)):
        if k == 3:
            continue
        p.rect(hx, bot + 6, 1, 4 + k % 3, TIMBER[1])
        col = (210, 200, 170) if k % 2 else (90, 110, 50)
        p.rect(hx - 1, bot + 10 + k % 3, 3, 4, col)
        p.put(hx - 1, bot + 10 + k % 3, tuple(min(255, c + 30) for c in col))
    p.rect(55, bot + 6, 1, 3, IRON[2])
    p.rect(53, bot + 9, 5, 7, IRON[1])
    p.rect(54, bot + 10, 3, 5, GLASS[3])
    p.put(55, bot + 11, GLASS[5])
    p.light(55.5, bot + 13, 30, 0.6)
    # Counter.
    planks(p, 6, 84, 96, ground - 84, seed=9)
    p.rect(4, 82, 100, 3, TIMBER[4])
    p.rect(4, 82, 100, 1, TIMBER[5])
    rail(p, 6, 98, 96, 2)
    # Goods on the counter: apples crate, pumpkins, loaves, cheese, cabbages.
    p.rect(10, 74, 20, 8, TIMBER[3])
    p.rect(10, 74, 20, 1, TIMBER[5])
    for k, (ax, ay) in enumerate(((11, 71), (15, 70), (19, 71), (23, 70), (13, 68), (18, 67), (22, 68))):
        g.apple(p, ax, ay, red=k % 4 != 2)
    pumpkin(p, 32, 72, 12, 10)
    pumpkin(p, 42, 75, 9, 7)
    for lx in (53, 61):
        g.loaf(p, lx, 75)
    g.loaf(p, 57, 71)
    # Cheese wheel.
    for yy in range(73, 82):
        for xx in range(70, 82):
            if ((xx - 75.5) / 6) ** 2 + ((yy - 77.5) / 4.5) ** 2 <= 1:
                p.put(xx, yy, (230, 186, 80) if yy < 76 else (198, 150, 56))
    p.rect(76, 74, 5, 3, (246, 214, 120))
    autumn.basket(p, 84, 76)
    # Price slate.
    p.rect(40, 88, 18, 8, (34, 34, 40))
    p.rect(40, 88, 18, 1, TIMBER[4])
    for k in range(4):
        p.put(43 + k * 3, 91, (200, 200, 190))
    p.rect(51, 93, 4, 1, (200, 200, 190))
    if tier >= 2:
        banner(p, 92, 12, 10, 18, CLOTH_GREEN, "wheat")
    # Ground clutter at the sides (the name chip covers the middle).
    g.crates_and_goods(p, 92, 116)
    pumpkin(p, 0, 118, 12, 10, lit=True)
    autumn.basket(p, 13, 122)
    return finish(p).image()


# --- Inn ---------------------------------------------------------------------


def inn(tier: int) -> "Image":
    w, h = INN
    p = Sprite(w, h)
    ground = 138
    # Stone ground floor.
    stone(p, 14, 100, 80, ground - 100, seed=2)
    # Jettied upper floor.
    if tier == 0:
        planks(p, 8, 62, 92, 38, seed=3)
        rail(p, 8, 62, 92)
        rail(p, 8, 97, 92)
    else:
        half_timber(p, 8, 62, 92, 38, posts=[22, 44, 66], braces="x", seed=5)
    # Joist ends under the jetty.
    for jx in range(10, 98, 6):
        p.rect(jx, 100, 3, 2, TIMBER[3])
        p.put(jx, 100, TIMBER[5])
    eave_shadow(p, 14, 102, 80, 3)
    # Big tile roof, dormer, chimney.
    chimney(p, 78, 4, 30, 11)
    roof(p, 22, 64, 20, 88, 2, 106, ramp=SHINGLE if tier == 0 else TILE, split=80, seed=3)
    eave_shadow(p, 8, 66, 92, 3)
    # Dormer.
    p.rect(40, 30, 26, 18, PLASTER[3])
    gable_front(p, 53, 18, 32, 16, posts=0, band=4, ramp=SHINGLE if tier == 0 else TILE)
    post(p, 40, 30, 18)
    post(p, 63, 30, 18)
    window(p, 47, 33, 12, 12, lattice=False, glow=0.3)
    rail(p, 38, 47, 30, 2)
    # Upper windows with boxes.
    for wx in (14, 36, 58, 80):
        window(p, wx + 2, 70, 10, 13, lattice=tier > 0, box=True, glow=0.28)
    # Ground floor: arched door with warm crack, two windows, two lanterns.
    door(p, 46, 112, 16, ground - 112, lit=True)
    window(p, 22, 110, 12, 12, shutters=True)
    window(p, 76, 110, 12, 12, shutters=True)
    lantern(p, 43, 106, side=-1)
    lantern(p, 65, 106, side=1)
    # Hanging sign.
    p.rect(98, 74, 8, 1, IRON[2])
    p.put(98, 75, IRON[1])
    p.rect(99, 75, 1, 3, IRON[1])
    p.rect(104, 75, 1, 3, IRON[1])
    p.rect(96, 78, 11, 10, TIMBER[3])
    p.rect(96, 78, 11, 1, TIMBER[5])
    p.rect(99, 80, 4, 5, GOLD[3])
    p.put(103, 81, GOLD[2])
    p.put(99, 80, GOLD[5])
    if tier >= 2:
        banner(p, 24, 86, 9, 0, CLOTH_RED, "mug")
        p.rect(8, 63, 92, 1, GOLD[3])
    # Bench and barrels at the corners.
    g.barrel(p, 2, 126)
    p.rect(92, 128, 14, 2, TIMBER[4])
    p.rect(93, 130, 2, 6, TIMBER[1])
    p.rect(103, 130, 2, 6, TIMBER[1])
    pumpkin(p, 94, 144, 12, 9, lit=True)
    pumpkin(p, 2, 146, 10, 7)
    return finish(p, [(83, 2)]).image()


# --- Guild -------------------------------------------------------------------


def guild(tier: int) -> "Image":
    w, h = GUILD
    p = Sprite(w, h)
    ground = 162
    roof_ramp = SHINGLE if tier == 0 else TILE
    # Left wing: stone below, timber above, hip roof.
    stone(p, 6, 116, 52, ground - 116, seed=1)
    if tier == 0:
        planks(p, 6, 88, 52, 28, seed=6)
        rail(p, 6, 88, 52)
    else:
        half_timber(p, 6, 88, 52, 28, posts=[16, 33], braces="/\\", seed=2)
    roof(p, 64, 90, 18, 58, 0, 60, ramp=roof_ramp, seed=5)
    eave_shadow(p, 6, 92, 52, 3)
    window(p, 13, 96, 8, 11, glow=0.25)
    window(p, 41, 96, 8, 11, glow=0.25)
    window(p, 14, 128, 10, 12, arch=True, shutters=False)
    window(p, 38, 128, 10, 12, arch=True)
    # Right hall with the gable facing us.
    stone(p, 100, 120, 68, ground - 120, seed=4)
    if tier == 0:
        planks(p, 100, 80, 68, 40, seed=7)
        rail(p, 100, 80, 68)
        rail(p, 100, 117, 68)
    else:
        half_timber(p, 100, 80, 68, 40, posts=[22, 43], braces="x", seed=8)
    gable_front(p, 134, 34, 80, 36, posts=2, band=6, ramp=roof_ramp)
    eave_shadow(p, 100, 82, 68, 2)
    window(p, 128, 50, 12, 14, lattice=True, glow=0.3)
    window(p, 106, 88, 10, 13, box=True)
    window(p, 128, 88, 12, 13, lattice=True, box=True)
    window(p, 152, 88, 10, 13, box=True)
    window(p, 108, 130, 12, 12, shutters=True)
    window(p, 146, 130, 12, 12, shutters=True)
    lantern(p, 133, 126, side=1)
    # Tower in the middle, dark stone, steep pyramid roof.
    tx, tw = 58, 44
    stone(p, tx, 40, tw, ground - 40, seed=7)
    for y in range(40, ground):
        p.put(tx + tw - 1, y, STONE[0])
        p.put(tx + tw - 2, y, STONE[1])
    # Corner quoins.
    for y in range(44, ground, 8):
        p.rect(tx, y, 4, 4, STONE[4])
        p.rect(tx + tw - 4, y + 4, 4, 4, STONE[2])
    # Pyramid roof as one plane (apex to eave).
    roof(p, 4, 44, 78, 82, 52, 108, ramp=roof_ramp, split=80, seed=9)
    eave_shadow(p, tx, 46, tw, 3)
    # Finial and spikes.
    p.rect(79, 0, 2, 5, IRON[3] if tier < 2 else GOLD[3])
    p.put(79, 0, IRON[5] if tier < 2 else GOLD[5])
    for sx in (54, 106):
        p.rect(sx, 38, 2, 6, IRON[2])
        p.put(sx, 37, IRON[4])
    # Tower dormer, window column, emblem diamond.
    p.rect(73, 24, 14, 12, STONE[3])
    gable_front(p, 80, 18, 26, 9, posts=0, band=3, ramp=roof_ramp)
    window(p, 76, 27, 8, 8, arch=True, glow=0.25)
    window(p, 74, 54, 12, 16, arch=True, lattice=True)
    for d in range(6):
        p.rect(80 - d, 78 + d, d * 2 + 1, 1, GOLD[3] if d < 3 else GOLD[2])
        p.rect(80 - d, 89 - d, d * 2 + 1, 1, GOLD[2])
    p.put(80, 80, GOLD[5])
    window(p, 75, 98, 10, 14, arch=True)
    # Tower door, open, warm inside.
    door(p, 70, 128, 20, ground - 128, lit=True)
    lantern(p, 66, 122, side=-1)
    lantern(p, 94, 122, side=1)
    if tier >= 2:
        banner(p, 61, 60, 9, 26, CLOTH_BLUE, "sword")
        banner(p, 90, 60, 9, 26, CLOTH_RED, "sword")
        p.rect(100, 81, 68, 1, GOLD[3])
    elif tier == 1:
        banner(p, 90, 60, 9, 22, CLOTH_BLUE, "sword")
    # Steps and corner clutter.
    foundation(p, 66, ground, 28, 4, seed=2)
    pumpkin(p, 2, 166, 13, 10, lit=True)
    pumpkin(p, 16, 170, 9, 7)
    pumpkin(p, 156, 168, 12, 9, lit=True)
    autumn.hay_bale(p, 150, 152, 18, 10)
    return finish(p).image()


# --- Vault -------------------------------------------------------------------


def vault(opened: bool) -> "Image":
    w, h = VAULT
    p = Sprite(w, h)
    ground = 96
    # Squat strongroom of big dressed blocks.
    stone(p, 6, 34, 100, ground - 34, seed=3)
    for y in range(34, ground, 10):
        p.rect(6, y, 5, 5, STONE[4])
        p.rect(101, y + 5, 5, 5, STONE[2])
    for y in range(34, ground):
        p.put(105, y, STONE[0])
    # Tile roof and a stone parapet ridge.
    roof(p, 10, 36, 22, 90, 0, 112, ramp=TILE, split=92, seed=7)
    eave_shadow(p, 6, 38, 100, 3)
    chimney(p, 80, 2, 16, 9)
    # Stone arch ring around the round door.
    cx, cy, r = 56, 68, 22
    for y in range(cy - r - 6, cy + r + 4):
        for x in range(cx - r - 6, cx + r + 7):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r + 1 < d <= r + 6:
                ang = math.atan2(y - cy, x - cx)
                seg = int((ang + math.pi) / math.tau * 18)
                tone = 3 + seg % 2
                if d > r + 5:
                    tone = 1
                if abs(((ang + math.pi) / math.tau * 18) % 1) < 0.08:
                    tone = 0
                p.put(x, y, STONE[tone])
            elif d <= r + 1:
                p.put(x, y, (14, 12, 18))
    p.rect(cx - 4, cy - r - 8, 9, 6, STONE[5])
    p.put(cx, cy - r - 6, GOLD[4])
    if opened:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r - 1:
                    p.put(x, y, (40, 24, 20) if y < cy + 4 else (58, 34, 22))
        # A heap of coins: a mound, brighter at the top, coin rims.
        for y in range(cy - 4, cy + r):
            for x in range(cx - r, cx + r):
                top = cy + 2 + ((x + 0.5 - cx) / (r - 2)) ** 2 * 12
                if y >= top and math.hypot(x + 0.5 - cx, y + 0.5 - cy) < r - 1:
                    tone = 4 if y < top + 2 else 3 if y < top + 6 else 2
                    if _h(x, y) % 5 == 0:
                        tone += 1
                    if (x + y * 3) % 7 == 0:
                        tone -= 1
                    p.put(x, y, GOLD[max(0, min(5, tone))])
        for k in range(6):
            p.rect(cx - 9 + k * 3, cy - 6 - (k % 2) * 2, 2, 8, GOLD[3])
            p.put(cx - 9 + k * 3, cy - 6 - (k % 2) * 2, GOLD[5])
        p.put(cx - 2, cy + 4, (200, 50, 60))
        p.put(cx + 5, cy + 6, (60, 160, 140))
        # Door swung to the right, seen edge-on.
        for y in range(cy - r, cy + r + 1):
            span = math.sqrt(max(0, r * r - (y - cy) ** 2))
            for x in range(cx + r - 2, cx + r + 7):
                if abs(y - cy) <= span:
                    p.put(x, y, IRON[3] if x < cx + r + 3 else IRON[2])
        p.light(cx, cy + 6, 40, 0.7)
    else:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                if d > 1:
                    continue
                light = -0.55 * (x - cx) / r - 0.55 * (y - cy) / r
                tone = 2 + (1 if light > 0.1 else 0) + (1 if light > 0.5 else 0) - (1 if light < -0.45 else 0)
                if 0.74 < d < 0.86:
                    tone += 1
                if d >= 0.9:
                    tone = 1
                p.put(x, y, IRON[max(0, min(5, tone))])
        for i in range(16):
            a = i / 16 * math.tau
            rx = round(cx + (r - 3.5) * math.cos(a))
            ry = round(cy + (r - 3.5) * math.sin(a))
            p.put(rx, ry, IRON[5])
            p.put(rx + 1, ry + 1, IRON[0])
        for i in range(6):
            a = i / 6 * math.tau + 0.3
            for k in range(4, 12):
                x = round(cx + k * math.cos(a))
                y = round(cy + k * math.sin(a))
                p.put(x, y, GOLD[2])
                p.put(x, y - 1, GOLD[3])
            ex = round(cx + 12 * math.cos(a))
            ey = round(cy + 12 * math.sin(a))
            p.rect(ex - 1, ey - 1, 3, 3, GOLD[3])
            p.put(ex - 1, ey - 1, GOLD[5])
        for y in range(cy - 3, cy + 4):
            for x in range(cx - 3, cx + 4):
                if (x - cx) ** 2 + (y - cy) ** 2 <= 10:
                    p.put(x, y, GOLD[3] if (x - cx) + (y - cy) < 0 else GOLD[2])
        p.put(cx - 1, cy - 2, GOLD[5])
        # Hinges on the left.
        for hy in (cy - 12, cy + 10):
            p.rect(cx - r - 3, hy, 7, 3, IRON[2])
            p.put(cx - r - 3, hy, IRON[4])
    # Barred slit windows, lit from inside.
    for wx in (16, 88):
        p.rect(wx, 46, 8, 14, (14, 12, 18))
        p.rect(wx + 1, 47, 6, 12, GLASS[2])
        p.rect(wx + 2, 50, 3, 6, GLASS[3])
        for bx in (wx + 2, wx + 5):
            p.rect(bx, 47, 1, 12, IRON[2])
        p.light(wx + 4, 54, 16, 0.25)
    lantern(p, 24, 70, side=-1)
    lantern(p, 88, 70, side=1)
    # Steps.
    foundation(p, 26, ground, 60, 4, seed=1)
    foundation(p, 32, ground - 3, 48, 3, seed=2)
    pumpkin(p, 0, 100, 12, 10, lit=True)
    pumpkin(p, 98, 102, 12, 9)
    autumn.basket(p, 12, 106)
    return finish(p).image()


def ember_dim(img):
    """Pull pale street stones down to the warm brown of the square, so the
    street reads as the same cobbles in shade, not a lilac band.
    Lit pixels (leaves in glow colors) are kept."""
    src = img.convert("RGBA")
    out = []
    for r, g_, b, a in src.getdata():
        if a == 0 or (r, g_, b) in autumn.EMISSIVE:
            out.append((r, g_, b, a))
            continue
        out.append((int(r * 0.76), int(g_ * 0.64), int(b * 0.58), a))
    src.putdata(out)
    return src
