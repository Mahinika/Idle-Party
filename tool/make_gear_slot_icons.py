"""Crop paper-doll idle overlays to tight 64×64 slot icons.

Full 128×128 overlays sit in a corner (weapons) or cover the body (armor).
GEAR/BAG slots need a bbox crop so icons match the doll without muddy zoom.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
MIN_OPAQUE = 40
ICON = 64
# Hands are sparse wrist pixels — still crop when enough opaque remains.
HANDS_MIN_OPAQUE = 24


def opaque_count(im: Image.Image) -> int:
    a = im.split()[-1]
    return sum(1 for p in a.getdata() if p > 24)


def make_icon(im: Image.Image, *, min_opaque: int = MIN_OPAQUE) -> Image.Image | None:
    bbox = im.getbbox()
    if bbox is None:
        return None
    crop = im.crop(bbox)
    if opaque_count(crop) < min_opaque:
        return None
    w, h = crop.size
    side = max(w, h) + 6
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - w) // 2, (side - h) // 2), crop)
    return canvas.resize((ICON, ICON), Image.Resampling.NEAREST)


def convert_folder(folder: Path) -> int:
    n = 0
    if not folder.is_dir():
        return 0
    for src in folder.glob("*_idle.png"):
        if "_authored" in src.parts:
            continue
        base = src.name[: -len("_idle.png")]
        token = base.split("_")[0]
        min_op = HANDS_MIN_OPAQUE if token == "hands" else MIN_OPAQUE
        im = Image.open(src).convert("RGBA")
        icon = make_icon(im, min_opaque=min_op)
        dest = src.with_name(src.name.replace("_idle.png", "_icon.png"))
        if icon is None:
            if dest.exists():
                dest.unlink()
            continue
        icon.save(dest)
        n += 1
    # Boots BAG icons: lower band of legs (body still folds boots → legs).
    n += write_boots_icons(folder)
    return n


def write_boots_icons(folder: Path) -> int:
    n = 0
    for tier in ("t0", "t2"):
        legs = folder / f"legs_{tier}_idle.png"
        if not legs.exists():
            continue
        im = Image.open(legs).convert("RGBA")
        # Keep the foot/shin band so BAG reads as boots, not full pants.
        boots = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        boots.paste(im.crop((0, 72, 128, 128)), (0, 72))
        icon = make_icon(boots, min_opaque=HANDS_MIN_OPAQUE)
        dest = folder / f"boots_{tier}_icon.png"
        if icon is None:
            if dest.exists():
                dest.unlink()
            continue
        icon.save(dest)
        n += 1
    return n


def main() -> None:
    n = convert_folder(ROOT / "gear")
    for family in ("warrior", "healer", "mage", "rogue"):
        n += convert_folder(ROOT / family / "gear")
    print(f"wrote {n} slot icons")


if __name__ == "__main__":
    main()
