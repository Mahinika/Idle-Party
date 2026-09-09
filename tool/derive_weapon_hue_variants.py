"""Derive named weapon looks by recoloring existing authored idle masters.

Paper-doll rule: recolor existing alpha — do not invent geometry.
Writes idle overlays + BAG icons under gear/ and gear/_authored/.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char" / "gear"
AUTH = ROOT / "_authored"

# (new_id, source_id, hue_fn_name)
VARIANTS: list[tuple[str, str, str]] = [
    ("sword_emberfang", "sword_t0", "ember"),
    ("staff_voidspire", "staff_t0", "void"),
    ("bow_ashflight", "bow_t0", "ash"),
    ("axe_stormcleave", "axe_t0", "storm"),
    ("mace_soulhammer", "mace_t0", "soul"),
    ("dagger_venomkiss", "dagger_t0", "venom"),
    ("shield_frostwall", "shield_t0", "frost"),
    ("frill_embercodex", "frill_t0", "ember"),
]


def recolor(im: Image.Image, mode: str) -> Image.Image:
    out = im.copy().convert("RGBA")
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
            if mode == "ember":
                nr = int(50 + lum * 205)
                ng = int(28 + lum * 110)
                nb = int(18 + lum * 55)
            elif mode == "void":
                nr = int(48 + lum * 120)
                ng = int(28 + lum * 70)
                nb = int(70 + lum * 185)
            elif mode == "ash":
                nr = int(42 + lum * 150)
                ng = int(40 + lum * 130)
                nb = int(36 + lum * 100)
                if lum > 0.55:
                    nr = min(255, nr + 40)
                    ng = min(255, ng + 18)
            elif mode == "storm":
                nr = int(30 + lum * 90)
                ng = int(48 + lum * 150)
                nb = int(70 + lum * 185)
            elif mode == "soul":
                nr = int(36 + lum * 100)
                ng = int(70 + lum * 170)
                nb = int(80 + lum * 175)
                if lum > 0.6:
                    nr = min(255, nr + 50)
                    ng = min(255, ng + 40)
            elif mode == "venom":
                nr = int(28 + lum * 80)
                ng = int(70 + lum * 185)
                nb = int(36 + lum * 90)
            elif mode == "frost":
                nr = int(40 + lum * 120)
                ng = int(70 + lum * 165)
                nb = int(95 + lum * 160)
            else:
                nr, ng, nb = r, g, b
            px[x, y] = (
                max(0, min(255, nr)),
                max(0, min(255, ng)),
                max(0, min(255, nb)),
                a,
            )
    return out


def icon_crop(im: Image.Image) -> Image.Image:
    bb = im.getbbox()
    if not bb:
        return Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    cropped = im.crop(bb)
    # Pad to square then resize to 32 for BAG.
    w, h = cropped.size
    side = max(w, h)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - w) // 2, (side - h) // 2), cropped)
    return square.resize((32, 32), Image.Resampling.NEAREST)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    AUTH.mkdir(parents=True, exist_ok=True)
    for new_id, src_id, mode in VARIANTS:
        src = AUTH / f"{src_id}_idle.png"
        if not src.exists():
            src = ROOT / f"{src_id}_idle.png"
        if not src.exists():
            print(f"SKIP {new_id}: missing source {src_id}")
            continue
        idle = recolor(Image.open(src).convert("RGBA"), mode)
        for folder in (AUTH, ROOT):
            idle.save(folder / f"{new_id}_idle.png")
        icon_crop(idle).save(ROOT / f"{new_id}_icon.png")
        print(f"wrote {new_id}")


if __name__ == "__main__":
    main()
