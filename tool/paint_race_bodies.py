"""Bake race undertunic bodies that match gold-master pose (for gear overlays).

Pipeline:
  _src pose → paint_undertunic (helkropp cloth, hat/hood stripped)
  → flatten cloth chroma → race palette wash → race features
  → tint → validate → save

Gear overlays stay untouched. Bodies keep the same silhouette as
`build_owned_gear_layers.paint_undertunic` so plate/robe extracts line up.

Writes:
  assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png
  assets/custom/char/<family>/<race>_<m|f>_body_tint_<anim>.png
  assets/custom/char/<family>/body_<anim>.png          (human male default)
  assets/custom/char/<family>/body_tint_<anim>.png
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
    TUNIC,
    bbox,
    despeckle_alpha,
    face_region,
    flat_undertunic_pixel,
    is_gold_pixel,
    is_hair_color,
    is_hat_or_hood,
    is_skin,
    load128,
    lum,
    paint_undertunic,
    sample_face,
    strip_equipped_helm_from_body,
    _chin_y,
)

REPO = Path(__file__).resolve().parents[1]

INK = (28, 22, 48)
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


CONFIG = BuildConfig()


def clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))


def shade_from(
    source: tuple[int, int, int],
    target: tuple[int, int, int],
    *,
    strength: float = 1.0,
) -> tuple[int, int, int]:
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


def dist2(ax: float, ay: float, bx: float, by: float) -> float:
    return (ax - bx) * (ax - bx) + (ay - by) * (ay - by)


def head_clip(x: int, y: int, fx: float, fy: float, radius: float) -> bool:
    return dist2(x, y, fx, fy) <= radius * radius


def is_healer_circlet_trim(rgb: tuple[int, int, int]) -> bool:
    if is_gold_pixel(rgb):
        return True
    r, g, b = rgb
    if r >= 155 and g >= 90 and b < 145 and (g - b) >= 35 and (r - b) >= 40:
        return True
    if r >= 200 and g >= 150 and b < 155 and (r - b) > 55:
        return True
    return False


def load_body(family: str, anim: str) -> Image.Image:
    src_path = ROOT / family / "_src" / f"body_{anim}.png"
    path = src_path if src_path.exists() else ROOT / family / f"body_{anim}.png"
    im = Image.open(path).convert("RGBA")
    if im.size != CONFIG.size:
        raise SystemExit(f"{path} is {im.size}, want {CONFIG.size}")
    return im


def scrub_hat_hood(body: Image.Image, family: str, face: tuple[int, int, int], box) -> None:
    """Second pass: kill circlet/hood crumbs paint_undertunic can leave."""
    fx, fy, face_half = face_region(body, face, box)
    chin = float(_chin_y(body, face, fx, fy, face_half))
    op = body.load()
    for y in range(0, int(chin) + 6):
        for x in range(128):
            r, g, b, a = op[x, y]
            if a < 16:
                continue
            rgb = (r, g, b)
            if is_skin(rgb, face):
                continue
            if is_hair_color(family, rgb) and y >= fy - 12 and abs(x - fx) <= face_half * 1.35:
                continue
            if family == "healer" and is_healer_circlet_trim(rgb):
                op[x, y] = (0, 0, 0, 0)
                continue
            if is_hat_or_hood(family, rgb) or is_gold_pixel(rgb):
                op[x, y] = (0, 0, 0, 0)
                continue
            if family == "mage" and y < fy - 8 and not is_hair_color(family, rgb):
                op[x, y] = (0, 0, 0, 0)


def flatten_cloth(
    body: Image.Image,
    family: str,
    face: tuple[int, int, int],
    box,
    *,
    female: bool,
) -> Image.Image:
    """Keep pose alpha, replace plate/robe chroma with flat undertunic cloth."""
    fx, fy, face_half = face_region(body, face, box)
    chin = float(_chin_y(body, face, fx, fy, face_half))
    x0, y0, x1, y1 = box
    mid_y = y0 + int((y1 - y0) * 0.62)
    tunic, pants = TUNIC[family]
    if female:
        tunic = (
            clamp8(tunic[0] * 1.06 + 14),
            clamp8(tunic[1] * 1.06 + 14),
            clamp8(tunic[2] * 1.04 + 10),
        )
        pants = (
            clamp8(pants[0] * 0.95 + 6),
            clamp8(pants[1] * 0.92 + 4),
            clamp8(pants[2] * 0.95 + 6),
        )
    out = body.copy()
    op = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = op[x, y]
            if a < 40:
                continue
            rgb = (r, g, b)
            if is_skin(rgb, face):
                continue
            if y <= chin + 6 and (
                is_hair_color(family, rgb) or lum(rgb) < 0.2
            ):
                continue
            if y <= chin + 8 and abs(x - fx) <= face_half * 2.2:
                # Keep face ink / eyes / hair — never flatten the head.
                if lum(rgb) < 0.55 or is_hair_color(family, rgb):
                    continue
            op[x, y] = flat_undertunic_pixel(x, y, fx, mid_y, tunic, pants, a)
    return despeckle_alpha(out)


def rebuild_cloth_tint(
    body: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box,
) -> Image.Image:
    """Cloth-only mask matching check_paper_doll_facit head/skin rules.

    Facit keys off gold-master skin pixels, not the washed undertunic colors
    (cream healer cloth and warm warrior tunic often false-positive as skin).
    """
    fx, fy, face_half = face_region(src, face, box)
    chin = float(_chin_y(src, face, fx, fy, face_half))
    op = body.load()
    sp = src.load()
    tint = Image.new("RGBA", CONFIG.size, (0, 0, 0, 0))
    tp = tint.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = op[x, y]
            if a < 40:
                continue
            if y <= chin + 8 and abs(x - fx) <= face_half * 2.4:
                continue
            sr, sg, sb, sa = sp[x, y]
            if sa >= 40 and is_skin((sr, sg, sb), face):
                continue
            tp[x, y] = tint_pixel((r, g, b), a)
    return tint


def apply_race_palette(
    body: Image.Image,
    family: str,
    look: RaceLook,
    *,
    female: bool,
    face: tuple[int, int, int],
    box,
    src: Image.Image,
) -> tuple[Image.Image, Image.Image]:
    fx, fy, face_half = face_region(body, face, box)
    chin = float(_chin_y(body, face, fx, fy, face_half))
    skin_t = look.skin_f if female else look.skin_m
    hair_t = look.hair_f if female else look.hair_m
    tunic, pants = TUNIC[family]
    if female:
        tunic = (
            clamp8(tunic[0] * 1.06 + 14),
            clamp8(tunic[1] * 1.06 + 14),
            clamp8(tunic[2] * 1.04 + 10),
        )
        pants = (
            clamp8(pants[0] * 0.95 + 6),
            clamp8(pants[1] * 0.92 + 4),
            clamp8(pants[2] * 0.95 + 6),
        )
    x0, y0, x1, y1 = box
    mid_y = y0 + int((y1 - y0) * 0.62)

    out = body.copy()
    op = out.load()
    tint = Image.new("RGBA", CONFIG.size, (0, 0, 0, 0))
    tp = tint.load()

    # Tag eyes first from bright skin pixels in the eye band.
    eyes: set[tuple[int, int]] = set()
    for y in range(max(0, int(fy - 2)), min(128, int(fy + 4))):
        for x in range(max(0, int(fx - face_half)), min(128, int(fx + face_half) + 1)):
            r, g, b, a = op[x, y]
            if a < 40 or not is_skin((r, g, b), face):
                continue
            if lum((r, g, b)) < 0.78:
                continue
            dx = abs(x - fx)
            if 3.0 <= dx <= face_half * 0.85:
                eyes.add((x, y))

    for y in range(128):
        for x in range(128):
            r, g, b, a = op[x, y]
            if a < 16:
                continue
            rgb = (r, g, b)

            # Eyes win.
            if (x, y) in eyes:
                op[x, y] = (*look.eye, 255)
                tp[x, y] = (0, 0, 0, 0)
                continue

            if is_skin(rgb, face):
                washed = shade_from(rgb, skin_t, strength=0.75)
                if look.fur and lum(rgb) < 0.38:
                    washed = shade_from(washed, look.skin_shadow, strength=0.55)
                elif y > fy + face_half * 0.35 and lum(rgb) < 0.42:
                    washed = shade_from(washed, look.skin_shadow, strength=0.5)
                op[x, y] = (*washed, a)
                tp[x, y] = (0, 0, 0, 0)
                continue

            # Kill leftover circlet / hood before hair wash.
            if family == "healer" and is_healer_circlet_trim(rgb):
                op[x, y] = (0, 0, 0, 0)
                tp[x, y] = (0, 0, 0, 0)
                continue
            if y <= chin + 8 and (is_hat_or_hood(family, rgb) or is_gold_pixel(rgb)):
                op[x, y] = (0, 0, 0, 0)
                tp[x, y] = (0, 0, 0, 0)
                continue

            if y <= chin + 6 and is_hair_color(family, rgb):
                op[x, y] = (*shade_from(rgb, hair_t, strength=0.8), a)
                tp[x, y] = (0, 0, 0, 0)
                continue

            # Face ink
            if y <= chin + 4 and abs(x - fx) <= face_half * 1.4 and lum(rgb) < 0.18:
                op[x, y] = (*INK, a)
                tp[x, y] = (0, 0, 0, 0)
                continue

            # Cloth — soft race-neutral family tunic (already flattened).
            cloth = tunic if y < mid_y else pants
            washed = shade_from(rgb, cloth, strength=0.45)
            op[x, y] = (*washed, a)
            if y > chin + 8 and not is_skin(washed, face) and not is_skin(washed, skin_t):
                # Facit: never tint gold-master skin pixels.
                # We only have live body here; skip head band already.
                tp[x, y] = tint_pixel(washed, a)
            else:
                tp[x, y] = (0, 0, 0, 0)

    # Small clean eye ovals (readable at LOOK card size).
    eye_y = fy + 0.5
    eye_dx = face_half * 0.38
    for side in (-1.0, 1.0):
        ex = fx + side * eye_dx
        for y in range(int(eye_y - 1), int(eye_y + 2)):
            for x in range(int(ex - 2), int(ex + 3)):
                if 0 <= x < 128 and 0 <= y < 128:
                    if (x - ex) ** 2 / 4.5 + (y - eye_y) ** 2 / 2.2 <= 1.0:
                        op[x, y] = (*look.eye, 255)
                        tp[x, y] = (0, 0, 0, 0)

    occupied = {(x, y) for y in range(128) for x in range(128) if op[x, y][3] > 16}
    if look.ears:
        _paint_ears(
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
        _paint_tusks(op, fx, fy, face_half, chin, skin_t)
    if look.horns_up:
        _paint_horns_up(op, fx, fy, face_half)
    if look.horns_side:
        _paint_horns_side(op, fx, fy, face_half)

    return out, rebuild_cloth_tint(out, src, face, box)


def _paint_ears(
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
    soft_edge: bool,
) -> None:
    width = 3.0 if female else 4.2
    lift = max(5, length - 4)
    left_edge = int(fx - face_half)
    right_edge = int(fx + face_half)
    for x, y in occupied:
        if abs(y - fy) > 4:
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
                    if not head_clip(x, y, fx, fy, face_half * 2.8):
                        continue
                    if abs(x - fx) < face_half * 0.62 and fy - 6 < y < chin:
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


def _paint_tusks(op, fx, fy, face_half, chin, skin) -> None:
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
                    if not head_clip(x, y, fx, fy, face_half * 2.4):
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.7) ** 2
                    rgb = INK if edge else shade_from(skin, ivory, strength=0.4)
                    op[x, y] = (*rgb, 255)


def _paint_horns_up(op, fx, fy, face_half) -> None:
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
                    if not head_clip(x, y, fx, fy, face_half * 2.8):
                        continue
                    edge = (x - cx) ** 2 + (y - cy) ** 2 > (rad - 0.65) ** 2
                    op[x, y] = (*(INK if edge else bone), 255)


def _paint_horns_side(op, fx, fy, face_half) -> None:
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
                    if not head_clip(x, y, fx, fy, face_half * 2.8):
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
    src_path = ROOT / family / "_src" / f"body_{anim}.png"
    if not src_path.exists():
        src_path = ROOT / family / f"body_{anim}.png"
    src = load_body(family, anim)
    # Facit samples chin/face on load128 (dark canvas knocked out). Tint must
    # use the same geometry or hair pixels count as head overlap.
    geom = load128(src_path)
    box = bbox(src)
    face = sample_face(src, box, family)
    geom_box = bbox(geom)
    geom_face = sample_face(geom, geom_box, family)
    body, _ = paint_undertunic(src, family, face, box)
    # Helm overlay owns the hat — only punch mage/healer bodies. Warrior/rogue
    # strip_equipped_helm deletes the painted scalp (coif mask covers the face).
    if family in ("mage", "healer"):
        strip_equipped_helm_from_body(family, body)
        scrub_hat_hood(body, family, face, box)
    # Family defaults (human male) stay close to paint_undertunic so idle facit
    # vs dressed _src stays under the hard-diff gate. Race/sex variants flatten
    # + wash for LOOK identity.
    if look.key == "human" and not female:
        return body, rebuild_cloth_tint(body, geom, geom_face, geom_box)
    body = flatten_cloth(body, family, face, box, female=female)
    if family in ("mage", "healer"):
        scrub_hat_hood(body, family, face, box)
    out, _ = apply_race_palette(
        body, family, look, female=female, face=face, box=box, src=src
    )
    return out, rebuild_cloth_tint(out, geom, geom_face, geom_box)


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
        if tint.getbbox() is None:
            raise RuntimeError(f"Generated tint is completely empty: {tint_path}")


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
        draw.text((x + 2, y + 130), f"{fam[0]}/{race}/{sex}", fill=(220, 210, 190, 255), font=font)
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
