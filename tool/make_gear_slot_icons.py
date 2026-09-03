"""Crop paper-doll idle overlays to tight 64×64 slot icons.

Full 128×128 overlays sit in a corner (weapons) or cover the body (armor).
GEAR/BAG slots need a bbox crop so icons match the doll without muddy zoom.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
MIN_OPAQUE = 80
ICON = 64
SKIP_STEMS = {"hands"}  # gloves are tiny wrist pixels — Kenney reads better


def opaque_count(im: Image.Image) -> int:
    a = im.split()[-1]
    return sum(1 for p in a.getdata() if p > 24)


def make_icon(im: Image.Image) -> Image.Image | None:
    bbox = im.getbbox()
    if bbox is None:
        return None
    crop = im.crop(bbox)
    if opaque_count(crop) < MIN_OPAQUE:
        return None
    w, h = crop.size
    side = max(w, h) + 6
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - w) // 2, (side - h) // 2), crop)
    return canvas.resize((ICON, ICON), Image.Resampling.NEAREST)


def stem_ok(name: str) -> bool:
    if not name.endswith("_idle.png"):
        return False
    base = name[: -len("_idle.png")]
    token = base.split("_")[0]
    return token not in SKIP_STEMS


def convert_folder(folder: Path) -> int:
    n = 0
    if not folder.is_dir():
        return 0
    for src in folder.glob("*_idle.png"):
        if not stem_ok(src.name):
            continue
        if "_authored" in src.parts:
            continue
        im = Image.open(src).convert("RGBA")
        icon = make_icon(im)
        dest = src.with_name(src.name.replace("_idle.png", "_icon.png"))
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
