"""Bake bare undertunic / shorts bodies for every race × sex × family.

Cataclysm playable races (12) — no Pandaren. Starts from each family's pose
body, keeps face/hair/skin, drops hats/hoods/plate/robes, paints a plain
sleeveless top + shorts, then applies race palette + features.

Writes:
  assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png
  assets/custom/char/<family>/<race>_<m|f>_body_tint_<anim>.png
  assets/custom/char/<family>/body_<anim>.png          (human male default)
  assets/custom/char/<family>/body_tint_<anim>.png

Original pixels derived from owned Idle Party bodies — not WoW dumps.
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
# Plain cloth — not plate, not ornate robe.
TOP_M = (168, 152, 120)
TOP_F = (220, 210, 198)
SHORTS_M = (72, 60, 48)
SHORTS_F = (96, 72, 88)

FAMILIES = ("warrior", "healer", "mage", "rogue")


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


RACES: tuple[RaceLook, ...] = (
    RaceLook(
        "human",
        (210, 168, 132),
        (220, 180, 148),
        (130, 90, 62),
        (72, 48, 32),
        (196, 168, 96),
        (40, 28, 24),
    ),
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
    # Prefer gold-master pose when present so we do not strip an already-stripped body.
    src_path = ROOT / family / "_src" / f"body_{anim}.png"
    if src_path.exists():
        path = src_path
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"{path} is {im.size}, want 128x128")
    return im


def classify(
    src: Image.Image,
    family: str,
) -> tuple[Image.Image, dict[str, set[tuple[int, int]]], tuple[float, float, float, float]]:
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
            if y <= chin + 8 and (is_hat_or_hood(family, rgb) or is_gold_pixel(rgb)):
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


def body_column_xs(opaque: set[tuple[int, int]], y0: int, y1: int) -> tuple[int, int]:
    xs = [x for x, y in opaque if y0 <= y <= y1]
    if not xs:
        return 40, 88
    return min(xs), max(xs)


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
    soft_edge: bool = False,
) -> set[tuple[int, int]]:
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
            for y in range(max(0, int(cy - rad - 1)), min(128, int(cy + rad + 2))):
                for x in range(max(0, int(cx - rad - 1)), min(128, int(cx + rad + 2))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    if abs(x - fx) < face_half * 0.62 and fy - 6 < y < chin:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 1.05) ** 2
                    if edge or t > 0.92:
                        if soft_edge:
                            shade = 0.55
                            rgb = (
                                clamp8(skin[0] * shade),
                                clamp8(skin[1] * shade),
                                clamp8(skin[2] * shade),
                            )
                        else:
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


def paint_tusks(op, fx, fy, face_half, chin, skin) -> set[tuple[int, int]]:
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
                    op[x, y] = (*(INK if edge else wash(skin, ivory)), 255)
                    painted.add((x, y))
    return painted


def paint_horns_up(op, fx, fy, face_half) -> set[tuple[int, int]]:
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


def paint_horns_side(op, fx, fy, face_half) -> set[tuple[int, int]]:
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


def paint_undertunic_body(
    family: str,
    anim: str,
    look: RaceLook,
    *,
    female: bool,
) -> tuple[Image.Image, Image.Image]:
    """Bare top + shorts on the family pose. No hats, plate, or robes."""
    src = load_body(family, anim)
    box = bbox(src)
    face = sample_face(src, box, family)
    src, tags, (fx, fy, face_half, chin) = classify(src, family)
    skin_t = look.skin_f if female else look.skin_m
    hair_t = look.hair_f if female else look.hair_m
    top_t = TOP_F if female else TOP_M
    shorts_t = SHORTS_F if female else SHORTS_M
    sp = src.load()
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    op = out.load()

    # Head only — never copy hat / hood / circlet / class helm.
    face_skin = {
        (x, y)
        for x, y in tags["skin"]
        if y <= chin + 4 and dist2(x, y, fx, fy) <= (face_half * 1.55) ** 2
    }
    for x, y in tags["ink"]:
        if (x, y) in face_skin or (
            y <= chin + 4 and dist2(x, y, fx, fy) <= (face_half * 1.35) ** 2
        ):
            op[x, y] = (*INK, sp[x, y][3])
    for x, y in face_skin:
        rgb = wash(sp[x, y][:3], skin_t)
        if look.fur and lum(sp[x, y][:3]) < 0.38:
            rgb = wash(rgb, look.skin_shadow)
        elif y > fy + face_half * 0.35 and lum(sp[x, y][:3]) < 0.42:
            rgb = wash(rgb, look.skin_shadow)
        op[x, y] = (*rgb, sp[x, y][3])
    for x, y in tags["eye"]:
        op[x, y] = (*look.eye, 255)

    # Hair / hat: warrior+rogue keep tagged hair (no hat). Mage+healer: full
    # head wipe — never restore hood/hat ink from the gold master.
    if family in ("mage", "healer"):
        # 1) Erase every head-adjacent pixel from the source pose.
        for y in range(0, min(128, int(chin) + 6)):
            for x in range(128):
                op[x, y] = (0, 0, 0, 0)
        # 2) Face oval from true skin only (hood/cloth never counts).
        for x, y in tags["opaque"]:
            if y > chin + 1:
                continue
            if dist2(x, y, fx, fy) > (face_half * 1.25) ** 2:
                continue
            r, g, b, a = sp[x, y]
            if a < 40 or not is_skin((r, g, b), face):
                continue
            rgb = wash((r, g, b), skin_t)
            if look.fur and lum((r, g, b)) < 0.38:
                rgb = wash(rgb, look.skin_shadow)
            op[x, y] = (*rgb, 255)
        # Fill any holes left by the hood wipe so the face stays solid.
        for y in range(max(0, int(fy - face_half)), min(128, int(chin) + 1)):
            for x in range(
                max(0, int(fx - face_half)),
                min(128, int(fx + face_half) + 1),
            ):
                if dist2(x, y, fx, fy) > (face_half * 0.95) ** 2:
                    continue
                if op[x, y][3] >= 40:
                    continue
                op[x, y] = (*wash((180, 140, 110), skin_t), 255)
        # 3) Eyes
        for x, y in tags["eye"]:
            if dist2(x, y, fx, fy) <= (face_half * 1.3) ** 2:
                op[x, y] = (*look.eye, 255)
        # 4) Cheek/chin ink only — never a crown ring (that reads as a hood).
        for x, y in tags["opaque"]:
            if op[x, y][3] < 40:
                continue
            if y < fy:  # forehead/crown stays hair or bare skin
                continue
            if y > fy + face_half * 0.7:
                continue
            if dist2(x, y, fx, fy) > (face_half * 1.05) ** 2:
                continue
            if dist2(x, y, fx, fy) < (face_half * 0.92) ** 2:
                continue
            op[x, y] = (*INK, 255)
        # 5) Short fringe in race hair color (no muddy brown→hood wash).
        fringe_cy = fy - face_half * 0.55
        for y in range(max(0, int(fy - face_half * 1.1)), int(fy - 1)):
            for x in range(
                max(0, int(fx - face_half * 0.75)),
                min(128, int(fx + face_half * 0.75) + 1),
            ):
                if dist2(x, y, fx, fringe_cy) > (face_half * 0.7) ** 2:
                    continue
                if op[x, y][3] > 40 and is_skin(op[x, y][:3], face):
                    continue
                # Soft top edge so it reads as bangs, not a cowl.
                edge = dist2(x, y, fx, fringe_cy) > (face_half * 0.55) ** 2
                if edge:
                    rgb = (
                        clamp8(hair_t[0] * 0.72),
                        clamp8(hair_t[1] * 0.72),
                        clamp8(hair_t[2] * 0.72),
                    )
                else:
                    rgb = hair_t
                op[x, y] = (*rgb, 255)
    else:
        for x, y in tags["hair"]:
            if (x, y) in tags["hat"]:
                continue
            if y > chin + 4:
                continue
            op[x, y] = (*wash(sp[x, y][:3], hair_t), sp[x, y][3])
        for x, y in tags["hat"]:
            op[x, y] = (0, 0, 0, 0)

    # Clear everything below the chin — rebuild a slim undertunic body.
    for y in range(int(chin) + 1, 128):
        for x in range(128):
            op[x, y] = (0, 0, 0, 0)

    # --- Slim body (ignore plate/robe silhouette) ---
    # Start below the facit head band (chin+8) so tint masks stay legal.
    shoulder_y = int(chin + 10)
    hip_y = shoulder_y + (24 if female else 26)
    crotch_y = hip_y + (12 if female else 14)
    foot_y = min(120, crotch_y + 28)
    torso_w = 9 if female else 11
    arm_len = 18 if female else 20
    leg_w = 4

    cloth_pixels: set[tuple[int, int]] = set()

    def put(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
        if 0 <= x < 128 and 0 <= y < 128:
            op[x, y] = (*rgb, a)

    def shade(target: tuple[int, int, int], seed: float) -> tuple[int, int, int]:
        mix = 0.55 + 0.45 * max(0.2, min(1.0, seed))
        return (
            clamp8(target[0] * mix),
            clamp8(target[1] * mix),
            clamp8(target[2] * mix),
        )

    def mark_cloth(x: int, y: int) -> None:
        # Facit forbids tint where the gold-master still reads as skin.
        if y <= chin + 8:
            return
        if (x, y) in tags["skin"] or (x, y) in tags["eye"] or (x, y) in tags["hair"]:
            return
        r, g, b, a = sp[x, y]
        if a >= 40 and is_skin((r, g, b), face):
            return
        cloth_pixels.add((x, y))

    # Short neck so the head doesn't float after the hood wipe.
    for y in range(int(chin), min(shoulder_y, int(chin) + 6)):
        half = 3 if y < chin + 3 else 4
        for x in range(int(fx - half), int(fx + half) + 1):
            put(x, y, wash((180, 140, 110), skin_t))

    # Torso undertunic
    for y in range(shoulder_y, hip_y + 1):
        t = (y - shoulder_y) / max(1, hip_y - shoulder_y)
        half = torso_w - int(t * 1.5)
        for x in range(int(fx - half), int(fx + half) + 1):
            put(x, y, shade(top_t, 0.75 - t * 0.15))
            mark_cloth(x, y)

    # Shorts
    for y in range(hip_y, crotch_y + 1):
        t = (y - hip_y) / max(1, crotch_y - hip_y)
        half = max(6, torso_w - 1 - int(t * 2))
        for x in range(int(fx - half), int(fx + half) + 1):
            put(x, y, shade(shorts_t, 0.65 - t * 0.1))
            mark_cloth(x, y)

    # Arms (skin)
    for side in (-1, 1):
        ax0 = int(fx + side * (torso_w - 1))
        for i in range(arm_len):
            x = ax0 + side * (i // 2)
            y = shoulder_y + 3 + (i * 2) // 3
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    if dx * dx + dy * dy <= 5:
                        put(x + dx, y + dy, wash((180, 140, 110), skin_t))

    # Legs (skin)
    for side in (-1, 1):
        lx = int(fx + side * 4)
        for y in range(crotch_y, foot_y):
            for dx in range(-leg_w, leg_w + 1):
                put(lx + dx, y, wash((180, 140, 110), skin_t))
            if y >= foot_y - 3:
                for dx in range(-leg_w - 1, leg_w + 2):
                    put(lx + dx, y, wash((160, 120, 90), skin_t))

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
            soft_edge=family in ("mage", "healer"),
        )
    if look.tusks:
        extras |= paint_tusks(op, fx, fy, face_half, chin, skin_t)
    if look.horns_up:
        extras |= paint_horns_up(op, fx, fy, face_half)
    if look.horns_side:
        extras |= paint_horns_side(op, fx, fy, face_half)

    # Cloth-only tint mask for spec wash — never head/hair/skin.
    tint = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    mp = tint.load()
    for x, y in cloth_pixels:
        if y <= chin + 4:
            continue
        if op[x, y][3] < 40:
            continue
        shade_v = max(88, min(255, int(88 + lum(op[x, y][:3]) * 220)))
        mp[x, y] = (shade_v, shade_v, shade_v, op[x, y][3])
    return out, tint


def save_pair(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    last: Exception | None = None
    for attempt in range(8):
        try:
            tmp = path.with_name(path.name + ".writing.png")
            im.save(tmp)
            tmp.replace(path)
            return
        except OSError as exc:
            last = exc
            import time

            time.sleep(0.15 * (attempt + 1))
    raise last  # type: ignore[misc]


def punch_robe_faces(families: tuple[str, ...]) -> None:
    for family in families:
        src_path = ROOT / family / "_src" / "body_idle.png"
        if not src_path.exists():
            src_path = ROOT / family / "body_idle.png"
        src = Image.open(src_path).convert("RGBA")
        box = bbox(src)
        face = sample_face(src, box, family)
        gear = ROOT / family / "gear"
        if not gear.is_dir():
            continue
        for path in sorted(gear.glob("chest*_idle.png")):
            if "_authored" in path.parts:
                continue
            im = Image.open(path).convert("RGBA")
            strip_head_from_layer(im, src, face, box)
            im.save(path)


def main() -> int:
    punch_robe_faces(("healer", "mage"))
    human = next(r for r in RACES if r.key == "human")
    count = 0
    for family in FAMILIES:
        for look in RACES:
            for sex, female in (("m", False), ("f", True)):
                for anim in ANIMS:
                    body, tint = paint_undertunic_body(
                        family, anim, look, female=female
                    )
                    stem = ROOT / family / f"{look.key}_{sex}_body_{anim}.png"
                    tstem = ROOT / family / f"{look.key}_{sex}_body_tint_{anim}.png"
                    save_pair(stem, body)
                    save_pair(tstem, tint)
                    count += 1
                    # Default family body = human male undertunic (unequipped doll).
                    if look.key == "human" and sex == "m":
                        save_pair(ROOT / family / f"body_{anim}.png", body)
                        save_pair(ROOT / family / f"body_tint_{anim}.png", tint)
        print("ok", family)
    print(f"done — {count} race bodies + family human-male defaults")
    # Preview strip for owner.
    preview = Image.new("RGBA", (128 * 6 + 40, 128 * 4 + 40), (24, 20, 32, 255))
    samples = [
        ("warrior", "human", "m"),
        ("warrior", "orc", "m"),
        ("healer", "human", "f"),
        ("healer", "nightelf", "f"),
        ("mage", "bloodelf", "m"),
        ("rogue", "goblin", "m"),
        ("warrior", "tauren", "m"),
        ("healer", "draenei", "f"),
        ("mage", "worgen", "m"),
        ("rogue", "troll", "f"),
        ("warrior", "forsaken", "m"),
        ("healer", "dwarf", "f"),
    ]
    for i, (fam, race, sex) in enumerate(samples):
        im = Image.open(ROOT / fam / f"{race}_{sex}_body_idle.png").convert("RGBA")
        x = 8 + (i % 6) * (128 + 4)
        y = 8 + (i // 6) * (128 + 4)
        preview.paste(im, (x, y), im)
    out = REPO / "tool" / "out" / "undertunic_race_preview.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    preview.save(out)
    print("preview", out.relative_to(REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main())
