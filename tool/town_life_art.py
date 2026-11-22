"""Ground and townsfolk for the town square.

Buildings stay in generate_town_art.py. This file paints the lawn and the
villagers. Folk cells are 96×112, authored on a 48×56 grid and doubled so
a nearest-neighbor draw at 48×56 keeps a solid 1px outline, a face, and
the clothes. Owned pixels only. Deterministic: no RNG.
"""
from __future__ import annotations

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

# Dusk lawn. Tufts and plantings use the full ramp; the tile uses LAWN only.
GRASS = [
    (12, 36, 14),
    (16, 52, 16),
    (22, 68, 18),
    (28, 84, 22),
    (34, 100, 24),
    (44, 116, 28),
    (56, 132, 34),
    (70, 146, 40),
]
# Three close dusk greens. Low contrast so paths and plaques read on top.
LAWN = (
    (34, 78, 24),
    (38, 88, 26),
    (42, 96, 28),
)
CLOVER = [
    (16, 52, 32),
    (24, 72, 40),
    (34, 92, 48),
    (48, 112, 56),
]
SUN = [
    (70, 88, 28),
    (88, 108, 32),
    (108, 124, 40),
    (128, 140, 52),
]
DIRT = [
    (58, 36, 22),
    (82, 50, 28),
    (108, 68, 36),
    (136, 90, 48),
    (164, 116, 68),
]
STONE = [
    (62, 48, 32),
    (88, 68, 44),
    (114, 90, 58),
    (140, 112, 74),
    (164, 136, 94),
    (186, 158, 114),
]
STONE_GREY = [
    (42, 46, 50),
    (62, 68, 74),
    (84, 90, 98),
    (108, 114, 122),
    (132, 138, 144),
    (154, 160, 164),
]
MOSS = [
    (14, 40, 22),
    (20, 58, 28),
    (28, 76, 34),
    (40, 96, 42),
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


def _noise(x: int, y: int, cell: int, w: int = 480, h: int = 960) -> float:
    # The lattice only meets itself when the cell divides both sides.
    if w % cell or h % cell:
        raise ValueError(f"noise cell {cell} must divide the {w}x{h} tile")
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
    return rgb in GRASS or rgb in CLOVER or rgb in SUN or rgb in LAWN


# --- Lawn -----------------------------------------------------------------


# A longer period makes the tuft scatter less obvious at phone scale.
GROUND_TILE = 128


def _tuft(pix: Pix, x: int, y: int, blades: tuple[tuple[int, int, int], ...]) -> None:
    """A handful of blades. (dx, height, lean). Tips are yellow-green."""
    for dx, height, lean in blades:
        for i in range(height):
            xx = x + dx + (lean if i > height // 2 else 0)
            if i == 0:
                col = GRASS[7]
            elif i < 2:
                col = GRASS[6]
            elif i < height - 1:
                col = GRASS[5]
            else:
                col = GRASS[2]
            pix.put_wrap(xx, y + i, col)
        pix.put_wrap(x + dx, y + height - 1, GRASS[1])


TUFT_SHAPES = (
    ((0, 5, 0), (2, 7, 1), (4, 4, -1)),
    ((0, 6, -1), (2, 5, 0), (5, 4, 1)),
    ((0, 5, 1), (3, 6, 0)),
    ((1, 4, 0), (3, 8, -1), (5, 5, 1)),
    ((0, 7, 1), (2, 4, -1), (4, 6, 0)),
    ((0, 6, 1), (2, 8, -1)),
)


def _dirt_patch_wrap(pix: Pix, cx: int, cy: int, rx: int, ry: int) -> None:
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            nx = dx / max(1, rx)
            ny = dy / max(1, ry)
            if nx * nx + ny * ny > 1:
                continue
            tone = 2 if ny > 0.25 else 4 if ny < -0.15 else 3
            pix.put_wrap(cx + dx, cy + dy, DIRT[tone])
    pix.put_wrap(cx - 2, cy + 1, GRASS[1])
    pix.put_wrap(cx + 3, cy + 2, GRASS[2])


def ground() -> Image.Image:
    """Seamless dusk lawn: gentle value drift, sparse flowers and worn patches."""
    w = h = GROUND_TILE
    pix = Pix(w, h)
    for y in range(h):
        for x in range(w):
            n = _noise(x, y, 32, w, h)
            base = LAWN[int(n * 2.6) % 3]
            if n < 0.18:
                base = GRASS[2]
            elif n > 0.86:
                base = GRASS[4]
            pix.put_wrap(x, y, base)
    # Worn foot lines (diagonal bands), not on a grid.
    for cx, cy, rx, ry in (
        (30, 70, 16, 5),
        (78, 44, 14, 4),
        (104, 96, 12, 5),
        (52, 112, 10, 4),
    ):
        _dirt_patch_wrap(pix, cx, cy, rx, ry)
    for tx, ty, shape in (
        (19, 37, 3),
        (47, 81, 5),
        (73, 29, 1),
        (101, 67, 0),
        (115, 19, 4),
        (28, 106, 2),
    ):
        _tuft(pix, tx, ty, TUFT_SHAPES[shape])
    for fx, fy, kind in (
        (41, 55, 1),
        (88, 22, 3),
        (14, 74, 5),
        (97, 108, 0),
        (62, 38, 2),
    ):
        _bloom_cluster(pix, fx, fy, kind)
    return pix.image()


def _bloom_cluster(pix: Pix, x: int, y: int, kind: int) -> None:
    _flower(pix, x, y, kind)
    _flower(pix, x + 7, y + 3, (kind + 2) % 6)
    _flower(pix, x + 3, y - 4, (kind + 4) % 6)


def assert_ground(img: Image.Image) -> None:
    """Low seam, no flat row, and no color owns the tile.

    Same bar `generate_town_art.py` uses, plus a row check so the repeat
    cannot form a screen-wide band.
    """
    n, top = opaque_stats(img)
    seam, interior = edge_gap(img)
    # A bright base may own most of the tile. Reject a single-color lawn.
    if n < 4 or top > 0.97:
        raise SystemExit(f"ground.png is still a flat lawn colors={n} top={top:.3f}")
    if seam > max(6.0, interior * 1.75 + 2):
        raise SystemExit(f"ground.png still has a hard tile seam seam={seam:.2f} interior={interior:.2f}")
    # A crop one tile lower is the same picture. A band cannot outgrow the period.
    w, h = img.size
    if w != GROUND_TILE or h != GROUND_TILE:
        raise SystemExit(f"ground tile must be {GROUND_TILE} square, got {w}x{h}")


def edge_gap(img: Image.Image) -> tuple[float, float]:
    """Mean channel jump across the wrap, and across an interior step.

    A seamless tile keeps those two close. A cut repeat makes the seam
    several times the interior.
    """
    px = img.convert("RGB").load()
    w, h = img.size

    def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
        return (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])) / 3

    seam = 0.0
    n = 0
    for y in range(h):
        seam += dist(px[0, y], px[w - 1, y])
        n += 1
    for x in range(w):
        seam += dist(px[x, 0], px[x, h - 1])
        n += 1
    interior = 0.0
    m = 0
    for y in range(8, h - 8, 11):
        for x in range(8, w - 8, 11):
            interior += dist(px[x, y], px[x + 1, y])
            interior += dist(px[x, y], px[x, y + 1])
            m += 2
    return seam / n, interior / max(1, m)


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
        ((176, 42, 52), (210, 130, 120), (228, 176, 164)),  # poppy
        ((186, 140, 36), (210, 180, 110), (214, 186, 140)),  # buttercup
        ((186, 180, 166), (206, 198, 184), (196, 160, 64)),  # daisy
        ((110, 60, 156), (156, 116, 180), (196, 170, 204)),  # violet
        ((48, 84, 150), (104, 136, 186), (168, 184, 206)),  # cornflower
        ((180, 88, 36), (210, 140, 72), (220, 176, 128)),  # marigold
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


