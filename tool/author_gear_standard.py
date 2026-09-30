"""Draw gear masters into gear/_authored/. Never writes live doll PNGs.

Each recipe names the silhouette hook that makes it readable at phone size.
Pixels are stepped (no rotated ellipses). The fill is the same language as
the armor: a material ramp, a dark core, a gold edge on the lit side, and
an ink contour. Existing masters are kept unless --force is passed.
"""
from __future__ import annotations

import math
import sys
from collections import deque
from pathlib import Path

from PIL import Image

from gear_style import MATERIAL_RAMPS, paint_material, style_lock
from paper_doll_paths import LIVE_CHAR

N = 128
AUTH = LIVE_CHAR / "gear" / "_authored"


def _blank() -> Image.Image:
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


# Gray is the recipe's own material. The other marks stay on accent ramps.
_GRAY = (170, 170, 176, 255)
_GOLD = (4, 5, 6, 255)
_WOOD = (8, 9, 10, 255)
_GEM = (1, 2, 3, 255)
_STRING = (12, 13, 14, 255)


def _put(im: Image.Image, pts: set[tuple[int, int]]) -> None:
    _put_color(im, pts, _GRAY)


def _put_mark(im: Image.Image, pts: set[tuple[int, int]], kind: str) -> None:
    color = {"gold": _GOLD, "wood": _WOOD, "gem": _GEM, "string": _STRING}[kind]
    _put_color(im, pts, color)


def _put_color(im: Image.Image, pts: set[tuple[int, int]], color) -> None:
    px = im.load()
    for x, y in pts:
        if 0 <= x < N and 0 <= y < N:
            px[x, y] = color


def _disk(cx: int, cy: int, r: int) -> set[tuple[int, int]]:
    pts: set[tuple[int, int]] = set()
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                pts.add((x, y))
    return pts


