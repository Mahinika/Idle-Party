#!/usr/bin/env python3
"""Generate lib/visual/owned_gear_grips.dart from char/gear/*_idle.png.

Each weapon picks its own hold on an opaque pixel. A blade, axe, mace, or
wand is held in the handle, in from the butt, so the pommel hangs past the
fist. A staff or polearm is held up the shaft, not at the end. A bow is held
on the stave. A shield hangs from its top rim. The rest angle aims that
weapon's tip up and out.

Do not hand-edit the Dart file. Run this script.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

from paper_doll_paths import CHAR, REPO

ROOT = REPO
GEAR = CHAR / "gear"
OUT = ROOT / "lib" / "visual" / "owned_gear_grips.dart"
ALPHA = 40
# How far from the butt toward the tip the hand closes. The butt stays
# past the fist, so the weapon looks held instead of perched on the knuckle.
HOLD_FROM_BUTT = {
    "sword_": 0.22,
    "dagger_": 0.28,
    "axe_": 0.20,
    "mace_": 0.30,
    "wand_": 0.45,
    "staff_": 0.36,
    "polearm_": 0.32,
    "gun_": 0.30,
    "crossbow_": 0.24,
}
# Shorter than this (thrown star, fist) has no blade to aim.
MIN_REACH = 22


def _section_center(
    im: Image.Image, y0: int, y1: int
) -> tuple[float, float] | None:
    """Middle of the opaque span on the middle row of the band.

    A mass centroid sits on the heavy side of a thin shaft (the left edge
    of a staff). The span middle is the handle the hand closes around.
    """
    px = im.load()
    mids: list[tuple[float, int]] = []
    for y in range(max(0, y0), min(im.height, y1)):
        xs = [x for x in range(im.width) if px[x, y][3] >= ALPHA]
        if xs:
            mids.append(((xs[0] + xs[-1]) / 2, y))
    if not mids:
        return None
    return mids[len(mids) // 2]


def _snap_to_opaque(
    im: Image.Image, x: float, y: float
) -> tuple[float, float]:
    """Nearest opaque pixel — a span middle can still fall in a hole."""
    px = im.load()
    xi = min(max(int(round(x)), 0), im.width - 1)
    yi = min(max(int(round(y)), 0), im.height - 1)
    if px[xi, yi][3] >= ALPHA:
        return (float(xi), float(yi))
    best = (x, y)
    best_d = None
    for yy in range(im.height):
        for xx in range(im.width):
            if px[xx, yy][3] < ALPHA:
                continue
            d = (xx - x) ** 2 + (yy - y) ** 2
            if best_d is None or d < best_d:
                best_d = d
                best = (float(xx), float(yy))
    return best


def _bow_stave(im: Image.Image) -> tuple[float, float] | None:
    """The straight limb, not the string. The fullest column is the stave."""
    px = im.load()
    bbox = im.getbbox()
    if bbox is None:
        return None
    counts = [0] * im.width
    for y in range(bbox[1], bbox[3]):
        for x in range(im.width):
            if px[x, y][3] >= ALPHA:
                counts[x] += 1
    if max(counts) == 0:
        return None
    x = max(range(im.width), key=lambda i: counts[i])
    ys = [y for y in range(im.height) if px[x, y][3] >= ALPHA]
    return (float(x), float(ys[len(ys) // 2]))


def _ends(im: Image.Image) -> tuple[tuple[int, int], tuple[int, int]] | None:
    """Tip is the upper-left end. Butt is the lower-right end."""
    px = im.load()
    pts = [
        (x, y)
        for y in range(im.height)
        for x in range(im.width)
        if px[x, y][3] >= ALPHA
    ]
    if not pts:
        return None
    tip = min(pts, key=lambda p: (p[0] + p[1], p[1], p[0]))
    butt = max(pts, key=lambda p: (p[0] + p[1], p[1], p[0]))
    return tip, butt


def _hold_from_butt(stem: str) -> float | None:
    for prefix, along in HOLD_FROM_BUTT.items():
        if stem.startswith(prefix):
            return along
    return None


def _along(
    im: Image.Image, butt: tuple[int, int], tip: tuple[int, int], along: float
) -> tuple[float, float]:
    """A point on the weapon, `along` of the way from the butt to the tip."""
    x = butt[0] + (tip[0] - butt[0]) * along
    y = butt[1] + (tip[1] - butt[1]) * along
    return _snap_to_opaque(im, x, y)


def _grip_px(
    im: Image.Image, stem: str
) -> tuple[tuple[float, float] | None, tuple[int, int] | None]:
    """Grip pixel, and the tip the rest angle should aim."""
    bbox = im.getbbox()
    if bbox is None:
        return None, None
    _, top, _, bottom = bbox
    if stem.startswith("bow_"):
        point = _bow_stave(im)
        return (None if point is None else _snap_to_opaque(im, *point)), None
    if stem.startswith(("shield_", "frill_")):
        # Hold the top rim so the shield hangs below the hand, not over the face.
        band = max(6, int((bottom - top) * 0.22))
        point = _section_center(im, top, top + band)
        return (None if point is None else _snap_to_opaque(im, *point)), None
    if stem.startswith(("fist_", "thrown_")):
        point = _section_center(im, top, bottom)
        return (None if point is None else _snap_to_opaque(im, *point)), None
    ends = _ends(im)
    along = _hold_from_butt(stem)
    if ends is None or along is None:
        point = _section_center(im, top, bottom)
        return (None if point is None else _snap_to_opaque(im, *point)), None
    tip, butt = ends
    return _along(im, butt, tip, along), tip


def _wrap(angle: float) -> float:
    while angle > math.pi:
        angle -= 2 * math.pi
    while angle < -math.pi:
        angle += 2 * math.pi
    return angle


def _farthest(
    im: Image.Image, gx: float, gy: float
) -> tuple[float, float, float] | None:
    px = im.load()
    best = None
    best_d = -1.0
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] < ALPHA:
                continue
            d = (x - gx) ** 2 + (y - gy) ** 2
            if d > best_d:
                best_d = d
                best = (float(x), float(y), d)
    return best


def _rest(
    im: Image.Image,
    stem: str,
    gx: float,
    gy: float,
    outward: float,
    aim: tuple[int, int] | None = None,
) -> float:
    """Clockwise radians that aim the tip up-and-out. Flutter rotate is clockwise."""
    if stem.startswith(("shield_", "frill_", "fist_", "thrown_")):
        return 0.0
    if stem.startswith("bow_"):
        # A vertical stave crosses the cheek. Tip the upper limb outward.
        desired = math.atan2(-1.0, 0.55 if outward > 0 else -0.55)
        tip = _farthest(im, gx, gy)
        if tip is None:
            return 0.0
        return _wrap(desired - math.atan2(tip[1] - gy, tip[0] - gx))
    if aim is not None:
        current = math.atan2(aim[1] - gy, aim[0] - gx)
    else:
        tip = _farthest(im, gx, gy)
        if tip is None or tip[2] < MIN_REACH * MIN_REACH:
            return 0.0
        current = math.atan2(tip[1] - gy, tip[0] - gx)
    if stem.startswith(("gun_", "crossbow_")):
        desired = math.atan2(-0.08, 1.0 if outward > 0 else -1.0)
    elif stem.startswith(("staff_", "polearm_")):
        desired = math.atan2(-1.0, 0.12 if outward > 0 else -0.12)
    else:
        desired = math.atan2(-1.0, outward)
    return _wrap(desired - current)


def main() -> None:
    lines: list[str] = [
        "// GENERATED by tool/gen_owned_gear_grips.py — do not hand-edit.",
        "// Grip: that weapon's hold, on an opaque pixel. The butt hangs past it.",
        "// Rest: clockwise radians so a blade points up and out.",
        "// restOff aims the same art up and out from the left hand.",
        "",
        "import 'dart:ui' show Offset;",
        "",
        "/// Per-[visualSetId] grip points for owned hand items on the paper-doll.",
        "abstract final class OwnedGearGrips {",
        "  static const Map<String, Offset> byVisualSetId = {",
    ]
    rests: list[str] = []
    rests_off: list[str] = []

    count = 0
    for path in sorted(GEAR.glob("*_idle.png")):
        stem = path.name.removesuffix("_idle.png")
        im = Image.open(path).convert("RGBA")
        grip, aim = _grip_px(im, stem)
        if grip is None:
            continue
        gx, gy = grip
        rest = _rest(im, stem, gx, gy, 0.40, aim)
        rest_off = _rest(im, stem, gx, gy, -0.40, aim)
        lines.append(f"    '{stem}': Offset({gx / 128:.4f}, {gy / 128:.4f}),")
        rests.append(f"    '{stem}': {rest:.4f},")
        rests_off.append(f"    '{stem}': {rest_off:.4f},")
        count += 1
        print(
            f"{stem:28s} grip=({gx / 128:.3f},{gy / 128:.3f}) "
            f"rest={rest:+.2f} off={rest_off:+.2f}"
        )

    lines.extend(
        [
            "  };",
            "",
            "  static const Map<String, double> restByVisualSetId = {",
            *rests,
            "  };",
            "",
            "  static const Map<String, double> restOffByVisualSetId = {",
            *rests_off,
            "  };",
            "",
            "  static const Offset mainHandFallback = Offset(0.75, 0.82);",
            "  static const Offset offHandFallback = Offset(0.26, 0.65);",
            "",
            "  static Offset forVisualSetId(",
            "    String visualSetId, {",
            "    required bool offHand,",
            "  }) {",
            "    final hit = byVisualSetId[visualSetId];",
            "    if (hit != null) return hit;",
            "    return offHand ? offHandFallback : mainHandFallback;",
            "  }",
            "",
            "  static String? visualSetIdFromAsset(String assetPath) {",
            "    final name = assetPath.split('/').last;",
            "    for (final suffix in ['_idle.png', '_walk.png', '_attack.png']) {",
            "      if (name.endsWith(suffix)) {",
            "        return name.substring(0, name.length - suffix.length);",
            "      }",
            "    }",
            "    return null;",
            "  }",
            "",
            "  static Offset forAsset(String assetPath, {required bool offHand}) {",
            "    final id = visualSetIdFromAsset(assetPath);",
            "    if (id == null) {",
            "      return offHand ? offHandFallback : mainHandFallback;",
            "    }",
            "    return forVisualSetId(id, offHand: offHand);",
            "  }",
            "",
            "  /// Idle twist added on top of the hand anchor's swing.",
            "  static double restForAsset(",
            "    String assetPath, {",
            "    required bool offHand,",
            "  }) {",
            "    final id = visualSetIdFromAsset(assetPath);",
            "    if (id == null) return 0;",
            "    final map = offHand ? restOffByVisualSetId : restByVisualSetId;",
            "    return map[id] ?? 0;",
            "  }",
            "}",
            "",
        ]
    )
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {count} grips -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