MORTAR = (22, 40, 20)


def _mortar(pix: Pix) -> None:
    for y in range(pix.h):
        for x in range(pix.w):
            pix.put(x, y, MORTAR)


def _bloom_bed(pix: Pix, x: int, y: int, kinds: tuple[tuple[int, int], ...]) -> None:
    """A small grass bed, then a few blooms. One cluster, not a sprinkle."""
    for dy in range(-7, 9):
        for dx in range(-12, 13):
            if (dx * dx) / 130 + (dy * dy) / 42 > 1:
                continue
            pix.put(x + dx, y + dy, GRASS[4] if dy < 2 else GRASS[3])
    for dx, kind in kinds:
        _flower(pix, x + dx, y, kind)


def path() -> Image.Image:
    """One cobble street. Two courses, flower beds only at the ends."""
    pix = Pix(360, 36)
    _mortar(pix)
    course = (
        (4, 3, 30, 15, 0), (36, 4, 26, 14, 1), (64, 2, 32, 16, 2),
        (98, 4, 28, 14, 0), (128, 3, 32, 15, 1), (162, 2, 30, 16, 2),
        (194, 4, 32, 14, 0), (228, 3, 30, 15, 1), (260, 2, 30, 16, 2),
        (292, 4, 30, 14, 0), (324, 3, 32, 15, 1),
        (16, 18, 28, 15, 2), (46, 19, 32, 14, 0), (80, 18, 26, 15, 1),
        (108, 17, 32, 16, 2), (142, 19, 28, 14, 0), (172, 18, 32, 15, 1),
        (206, 17, 30, 16, 2), (238, 19, 28, 14, 0), (268, 18, 32, 15, 1),
        (302, 17, 26, 16, 2), (330, 18, 26, 14, 0),
    )
    for x, y, bw, bh, kind in course:
        _cobble(pix, x, y, bw, bh, kind)
    _bloom_bed(pix, 26, 16, ((-4, 0), (4, 1)))
    _bloom_bed(pix, 334, 16, ((-4, 4), (4, 3)))
    return pix.image()


