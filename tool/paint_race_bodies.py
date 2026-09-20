"""Bake bare undertunic / shorts bodies for every race × sex × family.

Pipeline (deterministic):
  source body → classify → clean masks → paint canonical undertunic
  → race palette → race features → tint → validate → save

Source is used only for pose anchors, face/hair/eye placement, and shading.
Family plate/robe/hat pixels never become the clothing silhouette.

Writes:
  assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png
  assets/custom/char/<family>/<race>_<m|f>_body_tint_<anim>.png
  assets/custom/char/<family>/body_<anim>.png          (human male default)
  assets/custom/char/<family>/body_tint_<anim>.png

Original pixels derived from owned Idle Party bodies — not WoW dumps.
"""

from __future__ import annotations

import sys
import time
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

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

INK = (28, 22, 48)
TOP_M = (176, 158, 128)
TOP_F = (228, 218, 204)
SHORTS_M = (78, 64, 52)
SHORTS_F = (104, 78, 92)

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


@dataclass(frozen=True)
class BuildConfig:
    size: tuple[int, int] = (128, 128)
    families: tuple[str, ...] = FAMILIES
    races: tuple[RaceLook, ...] = RACES
    sexes: tuple[tuple[str, bool], ...] = (("m", False), ("f", True))
    animations: tuple[str, ...] = ANIMS
    write_defaults: bool = True
    write_preview: bool = True
    validate: bool = True
    # Never mutate owned gear overlays from this bake.
    punch_chest_heads: bool = False


CONFIG = BuildConfig()


@dataclass(frozen=True)
class PoseAnchors:
    fx: float
    fy: float
    face_half: float
    chin: float
    face_rgb: tuple[int, int, int]
    shoulder_y: int
    hip_y: int
    crotch_y: int
    foot_y: int
    torso_half: float
    hand_l: tuple[float, float]
    hand_r: tuple[float, float]
    foot_l: tuple[float, float]
    foot_r: tuple[float, float]


def clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))


def shade_from(
    source: tuple[int, int, int],
    target: tuple[int, int, int],
    *,
    strength: float = 1.0,
) -> tuple[int, int, int]:
    """Transfer source lightness onto the race/cloth palette."""
    src_l = lum(source)
    target_l = max(lum(target), 0.08)
    ratio = src_l / target_l
    ratio = max(0.45, min(1.30, ratio))
    ratio = 1.0 + (ratio - 1.0) * strength
    return (
        clamp8(target[0] * ratio),
        clamp8(target[1] * ratio),
        clamp8(target[2] * ratio),
    )


