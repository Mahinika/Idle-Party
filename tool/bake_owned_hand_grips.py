#!/usr/bin/env python3
"""Bake shared hand-item overlays so the *handle/hold* UV sits on the owned hand socket.

Weapons: grip = bottom-center of opaque bbox (handle / pommel).
Shields/frills: grip = opaque bbox center.

Updates both `char/gear/` and matching `_authored/` masters. Icons unchanged.
Regen grips after: `py tool/gen_owned_gear_grips.py`.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEAR = ROOT / "assets" / "custom" / "char" / "gear"
AUTHORED = GEAR / "_authored"

MAIN_HAND_UV = (0.78, 0.64)
OFF_HAND_UV = (0.22, 0.64)
MIN_SHIFT_PX = 3.0


def grip_uv(im: Image.Image, *, off_hand: bool) -> tuple[float, float] | None:
    bbox = im.getbbox()
    if bbox is None:
        return None
    left, top, right, bottom = bbox
    cx = (left + right) / 2 / 128
    if off_hand:
        return (cx, (top + bottom) / 2 / 128)
    # Handle / pommel near the bottom of the weapon silhouette.
    return (cx, max(0.0, (bottom - 5) / 128))


def bake_one(path: Path) -> tuple[bool, str]:
    stem_anim = path.name.removesuffix(".png")
    parts = stem_anim.rsplit("_", 1)
    if len(parts) != 2 or parts[1] not in ("idle", "walk", "attack"):
        return False, "skip-name"
    stem = parts[0]
    off = stem.startswith(("shield_", "frill_"))
    target = OFF_HAND_UV if off else MAIN_HAND_UV

    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        return False, f"bad-size-{im.size}"
    grip = grip_uv(im, off_hand=off)
    if grip is None:
        return False, "empty"

    dx = target[0] * 128 - grip[0] * 128
    dy = target[1] * 128 - grip[1] * 128
    mag = math.hypot(dx, dy)
    if mag < MIN_SHIFT_PX:
        return False, f"ok(|s|={mag:.1f})"

    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (int(round(dx)), int(round(dy))), im)
    if out.getbbox() is None:
        return False, "shift-empty"
    out.save(path)
    return True, f"shift=({dx:+.1f},{dy:+.1f})"


def main() -> None:
    updated = 0
    skipped = 0
    for folder in (GEAR, AUTHORED):
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.png")):
            if path.name.endswith("_icon.png"):
                continue
            name = path.name
            if not any(
                name.startswith(p)
                for p in (
                    "sword_",
                    "staff_",
                    "dagger_",
                    "mace_",
                    "axe_",
                    "bow_",
                    "shield_",
                    "frill_",
                )
            ):
                continue
            changed, note = bake_one(path)
            rel = path.relative_to(ROOT)
            if changed:
                updated += 1
                print(f"BAKE {rel}: {note}")
            else:
                skipped += 1
                if not note.startswith("ok"):
                    print(f"skip {rel}: {note}")
    print(f"done: baked={updated} skipped={skipped}")


if __name__ == "__main__":
    main()