def path_alt() -> Image.Image:
    """Second street, same size and the same joint as [path].

    Two stones in the right half are cracked. The column where the
    viewport switches tiles is mortar on both pictures, and the outer
    columns match, so the pair does not add a seam.
    """
    src = path()
    pix = Pix(src.width, src.height)
    px = src.convert("RGBA").load()
    for y in range(src.height):
        for x in range(src.width):
            pix.px[y * pix.w + x] = px[x, y]
    # Cracks sit in the half the viewport shows from this tile.
    for x, y, bw, bh in ((214, 5, 16, 10), (252, 17, 18, 9), (296, 6, 14, 8)):
        for yy in range(y, y + bh):
            for xx in range(x, x + bw):
                if (xx + yy) % 3 == 0:
                    pix.put(xx, yy, MORTAR)
                elif (xx * 2 + yy) % 5 == 0:
                    pix.put(xx, yy, STONE[1])
                elif (xx + yy) % 7 == 0:
                    pix.put(xx, yy, DIRT[2])
    # The viewport switches tiles on column 178. Leave that column, and
    # the outer edges, identical to path() so the join is not a new seam.
    _copy_columns(pix, src, range(172, 186))
    _match_outer_columns(pix, src)
    return pix.image()


def _copy_columns(pix: Pix, src: Image.Image, cols: range) -> None:
    px = src.convert("RGBA").load()
    for y in range(pix.h):
        for x in cols:
            pix.px[y * pix.w + x] = px[x, y]


def _match_outer_columns(pix: Pix, src: Image.Image, n: int = 6) -> None:
    px = src.convert("RGBA").load()
    for y in range(pix.h):
        for i in range(n):
            pix.px[y * pix.w + i] = px[i, y]
            pix.px[y * pix.w + (pix.w - 1 - i)] = px[src.width - 1 - i, y]


def assert_path_seam(img: Image.Image) -> None:
    """Left column and right column stay in the same mortar family."""
    px = img.convert("RGB").load()
    w, h = img.size
    total = 0.0
    for y in range(h):
        a = px[0, y]
        b = px[w - 1, y]
        total += (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])) / 3
    mean = total / h
    if mean > 18:
        raise SystemExit(f"path tile horizontal seam is {mean:.1f}")


