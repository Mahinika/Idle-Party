"""Single source for gear-art numbers.

Facit, the gear build, and author_gear_standard.py read palettes, ink,
light, proportions, and gate thresholds from here. Docs describe the
rules and point at this file — they do not copy the numbers.

Measured from assets/custom/char/*/_src/body_idle.png
(tool/measure_gold_masters.py): warrior edge median (26, 27, 28),
light correlation +0.14 toward the upper left. Healer’s edge median is
the pale robe, not the ink, so the shared ink follows the darker bodies.
"""
from __future__ import annotations

from PIL import Image

# Warm dark brown, close to the measured gold-master ink, never pure black.
INK: tuple[int, int, int] = (32, 22, 18)

# Image y grows downward, so a negative y component is up. Upper-left light.
LIGHT_DIR: tuple[float, float] = (-0.85, -0.70)

# Five steps, dark to light, plus a separate highlight used by plate.
def _ramp(*rows: tuple[int, int, int]) -> tuple[tuple[int, int, int], ...]:
    return rows


MATERIAL_RAMPS: dict[str, tuple[tuple[int, int, int], ...]] = {
    "cloth": _ramp(
        (78, 62, 84),
        (118, 96, 122),
        (164, 142, 158),
        (206, 188, 196),
        (236, 226, 220),
    ),
    "leather": _ramp(
        (62, 36, 22),
        (102, 62, 34),
        (142, 88, 46),
        (176, 122, 68),
        (206, 160, 104),
    ),
    "mail": _ramp(
        (48, 56, 68),
        (78, 90, 104),
        (118, 132, 146),
        (158, 172, 184),
        (196, 208, 216),
    ),
    "plate": _ramp(
        (42, 46, 54),
        (72, 78, 88),
        (108, 116, 126),
        (150, 158, 168),
        (198, 206, 214),
    ),
    "wood": _ramp(
        (72, 44, 24),
        (112, 72, 36),
        (148, 102, 52),
        (176, 132, 76),
    ),
    "gold": _ramp(
        (92, 62, 22),
        (148, 104, 36),
        (196, 152, 52),
        (232, 196, 96),
    ),
    "gem": _ramp(
        (36, 64, 112),
        (52, 104, 164),
        (96, 160, 204),
        (176, 216, 232),
    ),
    "glow": _ramp(
        (48, 24, 72),
        (104, 48, 140),
        (168, 88, 196),
        (220, 160, 232),
    ),
}

ACCENT_RAMPS = ("wood", "gold", "gem", "glow")

# Authored pieces stay on a ramp. Gold-master extracts are denser and are
# judged by EXTRACT_MIN_COLORS instead.
AUTHORED_MAX_COLORS = 28
# Native extracts include tiny trims (a healer cloak can be a handful of
# pixels). The flat-style failure lives on the authored check instead.
EXTRACT_MIN_COLORS = 4
# Chebyshev distance from a pixel to the nearest allowed ramp color.
PALETTE_MAX_DIST = 22
# Share of outline pixels that may be near-pure black (max channel < 16).
MAX_BLACK_EDGE = 0.08
# Luminance correlation with upper-left. Gold masters are weak (~0.14);
# authored pieces are painted so this stays clearly positive.
MIN_LIGHT = 0.05
# Share of 2×2 blocks that are uniform. 1.0 means the art was scaled up.
MAX_BLOCK = 0.92

# Longest bbox side on the 128 canvas, except shield (width) .
PROPORTIONS: dict[str, tuple[int, int]] = {
    "dagger": (28, 40),
    "fist": (28, 40),
    "thrown": (28, 40),
    "wand": (36, 50),
    "sword": (60, 80),
    "axe": (50, 70),
    "mace": (50, 70),
    "gun": (50, 70),
    "crossbow": (50, 70),
    "bow": (80, 95),
    "staff": (90, 110),
    "polearm": (90, 110),
    "shield": (50, 60),
    "frill": (45, 55),
}
WIDTH_TYPES = frozenset({"shield"})

# Phone sizes. BAG cell icon is 26 (lib/ui/shell/bag_slot.dart).
# Dungeon: stage width 360 / 20 tiles * owned scale 1.72 * mage read 1.0.
BAG_ICON_PX = 26
DUNGEON_HERO_PX = 31

# Existing facit thresholds (moved here so they are not copied elsewhere).
MAX_HARD_DIFF_IDLE = 0.38
MIN_MATERIAL_SIL_DIFF = 0.12
MIN_SQUINT_SIL_DIFF = 0.08
MIN_T2_GROW = 0.03
MAX_T2_SIL_DRIFT = 0.62
MAX_T2_PALETTE_DRIFT = 0.16
MIN_STYLE_SIL_DIFF = 0.12
MIN_UNIQUE_SQUINT = 0.08
MIN_READ_DIFF = 0.06

