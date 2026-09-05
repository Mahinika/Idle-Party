"""Derive material armor overlays from existing family extracts.

Paper-doll rule: recolor / thicken existing alpha — do not invent geometry.

- Rogue mail: steel blue-grey from leather `*_t0` / `*_t2`
- Healer plate: heavier metal/gold from cloth extracts

Also writes boots_*_{mail,plate}_t*_icon.png foot-band crops.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
TOOL = Path(__file__).resolve().parent
ANIMS = ("idle", "walk", "attack")
SLOTS = ("helm", "chest", "legs", "cloak", "hands")
TIERS = ("t0", "t2")


def thicken(im: Image.Image, passes: int = 1) -> Image.Image:
    if im.getbbox() is None:
        return im
    out = im.copy()
    for _ in range(passes):
        src = out.copy()
        sp, op = src.load(), out.load()
        for y in range(1, 127):
            for x in range(1, 127):
                if sp[x, y][3] > 40:
                    continue
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    r, g, b, a = sp[x + dx, y + dy]
                    if a > 80:
                        op[x, y] = (r, g, b, min(255, a - 20))
                        break
    return out


def to_mail(im: Image.Image) -> Image.Image:
    """Leather → steel mail (desaturate + cool grey-blue)."""
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
            # Cool steel: lift midtones, mute warm leather.
            nr = int(40 + lum * 150)
            ng = int(48 + lum * 155)
            nb = int(58 + lum * 165)
            # Keep a faint highlight sheen on bright pixels.
            if lum > 0.55:
                nr = min(255, nr + 18)
                ng = min(255, ng + 22)
                nb = min(255, nb + 28)
            px[x, y] = (nr, ng, nb, a)
    return ImageEnhance.Contrast(out).enhance(1.10)


def to_plate(im: Image.Image) -> Image.Image:
    """Cloth → heavier plate (metal gold + one thicken)."""
    out = thicken(im, passes=1)
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (
                min(255, int(r * 0.55 + 95)),
                min(255, int(g * 0.48 + 70)),
                min(255, int(b * 0.32 + 28)),
                a,
            )
    return ImageEnhance.Contrast(out).enhance(1.12)


def write_boots_icon(legs: Image.Image, dest: Path) -> None:
    """Foot-band crop matching make_gear_slot_icons.write_boots_icons."""
    boots = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    boots.paste(legs.crop((0, 72, 128, 128)), (0, 72))
    bbox = boots.getbbox()
    if bbox is None:
        return
    crop = boots.crop(bbox)
    w, h = crop.size
    side = max(w, h) + 6
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - w) // 2, (side - h) // 2), crop)
    icon = canvas.resize((64, 64), Image.Resampling.NEAREST)
    icon.save(dest)


def derive_family(
    family: str,
    material: str,
    convert,
) -> int:
    gear = ROOT / family / "gear"
    n = 0
    for slot in SLOTS:
        for tier in TIERS:
            for anim in ANIMS:
                src = gear / f"{slot}_{tier}_{anim}.png"
                if not src.exists():
                    raise SystemExit(f"missing source {src}")
                im = Image.open(src).convert("RGBA")
                out = convert(im)
                dest = gear / f"{slot}_{material}_{tier}_{anim}.png"
                out.save(dest)
                n += 1
            # Boots icon from idle legs material variant
            if slot == "legs":
                idle = gear / f"legs_{material}_{tier}_idle.png"
                legs = Image.open(idle).convert("RGBA")
                write_boots_icon(legs, gear / f"boots_{material}_{tier}_icon.png")
                n += 1
    return n


def main() -> None:
    n = 0
    n += derive_family("rogue", "mail", to_mail)
    n += derive_family("healer", "plate", to_plate)
    print(f"wrote {n} material frames/icons")
    subprocess.check_call([sys.executable, str(TOOL / "make_gear_slot_icons.py")])


if __name__ == "__main__":
    main()
