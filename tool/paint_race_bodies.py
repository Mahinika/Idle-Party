"""Author Idle Party race undertunics from family pose bodies.

Does **not** rebuild gear overlays or family `body_*.png`. Writes:

  assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png
  assets/custom/char/<family>/<race>_<m|f>_body_tint_<anim>.png

Night Elf day-one: warrior male + healer female. Original pixels derived from
owned Idle Party bodies (pose/anchors) — not WoW/Kenney dumps.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image

from build_owned_gear_layers import (
    ANIMS,
    ROOT,
    bbox,
    face_region,
    is_gold_pixel,
    is_hair_color,
    is_hat_or_hood,
    is_skin,
    lum,
    sample_face,
    _chin_y,
)

REPO = Path(__file__).resolve().parents[1]

# Purple-blue night-elf skin (male slightly cooler, female slightly lighter).
SKIN_M = (104, 96, 176)
SKIN_F = (128, 112, 188)
SKIN_SHADOW = (52, 44, 110)
HAIR_M = (40, 56, 92)
HAIR_F = (156, 204, 214)
EYE = (188, 244, 255)
INK = (28, 22, 48)
# Simple cloth — not plate / not an ornate robe.
CLOTH_M = (118, 108, 86)
CLOTH_F = (214, 208, 224)


def clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))


def wash(rgb: tuple[int, int, int], target: tuple[int, int, int]) -> tuple[int, int, int]:
    """Keep source shading, swap chroma to [target]."""
    l = lum(rgb)
    tl = lum(target)
    s = l / max(0.12, tl)
    s = max(0.35, min(1.35, s))
    return (
        clamp8(target[0] * s),
        clamp8(target[1] * s),
        clamp8(target[2] * s),
    )


def in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
    if rx <= 0 or ry <= 0:
        return False
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def dist2(ax: float, ay: float, bx: float, by: float) -> float:
    return (ax - bx) * (ax - bx) + (ay - by) * (ay - by)


def load_body(family: str, anim: str) -> Image.Image:
    path = ROOT / family / f"body_{anim}.png"
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"{path} is {im.size}, want 128x128")
    return im


def classify(
    src: Image.Image,
    family: str,
) -> tuple[Image.Image, dict[str, set[tuple[int, int]]], tuple[float, float, float, float]]:
    """Tag pose pixels. Face stats come from the owned family body."""
    box = bbox(src)
    face = sample_face(src, box, family)
    fx, fy, face_half = face_region(src, face, box)
    chin = _chin_y(src, face, fx, fy, face_half)
    px = src.load()
    tags: dict[str, set[tuple[int, int]]] = {
        "skin": set(),
        "hair": set(),
        "hat": set(),
        "eye": set(),
        "ink": set(),
        "cloth": set(),
        "opaque": set(),
    }
    rx = max(11.0, face_half * 1.45)
    ry = max(12.0, face_half * 1.35)
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            tags["opaque"].add((x, y))
            rgb = (r, g, b)
            l = lum(rgb)
            in_head = in_ellipse(x, y, fx, fy, rx, ry) and y <= chin + 3
            if l < 0.11:
                tags["ink"].add((x, y))
                continue
            # Circlet / hood / gold before bright-eye, or the hat becomes "eyes".
            if y <= chin + 6 and (is_hat_or_hood(family, rgb) or is_gold_pixel(rgb)):
                tags["hat"].add((x, y))
                continue
            if family in ("mage", "healer") and y < fy - 1 and not is_skin(rgb, face):
                if is_hair_color(family, rgb):
                    tags["hair"].add((x, y))
                else:
                    tags["hat"].add((x, y))
                continue
            if is_skin(rgb, face) and (in_head or y > chin):
                # Hands / face / neck — not brown plate mistaken as peach.
                if in_head or dist2(x, y, fx, fy) <= (face_half * 3.2) ** 2:
                    tags["skin"].add((x, y))
                    continue
                if y > 88 and is_skin(rgb, face):
                    tags["skin"].add((x, y))
                    continue
            if y <= chin + 6 and is_hair_color(family, rgb):
                tags["hair"].add((x, y))
                continue
            if in_head and not is_gold_pixel(rgb) and l < 0.55 and r > g:
                # Residual brown hair that missed the family hair heuristic.
                if y < fy + 2:
                    tags["hair"].add((x, y))
                    continue
            tags["cloth"].add((x, y))
    # Specular dots in the eye band only (not cheeks, not circlet).
    for y in range(max(0, int(fy - 2)), min(128, int(fy + 4))):
        for x in range(max(0, int(fx - face_half)), min(128, int(fx + face_half) + 1)):
            if (x, y) not in tags["skin"]:
                continue
            r, g, b, a = px[x, y]
            if lum((r, g, b)) < 0.78:
                continue
            dx = abs(x - fx)
            if 3.0 <= dx <= face_half * 0.85:
                tags["skin"].discard((x, y))
                tags["eye"].add((x, y))
    return src, tags, (fx, fy, face_half, chin)


def paint_ears(
    op,
    fx: float,
    fy: float,
    face_half: float,
    chin: float,
    *,
    female: bool,
    skin: tuple[int, int, int],
    occupied: set[tuple[int, int]],
) -> set[tuple[int, int]]:
    """Pointed chibi ears, attached at the hair silhouette. Original pixels."""
    painted: set[tuple[int, int]] = set()
    length = 18 if female else 14
    width = 3.6 if female else 4.6
    lift = 13 if female else 10
    ear_y = int(fy - 1)
    left_edge = int(fx - face_half)
    right_edge = int(fx + face_half)
    for x, y in occupied:
        if abs(y - ear_y) > 3:
            continue
        if abs(x - fx) > face_half + 10:
            continue
        if x < fx:
            left_edge = min(left_edge, x)
        else:
            right_edge = max(right_edge, x)
    for side in (-1, 1):
        ax = (left_edge - 1) if side < 0 else (right_edge + 1)
        ay = fy - 2.0
        tx = ax + side * length
        ty = ay - lift
        steps = max(8, int(length + 6))
        for i in range(steps + 1):
            t = i / steps
            cx = ax + (tx - ax) * t
            cy = ay + (ty - ay) * t
            # Taper toward the tip.
            rad = width * (1.0 - t * 0.88)
            r0 = int(math.floor(cx - rad - 1))
            r1 = int(math.ceil(cx + rad + 1))
            c0 = int(math.floor(cy - rad - 1))
            c1 = int(math.ceil(cy + rad + 1))
            for y in range(max(0, c0), min(128, c1 + 1)):
                for x in range(max(0, r0), min(128, r1 + 1)):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    # Don't punch through the face core; overwrite hair at the rim.
                    if abs(x - fx) < face_half * 0.62 and fy - 6 < y < chin:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 1.05) ** 2
                    rgb = INK if edge or t > 0.92 else wash(skin, skin)
                    if not edge:
                        # Slight inner shadow toward the head.
                        shade = 0.72 + 0.28 * t
                        rgb = (
                            clamp8(skin[0] * shade),
                            clamp8(skin[1] * shade),
                            clamp8(skin[2] * shade),
                        )
                    a = 255
                    op[x, y] = (*rgb, a)
                    painted.add((x, y))
    return painted


def paint_nightelf(family: str, anim: str, *, female: bool) -> tuple[Image.Image, Image.Image]:
    src = load_body(family, anim)
    src, tags, (fx, fy, face_half, chin) = classify(src, family)
    skin_t = SKIN_F if female else SKIN_M
    hair_t = HAIR_F if female else HAIR_M
    cloth_t = CLOTH_F if female else CLOTH_M
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    op = out.load()
    sp = src.load()

    hat_fill = hair_t
    rx_hat = face_half * 1.12
    for x, y in tags["hat"]:
        # Drop the circlet/hood ring so gear helms sit on hair, not a crown.
        if y < fy - face_half * 0.72:
            continue
        if dist2(x, y, fx, fy) > (rx_hat * 1.35) ** 2:
            continue
        op[x, y] = (*wash(sp[x, y][:3], hat_fill), sp[x, y][3])

    for x, y in tags["ink"]:
        op[x, y] = (*INK, sp[x, y][3])

    for x, y in tags["hair"]:
        op[x, y] = (*wash(sp[x, y][:3], hair_t), sp[x, y][3])

    for x, y in tags["skin"]:
        rgb = wash(sp[x, y][:3], skin_t)
        # Cooler shadow under chin / ears attachment.
        if y > fy + face_half * 0.35:
            rgb = wash(rgb, SKIN_SHADOW) if lum(sp[x, y][:3]) < 0.42 else rgb
        op[x, y] = (*rgb, sp[x, y][3])

    for x, y in tags["eye"]:
        op[x, y] = (*EYE, 255)

    for x, y in tags["cloth"]:
        r, g, b, a = sp[x, y]
        # Flatten ornate gold trim to cloth.
        if is_gold_pixel((r, g, b)):
            op[x, y] = (*wash((r, g, b), cloth_t), a)
        else:
            # Flatten plate/robe shading so equipped overlays read.
            flat = wash((r, g, b), cloth_t)
            l = lum(flat)
            mix = 0.55 + 0.45 * l
            op[x, y] = (
                clamp8(cloth_t[0] * mix),
                clamp8(cloth_t[1] * mix),
                clamp8(cloth_t[2] * mix),
                a,
            )

    occupied = {(x, y) for y in range(128) for x in range(128) if op[x, y][3] > 16}
    ears = paint_ears(
        op,
        fx,
        fy,
        face_half,
        chin,
        female=female,
        skin=skin_t,
        occupied=occupied,
    )

    # Tint mask: cloth only. Copy family mask occupancy, drop skin/hair/ears.
    family_mask = Image.open(ROOT / family / f"body_tint_{anim}.png").convert("RGBA")
    tint = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    mp = tint.load()
    fp = family_mask.load()
    skip = tags["skin"] | tags["hair"] | tags["hat"] | tags["eye"] | tags["ink"] | ears
    for y in range(128):
        for x in range(128):
            if op[x, y][3] < 40:
                continue
            if (x, y) in skip:
                continue
            if fp[x, y][3] < 40:
                # New cloth pixels (rare) still get a mid gray.
                if (x, y) in tags["cloth"]:
                    shade = max(88, min(255, int(88 + lum(op[x, y][:3]) * 220)))
                    mp[x, y] = (shade, shade, shade, op[x, y][3])
                continue
            mp[x, y] = fp[x, y]
    return out, tint


def save_pair(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def main() -> int:
    jobs = (
        ("warrior", "nightelf", "m", False),
        ("healer", "nightelf", "f", True),
    )
    for family, race, sex, female in jobs:
        for anim in ANIMS:
            body, tint = paint_nightelf(family, anim, female=female)
            stem = ROOT / family / f"{race}_{sex}_body_{anim}.png"
            tstem = ROOT / family / f"{race}_{sex}_body_tint_{anim}.png"
            save_pair(stem, body)
            save_pair(tstem, tint)
            print("ok", stem.relative_to(REPO))
    print("done — night elf warrior male + healer female")
    return 0


if __name__ == "__main__":
    sys.exit(main())
