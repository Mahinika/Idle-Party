"""Class marks and extra armor shapes from pixels we already own.

No new geometry. Paladin widens the warrior plate extract. Death knight
shifts that same helm up and darkens it. Warlock drops the mage hat extract
so it reads as a hood. Chest uses the same moves on the family chest.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char"


def load(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"expected 128: {path}")
    return im


def shift(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def scale_wider(im: Image.Image, sx: float) -> Image.Image:
    box = im.getbbox()
    if box is None:
        return im
    crop = im.crop(box)
    width = max(1, int(round(crop.width * sx)))
    if width > 128:
        width = 128
    scaled = crop.resize((width, crop.height), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cx = (box[0] + box[2]) // 2
    x = max(0, min(128 - width, cx - width // 2))
    y = box[1]
    out.paste(scaled, (x, y), scaled)
    return out


def ramp(im: Image.Image, fn) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (*fn(r, g, b), a)
    return out


def gold(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.62 + 78)),
        min(255, int(g * 0.50 + 52)),
        min(255, int(b * 0.34 + 18)),
    )


def dusk(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.28 + 18)),
        min(255, int(g * 0.30 + 16)),
        min(255, int(b * 0.42 + 28)),
    )


def shadow(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.34 + 22)),
        min(255, int(g * 0.22 + 8)),
        min(255, int(b * 0.40 + 24)),
    )


def write(family: str, stem: str, im: Image.Image) -> None:
    path = ROOT / family / "gear" / f"{stem}_idle.png"
    im.save(path)
    print(path.relative_to(REPO))


def derive(family: str, slot: str, tier: str, transform) -> None:
    src = load(ROOT / family / "gear" / f"{slot}_{tier}_idle.png")
    write(family, f"{slot}_{transform.__name__}_{tier}", transform(src))


def paladin(im: Image.Image) -> Image.Image:
    return ImageEnhance.Contrast(ramp(scale_wider(im, 1.14), gold)).enhance(1.08)


def deathknight(im: Image.Image) -> Image.Image:
    return ImageEnhance.Contrast(ramp(shift(im, 0, -5), dusk)).enhance(1.12)


def warlock(im: Image.Image) -> Image.Image:
    return ImageEnhance.Contrast(ramp(shift(im, 0, 7), shadow)).enhance(1.1)


def brass(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.78 + 36)),
        min(255, int(g * 0.62 + 18)),
        min(255, int(b * 0.48 + 8)),
    )


def steel(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.55 + 12)),
        min(255, int(g * 0.68 + 22)),
        min(255, int(b * 0.82 + 36)),
    )


def wide(im: Image.Image) -> Image.Image:
    return ramp(scale_wider(im, 1.34), brass)


def slim(im: Image.Image) -> Image.Image:
    return ramp(scale_wider(im, 0.74), steel)


def write_shapes() -> None:
    slots = ("helm", "chest", "legs", "cloak", "hands")
    for family in ("warrior", "healer", "mage", "rogue"):
        for slot in slots:
            src = load(ROOT / family / "gear" / f"{slot}_t0_idle.png")
            write(family, f"{slot}_wide", wide(src))
            write(family, f"{slot}_slim", slim(src))


def main() -> None:
    for tier in ("t0", "t2"):
        for slot in ("helm", "chest"):
            derive("warrior", slot, tier, paladin)
            derive("warrior", slot, tier, deathknight)
            derive("mage", slot, tier, warlock)
    write_shapes()


if __name__ == "__main__":
    main()
