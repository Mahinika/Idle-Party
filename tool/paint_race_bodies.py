"""Author Idle Party race undertunics from family pose bodies.

Cataclysm playable races (12) — no Pandaren. Does **not** rebuild gear overlays
or family `body_*.png`. Writes:

  assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png
  assets/custom/char/<family>/<race>_<m|f>_body_tint_<anim>.png

Original pixels derived from owned Idle Party bodies — not WoW dumps.
Human uses the family body (no race files).
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass
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
    strip_head_from_layer,
    _chin_y,
)

REPO = Path(__file__).resolve().parents[1]

INK = (28, 22, 48)
CLOTH_M = (118, 108, 86)
CLOTH_F = (214, 208, 224)


@dataclass(frozen=True)
class RaceLook:
    key: str
    skin_m: tuple[int, int, int]
    skin_f: tuple[int, int, int]
    skin_shadow: tuple[int, int, int]
    hair_m: tuple[int, int, int]
    hair_f: tuple[int, int, int]
    eye: tuple[int, int, int]
    ears: bool = False
    ear_length: int = 12
    tusks: bool = False
    horns_up: bool = False
    horns_side: bool = False
    fur: bool = False


# Alliance then Horde — same order as LOOK UI.
RACES: tuple[RaceLook, ...] = (
    RaceLook(
        "dwarf",
        (196, 148, 112),
        (210, 164, 128),
        (120, 78, 54),
        (92, 52, 28),
        (168, 96, 48),
        (240, 236, 220),
    ),
    RaceLook(
        "nightelf",
        (104, 96, 176),
        (128, 112, 188),
        (52, 44, 110),
        (40, 56, 92),
        (186, 196, 214),
        (188, 244, 255),
        ears=True,
        ear_length=14,
    ),
    RaceLook(
        "gnome",
        (210, 168, 132),
        (220, 180, 148),
        (130, 90, 62),
        (48, 140, 72),
        (220, 96, 160),
        (250, 248, 240),
        ears=True,
        ear_length=7,
    ),
    RaceLook(
        "draenei",
        (120, 148, 188),
        (148, 172, 208),
        (56, 72, 110),
        (220, 228, 236),
        (236, 240, 248),
        (220, 248, 255),
        horns_up=True,
    ),
    RaceLook(
        "worgen",
        (96, 96, 104),
        (112, 112, 120),
        (48, 48, 56),
        (40, 40, 48),
        (72, 72, 80),
        (255, 220, 120),
        fur=True,
    ),
    RaceLook(
        "orc",
        (72, 128, 64),
        (96, 148, 80),
        (36, 72, 32),
        (36, 40, 36),
        (48, 44, 40),
        (255, 240, 180),
        tusks=True,
    ),
    RaceLook(
        "forsaken",
        (120, 140, 120),
        (140, 156, 140),
        (56, 68, 56),
        (48, 40, 48),
        (72, 64, 72),
        (180, 255, 160),
    ),
    RaceLook(
        "tauren",
        (120, 84, 52),
        (148, 108, 72),
        (64, 40, 24),
        (72, 48, 28),
        (96, 68, 40),
        (255, 236, 180),
        fur=True,
        horns_side=True,
    ),
    RaceLook(
        "troll",
        (64, 120, 160),
        (88, 144, 180),
        (28, 64, 88),
        (32, 40, 56),
        (200, 80, 48),
        (255, 248, 200),
        ears=True,
        ear_length=16,
        tusks=True,
    ),
    RaceLook(
        "bloodelf",
        (228, 188, 160),
        (236, 200, 176),
        (140, 96, 72),
        (180, 40, 36),
        (220, 168, 64),
        (120, 220, 120),
        ears=True,
        ear_length=13,
    ),
    RaceLook(
        "goblin",
        (96, 148, 64),
        (120, 168, 80),
        (48, 80, 32),
        (28, 28, 28),
        (200, 48, 48),
        (255, 248, 120),
        ears=True,
        ear_length=10,
    ),
)


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
                if y < fy + 2:
                    tags["hair"].add((x, y))
                    continue
            tags["cloth"].add((x, y))
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
    length: int,
) -> set[tuple[int, int]]:
    """Pointed chibi ears. Original pixels."""
    painted: set[tuple[int, int]] = set()
    width = 3.0 if female else 4.2
    lift = max(5, length - 4)
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
            rad = width * (1.0 - t * 0.88)
            r0 = int(math.floor(cx - rad - 1))
            r1 = int(math.ceil(cx + rad + 1))
            c0 = int(math.floor(cy - rad - 1))
            c1 = int(math.ceil(cy + rad + 1))
            for y in range(max(0, c0), min(128, c1 + 1)):
                for x in range(max(0, r0), min(128, r1 + 1)):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    if abs(x - fx) < face_half * 0.62 and fy - 6 < y < chin:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 1.05) ** 2
                    if edge or t > 0.92:
                        rgb = INK
                    else:
                        shade = 0.72 + 0.28 * t
                        rgb = (
                            clamp8(skin[0] * shade),
                            clamp8(skin[1] * shade),
                            clamp8(skin[2] * shade),
                        )
                    op[x, y] = (*rgb, 255)
                    painted.add((x, y))
    return painted


def paint_tusks(
    op,
    fx: float,
    fy: float,
    face_half: float,
    chin: float,
    skin: tuple[int, int, int],
) -> set[tuple[int, int]]:
    painted: set[tuple[int, int]] = set()
    ivory = (232, 220, 188)
    for side in (-1, 1):
        ax = fx + side * (face_half * 0.35)
        ay = chin - 1
        for i in range(7):
            t = i / 6
            cx = ax + side * (1.2 + t * 2.5)
            cy = ay + 1 + t * 5
            rad = 1.6 - t * 0.7
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.7) ** 2
                    rgb = INK if edge else wash(skin, ivory)
                    op[x, y] = (*rgb, 255)
                    painted.add((x, y))
    return painted


def paint_horns_up(
    op,
    fx: float,
    fy: float,
    face_half: float,
) -> set[tuple[int, int]]:
    painted: set[tuple[int, int]] = set()
    bone = (220, 214, 198)
    for side in (-1, 1):
        ax = fx + side * (face_half * 0.55)
        ay = fy - face_half * 0.7
        for i in range(8):
            t = i / 7
            cx = ax + side * t * 2.0
            cy = ay - t * 8
            rad = 1.8 - t * 0.9
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.65) ** 2
                    op[x, y] = (*(INK if edge else bone), 255)
                    painted.add((x, y))
    return painted


def paint_horns_side(
    op,
    fx: float,
    fy: float,
    face_half: float,
) -> set[tuple[int, int]]:
    painted: set[tuple[int, int]] = set()
    bone = (210, 190, 150)
    for side in (-1, 1):
        ax = fx + side * face_half
        ay = fy - 2
        for i in range(10):
            t = i / 9
            cx = ax + side * (3 + t * 10)
            cy = ay - t * 3
            rad = 2.2 - t * 1.1
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.7) ** 2
                    op[x, y] = (*(INK if edge else bone), 255)
                    painted.add((x, y))
    return painted


def paint_race(
    family: str,
    anim: str,
    look: RaceLook,
    *,
    female: bool,
) -> tuple[Image.Image, Image.Image]:
    src = load_body(family, anim)
    src, tags, (fx, fy, face_half, chin) = classify(src, family)
    skin_t = look.skin_f if female else look.skin_m
    hair_t = look.hair_f if female else look.hair_m
    cloth_t = CLOTH_F if female else CLOTH_M
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    op = out.load()
    sp = src.load()

    hat_fill = hair_t
    rx_hat = face_half * 1.12
    for x, y in tags["hat"]:
        if family == "healer":
            continue
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
        if look.fur:
            # Soften skin into fur-ish midtones.
            rgb = wash(rgb, look.skin_shadow) if lum(sp[x, y][:3]) < 0.38 else rgb
        elif y > fy + face_half * 0.35 and lum(sp[x, y][:3]) < 0.42:
            rgb = wash(rgb, look.skin_shadow)
        op[x, y] = (*rgb, sp[x, y][3])

    for x, y in tags["eye"]:
        op[x, y] = (*look.eye, 255)

    for x, y in tags["cloth"]:
        r, g, b, a = sp[x, y]
        if is_gold_pixel((r, g, b)):
            op[x, y] = (*wash((r, g, b), cloth_t), a)
        else:
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
    extras: set[tuple[int, int]] = set()
    if look.ears:
        extras |= paint_ears(
            op,
            fx,
            fy,
            face_half,
            chin,
            female=female,
            skin=skin_t,
            occupied=occupied,
            length=look.ear_length if not female else max(6, look.ear_length - 2),
        )
    if look.tusks:
        extras |= paint_tusks(op, fx, fy, face_half, chin, skin_t)
    if look.horns_up:
        extras |= paint_horns_up(op, fx, fy, face_half)
    if look.horns_side:
        extras |= paint_horns_side(op, fx, fy, face_half)

    family_mask = Image.open(ROOT / family / f"body_tint_{anim}.png").convert("RGBA")
    tint = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    mp = tint.load()
    fp = family_mask.load()
    skip = tags["skin"] | tags["hair"] | tags["hat"] | tags["eye"] | tags["ink"] | extras
    for y in range(128):
        for x in range(128):
            if op[x, y][3] < 40:
                continue
            if (x, y) in skip:
                continue
            if fp[x, y][3] < 40:
                if (x, y) in tags["cloth"]:
                    shade = max(88, min(255, int(88 + lum(op[x, y][:3]) * 220)))
                    mp[x, y] = (shade, shade, shade, op[x, y][3])
                continue
            mp[x, y] = fp[x, y]
    return out, tint


def save_pair(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def punch_robe_faces(families: tuple[str, ...]) -> None:
    """Healer/mage chest extracts baked a human face onto the torso overlay."""
    for family in families:
        src_path = ROOT / family / "_src" / "body_idle.png"
        if not src_path.exists():
            src_path = ROOT / family / "body_idle.png"
        src = Image.open(src_path).convert("RGBA")
        box = bbox(src)
        face = sample_face(src, box, family)
        gear = ROOT / family / "gear"
        for path in sorted(gear.glob("chest*_idle.png")):
            if "_authored" in path.parts:
                continue
            im = Image.open(path).convert("RGBA")
            strip_head_from_layer(im, src, face, box)
            im.save(path)
            print("punched", path.relative_to(REPO))


def main() -> int:
    jobs: list[tuple[str, RaceLook, str, bool]] = []
    for look in RACES:
        jobs.append(("warrior", look, "m", False))
        jobs.append(("healer", look, "f", True))
        jobs.append(("mage", look, "m", False))
        jobs.append(("rogue", look, "m", False))
    punch_robe_faces(("healer", "mage"))
    for family, look, sex, female in jobs:
        for anim in ANIMS:
            body, tint = paint_race(family, anim, look, female=female)
            stem = ROOT / family / f"{look.key}_{sex}_body_{anim}.png"
            tstem = ROOT / family / f"{look.key}_{sex}_body_tint_{anim}.png"
            save_pair(stem, body)
            save_pair(tstem, tint)
            print("ok", stem.relative_to(REPO))
    print(f"done — {len(RACES)} races × 4 families")
    return 0


if __name__ == "__main__":
    sys.exit(main())