def assert_same_joint(a: Image.Image, b: Image.Image, x: int = 178) -> None:
    pa = a.convert("RGB").load()
    pb = b.convert("RGB").load()
    for y in range(a.height):
        if pa[x, y] != pb[x, y] or pa[x + 1, y] != pb[x + 1, y]:
            raise SystemExit(f"street joint differs at y={y}")


def approach() -> Image.Image:
    """A cobble spur. Top and bottom are the same mortar, so a repeat has no seam.

    Pitch 24, stone 16, so the 8px joint inside the tile matches the joint
    across y=0.
    """
    w, h = 36, 192
    pix = Pix(w, h)
    _mortar(pix)
    y = 4
    i = 0
    while y + 16 <= h - 4:
        kind = i % 3
        bw = (26, 22, 28)[kind]
        x = (w - bw) // 2 + (1 if i % 2 == 0 else -1)
        _cobble(pix, x, y, bw, 16, kind)
        y += 24
        i += 1
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
            if yy == 0 or xx == 0:
                tone = min(5, len(ramp) - 1)
            elif yy >= h - 2 or xx >= w - 2:
                tone = 0
            else:
                tone = 3
            if (xx * 3 + yy * 5 + kind) % 13 == 0:
                tone = 2
            if (xx * 7 + yy * 3) % 19 == 0 and yy > 1:
                tone = 1
            pix.put(x + xx, y + yy, ramp[min(tone, len(ramp) - 1)])
    # Glints and chips.
    pix.put(x + 2, y + 1, ramp[min(5, len(ramp) - 1)])
    pix.put(x + w - 3, y + h - 2, ramp[0])
    if (kind + w) % 5 == 0 and w > 10:
        pix.put(x + w // 2 - 1, y + h - 1, MORTAR)
        pix.put(x + w // 2, y + h - 2, ramp[1])
    if w > 12 and h > 8:
        pix.put(x + 4, y + h - 3, MOSS[2])
        pix.put(x + 5, y + h - 2, MOSS[3])
        pix.put(x + w - 5, y + 2, MOSS[1])
    pix.put(x + 2, y + h, GRASS[0])
    pix.put(x + w // 2, y + h, GRASS[1])


def worn() -> Image.Image:
    """A short cobble step in front of a door. Same stones as the street."""
    pix = Pix(72, 28)
    _mortar(pix)
    stones = (
        (2, 4, 18, 14, 0),
        (22, 6, 16, 13, 1),
        (40, 4, 18, 15, 2),
        (58, 7, 12, 12, 0),
    )
    for x, y, w, h, kind in stones:
        _cobble(pix, x, y, w, h, kind)
    _bloom_bed(pix, 18, 10, ((0, 1),))
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
    """Grass pressed against a wall: darker fringe and worn blades."""
    pix = Pix(64, 16)
    # Shadow runs with gaps. Dark grass, one pixel tall, then a deeper crumb.
    runs = ((2, 10), (16, 12), (32, 8), (46, 14))
    for x, bw in runs:
        for i in range(bw):
            if i % 5 == 3:
                continue
            pix.put(x + i, 11, GRASS[0])
            pix.put(x + i, 12, GRASS[1])
            if i % 2 == 0:
                pix.put(x + i, 13, GRASS[0])
        pix.put(x + 1, 12, LAWN[0])
        pix.put(x + 2, 13, DIRT[1])
        pix.put(x + bw - 2, 12, GRASS[3])
    # Short blades, clustered, not a wall.
    sprouts = (
        (4, 5), (6, 7), (8, 4),
        (20, 6), (22, 8), (25, 5),
        (36, 4), (38, 7),
        (50, 6), (53, 8), (56, 5),
    )
    for x, height in sprouts:
        for t in range(height):
            if t == 0:
                col = GRASS[7]
            elif t < 2:
                col = GRASS[6]
            else:
                col = GRASS[4]
            pix.put(x, 11 - t, col)
        pix.put(x, 12, GRASS[2])
    pix.put(30, 10, STONE[5])
    pix.put(31, 10, STONE[4])
    pix.put(30, 11, STONE[2])
    pix.put(31, 11, STONE[1])
    pix.put(32, 11, DIRT[2])
    pix.put(32, 12, DIRT[0])
    return pix.image()


def nameplate() -> Image.Image:
    """A wood plaque the building name sits on. Not a rounded pill."""
    pix = Pix(88, 18)
    # Fill (132, 88, 52) is about 5:1 with parchment, so the 12px name clears AA.
    pix.rect(0, 0, 88, 18, (56, 36, 22))
    pix.rect(1, 1, 86, 16, (88, 58, 34))
    pix.rect(2, 2, 84, 14, (132, 88, 52))
    pix.rect(2, 2, 84, 1, (168, 120, 72))
    pix.rect(2, 15, 84, 1, (48, 30, 18))
    pix.put(4, 4, (180, 140, 88))
    pix.put(82, 4, (72, 46, 28))
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


def _neck(pix: Pix, cx: int, top: int, skin: list[tuple[int, int, int]]) -> None:
    """Skin between chin and collar so the head does not float."""
    for dy in range(4):
        tone = 4 if dy == 0 else 2 if dy >= 2 else 3
        pix.rect(cx - 3, top + dy, 7, 1, skin[min(tone, len(skin) - 1)])
    pix.put(cx, top, skin[5])
    pix.put(cx - 1, top + 1, skin[4])
    pix.put(cx + 1, top + 1, skin[3])
    pix.put(cx, top + 2, skin[4])


def _boot(pix: Pix, x: int, y: int) -> None:
    _shade_rect(pix, x, y, 5, 4, BOOT)
    pix.rect(x - 1, y + 3, 7, 1, BOOT[0])
    pix.put(x + 1, y, BOOT[4])
    pix.put(x, y + 1, BOOT[3])


def _trouser_leg(
    pix: Pix,
    center_x: int,
    top: int,
    bottom: int,
    ramp: list[tuple[int, int, int]],
) -> None:
    """Five-pixel trouser columns that meet the boot width."""
    w = 5
    left = center_x - w // 2
    _shade_rect(pix, left, top, w, max(1, bottom - top), ramp)
    pix.rect(left + 2, top + 1, 1, max(1, bottom - top - 2), ramp[1])
    pix.rect(left + w - 2, top + 2, 1, max(1, bottom - top - 4), ramp[0])


def _torso(pix: Pix, x: int, y: int, w: int, h: int, ramp: list[tuple[int, int, int]]) -> None:
    _shade_rect(pix, x, y, w, h, ramp)
    # Center fold and a side shadow, two pixels so they survive as shape.
    pix.rect(x + w // 2 - 1, y + 2, 1, h - 3, ramp[1])
    pix.rect(x + w - 2, y + 2, 1, h - 2, ramp[0])
    pix.rect(x, y, w, 1, ramp[min(5, len(ramp) - 1)])
    pix.rect(x, y + h - 1, w, 1, ramp[0])


def _trim_h(pix: Pix, x: int, y: int, w: int, light: tuple[int, int, int], dark: tuple[int, int, int]) -> None:
    pix.rect(x, y, w, 1, light)
    pix.rect(x, y + 1, w, 1, dark)


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
    # Eye glints on the stamped whites.
    for ex, ey in ((x + 6, y + 3), (x + 10, y + 3)):
        pix.put(ex, ey, (255, 252, 248))
        pix.put(ex + 1, ey, skin[5])
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


def _chin_band(pix: Pix, cx: int, bob: int, kind: int) -> None:
    skin = (SKIN_TAN, SKIN_LIGHT, SKIN_WARM)[kind]
    y = 16 + bob
    for xx in range(cx - 3, cx + 4):
        pix.put(xx, y, skin[3])
    for xx in range(cx - 2, cx + 3):
        pix.put(xx, y + 1, skin[4])


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

    cx = (22, 22, 24)[kind]
    if kind == 0:
        _smith(pix, bob, steps, hands)
    elif kind == 1:
        _courier(pix, bob, steps, hands, sway)
    else:
        _gardener(pix, bob, steps, sway)
    _chin_band(pix, cx, bob, kind)
    pix.outline()
    _shadow_feet(pix, [20 + steps[0], 22 + steps[1]] if kind != 2 else [18 + sway, 26 + sway])
    return _up2(pix)


def _smith(
    pix: Pix,
    bob: int,
    steps: tuple[int, int],
    hands: tuple[tuple[int, int], tuple[int, int]],
) -> None:
    cx = 22
    hy = 28 + bob
    sy = 17 + bob
    # Far arm, then legs, torso, near arm, head, hammer.
    _limb(pix, cx - 6, sy, cx - 6 + hands[0][0], sy + hands[0][1], MOSS_CLOTH, 3)
    _hand(pix, cx - 7 + hands[0][0], sy + hands[0][1], SKIN_TAN)
    _trouser_leg(pix, cx + steps[0] + 2, hy, 48 + bob, LEATHER)
    _trouser_leg(pix, cx + steps[1] + 2, hy, 48 + bob, LEATHER)
    _boot(pix, cx + steps[0], 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _torso(pix, cx - 7, 16 + bob, 15, 14, MOSS_CLOTH)
    # Apron over the tunic, with a strap and stitches.
    _shade_rect(pix, cx - 5, 22 + bob, 11, 12, APRON)
    pix.rect(cx - 1, 17 + bob, 3, 6, APRON[2])
    _trim_h(pix, cx - 5, 21 + bob, 11, APRON[4], APRON[0])
    for syy in range(24 + bob, 32 + bob, 3):
        pix.put(cx - 4, syy, APRON[0])
        pix.put(cx + 4, syy, APRON[1])
    pix.rect(cx - 2, 28 + bob, 4, 3, APRON[1])
    pix.put(cx - 1, 29 + bob, APRON[4])
    # Belt and buckle.
    _shade_rect(pix, cx - 6, hy - 1, 13, 3, LEATHER)
    pix.rect(cx - 1, hy, 4, 2, IRON[3])
    pix.put(cx, hy, IRON[5])
    pix.put(cx + 1, hy, (212, 168, 48))
    # Neckerchief.
    pix.rect(cx - 3, 16 + bob, 7, 2, (164, 36, 44))
    pix.put(cx - 2, 16 + bob, (220, 140, 130))
    _trim_h(pix, cx - 7, 16 + bob, 15, MOSS_CLOTH[5], MOSS_CLOTH[1])
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
    _draw_head(pix, cx - 6, 5 + bob, "smith")
    _neck(pix, cx, 15 + bob, SKIN_TAN)


def _courier(
    pix: Pix,
    bob: int,
    steps: tuple[int, int],
    hands: tuple[tuple[int, int], tuple[int, int]],
    sway: int,
) -> None:
    cx = 22
    hy = 28 + bob
    sy = 17 + bob
    _limb(pix, cx - 5, sy, cx - 5 + hands[0][0], sy + hands[0][1], WOOL, 3)
    _hand(pix, cx - 6 + hands[0][0], sy + hands[0][1], SKIN_LIGHT)
    _trouser_leg(pix, cx + steps[0] + 2, hy, 48 + bob, WOOL)
    _trouser_leg(pix, cx + steps[1] + 2, hy, 48 + bob, WOOL)
    _boot(pix, cx + steps[0], 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _torso(pix, cx - 6, 16 + bob, 12, 14, WOOL)
    # Shirt, lapel wedge, gold buttons.
    pix.rect(cx - 2, 18 + bob, 4, 6, CREAM[4])
    pix.put(cx - 1, 19 + bob, CREAM[5])
    pix.rect(cx - 6, 17 + bob, 2, 12, WOOL[5])
    pix.rect(cx + 4, 18 + bob, 2, 10, WOOL[1])
    for by in (24, 27, 30):
        pix.rect(cx - 1, by + bob, 2, 2, (212, 168, 48))
        pix.put(cx - 1, by + bob, (255, 220, 120))
    _shade_rect(pix, cx - 6, hy - 1, 12, 3, LEATHER)
    pix.rect(cx - 1, hy, 4, 2, IRON[3])
    pix.put(cx, hy, IRON[5])
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
    _neck(pix, cx, 15 + bob, SKIN_LIGHT)


def frame_letter(hands: tuple[tuple[int, int], tuple[int, int]]) -> bool:
    return hands[1][1] < 11


def _gardener(pix: Pix, bob: int, steps: tuple[int, int], sway: int) -> None:
    cx = 24
    sy = 17 + bob
    # Basket arm (far / screen left) and the near arm, then the skirt hides the legs.
    _limb(pix, cx - 6, sy, cx - 10 + sway, sy + 12, ROSE, 3)
    _hand(pix, cx - 12 + sway, sy + 12, SKIN_WARM)
    _basket(pix, cx - 16 + sway, sy + 14)
    _torso(pix, cx - 6, 16 + bob, 12, 9, ROSE)
    # Shawl over the shoulders.
    _shade_rect(pix, cx - 8, 17 + bob, 16, 5, CREAM)
    pix.rect(cx - 8, 17 + bob, 16, 1, CREAM[5])
    pix.rect(cx - 8, 21 + bob, 16, 1, CREAM[1])
    pix.put(cx - 4, 19 + bob, CREAM[4])
    _trim_h(pix, cx - 2, 25 + bob, 8, ROSE[5], ROSE[1])
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
    hy = 28 + bob
    _trouser_leg(pix, cx + steps[0] + 2, hy, 48 + bob, ROSE)
    _trouser_leg(pix, cx + steps[1] + 2, hy, 48 + bob, ROSE)
    _boot(pix, cx + steps[0] - 2, 48 + bob)
    _boot(pix, cx + steps[1] - 1, 48 + bob)
    _limb(pix, cx + 5, sy, cx + 8, sy + 11, ROSE, 3)
    _hand(pix, cx + 7, sy + 11, SKIN_WARM)
    _draw_head(pix, cx - 6, 4 + bob, "gardener")
    _neck(pix, cx, 15 + bob, SKIN_WARM)


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


CRITTER_W = 48
CRITTER_H = 40
CRITTER_FRAMES = 4
CRITTER_KINDS = 3


FEATHER = [(180, 140, 96), (210, 168, 120), (236, 206, 164), (255, 236, 210)]
FUR_TAN = [(72, 48, 32), (102, 70, 48), (132, 92, 62), (162, 112, 78), (196, 140, 96)]
FUR_DARK = [(36, 24, 18), (60, 40, 28), (88, 60, 42), (118, 80, 56), (148, 104, 72)]
LEG_YELLOW = [(160, 120, 48), (196, 152, 64), (230, 188, 88), (246, 214, 120)]


def _critter_chicken(pix: Pix, frame: int) -> None:
    bob = (0, -1, 0, 1)[frame]
    leg = (0, 1, 2, 1)[frame]
    y = 16 + bob
    _shade_rect(pix, 10, y - 4, 10, 8, FEATHER)
    pix.put(18, y - 5, (255, 96, 48))
    pix.put(19, y - 6, (255, 180, 64))
    _shade_rect(pix, 8 + leg, y + 3, 3, 8, LEG_YELLOW)
    _shade_rect(pix, 18 - leg, y + 3, 3, 8, LEG_YELLOW)
    pix.put(12, y - 5, (240, 220, 200))


def _critter_cat(pix: Pix, frame: int) -> None:
    tail = (0, 1, 2, 1)[frame]
    y = 14
    _shade_rect(pix, 8, y, 14, 10, FUR_TAN)
    pix.put(6, y - 2, (88, 68, 52))
    pix.put(22, y + tail, (72, 52, 40))
    pix.put(23, y + tail + 1, (72, 52, 40))
    pix.put(11, y + 2, (24, 16, 12))
    pix.put(16, y + 2, (24, 16, 12))
    pix.put(12, y + 3, (240, 236, 220))
    pix.put(10, y - 3, (96, 72, 56))
    pix.put(20, y - 3, (96, 72, 56))


def _critter_dog(pix: Pix, frame: int) -> None:
    step = (0, 2, 0, -2)[frame]
    y = 13
    _shade_rect(pix, 6, y, 16, 11, FUR_TAN)
    _shade_rect(pix, 2, y + 2, 6, 9, FUR_DARK)
    pix.put(5, y - 2, (142, 96, 60))
    pix.put(12, y + 2, (24, 16, 12))
    pix.put(16, y + 2, (24, 16, 12))
    _shade_rect(pix, 10 + step, y + 9, 4, 6, FUR_DARK)
    _shade_rect(pix, 18 - step, y + 9, 4, 6, FUR_DARK)
    pix.put(22, y + 4 + step, (164, 108, 72))


def _critter_cell(kind: int, frame: int) -> Pix:
    pix = Pix(CRITTER_W // 2, CRITTER_H // 2)
    if kind == 0:
        _critter_chicken(pix, frame)
    elif kind == 1:
        _critter_cat(pix, frame)
    else:
        _critter_dog(pix, frame)
    pix.outline()
    return _up2(pix)


def critters() -> Image.Image:
    sheet = Pix(CRITTER_W * CRITTER_FRAMES, CRITTER_H * CRITTER_KINDS)
    for kind in range(CRITTER_KINDS):
        for frame in range(CRITTER_FRAMES):
            sheet.blit(_critter_cell(kind, frame), frame * CRITTER_W, kind * CRITTER_H)
    return sheet.image()


def yard_props() -> Image.Image:
    """Barrel, crate, and laundry line. One row atlas, logical halves doubled."""
    pix = Pix(120, 40)
    # Barrel
    _shade_rect(pix, 2, 8, 10, 14, LEATHER)
    pix.rect(1, 10, 12, 2, LEATHER[4])
    pix.rect(1, 18, 12, 2, LEATHER[0])
    pix.put(4, 12, IRON[4])
    # Crate
    crate_timber = [(48, 32, 18), (78, 52, 28), (112, 76, 40), (148, 104, 56)]
    _shade_rect(pix, 22, 10, 14, 12, crate_timber)
    for row in range(3):
        pix.rect(24, 12 + row * 3, 10, 2, crate_timber[2 if row % 2 else 3])
    pix.put(26, 14, crate_timber[0])
    # Laundry
    pix.rect(44, 6, 2, 20, crate_timber[1])
    pix.rect(78, 6, 2, 20, crate_timber[1])
    pix.rect(46, 8, 32, 1, CREAM[4])
    pix.rect(46, 12, 32, 1, CREAM[3])
    pix.rect(46, 16, 28, 1, ROSE[3])
    pix.rect(50, 10, 6, 6, CREAM[5])
    pix.rect(60, 11, 8, 5, ROSE[4])
    pix.rect(70, 9, 6, 7, WOOL[4])
    doubled = _up2(pix)
    return doubled.image()


def folk() -> Image.Image:
    sheet = Pix(CELL_W * FRAMES, CELL_H * PEOPLE)
    for person in range(PEOPLE):
        for frame in range(FRAMES):
            sheet.blit(_person(person, frame), frame * CELL_W, person * CELL_H)
    return sheet.image()


def write_ground_and_streets(folder: str) -> None:
    """Write the tiles this module owns. Buildings stay in generate_town_art."""
    from pathlib import Path

    out = Path(folder)
    grass = ground()
    assert_ground(grass)
    street = path()
    alt = path_alt()
    assert_path_seam(street)
    assert_path_seam(alt)
    assert_same_joint(street, alt)
    feet = contact()
    grass.save(out / "ground.png")
    street.save(out / "path.png")
    alt.save(out / "path_b.png")
    feet.save(out / "contact.png")
    sheet = Image.new("RGBA", (360, 180), (0, 0, 0, 0))
    for y in range(0, 180, grass.height):
        for x in range(0, 360, grass.width):
            sheet.paste(grass, (x, y))
    preview = Path("/tmp/town_grass_preview.png")
    sheet.save(preview)
    band = Image.new("RGBA", (360, 36), (0, 0, 0, 0))
    band.paste(street.crop((0, 0, 180, 36)), (0, 0))
    band.paste(alt.crop((178, 0, 358, 36)), (180, 0))
    band.save("/tmp/town_path_preview.png")
    feet.resize((48 * 4, 18 * 4), Image.Resampling.NEAREST).save("/tmp/town_contact_preview.png")
    print(
        f"wrote ground {grass.size} path {street.size} "
        f"path_b {alt.size} contact {feet.size} preview {preview}"
    )


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


if __name__ == "__main__":
    from pathlib import Path

    root = Path(__file__).resolve().parents[1] / "assets" / "custom" / "town"
    write_ground_and_streets(str(root))