def tint_pixel(rgb: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    value = max(48, clamp8(255 * lum(rgb)))
    return (value, value, value, alpha)


def in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
    if rx <= 0 or ry <= 0:
        return False
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def dist2(ax: float, ay: float, bx: float, by: float) -> float:
    return (ax - bx) * (ax - bx) + (ay - by) * (ay - by)


def head_clip(x: int, y: int, fx: float, fy: float, radius: float) -> bool:
    return dist2(x, y, fx, fy) <= radius * radius


def load_body(family: str, anim: str) -> Image.Image:
    src_path = ROOT / family / "_src" / f"body_{anim}.png"
    path = src_path if src_path.exists() else ROOT / family / f"body_{anim}.png"
    im = Image.open(path).convert("RGBA")
    if im.size != CONFIG.size:
        raise SystemExit(f"{path} is {im.size}, want {CONFIG.size}")
    return im


def is_healer_circlet_trim(rgb: tuple[int, int, int]) -> bool:
    """Healer circlet / hood-gold that is_gold_pixel often misses (darker brass)."""
    if is_gold_pixel(rgb):
        return True
    r, g, b = rgb
    # Saturated yellow/brass trim — not soft blonde bob.
    if r >= 155 and g >= 90 and b < 145 and (g - b) >= 35 and (r - b) >= 40:
        return True
    if r >= 200 and g >= 150 and b < 155 and (r - b) > 55:
        return True
    return False


def classify(
    src: Image.Image,
    family: str,
) -> tuple[
    dict[str, set[tuple[int, int]]],
    PoseAnchors,
]:
    """Tag source pixels. Hats/hoods never enter skin/hair/eye masks."""
    box = bbox(src)
    face = sample_face(src, box, family)
    fx, fy, face_half = face_region(src, face, box)
    chin = float(_chin_y(src, face, fx, fy, face_half))
    px = src.load()
    tags: dict[str, set[tuple[int, int]]] = {
        "skin": set(),
        "hair": set(),
        "hat": set(),
        "eye": set(),
        "ink": set(),
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

            if family == "healer" and y <= chin + 8 and is_healer_circlet_trim(rgb):
                tags["hat"].add((x, y))
                continue
            if y <= chin + 8 and (is_hat_or_hood(family, rgb) or is_gold_pixel(rgb)):
                tags["hat"].add((x, y))
                continue
            # Mage tall hat / healer cowl above brows — never hair.
            if family in ("mage", "healer") and y < fy - 2 and not is_skin(rgb, face):
                # Circlet arc / hat cone above the forehead = hat, not fringe.
                if family == "healer" and (
                    is_healer_circlet_trim(rgb) or y < fy - 10 or abs(x - fx) > face_half * 1.15
                ):
                    tags["hat"].add((x, y))
                    continue
                if is_hair_color(family, rgb) and y >= fy - 14 and abs(x - fx) <= face_half * 1.2:
                    tags["hair"].add((x, y))
                else:
                    tags["hat"].add((x, y))
                continue
            if l < 0.11 and in_head:
                tags["ink"].add((x, y))
                continue
            if is_skin(rgb, face) and in_head:
                tags["skin"].add((x, y))
                continue
            # Hair: head band only — never circlet gold / hood ink.
            if y <= chin + 4 and in_head:
                if family == "healer" and is_healer_circlet_trim(rgb):
                    tags["hat"].add((x, y))
                    continue
                if is_hair_color(family, rgb):
                    tags["hair"].add((x, y))
                    continue
                if (
                    not is_gold_pixel(rgb)
                    and not (family == "healer" and is_healer_circlet_trim(rgb))
                    and l < 0.58
                    and abs(x - fx) <= face_half * 1.55
                    and y < fy + 3
                ):
                    tags["hair"].add((x, y))
                    continue
            # Hands / lower limbs for pose anchors only (not painted as cloth).
            if is_skin(rgb, face) and y > chin + 8:
                tags["skin"].add((x, y))

    # Eyes win over skin.
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

    anchors = _pose_anchors(src, tags, face, fx, fy, face_half, chin, box)
    return tags, anchors


def _centroid(pts: list[tuple[int, int]]) -> tuple[float, float] | None:
    if not pts:
        return None
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def _pose_anchors(
    src: Image.Image,
    tags: dict[str, set[tuple[int, int]]],
    face: tuple[int, int, int],
    fx: float,
    fy: float,
    face_half: float,
    chin: float,
    box: tuple[int, int, int, int],
) -> PoseAnchors:
    x0, y0, x1, y1 = box
    shoulder_y = int(chin + 8)
    hip_y = shoulder_y + 22
    crotch_y = hip_y + 12
    foot_y = min(118, y1 - 2)
    torso_half = max(10.0, face_half * 0.95)

    # Hands: skin blobs below mid, left/right of center.
    left_hand: list[tuple[int, int]] = []
    right_hand: list[tuple[int, int]] = []
    for x, y in tags["skin"]:
        if y < shoulder_y + 8 or y > crotch_y + 8:
            continue
        if x < fx - 6:
            left_hand.append((x, y))
        elif x > fx + 6:
            right_hand.append((x, y))
    hl = _centroid(left_hand) or (fx - torso_half - 10, shoulder_y + 18)
    hr = _centroid(right_hand) or (fx + torso_half + 10, shoulder_y + 18)

    # Feet: lowest opaque pixels left/right (not hat).
    left_foot: list[tuple[int, int]] = []
    right_foot: list[tuple[int, int]] = []
    for x, y in tags["opaque"]:
        if y < foot_y - 10 or (x, y) in tags["hat"]:
            continue
        if x < fx:
            left_foot.append((x, y))
        else:
            right_foot.append((x, y))
    fl = _centroid(left_foot) or (fx - 5, float(foot_y))
    fr = _centroid(right_foot) or (fx + 5, float(foot_y))
    foot_y = int(max(fl[1], fr[1], crotch_y + 20))

    # Shoulder width from opaque band under chin (ignore wide robes a bit).
    band = [x for x, y in tags["opaque"] if shoulder_y <= y <= shoulder_y + 6]
    if band:
        raw_half = (max(band) - min(band)) / 2.0
        # Clamp robe flare — undertunic is narrower than plate/robe.
        torso_half = max(10.0, min(14.0, raw_half * 0.55))

    return PoseAnchors(
        fx=fx,
        fy=fy,
        face_half=face_half,
        chin=chin,
        face_rgb=face,
        shoulder_y=shoulder_y,
        hip_y=hip_y,
        crotch_y=crotch_y,
        foot_y=foot_y,
        torso_half=torso_half,
        hand_l=hl,
        hand_r=hr,
        foot_l=(fl[0], float(foot_y)),
        foot_r=(fr[0], float(foot_y)),
    )


def _put(
    op,
    cloth: set[tuple[int, int]],
    x: int,
    y: int,
    rgb: tuple[int, int, int],
    *,
    is_cloth: bool = False,
) -> None:
    if 0 <= x < 128 and 0 <= y < 128:
        op[x, y] = (*rgb, 255)
        if is_cloth:
            cloth.add((x, y))
        else:
            cloth.discard((x, y))


def _capsule(
    op,
    cloth: set[tuple[int, int]],
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    radius: float,
    color: tuple[int, int, int],
    *,
    is_cloth: bool = False,
    outline: bool = False,
) -> None:
    steps = max(10, int(dist2(x0, y0, x1, y1) ** 0.5) + 6)
    for i in range(steps + 1):
        t = i / steps
        cx = x0 + (x1 - x0) * t
        cy = y0 + (y1 - y0) * t
        rad = max(2.2, radius * (1.0 - 0.08 * t))
        for y in range(max(0, int(cy - rad - 1)), min(128, int(cy + rad + 2))):
            for x in range(max(0, int(cx - rad - 1)), min(128, int(cx + rad + 2))):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 > rad * rad:
                    continue
                edge = outline and d2 > (rad - 0.85) ** 2
                if edge:
                    rgb = INK
                else:
                    # Soft round shading — never ink-fill thin limbs.
                    shade = 0.82 + 0.18 * (1.0 - (d2 / max(1.0, rad * rad)))
                    rgb = (
                        clamp8(color[0] * shade),
                        clamp8(color[1] * shade),
                        clamp8(color[2] * shade),
                    )
                _put(op, cloth, x, y, rgb, is_cloth=is_cloth and not edge)


def paint_canonical_body(
    tags: dict[str, set[tuple[int, int]]],
    anchors: PoseAnchors,
    look: RaceLook,
    *,
    female: bool,
    family: str,
    src: Image.Image,
) -> tuple[Image.Image, Image.Image]:
    """Paint sleeveless top + shorts from pose masks — never source clothing."""
    skin_t = look.skin_f if female else look.skin_m
    hair_t = look.hair_f if female else look.hair_m
    top_t = TOP_F if female else TOP_M
    shorts_t = SHORTS_F if female else SHORTS_M
    # Soft family tint on cloth only (identity), still plain undertunic cut.
    if family == "mage":
        top_t = (clamp8(top_t[0] * 0.78 + 40), clamp8(top_t[1] * 0.78 + 36), clamp8(top_t[2] * 0.95 + 50))
    elif family == "healer":
        top_t = (clamp8(top_t[0] * 1.02 + 8), clamp8(top_t[1] * 1.02 + 8), clamp8(top_t[2] * 1.0 + 6))
    elif family == "rogue":
        top_t = (clamp8(top_t[0] * 0.7), clamp8(top_t[1] * 0.78), clamp8(top_t[2] * 0.65))
        shorts_t = (clamp8(shorts_t[0] * 0.85), clamp8(shorts_t[1] * 0.9), clamp8(shorts_t[2] * 0.8))

    out = Image.new("RGBA", CONFIG.size, (0, 0, 0, 0))
    op = out.load()
    sp = src.load()
    cloth: set[tuple[int, int]] = set()
    a = anchors
    # Slightly roomier undertunic so cloth tint stays above facit floors.
    th = a.torso_half * (0.98 if female else 1.08)
    th = max(11.0, min(16.0, th))

    # --- Legs (skin) ---
    leg_r = 4.8 if female else 5.6
    _capsule(op, cloth, a.fx - 4, a.crotch_y, a.foot_l[0], a.foot_l[1], leg_r, skin_t)
    _capsule(op, cloth, a.fx + 4, a.crotch_y, a.foot_r[0], a.foot_r[1], leg_r, skin_t)

    # --- Shorts (canonical cloth — ignore source armor chroma) ---
    for y in range(a.hip_y, a.crotch_y + 3):
        t = (y - a.hip_y) / max(1, a.crotch_y + 2 - a.hip_y)
        half = th + 2 - t * 2.0
        for x in range(int(a.fx - half), int(a.fx + half) + 1):
            edge = abs(x - a.fx) > half - 1.0 or y in (a.hip_y, a.crotch_y + 2)
            if edge:
                rgb = INK
            else:
                hx = 1.0 - abs(x - a.fx) / max(1.0, half)
                shade = 0.72 + 0.22 * hx - 0.08 * t
                rgb = (
                    clamp8(shorts_t[0] * shade),
                    clamp8(shorts_t[1] * shade),
                    clamp8(shorts_t[2] * shade),
                )
            _put(op, cloth, x, y, rgb, is_cloth=not edge)

    # --- Torso undertunic (plain — no source plate/robe pattern) ---
    for y in range(a.shoulder_y, a.hip_y + 1):
        t = (y - a.shoulder_y) / max(1, a.hip_y - a.shoulder_y)
        half = th + 1 - t * 0.8
        for x in range(int(a.fx - half), int(a.fx + half) + 1):
            edge = abs(x - a.fx) > half - 1.0 or y == a.shoulder_y
            if edge:
                rgb = INK
            else:
                hx = 1.0 - abs(x - a.fx) / max(1.0, half)
                shade = 0.78 + 0.18 * hx - 0.1 * t
                rgb = (
                    clamp8(top_t[0] * shade),
                    clamp8(top_t[1] * shade),
                    clamp8(top_t[2] * shade),
                )
            _put(op, cloth, x, y, rgb, is_cloth=not edge)

    # --- Arms (skin) to hand anchors ---
    arm_r = 4.0 if female else 4.8
    _capsule(
        op,
        cloth,
        a.fx - th + 1,
        a.shoulder_y + 3,
        a.hand_l[0],
        a.hand_l[1],
        arm_r,
        skin_t,
    )
    _capsule(
        op,
        cloth,
        a.fx + th - 1,
        a.shoulder_y + 3,
        a.hand_r[0],
        a.hand_r[1],
        arm_r,
        skin_t,
    )

    # Hand pads
    for hx, hy in (a.hand_l, a.hand_r):
        for y in range(max(0, int(hy - 3)), min(128, int(hy + 4))):
            for x in range(max(0, int(hx - 3)), min(128, int(hx + 4))):
                if (x - hx) ** 2 + (y - hy) ** 2 <= 7:
                    _put(op, cloth, x, y, shade_from((180, 140, 110), skin_t, strength=0.6))

    # --- Neck ---
    for y in range(int(a.chin), a.shoulder_y + 1):
        half = 3.2 if y < a.chin + 3 else 4.0
        for x in range(int(a.fx - half), int(a.fx + half) + 1):
            edge = abs(x - a.fx) > half - 0.9
            rgb = INK if edge else shade_from((180, 140, 110), skin_t, strength=0.7)
            _put(op, cloth, x, y, rgb)

    # --- Head oval fill (solid face before hair/eyes) ---
    for y in range(max(0, int(a.fy - a.face_half * 1.15)), int(a.chin) + 1):
        for x in range(
            max(0, int(a.fx - a.face_half * 1.15)),
            min(128, int(a.fx + a.face_half * 1.15) + 1),
        ):
            if not in_ellipse(x, y, a.fx, a.fy, a.face_half * 1.05, a.face_half * 1.15):
                continue
            if (x, y) in tags["hat"]:
                continue
            seed = sp[x, y][:3] if (x, y) in tags["skin"] and sp[x, y][3] > 40 else (180, 140, 110)
            washed = shade_from(seed, skin_t, strength=0.7)
            if look.fur and lum(seed) < 0.38:
                washed = shade_from(washed, look.skin_shadow, strength=0.55)
            op[x, y] = (*washed, 255)

    # Hair over crown (classified only — never circlet/hood gold).
    for x, y in tags["hair"]:
        if (x, y) in tags["hat"]:
            continue
        r, g, b, aa = sp[x, y]
        if family == "healer" and is_healer_circlet_trim((r, g, b)):
            continue
        if is_gold_pixel((r, g, b)) or is_hat_or_hood(family, (r, g, b)):
            continue
        op[x, y] = (*shade_from((r, g, b), hair_t, strength=0.8), max(aa, 220))

    # Healer/mage: scrub any leftover circlet streaks outside the face oval.
    if family in ("healer", "mage"):
        for y in range(0, int(a.chin) + 2):
            for x in range(128):
                r, g, b, aa = op[x, y]
                if aa < 16:
                    continue
                rgb = (r, g, b)
                if is_skin(rgb, a.face_rgb) or is_skin(rgb, skin_t):
                    continue
                # Kill gold/brass streaks and orphan pixels above the brows.
                if family == "healer" and is_healer_circlet_trim(rgb):
                    op[x, y] = (0, 0, 0, 0)
                    continue
                if is_gold_pixel(rgb):
                    op[x, y] = (0, 0, 0, 0)
                    continue
                if y < a.fy - 8 and not head_clip(x, y, a.fx, a.fy, a.face_half * 1.05):
                    # Floating hood/circlet crumbs outside the head.
                    if abs(r - hair_t[0]) + abs(g - hair_t[1]) + abs(b - hair_t[2]) > 40:
                        op[x, y] = (0, 0, 0, 0)

    # Clean race eyes (small ovals) — wins over skin/hair noise.
    eye_y = a.fy + 0.5
    eye_dx = a.face_half * 0.38
    for side in (-1, 1):
        ex = a.fx + side * eye_dx
        for y in range(int(eye_y - 1), int(eye_y + 2)):
            for x in range(int(ex - 2), int(ex + 3)):
                if (x - ex) ** 2 / 4.5 + (y - eye_y) ** 2 / 2.2 <= 1.0:
                    op[x, y] = (*look.eye, 255)
        # Tiny highlight
        hx, hy = int(ex - side * 0.5), int(eye_y - 0.5)
        if 0 <= hx < 128 and 0 <= hy < 128:
            op[hx, hy] = (240, 240, 245, 255)

    # Classified eye tags as backup (same color).
    for x, y in tags["eye"]:
        if head_clip(x, y, a.fx, a.fy, a.face_half * 1.2):
            op[x, y] = (*look.eye, 255)

    # Soft cheek/chin ink only.
    for y in range(int(a.fy), int(a.chin) + 1):
        for x in range(int(a.fx - a.face_half), int(a.fx + a.face_half) + 1):
            if not in_ellipse(x, y, a.fx, a.fy, a.face_half * 1.05, a.face_half * 1.15):
                continue
            if in_ellipse(x, y, a.fx, a.fy, a.face_half * 0.92, a.face_half * 1.0):
                continue
            if op[x, y][3] > 40:
                op[x, y] = (*INK, 255)

    # Mage/healer fringe when hood wiped all hair.
    if family in ("mage", "healer"):
        has_hair = any(
            y < a.fy and (x, y) not in tags["hat"]
            for x, y in tags["hair"]
        )
        if not has_hair:
            fringe_cy = a.fy - a.face_half * 0.5
            for y in range(max(0, int(a.fy - a.face_half * 1.05)), int(a.fy - 1)):
                for x in range(
                    max(0, int(a.fx - a.face_half * 0.8)),
                    min(128, int(a.fx + a.face_half * 0.8) + 1),
                ):
                    if dist2(x, y, a.fx, fringe_cy) > (a.face_half * 0.72) ** 2:
                        continue
                    if op[x, y][3] > 40 and is_skin(op[x, y][:3], a.face_rgb):
                        continue
                    edge = dist2(x, y, a.fx, fringe_cy) > (a.face_half * 0.58) ** 2
                    rgb = (
                        (
                            clamp8(hair_t[0] * 0.72),
                            clamp8(hair_t[1] * 0.72),
                            clamp8(hair_t[2] * 0.72),
                        )
                        if edge
                        else hair_t
                    )
                    op[x, y] = (*rgb, 255)

    # Race features — clipped to head neighborhood.
    occupied = {(x, y) for y in range(128) for x in range(128) if op[x, y][3] > 16}
    if look.ears:
        _paint_ears(
            op,
            a,
            female=female,
            skin=skin_t,
            occupied=occupied,
            length=look.ear_length if not female else max(6, look.ear_length - 2),
            soft_edge=family in ("mage", "healer"),
        )
    if look.tusks:
        _paint_tusks(op, a, skin_t)
    if look.horns_up:
        _paint_horns_up(op, a)
    if look.horns_side:
        _paint_horns_side(op, a)

    # Tint from final cloth luminance only — never skin/hair/eyes.
    # Facit also forbids tint where the *gold-master* still reads as skin.
    tint = Image.new("RGBA", CONFIG.size, (0, 0, 0, 0))
    tp = tint.load()
    for x, y in cloth:
        if y <= a.chin + 8:
            continue
        if (x, y) in tags["skin"] or (x, y) in tags["hair"] or (x, y) in tags["eye"]:
            continue
        sr, sg, sb, sa = sp[x, y]
        if sa >= 40 and is_skin((sr, sg, sb), a.face_rgb):
            continue
        r, g, b, aa = op[x, y]
        if aa < 40:
            continue
        rgb = (r, g, b)
        if is_skin(rgb, a.face_rgb) or is_skin(rgb, skin_t):
            continue
        if abs(r - skin_t[0]) + abs(g - skin_t[1]) + abs(b - skin_t[2]) < 90:
            continue
        tp[x, y] = tint_pixel(rgb, aa)

    return out, tint


def _paint_ears(
    op,
    a: PoseAnchors,
    *,
    female: bool,
    skin: tuple[int, int, int],
    occupied: set[tuple[int, int]],
    length: int,
    soft_edge: bool,
) -> None:
    width = 3.0 if female else 4.2
    lift = max(5, length - 4)
    left_edge = int(a.fx - a.face_half)
    right_edge = int(a.fx + a.face_half)
    for x, y in occupied:
        if abs(y - a.fy) > 4:
            continue
        if x < a.fx:
            left_edge = min(left_edge, x)
        else:
            right_edge = max(right_edge, x)
    for side in (-1, 1):
        ax = (left_edge - 1) if side < 0 else (right_edge + 1)
        ay = a.fy - 2.0
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
                    if not head_clip(x, y, a.fx, a.fy, a.face_half * 2.8):
                        continue
                    if abs(x - a.fx) < a.face_half * 0.62 and a.fy - 6 < y < a.chin:
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 1.05) ** 2
                    if edge or t > 0.92:
                        if soft_edge:
                            rgb = (
                                clamp8(skin[0] * 0.55),
                                clamp8(skin[1] * 0.55),
                                clamp8(skin[2] * 0.55),
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


def _paint_tusks(op, a: PoseAnchors, skin: tuple[int, int, int]) -> None:
    ivory = (232, 220, 188)
    for side in (-1, 1):
        ax = a.fx + side * (a.face_half * 0.35)
        ay = a.chin - 1
        for i in range(7):
            t = i / 6
            cx = ax + side * (1.2 + t * 2.5)
            cy = ay + 1 + t * 5
            rad = 1.6 - t * 0.7
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    if not head_clip(x, y, a.fx, a.fy, a.face_half * 2.4):
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.7) ** 2
                    rgb = INK if edge else shade_from(skin, ivory, strength=0.4)
                    op[x, y] = (*rgb, 255)


def _paint_horns_up(op, a: PoseAnchors) -> None:
    bone = (220, 214, 198)
    for side in (-1, 1):
        ax = a.fx + side * (a.face_half * 0.55)
        ay = a.fy - a.face_half * 0.7
        for i in range(8):
            t = i / 7
            cx = ax + side * t * 2.0
            cy = ay - t * 8
            rad = 1.8 - t * 0.9
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    if not head_clip(x, y, a.fx, a.fy, a.face_half * 2.8):
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.65) ** 2
                    op[x, y] = (*(INK if edge else bone), 255)