# Material surface signatures for cross-material overlays.
MAIL_MIN_DITHER = 0.22
PLATE_MIN_RIVETS = 3
PLATE_MIN_HIGHLIGHT = 0.035
PLATE_MAX_DITHER = 0.20
LEATHER_MAX_HIGHLIGHT = 0.06
LEATHER_MIN_SEAMS = 2
CLOTH_MAX_DITHER = 0.16


def allowed_colors(material: str) -> list[tuple[int, int, int]]:
    names = [material] + [n for n in ACCENT_RAMPS if n != material]
    colors = [INK]
    for name in names:
        colors.extend(MATERIAL_RAMPS[name])
    return colors


def _nearest(rgb: tuple[int, int, int], colors: list[tuple[int, int, int]]):
    best = colors[0]
    best_d = 10**9
    for c in colors:
        d = max(abs(rgb[0] - c[0]), abs(rgb[1] - c[1]), abs(rgb[2] - c[2]))
        if d < best_d:
            best_d = d
            best = c
    return best, best_d


def quantize_to_ramp(im: Image.Image, material: str) -> Image.Image:
    """Snap opaque pixels onto [material]'s ramp plus accent ramps."""
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, dp = src.load(), out.load()
    colors = allowed_colors(material)
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            best, _ = _nearest((r, g, b), colors)
            dp[x, y] = (*best, 255)
    return out


def apply_outline(im: Image.Image, ink: tuple[int, int, int] = INK) -> Image.Image:
    """1 px outer contour on pixels that touch transparency."""
    src = im.convert("RGBA")
    out = src.copy()
    sp, dp = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] < 40:
                continue
            edge = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or sp[nx, ny][3] < 40:
                    edge = True
                    break
            if edge:
                dp[x, y] = (*ink, 255)
    return out


def apply_light(im: Image.Image, material: str) -> Image.Image:
    """Step each pixel along its ramp so the upper left is brighter.

    Pixels already on an accent ramp stay on that accent.
    """
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, dp = src.load(), out.load()
    bb = src.getbbox()
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    span = max(1, (x1 - x0) + (y1 - y0))
    groups = [material] + list(ACCENT_RAMPS)
    tables = {name: MATERIAL_RAMPS[name] for name in groups}
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            if (r, g, b) == INK:
                dp[x, y] = (*INK, 255)
                continue
            home = material
            home_d = 10**9
            for name, ramp in tables.items():
                _, d = _nearest((r, g, b), list(ramp))
                if d < home_d:
                    home_d = d
                    home = name
            ramp = tables[home]
            current, _ = _nearest((r, g, b), list(ramp))
            idx = ramp.index(current) if current in ramp else len(ramp) // 2
            # Nudge one step. Upper-left gets lighter; the pattern stays.
            t = 1.0 - ((x - x0) + (y - y0)) / span
            if t > 0.55:
                idx += 1
            elif t < 0.45:
                idx -= 1
            idx = max(0, min(len(ramp) - 1, idx))
            dp[x, y] = (*ramp[idx], 255)
    return out


def on_ramp(im: Image.Image, material: str) -> bool:
    """True when every opaque pixel is already an allowed color.

    A second style_lock must not nudge the light again.
    """
    allowed = set(allowed_colors(material))
    px = im.convert("RGBA").load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            if (r, g, b) not in allowed:
                return False
    return True


def _light_score(im: Image.Image) -> float:
    """Same upper-left correlation the facit uses."""
    px = im.convert("RGBA").load()
    w, h = im.size
    xs: list[int] = []
    ys: list[int] = []
    lums: list[float] = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            xs.append(x)
            ys.append(y)
            lums.append(0.299 * r + 0.587 * g + 0.114 * b)
    if len(lums) < 8:
        return 1.0
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    mean_l = sum(lums) / len(lums)
    num = den_l = den_p = 0.0
    for x, y, lum in zip(xs, ys, lums):
        pos = -((x - cx) + (y - cy))
        dl = lum - mean_l
        num += dl * pos
        den_l += dl * dl
        den_p += pos * pos
    if den_l <= 0 or den_p <= 0:
        return 0.0
    return num / ((den_l * den_p) ** 0.5)


def style_lock(im: Image.Image, material: str = "plate") -> Image.Image:
    """Quantize, light from the upper left, then a 1 px ink contour."""
    src = im.convert("RGBA")
    if on_ramp(src, material):
        out = apply_outline(src)
    else:
        out = apply_outline(apply_light(quantize_to_ramp(src, material), material))
    for _ in range(2):
        if _light_score(out) >= MIN_LIGHT:
            return out
        out = apply_outline(apply_light(out, material))
    if _light_score(out) < MIN_LIGHT:
        # Outlining again would ink the lighter edge and flatten the light.
        out = _lift_left(out, material)
    return out


