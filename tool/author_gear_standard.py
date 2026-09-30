"""Draw gear masters into gear/_authored/. Never writes live doll PNGs.

Each recipe names the silhouette hook that makes it readable at phone size.
Pixels are stepped (no rotated ellipses). gear_style.style_lock paints them
in the shared palette. Existing masters are kept unless --force is passed.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

from gear_style import paint_material, style_lock
from paper_doll_paths import LIVE_CHAR

N = 128
AUTH = LIVE_CHAR / "gear" / "_authored"


def _blank() -> Image.Image:
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def _put(im: Image.Image, pts: set[tuple[int, int]]) -> None:
    px = im.load()
    for x, y in pts:
        if 0 <= x < N and 0 <= y < N:
            px[x, y] = (170, 170, 176, 255)


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
    pts = _stroke(grip, tip, 1, 0.0, 0.28)
    pts |= _stroke(grip, tip, blade, 0.22, 1.0)
    if guard:
        left = _side(grip, tip, 0.24, -guard)
        right = _side(grip, tip, 0.24, guard)
        pts |= _thick(_line(*left, *right), 1)
    if head:
        hx, hy = _along(grip, tip, 0.92)
        pts |= _disk(hx, hy, head)
    _put(im, pts)
    _put(im, _disk(*grip, 2))
    return im


def forked(grip, tip, *, spread: int) -> Image.Image:
    im = weapon(grip, tip, blade=2, guard=5, hook="fork")
    px = im.load()
    for sign in (-1, 1):
        end = _side(grip, tip, 1.05, sign * spread)
        mid = _along(grip, tip, 0.72)
        for x, y in _thick(_line(*mid, *end), 2):
            if 0 <= x < N and 0 <= y < N:
                px[x, y] = (170, 170, 176, 255)
    return im


def crescent(grip, tip, *, bulge: int) -> Image.Image:
    im = _blank()
    pts = _stroke(grip, tip, 1, 0.0, 0.3)
    samples = []
    for i in range(8):
        t = 0.28 + 0.72 * i / 7
        bend = int(bulge * (1 - (2 * t - 1.3) ** 2))
        samples.append(_side(grip, tip, t, bend))
    for a, b in zip(samples, samples[1:]):
        pts |= _thick(_line(*a, *b), 2)
    _put(im, pts)
    _put(im, _disk(*grip, 2))
    return im


def notched(grip, tip) -> Image.Image:
    im = weapon(grip, tip, blade=3, guard=7, hook="notch")
    px = im.load()
    a = _along(grip, tip, 0.55)
    b = _along(grip, tip, 0.7)
    for x, y in _thick(_line(*a, *b), 2):
        if 0 <= x < N and 0 <= y < N:
            px[x, y] = (0, 0, 0, 0)
    return im


def bulb(grip, tip) -> Image.Image:
    im = weapon(grip, tip, blade=2, guard=4, hook="bulb")
    hx, hy = _along(grip, tip, 0.82)
    _put(im, _disk(hx, hy, 6))
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
    if clasp:
        pts |= _disk(x0 + w + 12, y0 + h // 2, 11)
    if ribbon:
        for y in range(y0, y0 + h + 12):
            for x in range(x0 + 4, x0 + 10):
                pts.add((x, y))
    _put(im, pts)
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
        pts |= _disk(x, y, 1)
        pts.add((cx + 2, y))
    if wings:
        pts |= _disk(cx - 4, top + 4, 4)
        pts |= _disk(cx - 4, bot - 4, 4)
    if arrow:
        mid = (top + bot) // 2
        pts |= _thick(_line(cx - 30, mid, cx + 6, mid), 2)
        pts |= _disk(cx - 30, mid, 4)
    _put(im, pts)
    return im


def staff(height: int, head: str) -> Image.Image:
    im = _blank()
    top = 16
    bot = top + height
    x = 100
    pts = _thick(_line(x, top, x - 6, bot), 1)
    if head == "orb":
        pts |= _disk(x, top + 4, 4)
    elif head == "fork":
        pts |= _thick(_line(x, top + 8, x - 8, top), 2)
        pts |= _thick(_line(x, top + 8, x + 8, top), 2)
    elif head == "diamond":
        pts |= _disk(x, top + 6, 7)
    elif head == "crook":
        pts |= _thick(_line(x, top + 10, x - 12, top + 2), 2)
        pts |= _disk(x - 12, top + 2, 3)
    _put(im, pts)
    return im


def gun() -> Image.Image:
    im = _blank()
    pts = _thick(_line(100, 96, 64, 78), 3)
    pts |= _thick(_line(68, 80, 42, 66), 2)
    pts |= _disk(40, 64, 3)
    _put(im, pts)
    return im


def crossbow() -> Image.Image:
    im = _blank()
    pts = _thick(_line(40, 74, 96, 74), 2)
    pts |= _thick(_line(68, 74, 92, 102), 3)
    pts |= _disk(40, 74, 4)
    pts |= _disk(96, 74, 4)
    _put(im, pts)
    return im


def polearm() -> Image.Image:
    im = _blank()
    pts = _thick(_line(96, 112, 96, 18), 2)
    pts |= _disk(112, 30, 9)
    _put(im, pts)
    return im


def fist() -> Image.Image:
    im = _blank()
    pts = _disk(70, 80, 8) | _disk(84, 76, 6) | _disk(58, 76, 5)
    _put(im, pts)
    return im


def thrown() -> Image.Image:
    im = _blank()
    pts = _thick(_line(64, 72, 64, 100), 2)
    pts |= _thick(_line(52, 86, 76, 86), 2)
    pts |= _disk(64, 86, 3)
    _put(im, pts)
    return im


def wand() -> Image.Image:
    im = _blank()
    pts = _thick(_line(108, 96, 78, 62), 1)
    pts |= _disk(76, 58, 3)
    _put(im, pts)
    return im


# grip, tip chosen so the bbox's long side lands inside gear_style.PROPORTIONS.
# hook: what a player can see at 26 px.
RECIPES: dict[str, tuple[Image.Image, str]] = {}


def _add(stem: str, im: Image.Image, hook: str, material: str) -> None:
    RECIPES[stem] = (style_lock(im, material), hook)


def _build_recipes() -> None:
    if RECIPES:
        return
    g, t = (108, 100), (46, 36)
    _add("sword_t0", weapon(g, t, blade=2, guard=6, hook="straight"), "straight crossguard", "plate")
    _add("sword_thunderfury", forked(g, t, spread=8), "forked tip", "plate")
    _add("sword_warglaive", crescent(g, t, bulge=14), "crescent edge", "plate")
    _add("sword_runebound", notched(g, t), "wide blade with a notch", "plate")
    _add("sword_emberfang", bulb(g, t), "bulb near the tip", "plate")
    _add("dagger_t0", weapon((100, 96), (74, 70), blade=1, guard=3, hook="short"), "short blade", "plate")
    _add("dagger_shadowfang", crescent((100, 96), (72, 68), bulge=8), "curved fang", "plate")
    _add("dagger_nightbite", forked((100, 96), (74, 70), spread=5), "split tip", "plate")
    _add("dagger_venomkiss", bulb((100, 96), (76, 72)), "leaf bulge", "plate")
    _add("mace_t0", weapon((104, 100), (58, 48), blade=1, head=4, hook="round"), "small round head", "plate")
    _add("mace_lightbringer", weapon((104, 100), (58, 48), blade=1, head=7, guard=4, hook="sun"), "spiked round head", "plate")
    _add("mace_dawnbreak", weapon((104, 100), (52, 46), blade=1, head=3, hook="block"), "block head", "plate")
    spiked = weapon((104, 100), (58, 48), blade=1, head=5, hook="hammer")
    _put(spiked, _disk(*_side((104, 100), (58, 48), 0.9, 8), 3))
    _add("mace_soulhammer", spiked, "head sticks out to one side", "plate")
    axe0 = weapon((104, 100), (56, 46), blade=1, hook="axe")
    _put(axe0, _disk(*_side((104, 100), (56, 46), 0.86, 7), 5))
    _add("axe_t0", axe0, "blade on one side", "plate")
    axe = weapon((104, 100), (56, 46), blade=1, hook="double")
    _put(axe, _disk(*_side((104, 100), (56, 46), 0.85, 8), 5))
    _put(axe, _disk(*_side((104, 100), (56, 46), 0.85, -8), 5))
    _add("axe_goreblade", axe, "blades on both sides", "plate")
    beard = weapon((104, 100), (56, 46), blade=1, hook="beard")
    _put(beard, _disk(*_side((104, 100), (56, 46), 0.7, 9), 6))
    _add("axe_bloodhowl", beard, "beard drops below the head", "plate")
    _add("axe_stormcleave", crescent((104, 100), (56, 46), bulge=16), "wide crescent head", "plate")
    _add("bow_t0", bow(86), "plain bow", "wood")
    _add("bow_eagle", bow(86, recurve=True), "tips bend back", "wood")
    _add("bow_windpierce", bow(86, arrow=True), "arrow across the limbs", "wood")
    _add("bow_ashflight", bow(86, wings=True), "winged tips", "wood")
    _add("staff_t0", staff(96, "orb"), "orb head", "wood")
    _add("staff_frostfire", staff(96, "fork"), "forked head", "wood")
    _add("staff_nethercore", staff(100, "diamond"), "wide diamond head", "wood")
    _add("staff_voidspire", staff(96, "crook"), "crooked head", "wood")
    _add("shield_t0", round_shield(54), "round shield", "plate")
    _add("shield_aegis", kite_shield(58, 46, point=True), "pointed kite", "plate")
    _add("shield_ironwall", kite_shield(60, 36, point=False), "broad rectangle", "plate")
    _add("shield_frostwall", kite_shield(50, 64, point=True), "tall narrow kite", "plate")
    _add("frill_t0", book(34, 46), "closed book", "cloth")
    _add("frill_prism", book(26, 46, clasp=True), "clasp on the edge", "cloth")
    _add("frill_soulcodex", book(36, 46, open_book=True), "open pages", "cloth")
    _add("frill_embercodex", book(34, 40, ribbon=True), "bookmark sticking out", "cloth")
    _add("wand_t0", wand(), "short rod with a gem", "wood")
    _add("gun_t0", gun(), "stock and a long barrel", "plate")
    _add("crossbow_t0", crossbow(), "wide prod on a stock", "plate")
    _add("polearm_t0", polearm(), "long shaft with a side blade", "wood")
    _add("fist_t0", fist(), "closed fist", "plate")
    _add("thrown_t0", thrown(), "four-point star", "plate")


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


def main() -> None:
    force = "--force" in sys.argv
    sample = "--sample" in sys.argv or "--all" not in sys.argv
    stems = SAMPLE if sample and "--all" not in sys.argv else set(RECIPES) if False else set()
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


if __name__ == "__main__":
    main()
