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


def _lum_rgb(rgb: tuple[int, int, int]) -> float:
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def _is_trim(rgb: tuple[int, int, int]) -> bool:
    """Brass edging. A pale robe is bright in every channel, so it is not trim."""
    r, g, b = rgb
    return r > 140 and b < 100 and r > g + 15 and g > b + 20


def _plate_highlight_and_rivets(dp, w: int, h: int, ramp, gold) -> None:
    """A solid upper-left highlight and four rivets. Both are gate requirements."""
    bb_pixels = [
        (x, y)
        for y in range(h)
        for x in range(w)
        if dp[x, y][3] >= 40
    ]
    if not bb_pixels:
        return
    xs = [p[0] for p in bb_pixels]
    ys = [p[1] for p in bb_pixels]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    span = max(1, (x1 - x0) + (y1 - y0))
    lit = sorted(
        (
            (
                1.0 - ((x - x0) + (y - y0)) / span,
                x,
                y,
            )
            for x, y in bb_pixels
        ),
        reverse=True,
    )
    for _, x, y in lit[: max(4, len(bb_pixels) // 14)]:
        dp[x, y] = (*ramp[4], 255)
    interior = [
        (x, y)
        for x, y in bb_pixels
        if 2 <= x < w - 2
        and 2 <= y < h - 2
        and dp[x, y][:3] != ramp[4]
        and all(
            dp[x + dx, y + dy][3] >= 40
            for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2))
        )
    ]
    if not interior:
        return
    step = max(1, len(interior) // 4)
    placed = 0
    for i in range(0, len(interior), step):
        x, y = interior[i]
        dp[x, y] = (*gold[3], 255)
        placed += 1
        if placed >= 4:
            break


def _surface_problems(im: Image.Image, material: str) -> list[str]:
    from facit.armor import signature_problems, surface_stats

    return signature_problems(material, surface_stats(im))


def ensure_material_signature(im: Image.Image, material: str) -> Image.Image:
    """Push a painted piece over the material gate without flattening it."""
    out = im.convert("RGBA")
    if material not in ("plate", "mail", "leather"):
        return out
    ramp = MATERIAL_RAMPS[material]
    if not _surface_problems(out, material):
        return out
    w, h = out.size
    dp = out.load()
    if material == "mail":
        for y in range(h):
            for x in range(w):
                if dp[x, y][3] < 40 or dp[x, y][:3] == ramp[0]:
                    continue
                dp[x, y] = (*ramp[3 if (x + y) % 2 == 0 else 1], 255)
    elif material == "leather":
        bright = [
            (x, y)
            for y in range(h)
            for x in range(w)
            if dp[x, y][3] >= 40 and _lum_rgb(dp[x, y][:3]) >= 185
        ]
        for x, y in bright:
            dp[x, y] = (*ramp[3], 255)
        occupied = [
            y
            for y in range(h)
            if any(dp[x, y][3] >= 40 for x in range(w))
        ]
        # Prefer rows that actually hold leather, a few pixels apart.
        picks = occupied[:: max(1, len(occupied) // 3)][:3]
        for y in picks:
            for x in range(w):
                if dp[x, y][3] >= 40:
                    dp[x, y] = (*ramp[0], 255)
    else:
        # A thin helm's ink edge is most of the picture and fails the
        # dither gate. Solid metal, and drop that edge when it has to.
        return _solid_plate(out)
    if material != "leather":
        out = style_lock(out, material)
    return out


def _solid_plate(im: Image.Image) -> Image.Image:
    """Flat plate, a compact highlight, and four rivets."""

    def paint(outline: bool) -> Image.Image:
        src = im.convert("RGBA")
        out = Image.new("RGBA", src.size, (0, 0, 0, 0))
        sp, dp = src.load(), out.load()
        ramp = MATERIAL_RAMPS["plate"]
        gold = MATERIAL_RAMPS["gold"]
        w, h = src.size
        for y in range(h):
            for x in range(w):
                if sp[x, y][3] >= 40:
                    dp[x, y] = (*ramp[2], 255)
        _plate_highlight_and_rivets(dp, w, h, ramp, gold)
        if outline:
            out = apply_outline(out)
        if _light_score(out) < MIN_LIGHT:
            lifted = _lift_left(out, "plate")
            if _light_score(lifted) >= MIN_LIGHT and not _surface_problems(
                lifted, "plate"
            ):
                return lifted
        return out

    outlined = paint(True)
    if not _surface_problems(outlined, "plate"):
        return outlined
    return paint(False)


def add_plate_bands(im: Image.Image) -> Image.Image:
    """Two dark lines across a flat plate so it reads as segments.

    A single fill looks like a robe. Lines only stay when the piece
    still passes the plate gate.
    """
    src = im.convert("RGBA")
    stats_now = _surface_problems(src, "plate")
    if stats_now:
        return src
    from facit.armor import surface_stats
    from facit.style import authored_problems

    if surface_stats(src)["dither"] > 0.12:
        return src
    bb = src.getbbox()
    if bb is None:
        return src
    out = src.copy()
    dp = out.load()
    x0, y0, x1, y1 = bb
    ramp = MATERIAL_RAMPS["plate"]
    gold = MATERIAL_RAMPS["gold"]
    for i in (1, 2):
        y = y0 + (y1 - y0) * i // 3
        for x in range(x0, x1):
            if dp[x, y][3] < 40:
                continue
            if dp[x, y][:3] in (ramp[4], gold[3]):
                continue
            dp[x, y] = (*ramp[0], 255)
    if _surface_problems(out, "plate") or authored_problems(out, "plate"):
        return src
    if _light_score(out) < MIN_LIGHT:
        return src
    return out


def brighten_leather_growth(base: Image.Image, late: Image.Image) -> Image.Image:
    """Extra leather on a small pauldron is dark outline.

    That pulls every row under the seam line, so no row counts as a
    stitch. Brighten the growth that is not the outer edge. Pixels the
    plain cut already owns stay put, so the two cuts keep one palette.
    """
    out = late.convert("RGBA").copy()
    if "leather-seams" not in _surface_problems(out, "leather"):
        return out
    sp = late.convert("RGBA").load()
    bp = base.convert("RGBA").load()
    dp = out.load()
    ramp = MATERIAL_RAMPS["leather"]
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] < 40 or bp[x, y][3] >= 40:
                continue
            edge = any(
                nx < 0 or ny < 0 or nx >= w or ny >= h or sp[nx, ny][3] < 40
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            )
            if not edge:
                dp[x, y] = (*ramp[3], 255)
    return out


def paint_material(mask: Image.Image, material: str) -> Image.Image:
    """Keep the donor's plates and straps. Stamp that material's surface on them.

    A flat fill is what made mail a grey cloud and leather a barcode. The
    donor's light and dark stay, then mail gets rings, leather a few
    stitches, and plate a highlight plus rivets.
    """
    src = mask.convert("RGBA")
    if material == "plate":
        # A lacy edge reads as cloth and also trips the dither gate.
        # Two passes, not six: more than that turns a harness into a blob.
        for _ in range(2):
            if _edge_share(src) <= 0.18:
                break
            src = _thicken(src, 1)
    w, h = src.size
    sp = src.load()
    lums = [
        _lum_rgb(sp[x, y][:3])
        for y in range(h)
        for x in range(w)
        if sp[x, y][3] >= 40
    ]
    if not lums:
        return src
    lums.sort()
    n = len(lums)
    varied = lums[-1] - lums[0] > 28
    dark_cut = lums[min(n - 1, int(n * 0.14))]
    ramp = MATERIAL_RAMPS[material if material in MATERIAL_RAMPS else "plate"]
    gold = MATERIAL_RAMPS["gold"]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dp = out.load()
    bb = src.getbbox() or (0, 0, w, h)
    x0, y0, x1, y1 = bb
    span = max(1, (x1 - x0) + (y1 - y0))

    def shade_index(lum: float, x: int, y: int) -> int:
        if varied and lum <= dark_cut:
            return 0
        if not varied:
            idx = 2
        else:
            # Rank in the donor, so a belt stays darker than a plate.
            lo, hi = 0, n
            while lo < hi:
                mid = (lo + hi) // 2
                if lums[mid] < lum:
                    lo = mid + 1
                else:
                    hi = mid
            idx = min(3, int((lo / max(1, n - 1)) * 3.99))
        if (x - x0) + (y - y0) < span * 0.42:
            idx = min(3, idx + 1)
        return idx

    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            if varied and material != "plate" and _is_trim((r, g, b)) and material != "cloth":
                dp[x, y] = (*gold[2], 255)
                continue
            dp[x, y] = (*ramp[shade_index(_lum_rgb((r, g, b)), x, y)], 255)

    if material == "mail":
        # Rings on the plates. The dark gaps between plates stay put.
        for y in range(h):
            for x in range(w):
                if dp[x, y][3] < 40 or dp[x, y][:3] in (ramp[0], gold[2]):
                    continue
                try:
                    idx = ramp.index(dp[x, y][:3])
                except ValueError:
                    idx = 2
                idx = min(4, idx + 1) if (x + y) % 2 == 0 else max(1, idx - 1)
                dp[x, y] = (*ramp[idx], 255)
    elif material == "leather":
        # A few stitch rows. Every row would be the barcode again.
        height = max(1, y1 - y0)
        for y in (
            y0 + height // 5,
            y0 + height // 2,
            y0 + (4 * height) // 5,
        ):
            if not 0 <= y < h:
                continue
            for x in range(w):
                if dp[x, y][3] < 40 or dp[x, y][:3] == gold[2]:
                    continue
                dp[x, y] = (*ramp[0], 255)
        bright = [
            (x, y)
            for y in range(h)
            for x in range(w)
            if dp[x, y][3] >= 40 and _lum_rgb(dp[x, y][:3]) >= 185
        ]
        cap = int(n * 0.05)
        for x, y in bright[cap:]:
            dp[x, y] = (*ramp[3], 255)
    elif material == "cloth":
        for y in range(h):
            for x in range(w):
                if dp[x, y][3] < 40:
                    continue
                fold = ((x - x0) // 6) % 2
                try:
                    idx = ramp.index(dp[x, y][:3])
                except ValueError:
                    idx = 2
                idx = min(4, idx + 1) if fold else max(0, idx - 1)
                dp[x, y] = (*ramp[idx], 255)
    else:
        # Big shade regions, not a speckled copy. Speckles fail the plate
        # dither gate; the armor's shape is already in the silhouette.
        blurred: dict[tuple[int, int], float] = {}
        for y in range(h):
            for x in range(w):
                if sp[x, y][3] < 40:
                    continue
                acc = count = 0
                for dy in range(-4, 5):
                    for dx in range(-4, 5):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] >= 40:
                            acc += _lum_rgb(sp[nx, ny][:3])
                            count += 1
                blurred[(x, y)] = acc / max(1, count)
        ordered = sorted(blurred.values())
        lo = ordered[len(ordered) // 3]
        hi = ordered[(2 * len(ordered)) // 3]
        for (x, y), value in blurred.items():
            if value < lo:
                color = ramp[1]
            elif value < hi:
                color = ramp[2]
            else:
                color = ramp[3]
            dp[x, y] = (*color, 255)
        _plate_highlight_and_rivets(dp, w, h, ramp, gold)
    return ensure_material_signature(style_lock(out, material), material)