def _lift_left(im: Image.Image, material: str) -> Image.Image:
    """Last resort so a thin bar still has light from the upper left."""
    src = im.convert("RGBA")
    out = src.copy()
    sp, dp = src.load(), out.load()
    bb = src.getbbox()
    if bb is None:
        return out
    x0, _, x1, _ = bb
    mid = (x0 + x1) // 2
    ramp = MATERIAL_RAMPS[material if material in MATERIAL_RAMPS else "plate"]
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            if (r, g, b) == INK:
                if x <= mid:
                    dp[x, y] = (*ramp[min(2, len(ramp) - 1)], 255)
                continue
            current, _ = _nearest((r, g, b), list(ramp))
            idx = ramp.index(current) if current in ramp else 1
            idx += 1 if x <= mid else -1
            idx = max(0, min(len(ramp) - 1, idx))
            dp[x, y] = (*ramp[idx], 255)
    return out


def repair_outline(im: Image.Image) -> Image.Image:
    """Ink only where an extract lost its contour. Interior pixels stay."""
    src = im.convert("RGBA")
    out = src.copy()
    sp, dp = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            touches = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or sp[nx, ny][3] < 40:
                    touches = True
                    break
            if touches and max(r, g, b) > 90:
                dp[x, y] = (*INK, 255)
    return out


def _edge_share(im: Image.Image) -> float:
    px = im.load()
    w, h = im.size
    opaque = edge = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 40:
                continue
            opaque += 1
            if any(
                nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] < 40
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            ):
                edge += 1
    return edge / max(1, opaque)


def _thicken(im: Image.Image, passes: int) -> Image.Image:
    """Grow a lacy silhouette so plate reads as a solid piece, not cloth."""
    out = im.copy()
    w, h = out.size
    for _ in range(passes):
        px = out.load()
        add = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] >= 40:
                    continue
                if any(
                    0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 40
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                ):
                    add.append((x, y))
        for x, y in add:
            px[x, y] = (255, 255, 255, 255)
    return out


def paint_material(mask: Image.Image, material: str) -> Image.Image:
    """Fill [mask]'s opaque pixels with that material's surface language.

    cloth = soft vertical folds. leather = matte with dark seams.
    mail = ring dither. plate = hard plates, highlight, rivets.
    """
    src = mask.convert("RGBA")
    if material == "plate":
        # A lacy edge reads as cloth and also trips the dither gate.
        for _ in range(6):
            if _edge_share(src) <= 0.12:
                break
            src = _thicken(src, 1)
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, dp = src.load(), out.load()
    ramp = MATERIAL_RAMPS[material if material in MATERIAL_RAMPS else "plate"]
    gold = MATERIAL_RAMPS["gold"]
    bb = src.getbbox() or (0, 0, src.width, src.height)
    x0, y0, x1, y1 = bb
    w, h = src.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] < 40:
                continue
            if material == "mail":
                color = ramp[3] if (x + y) % 2 == 0 else ramp[1]
            elif material == "leather":
                seam = 4 if (y1 - y0) < 40 else 7
                color = ramp[0] if (y - y0) % seam == 0 else ramp[2]
                if (y - y0) % seam == max(1, seam // 2) and (x - x0) % 9 == 0:
                    color = gold[2]
            elif material == "cloth":
                fold = ((x - x0) // 6) % 2
                color = ramp[3] if fold else ramp[2]
            else:
                color = ramp[2]
            dp[x, y] = (*color, 255)
    if material == "plate":
        # One solid highlight in the upper left. A speckled highlight
        # counts as dither; a block does not.
        lit = []
        for y in range(h):
            for x in range(w):
                if sp[x, y][3] < 40:
                    continue
                t = 1.0 - ((x - x0) + (y - y0)) / max(1, (x1 - x0) + (y1 - y0))
                lit.append((t, x, y))
        lit.sort(reverse=True)
        for _, x, y in lit[: max(4, len(lit) // 12)]:
            dp[x, y] = (*ramp[4], 255)
    if material == "plate":
        # A few inset rivets, far apart so they do not read as dither.
        interior = []
        for y in range(2, h - 2):
            for x in range(2, w - 2):
                if sp[x, y][3] < 40:
                    continue
                if any(
                    sp[x + dx, y + dy][3] < 40
                    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2))
                ):
                    continue
                interior.append((x, y))
        dark = [p for p in interior if dp[p][:3] != ramp[4]]
        picks = dark or interior
        if picks:
            step = max(1, len(picks) // 4)
            placed = 0
            for i in range(0, len(picks), step):
                x, y = picks[i]
                dp[x, y] = (*gold[3], 255)
                placed += 1
                if placed >= 4:
                    break
    return style_lock(out, material)
