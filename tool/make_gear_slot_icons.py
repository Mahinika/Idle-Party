"""Crop paper-doll idle overlays to tight 64×64 slot icons.

Full 128×128 overlays sit in a corner (weapons) or cover the body (armor).
GEAR/BAG slots need a bbox crop so icons match the doll without muddy zoom.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

from paper_doll_manifest import FAMILIES, icon_stems
from paper_doll_paths import CHAR as ROOT

MIN_OPAQUE = 40
ICON = 64
# Hands are sparse wrist pixels — still crop when enough opaque remains.
HANDS_MIN_OPAQUE = 24
SHOULDER_MIN_OPAQUE = 12


def opaque_count(im: Image.Image) -> int:
    a = im.split()[-1]
    pixels = (
        a.get_flattened_data()
        if hasattr(a, "get_flattened_data")
        else a.getdata()
    )
    return sum(1 for p in pixels if p > 24)


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


def _hide_covered_feet(im: Image.Image, folder: Path, stem: str) -> Image.Image:
    """Cloaks hide healer and mage legs, so the legs icon is not the boots."""
    if not stem.startswith("legs_"):
        return im
    family = folder.parent.name
    if family not in ("healer", "mage"):
        return im
    out = im.copy()
    px = out.load()
    for y in range(116, out.height):
        for x in range(out.width):
            px[x, y] = (0, 0, 0, 0)
    return out


def _icon_from_box(im: Image.Image, box: tuple[int, int, int, int] | None) -> Image.Image | None:
    """Crop [im] with the slot icon's box so a dye lines up on the icon."""
    if box is None:
        return None
    crop = im.crop(box)
    w, h = crop.size
    if w < 1 or h < 1:
        return None
    side = max(w, h) + 6
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - w) // 2, (side - h) // 2), crop)
    return canvas.resize((ICON, ICON), Image.Resampling.NEAREST)


def convert_folder(
    folder: Path, *, t2_only: bool = False, only: set[str] | None = None
) -> int:
    """Icons for [only] stems (family folders), or every overlay (shared)."""
    n = 0
    if not folder.is_dir():
        return 0
    for src in folder.glob("*_idle.png"):
        if "_authored" in src.parts:
            continue
        base = src.name[: -len("_idle.png")]
        if only is not None and base not in only:
            continue
        if t2_only and not base.endswith("_t2"):
            continue
        token = base.split("_")[0]
        if token == "hands":
            min_op = HANDS_MIN_OPAQUE
        elif token == "shoulder":
            min_op = SHOULDER_MIN_OPAQUE
        else:
            min_op = MIN_OPAQUE
        im = Image.open(src).convert("RGBA")
        im = _hide_covered_feet(im, folder, base)
        icon = make_icon(im, min_opaque=min_op)
        if base.startswith("chest_") and "_dye" not in base:
            dye = folder / f"{base}_dye.png"
            if dye.exists():
                dye_icon = _icon_from_box(
                    Image.open(dye).convert("RGBA"),
                    im.getbbox(),
                )
                dye_dest = folder / f"{base}_dye_icon.png"
                if dye_icon is None:
                    dye_icon = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
                dye_icon.save(dye_dest)
        dest = src.with_name(src.name.replace("_idle.png", "_icon.png"))
        if icon is None:
            if dest.exists():
                dest.unlink()
            continue
        icon.save(dest)
        n += 1
    # Boots BAG icons: lower band of legs (body still folds boots → legs).
    n += write_boots_icons(folder, t2_only=t2_only)
    return n


def write_boots_icons(folder: Path, *, t2_only: bool = False) -> int:
    n = 0
    for tier in (("t2",) if t2_only else ("t0", "t2")):
        legs = folder / f"legs_{tier}_idle.png"
        if not legs.exists():
            continue
        im = Image.open(legs).convert("RGBA")
        # Keep the foot/shin band so BAG reads as boots, not full pants.
        boots = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        boots.paste(im.crop((0, 100, 128, 128)), (0, 100))
        icon = make_icon(boots, min_opaque=HANDS_MIN_OPAQUE)
        dest = folder / f"boots_{tier}_icon.png"
        if icon is None:
            if dest.exists():
                dest.unlink()
            continue
        icon.save(dest)
        n += 1
    return n


def rewrite_boots(folder: Path) -> int:
    """Boots icons are the foot band of the finished legs overlay."""
    from derive_armor_material_variants import write_boots_icon
    from paper_doll_manifest import gear_files

    allowed = gear_files(folder.parent.name)
    n = 0
    for legs in sorted(folder.glob("legs_*_idle.png")):
        dest_name = legs.name.replace("legs_", "boots_", 1).replace(
            "_idle.png", "_icon.png"
        )
        if dest_name not in allowed:
            continue
        write_boots_icon(Image.open(legs).convert("RGBA"), folder / dest_name)
        n += 1
    return n


def write_all(*, t2_only: bool = False) -> int:
    n = convert_folder(ROOT / "gear", t2_only=t2_only)
    for family in FAMILIES:
        folder = ROOT / family / "gear"
        n += convert_folder(
            folder, t2_only=t2_only, only=set(icon_stems(family))
        )
        n += rewrite_boots(folder)
    return n


def main() -> None:
    from paper_doll_paths import refuse_live_writer, staged

    if not staged():
        refuse_live_writer("make_gear_slot_icons.py")
    print(f"wrote {write_all(t2_only='--t2-only' in sys.argv)} slot icons")


if __name__ == "__main__":
    main()