def _paint_horns_side(op, a: PoseAnchors) -> None:
    bone = (210, 190, 150)
    for side in (-1, 1):
        ax = a.fx + side * a.face_half
        ay = a.fy - 2
        for i in range(10):
            t = i / 9
            cx = ax + side * (3 + t * 10)
            cy = ay - t * 3
            rad = 2.2 - t * 1.1
            for y in range(max(0, int(cy - 3)), min(128, int(cy + 3))):
                for x in range(max(0, int(cx - 3)), min(128, int(cx + 3))):
                    if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                        continue
                    if not head_clip(x, y, a.fx, a.fy, a.face_half * 2.8):
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.7) ** 2
                    op[x, y] = (*(INK if edge else bone), 255)


def paint_undertunic_body(
    family: str,
    anim: str,
    look: RaceLook,
    *,
    female: bool,
) -> tuple[Image.Image, Image.Image]:
    src = load_body(family, anim)
    tags, anchors = classify(src, family)
    return paint_canonical_body(
        tags, anchors, look, female=female, family=family, src=src
    )


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
            time.sleep(0.15 * (attempt + 1))
    raise last  # type: ignore[misc]


def validate_image(path: Path, *, expected_size: tuple[int, int] = (128, 128)) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing generated file: {path}")
    with Image.open(path) as im:
        if im.size != expected_size:
            raise RuntimeError(f"{path}: got {im.size}, expected {expected_size}")
        if im.mode != "RGBA":
            raise RuntimeError(f"{path}: got {im.mode}, expected RGBA")