def _line(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    pts: list[tuple[int, int]] = []
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx - dy
    x, y = x0, y0
    while True:
        pts.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy
    return pts


def _thick(pts, radius: int) -> set[tuple[int, int]]:
    out: set[tuple[int, int]] = set()
    for x, y in pts:
        out |= _disk(x, y, radius)
    return out


def _along(a: tuple[int, int], b: tuple[int, int], t: float) -> tuple[int, int]:
    return (
        int(round(a[0] + (b[0] - a[0]) * t)),
        int(round(a[1] + (b[1] - a[1]) * t)),
    )


def _side(a: tuple[int, int], b: tuple[int, int], t: float, offset: int) -> tuple[int, int]:
    x, y = _along(a, b, t)
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = max(1, (dx * dx + dy * dy) ** 0.5)
    ox, oy = int(round(-dy / length * offset)), int(round(dx / length * offset))
    return x + ox, y + oy


def _stroke(a, b, radius: int, t0: float = 0.0, t1: float = 1.0) -> set[tuple[int, int]]:
    start, end = _along(a, b, t0), _along(a, b, t1)
    return _thick(_line(*start, *end), radius)


def _ramp_for(marker: tuple[int, int, int], material: str):
    if marker == _GOLD[:3]:
        return MATERIAL_RAMPS["gold"]
    if marker == _GEM[:3]:
        return MATERIAL_RAMPS["gem"]
    if marker == _WOOD[:3]:
        return MATERIAL_RAMPS["wood"]
    if marker == _STRING[:3]:
        dark = MATERIAL_RAMPS[material][0]
        return (dark, dark, dark, dark)
    return MATERIAL_RAMPS[material]


def _band(x, y, x0, y0, span, colors):
    t = 1.0 - ((x - x0) + (y - y0)) / span
    if t > 0.62:
        return colors[-1]
    if t > 0.35:
        return colors[len(colors) // 2]
    return colors[0]


def _distances(im: Image.Image) -> list[list[int]]:
    px = im.load()
    dist = [[999] * N for _ in range(N)]
    q: deque[tuple[int, int]] = deque()
    for y in range(N):
        for x in range(N):
            if px[x, y][3] < 40:
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        base = dist[y][x]
        if base >= 8:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and dist[ny][nx] > base + 1:
                dist[ny][nx] = base + 1
                q.append((nx, ny))
    return dist


def _edge_set(im: Image.Image) -> set[tuple[int, int]]:
    px = im.load()
    edge = set()
    for y in range(N):
        for x in range(N):
            if px[x, y][3] < 40:
                continue
            if any(
                nx < 0 or ny < 0 or nx >= N or ny >= N or px[nx, ny][3] < 40
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            ):
                edge.add((x, y))
    return edge


def _ramp_of(rgb: tuple[int, int, int]):
    for ramp in MATERIAL_RAMPS.values():
        if rgb in ramp:
            return ramp
    return None


def _lit_and_shadow(im: Image.Image) -> None:
    """Gold just inside the lit edge, dark just inside the shadow edge."""
    edge = _edge_set(im)
    px = im.load()
    gold = (*MATERIAL_RAMPS["gold"][3], 255)
    lit_hits = []
    shadow_hits = []
    for x, y in edge:
        lit = any(
            nx < 0 or ny < 0 or nx >= N or ny >= N or px[nx, ny][3] < 40
            for nx, ny in ((x - 1, y), (x, y - 1))
        )
        shadow = any(
            nx < 0 or ny < 0 or nx >= N or ny >= N or px[nx, ny][3] < 40
            for nx, ny in ((x + 1, y), (x, y + 1))
        )
        if lit:
            for dx, dy in ((1, 0), (0, 1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in edge and 0 <= nx < N and 0 <= ny < N:
                    lit_hits.append((nx, ny))
        if shadow:
            for dx, dy in ((-1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in edge and 0 <= nx < N and 0 <= ny < N:
                    shadow_hits.append((nx, ny))
    steel = set(MATERIAL_RAMPS["plate"]) | set(MATERIAL_RAMPS["cloth"])
    for x, y in shadow_hits:
        if px[x, y][3] < 40:
            continue
        ramp = _ramp_of(px[x, y][:3])
        if ramp is not None and px[x, y][:3] in steel:
            px[x, y] = (*ramp[0], 255)
    for x, y in lit_hits:
        if px[x, y][3] < 40 or px[x, y][:3] not in steel:
            continue
        px[x, y] = gold


def _fuller(im: Image.Image) -> None:
    """A dark groove down the middle. The shaded steel on either side stays."""
    plate = set(MATERIAL_RAMPS["plate"])
    dark = (*MATERIAL_RAMPS["plate"][0], 255)
    dist = _distances(im)
    px = im.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][:3] not in plate:
                continue
            d = dist[y][x]
            if d < 3:
                continue
            if any(
                0 <= x + dx < N
                and 0 <= y + dy < N
                and dist[y + dy][x + dx] > d
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                continue
            px[x, y] = dark


def _grain(im: Image.Image) -> None:
    wood = set(MATERIAL_RAMPS["wood"])
    dark = (*MATERIAL_RAMPS["wood"][0], 255)
    px = im.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][3] < 40 or px[x, y][:3] not in wood:
                continue
            if y % 4 == 0:
                px[x, y] = dark


def _rivets(im: Image.Image) -> None:
    plate = set(MATERIAL_RAMPS["plate"])
    dark = MATERIAL_RAMPS["plate"][0]
    gold = (*MATERIAL_RAMPS["gold"][3], 255)
    dist = _distances(im)
    px = im.load()
    bb = im.getbbox()
    if bb is None:
        return
    _, y0, _, y1 = bb
    mid = (y0 + y1) // 2
    picks = []
    for y in range(2, N - 2):
        for x in range(2, N - 2):
            if y > mid or dist[y][x] < 2 or px[x, y][:3] not in plate:
                continue
            if px[x, y][:3] == dark:
                continue
            picks.append((x, y))
    if not picks:
        return
    step = max(1, len(picks) // 4)
    placed = 0
    for i in range(0, len(picks), step):
        x, y = picks[i]
        if px[x, y][3] >= 40:
            px[x, y] = gold
            if x + 1 < N and px[x + 1, y][3] >= 40:
                px[x + 1, y] = gold
        placed += 1
        if placed >= 4:
            break


def _shade(im: Image.Image, material: str, kind: str) -> Image.Image:
    """Paint a mask the way armor is painted, then ink the contour."""
    src = im.convert("RGBA")
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sp, dp = src.load(), out.load()
    bb = src.getbbox()
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    span = max(1, (x1 - x0) + (y1 - y0))
    cloth = MATERIAL_RAMPS["cloth"]
    for y in range(N):
        for x in range(N):
            if sp[x, y][3] < 40:
                continue
            marker = sp[x, y][:3]
            ramp = _ramp_for(marker, material)
            if marker == _GRAY[:3] and material == "cloth":
                fold = cloth[3] if ((x - x0) // 5) % 2 else cloth[1]
                t = 1.0 - ((x - x0) + (y - y0)) / span
                color = cloth[-1] if t > 0.65 else cloth[0] if t < 0.28 else fold
            else:
                color = _band(x, y, x0, y0, span, ramp)
            dp[x, y] = (*color, 255)
    if kind == "blade":
        _fuller(out)
    elif kind in ("shield", "shield-gem"):
        _shield_face(out, gem=kind == "shield-gem")
    if kind in ("blade", "plate", "bow", "wood", "book"):
        _grain(out)
    if kind == "book":
        _book_spine(out)
    if kind == "bow":
        _bow_nocks(out)
    _lit_and_shadow(out)
    if material == "plate":
        _rivets(out)
    return style_lock(out, material)


def _shield_face(im: Image.Image, *, gem: bool) -> None:
    dist = _distances(im)
    px = im.load()
    bb = im.getbbox()
    if bb is None:
        return
    x0, y0, x1, y1 = bb
    span = max(1, (x1 - x0) + (y1 - y0))
    field = MATERIAL_RAMPS["gem"] if gem else MATERIAL_RAMPS["plate"]
    plate = set(MATERIAL_RAMPS["plate"])
    for y in range(N):
        for x in range(N):
            if dist[y][x] < 5 or px[x, y][:3] not in plate:
                continue
            ramp = field
            if gem:
                color = _band(x, y, x0, y0, span, ramp)
            else:
                t = 1.0 - ((x - x0) + (y - y0)) / span
                color = ramp[1] if t > 0.45 else ramp[0]
            px[x, y] = (*color, 255)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    gold_mid = (*MATERIAL_RAMPS["gold"][1], 255)
    gold_hi = (*MATERIAL_RAMPS["gold"][3], 255)
    for y in range(y0 + 6, y1 - 6):
        for x in (cx - 1, cx):
            if 0 <= x < N and px[x, y][3] >= 40:
                px[x, y] = gold_mid
    for x in range(x0 + 6, x1 - 6):
        for y in (cy - 1, cy):
            if 0 <= y < N and px[x, y][3] >= 40:
                px[x, y] = gold_mid
    for x, y in _disk(cx, cy, 4):
        if 0 <= x < N and 0 <= y < N and px[x, y][3] >= 40:
            px[x, y] = gold_hi
    if gem:
        for x, y in _disk(cx, cy, 2):
            if 0 <= x < N and 0 <= y < N and px[x, y][3] >= 40:
                px[x, y] = (*MATERIAL_RAMPS["gem"][-1], 255)


def _book_spine(im: Image.Image) -> None:
    bb = im.getbbox()
    if bb is None:
        return
    x0, y0, x1, y1 = bb
    cloth = set(MATERIAL_RAMPS["cloth"])
    dark = (*MATERIAL_RAMPS["cloth"][0], 255)
    px = im.load()
    sx = x0 + max(2, (x1 - x0) // 3)
    for y in range(y0 + 3, y1 - 3):
        for x in (sx, sx + 1):
            if 0 <= x < N and px[x, y][:3] in cloth:
                px[x, y] = dark


def _bow_nocks(im: Image.Image) -> None:
    """Horn tips. Color only, so the bow's outline stays the bow."""
    bb = im.getbbox()
    if bb is None:
        return
    wood = set(MATERIAL_RAMPS["wood"])
    gold = (*MATERIAL_RAMPS["gold"][2], 255)
    px = im.load()
    _, y0, _, y1 = bb
    for y in list(range(y0, y0 + 4)) + list(range(y1 - 4, y1)):
        for x in range(N):
            if px[x, y][:3] in wood:
                px[x, y] = gold


def _grip(im: Image.Image, grip, tip) -> None:
    _put_mark(im, _stroke(grip, tip, 3, 0.0, 0.30), "wood")
    _put_mark(im, _disk(*grip, 4), "gold")


def weapon(
    grip: tuple[int, int],
    tip: tuple[int, int],
    *,
    blade: int = 2,
    guard: int = 0,
    head: int = 0,
    hook: str,
) -> Image.Image:
    """A straight piece. [hook] is recorded by the recipe table, not drawn."""
    del hook
    im = _blank()
    _put(im, _stroke(grip, tip, blade, 0.22, 1.0))
    _grip(im, grip, tip)
    if guard:
        left = _side(grip, tip, 0.24, -guard)
        right = _side(grip, tip, 0.24, guard)
        _put_mark(im, _thick(_line(*left, *right), 3), "gold")
    if head:
        hx, hy = _along(grip, tip, 0.92)
        _put_mark(im, _disk(hx, hy, head), "gold")
    return im


def forked(grip, tip, *, spread: int, blade: int = 4) -> Image.Image:
    im = weapon(grip, tip, blade=blade, guard=max(5, blade + 2), hook="fork")
    for sign in (-1, 1):
        end = _side(grip, tip, 1.0, sign * spread)
        mid = _along(grip, tip, 0.78)
        _put_mark(im, _thick(_line(*mid, *end), 2), "gold")
    return im


def crescent(grip, tip, *, bulge: int, radius: int = 3) -> Image.Image:
    im = _blank()
    samples = []
    for i in range(8):
        t = 0.28 + 0.72 * i / 7
        bend = int(bulge * (1 - (2 * t - 1.3) ** 2))
        samples.append(_side(grip, tip, t, bend))
    pts: set[tuple[int, int]] = set()
    for a, b in zip(samples, samples[1:]):
        pts |= _thick(_line(*a, *b), radius)
    _put(im, pts)
    # A gold wire along the outer edge, still inside the crescent's width.
    wire: set[tuple[int, int]] = set()
    for a, b in zip(samples, samples[1:]):
        wire |= _thick(_line(*a, *b), 1)
    _put_mark(im, wire, "gold")
    _grip(im, grip, tip)
    return im


def notched(grip, tip) -> Image.Image:
    im = weapon(grip, tip, blade=6, guard=9, hook="notch")
    # Cut one flank off the middle. The other flank stays a solid blade.
    px = im.load()
    dx, dy = tip[0] - grip[0], tip[1] - grip[1]
    length2 = max(1, dx * dx + dy * dy)
    length = length2 ** 0.5
    nx, ny = -dy / length, dx / length
    for y in range(N):
        for x in range(N):
            if px[x, y][3] < 40:
                continue
            vx, vy = x - grip[0], y - grip[1]
            t = (vx * dx + vy * dy) / length2
            if t < 0.38 or t > 0.74:
                continue
            if vx * nx + vy * ny > 1:
                px[x, y] = (0, 0, 0, 0)
    return im


def bulb(grip, tip, *, blade: int = 4, size: int = 8) -> Image.Image:
    im = weapon(grip, tip, blade=blade, guard=5, hook="bulb")
    hx, hy = _along(grip, tip, 0.84)
    _put_mark(im, _disk(hx, hy, size), "gold")
    return im


def sun_mace() -> Image.Image:
    grip, tip = (104, 100), (58, 48)
    im = weapon(grip, tip, blade=3, guard=5, hook="sun")
    hx, hy = _along(grip, tip, 0.90)
    _put_mark(im, _disk(hx, hy, 8), "gold")
    for i in range(8):
        ang = i * math.pi / 4
        sx = hx + int(round(math.cos(ang) * 6))
        sy = hy + int(round(math.sin(ang) * 6))
        ex = hx + int(round(math.cos(ang) * 16))
        ey = hy + int(round(math.sin(ang) * 16))
        _put_mark(im, _thick(_line(sx, sy, ex, ey), 1), "gold")
    return im


def block_head(grip, tip, size: int) -> Image.Image:
    im = weapon(grip, tip, blade=3, guard=4, hook="block")
    hx, hy = _along(grip, tip, 0.92)
    pts = {
        (x, y)
        for y in range(hy - size, hy + size + 1)
        for x in range(hx - size, hx + size + 1)
    }
    _put_mark(im, pts, "gold")
    return im


def kite_shield(w: int, h: int, point: bool) -> Image.Image:
    im = _blank()
    pts: set[tuple[int, int]] = set()
    cx, top = 28, 58
    for y in range(h):
        t = y / max(1, h - 1)
        half = int(w / 2 * (1 - t * (0.85 if point else 0.15)))
        for x in range(cx - half, cx + half):
            pts.add((x, top + y))
    _put(im, pts)
    return im


def round_shield(d: int) -> Image.Image:
    im = _blank()
    _put(im, _disk(28, 82, d // 2))
    return im


def book(
    w: int,
    h: int,
    *,
    clasp: bool = False,
    open_book: bool = False,
    ribbon: bool = False,
) -> Image.Image:
    im = _blank()
    pts: set[tuple[int, int]] = set()
    x0, y0 = 8, 70
    if open_book:
        w = min(60, w + 14)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            pts.add((x, y))
    if open_book:
        for y in range(y0 + 2, y0 + h - 2):
            pts.discard((x0 + w // 2, y))
            pts.discard((x0 + w // 2 + 1, y))
    _put(im, pts)
    if clasp:
        _put_mark(im, _disk(x0 + w + 6, y0 + h // 2, 11), "gold")
    if ribbon:
        rib = {
            (x, y)
            for y in range(y0, y0 + h + 12)
            for x in range(x0 + 4, x0 + 10)
        }
        _put_mark(im, rib, "gold")
    return im


def bow(
    height: int, *, recurve: bool = False, wings: bool = False, arrow: bool = False
) -> Image.Image:
    im = _blank()
    pts: set[tuple[int, int]] = set()
    top, bot = 20, 20 + height
    cx = 96
    for i, y in enumerate(range(top, bot)):
        t = i / max(1, height)
        bend = int(16 * (1 - (2 * t - 1) ** 2))
        if recurve and (t < 0.12 or t > 0.88):
            bend -= 6
        x = cx - bend
        pts |= _disk(x, y, 2)
    _put(im, pts)
    _put_mark(im, {(cx + 2, y) for y in range(top, bot)}, "string")
    if wings:
        for y in (top + 14, bot - 14):
            t = (y - top) / max(1, height)
            bend = int(16 * (1 - (2 * t - 1) ** 2))
            limb_x = cx - bend
            _put_mark(im, _disk(limb_x - 12, y, 6), "gold")
            _put_mark(im, _thick(_line(limb_x - 12, y, limb_x, y), 2), "gold")
    if arrow:
        mid = (top + bot) // 2
        _put(im, _thick(_line(cx - 30, mid, cx + 6, mid), 2))
        _put_mark(im, _disk(cx - 30, mid, 4), "gold")
    return im


def staff(height: int, head: str) -> Image.Image:
    im = _blank()
    top = 16
    bot = top + height
    x = 100
    _put(im, _thick(_line(x, top, x - 6, bot), 3))
    if head == "orb":
        _put_mark(im, _disk(x, top + 4, 6), "gem")
    elif head == "fork":
        _put_mark(im, _thick(_line(x, top + 8, x - 10, top), 2), "gold")
        _put_mark(im, _thick(_line(x, top + 8, x + 10, top), 2), "gold")
    elif head == "diamond":
        _put_mark(im, _disk(x, top + 6, 8), "gem")
    elif head == "crook":
        _put_mark(im, _thick(_line(x, top + 10, x - 14, top + 2), 2), "gold")
        _put_mark(im, _disk(x - 14, top + 2, 4), "gem")
    return im


def gun() -> Image.Image:
    im = _blank()
    _put_mark(im, _thick(_line(100, 96, 64, 78), 3), "wood")
    _put(im, _thick(_line(68, 80, 42, 66), 2))
    _put_mark(im, _disk(40, 64, 4), "gold")
    return im


def crossbow() -> Image.Image:
    im = _blank()
    _put_mark(im, _thick(_line(40, 74, 96, 74), 3), "wood")
    _put(im, _thick(_line(68, 74, 92, 102), 3))
    _put_mark(im, _disk(40, 74, 5) | _disk(96, 74, 5), "gold")
    return im


def polearm() -> Image.Image:
    im = _blank()
    _put(im, _thick(_line(96, 112, 96, 18), 2))
    _put_mark(im, _disk(112, 30, 9), "gold")
    return im


def fist() -> Image.Image:
    im = _blank()
    _put(im, _disk(70, 80, 8) | _disk(84, 76, 6) | _disk(58, 76, 5))
    _put_mark(im, _disk(70, 78, 3), "gold")
    return im


def thrown() -> Image.Image:
    im = _blank()
    _put(im, _thick(_line(64, 72, 64, 100), 2) | _thick(_line(52, 86, 76, 86), 2))
    _put_mark(im, _disk(64, 86, 4), "gold")
    return im


def wand() -> Image.Image:
    im = _blank()
    _put(im, _thick(_line(108, 96, 78, 62), 2))
    _put_mark(im, _disk(76, 58, 5), "gem")
    return im


# grip, tip chosen so the bbox's long side lands inside gear_style.PROPORTIONS.
# hook: what a player can see at 26 px.
RECIPES: dict[str, tuple[Image.Image, str]] = {}


def _add(stem: str, im: Image.Image, hook: str, material: str, kind: str) -> None:
    RECIPES[stem] = (_shade(im, material, kind), hook)


def _build_recipes() -> None:
    if RECIPES:
        return
    g, t = (108, 100), (46, 36)
    _add("sword_t0", weapon(g, t, blade=6, guard=9, hook="straight"), "straight crossguard", "plate", "blade")
    _add("sword_thunderfury", forked(g, t, spread=11, blade=6), "forked tip", "plate", "blade")
    _add("sword_warglaive", crescent(g, t, bulge=16, radius=4), "crescent edge", "plate", "blade")
    _add("sword_runebound", notched(g, t), "wide blade with a notch", "plate", "blade")
    _add("sword_emberfang", bulb(g, t, blade=6, size=12), "bulb near the tip", "plate", "blade")
    dg, dt = (100, 96), (74, 70)
    _add("dagger_t0", weapon(dg, dt, blade=3, guard=4, hook="short"), "short blade", "plate", "blade")
    _add("dagger_shadowfang", crescent(dg, (72, 68), bulge=8, radius=2), "curved fang", "plate", "blade")
    _add("dagger_nightbite", forked(dg, dt, spread=7, blade=3), "split tip", "plate", "blade")
    _add("dagger_venomkiss", bulb(dg, (76, 72), blade=3, size=7), "leaf bulge", "plate", "blade")
    _add("mace_t0", weapon((104, 100), (58, 48), blade=3, head=5, hook="round"), "small round head", "plate", "plate")
    _add("mace_lightbringer", sun_mace(), "spiked round head", "plate", "plate")
    _add("mace_dawnbreak", block_head((104, 100), (52, 46), 6), "block head", "plate", "plate")
    hammer = weapon((104, 100), (58, 48), blade=3, head=5, hook="hammer")
    _put_mark(hammer, _disk(*_side((104, 100), (58, 48), 0.88, 10), 5), "gold")
    _add("mace_soulhammer", hammer, "head sticks out to one side", "plate", "plate")
    ag, at = (104, 100), (56, 46)
    axe0 = weapon(ag, at, blade=3, hook="axe")
    _put_mark(axe0, _disk(*_side(ag, at, 0.86, 8), 6), "gold")
    _add("axe_t0", axe0, "blade on one side", "plate", "plate")
    axe = weapon(ag, at, blade=3, hook="double")
    _put_mark(axe, _disk(*_side(ag, at, 0.85, 9), 6), "gold")
    _put_mark(axe, _disk(*_side(ag, at, 0.85, -9), 6), "gold")
    _add("axe_goreblade", axe, "blades on both sides", "plate", "plate")
    beard = weapon(ag, at, blade=3, hook="beard")
    _put_mark(beard, _disk(*_side(ag, at, 0.68, 10), 7), "gold")
    _add("axe_bloodhowl", beard, "beard drops below the head", "plate", "plate")
    _add("axe_stormcleave", crescent(ag, at, bulge=16, radius=2), "wide crescent head", "plate", "blade")
    _add("bow_t0", bow(86), "plain bow", "wood", "bow")
    _add("bow_eagle", bow(86, recurve=True), "tips bend back", "wood", "bow")
    _add("bow_windpierce", bow(86, arrow=True), "arrow across the limbs", "wood", "bow")
    _add("bow_ashflight", bow(86, wings=True), "winged tips", "wood", "bow")
    _add("staff_t0", staff(96, "orb"), "orb head", "wood", "wood")
    _add("staff_frostfire", staff(96, "fork"), "forked head", "wood", "wood")
    _add("staff_nethercore", staff(100, "diamond"), "wide diamond head", "wood", "wood")
    _add("staff_voidspire", staff(96, "crook"), "crooked head", "wood", "wood")
    _add("shield_t0", round_shield(54), "round shield", "plate", "shield")
    _add("shield_aegis", kite_shield(58, 46, point=True), "pointed kite", "plate", "shield-gem")
    _add("shield_ironwall", kite_shield(60, 36, point=False), "broad rectangle", "plate", "shield")
    _add("shield_frostwall", kite_shield(50, 64, point=True), "tall narrow kite", "plate", "shield")
    _add("frill_t0", book(34, 46), "closed book", "cloth", "book")
    _add("frill_prism", book(26, 46, clasp=True), "clasp on the edge", "cloth", "book")
    _add("frill_soulcodex", book(36, 46, open_book=True), "open pages", "cloth", "book")
    _add("frill_embercodex", book(34, 40, ribbon=True), "bookmark sticking out", "cloth", "book")
    _add("wand_t0", wand(), "short rod with a gem", "wood", "wood")
    _add("gun_t0", gun(), "stock and a long barrel", "plate", "plate")
    _add("crossbow_t0", crossbow(), "wide prod on a stock", "plate", "plate")
    _add("polearm_t0", polearm(), "long shaft with a side blade", "wood", "wood")
    _add("fist_t0", fist(), "closed fist", "plate", "plate")
    _add("thrown_t0", thrown(), "four-point star", "plate", "plate")


SAMPLE = {
    "sword_t0",
    "sword_thunderfury",
    "mace_lightbringer",
    "shield_aegis",
    "shield_t0",
    "wand_t0",
}


def write_shared(stems: set[str], *, force: bool) -> list[str]:
    _build_recipes()
    AUTH.mkdir(parents=True, exist_ok=True)
    written = []
    for stem in sorted(stems):
        dest = AUTH / f"{stem}_idle.png"
        if dest.exists() and not force:
            continue
        im, hook = RECIPES[stem]
        im.save(dest)
        written.append(f"{stem} ({hook})")
    return written


def write_healer_chest_materials() -> list[str]:
    """Keep the current silhouette, paint cloth/leather/mail/plate surfaces."""
    gear = LIVE_CHAR / "healer" / "gear"
    auth = gear / "_authored"
    auth.mkdir(parents=True, exist_ok=True)
    written = []
    native = Image.open(gear / "chest_t0_idle.png").convert("RGBA")
    for material in ("cloth", "leather", "mail", "plate"):
        painted = paint_material(native, material)
        name = "chest_t0_idle.png" if material == "cloth" else f"chest_{material}_t0_idle.png"
        # Native cloth stays the gold-master extract. Only cross-materials.
        if material == "cloth":
            continue
        dest = auth / name
        painted.save(dest)
        written.append(name)
    return written


def _material_of(stem: str) -> str:
    base = stem.split("_", 1)[0]
    if base in ("bow", "staff", "wand", "polearm"):
        return "wood"
    if base == "frill":
        return "cloth"
    return "plate"


def _check(stems: set[str]) -> list[str]:
    import json

    from facit.hands import proportion_key
    from facit.style import authored_problems
    from facit.unique import pair_problem
    from make_gear_slot_icons import make_icon
    from paper_doll_paths import TOOL

    catalog = json.loads((TOOL / "active_gear_models.json").read_text(encoding="utf-8"))
    images: dict[str, Image.Image] = {}
    problems: list[str] = []
    for ids in catalog["shared"].values():
        for stem in ids:
            path = AUTH / f"{stem}_idle.png"
            if not path.exists():
                path = LIVE_CHAR / "gear" / f"{stem}_idle.png"
            if not path.exists():
                problems.append(f"{stem} missing")
                continue
            im = Image.open(path).convert("RGBA")
            images[stem] = im
            if stem not in stems:
                continue
            bb = im.getbbox()
            if bb is None:
                problems.append(f"{stem} empty")
                continue
            w, h = bb[2] - bb[0], bb[3] - bb[1]
            key = proportion_key(stem.split("_", 1)[0], w, h)
            if key:
                problems.append(f"{stem} proportion {key} {w}x{h}")
            for item in authored_problems(im, _material_of(stem)):
                problems.append(f"{stem} style {item}")
    for base, ids in catalog["shared"].items():
        group = {stem: images[stem] for stem in ids if stem in images}
        icons = {}
        for stem, im in group.items():
            icon = make_icon(im)
            if icon is not None:
                icons[stem] = icon
        names = sorted(group)
        for i, left in enumerate(names):
            for right in names[i + 1 :]:
                key = pair_problem(group[left], group[right])
                if key:
                    problems.append(f"{base} doll {left}|{right} {key}")
                if left in icons and right in icons:
                    key = pair_problem(icons[left], icons[right])
                    if key:
                        problems.append(f"{base} icon {left}|{right} {key}")
    return problems


def _sheet() -> None:
    stems = sorted(RECIPES)
    cols = 8
    cell = 128
    rows = (len(stems) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (24, 18, 16, 255))
    for i, stem in enumerate(stems):
        im = RECIPES[stem][0]
        sheet.paste(im, ((i % cols) * cell, (i // cols) * cell), im)
    out = Path(__file__).resolve().parents[1] / "tool" / "out"
    out.mkdir(parents=True, exist_ok=True)
    big = sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST)
    dest = out / "weapon_sheet.png"
    tmp = out / "weapon_sheet.writing.png"
    big.save(tmp)
    tmp.replace(dest)
    print(f"sheet {dest}")


def main() -> None:
    force = "--force" in sys.argv
    _build_recipes()
    if "--all" in sys.argv:
        stems = set(RECIPES)
    elif "--sample" in sys.argv:
        stems = set(SAMPLE)
    else:
        print("pass --sample or --all")
        raise SystemExit(2)
    wrote = write_shared(stems, force=force)
    if "--healer-chests" in sys.argv:
        wrote += write_healer_chest_materials()
    print(f"wrote {len(wrote)} masters")
    for line in wrote:
        print(" ", line)
    if "--all" in sys.argv:
        _sheet()
        problems = _check(stems)
        if problems:
            print(f"{len(problems)} problems")
            for line in problems:
                print(" ", line)
            raise SystemExit(1)
        print("style, proportion, unique ok")


if __name__ == "__main__":
    main()