def validate_pair(body_path: Path, tint_path: Path) -> None:
    validate_image(body_path)
    validate_image(tint_path)
    with Image.open(body_path) as body, Image.open(tint_path) as tint:
        if body.getbbox() is None:
            raise RuntimeError(f"Generated body is completely empty: {body_path}")
        # Tint may be sparse on tiny cloth — allow empty only if body has cloth below chin.
        # Soft rule: tint should have some alpha when body does.
        body_a = body.getchannel("A")
        tint_a = tint.getchannel("A")
        if tint.getbbox() is None:
            # Accept empty tint only for debugging; warn via raise for ship.
            raise RuntimeError(f"Generated tint is completely empty: {tint_path}")
        # Alpha bbox need not match exactly (head has no tint); just ensure overlap.
        bb = body_a.getbbox()
        tb = tint_a.getbbox()
        if bb is None or tb is None:
            raise RuntimeError(f"Body/tint alpha missing:\n  {body_path}\n  {tint_path}")


def build_one(
    family: str,
    look: RaceLook,
    sex: str,
    female: bool,
    anim: str,
) -> tuple[Path, Path, Image.Image, Image.Image]:
    body, tint = paint_undertunic_body(family, anim, look, female=female)
    body_path = ROOT / family / f"{look.key}_{sex}_body_{anim}.png"
    tint_path = ROOT / family / f"{look.key}_{sex}_body_tint_{anim}.png"
    save_pair(body_path, body)
    save_pair(tint_path, tint)
    return body_path, tint_path, body, tint


def write_preview() -> None:
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
    cell_w, cell_h = 128 + 8, 128 + 22
    preview = Image.new("RGBA", (cell_w * 6 + 16, cell_h * 2 + 16), (24, 20, 32, 255))
    draw = ImageDraw.Draw(preview)
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None
    for i, (fam, race, sex) in enumerate(samples):
        im = Image.open(ROOT / fam / f"{race}_{sex}_body_idle.png").convert("RGBA")
        x = 8 + (i % 6) * cell_w
        y = 8 + (i // 6) * cell_h
        preview.paste(im, (x, y), im)
        label = f"{fam[0]}/{race}/{sex}"
        draw.text((x + 2, y + 130), label, fill=(220, 210, 190, 255), font=font)
    out = REPO / "tool" / "out" / "undertunic_race_preview.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    preview.save(out)
    print("preview", out.relative_to(REPO))


def main() -> int:
    cfg = CONFIG
    count = 0
    for family in cfg.families:
        for look in cfg.races:
            for sex, female in cfg.sexes:
                for anim in cfg.animations:
                    body_path, tint_path, body, tint = build_one(
                        family, look, sex, female, anim
                    )
                    if cfg.validate:
                        validate_pair(body_path, tint_path)
                    if cfg.write_defaults and look.key == "human" and sex == "m":
                        save_pair(ROOT / family / f"body_{anim}.png", body)
                        save_pair(ROOT / family / f"body_tint_{anim}.png", tint)
                    count += 1
        print("ok", family)
    print(f"done — {count} race bodies + family human-male defaults")
    if cfg.write_preview:
        write_preview()
    return 0


if __name__ == "__main__":
    sys.exit(main())
