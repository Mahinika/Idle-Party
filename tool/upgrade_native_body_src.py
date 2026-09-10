"""Upgrade native body armor via dressed _src gold masters.

Hunter-quality silhouettes come from warrior plate remapped per family material.
We bake them into `_src/body_idle.png`, then re-run `build_owned_gear_layers`
so extracts + facit idle stack stay aligned.

Rogue helm stays authored (`refresh_native_gear.py`) — not painted into _src.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

from build_owned_gear_layers import (
    TUNIC,
    bbox,
    process_family,
    recolor_to_cloth,
    sample_face,
    write_armor_preview,
)
from derive_armor_material_variants import (
    CONVERTERS,
    NATIVE_MATERIAL,
    SLOTS,
    family_src,
    load_donor,
    remap_overlay,
    slot_y_anchor,
)

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char"
TOOL = REPO / "tool"
DONOR = "warrior"
# Mage/healer _src includes hat pixels — rebaking body armor needs a separate
# hat-aware pass. Rogue has no helm in _src so this is safe today.
UPGRADE_FAMILIES = ("rogue",)
BODY_SLOTS = ("cloak", "legs", "chest", "hands")


def to_cloth(im: Image.Image, family: str) -> Image.Image:
    cloth_light, _cloth_dark = TUNIC[family]
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = recolor_to_cloth((r, g, b), cloth_light, a)
    return ImageEnhance.Contrast(out).enhance(1.06)


def convert_native(im: Image.Image, family: str) -> Image.Image:
    material = NATIVE_MATERIAL[family]
    if material == "cloth":
        return to_cloth(im, family)
    return CONVERTERS[material](im)


def native_slot_overlay(family: str, slot: str) -> Image.Image:
    _src, dest_box, _face = family_src(family)
    donor_im = load_donor(DONOR, slot, "t0", "idle", NATIVE_MATERIAL[DONOR])
    placed = remap_overlay(donor_im, dest_box, y_anchor=slot_y_anchor(slot))
    return convert_native(placed, family)


def composite_dressed_src(family: str) -> Image.Image:
    body = Image.open(ROOT / family / "body_idle.png").convert("RGBA")
    layers = {slot: native_slot_overlay(family, slot) for slot in BODY_SLOTS}
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for slot in ("cloak", "body", "legs", "chest", "hands"):
        if slot == "body":
            out = Image.alpha_composite(out, body)
        else:
            out = Image.alpha_composite(out, layers[slot])
    if family in ("mage", "healer"):
        helm = Image.open(ROOT / family / "gear" / "helm_t0_idle.png").convert("RGBA")
        out = Image.alpha_composite(out, helm)
    return out


def upgrade_family(family: str) -> None:
    src_path = ROOT / family / "_src" / "body_idle.png"
    backup = src_path.with_suffix(".png.bak")
    if not backup.exists():
        shutil.copyfile(src_path, backup)
    dressed = composite_dressed_src(family)
    dressed.save(src_path)
    print("upgraded _src", src_path.relative_to(REPO))


def rebuild_extracts(families: tuple[str, ...]) -> None:
    built: dict = {}
    for family in families:
        built[family] = process_family(family)
        write_armor_preview(family, built[family])


def main() -> int:
    for family in UPGRADE_FAMILIES:
        upgrade_family(family)
    rebuild_extracts(UPGRADE_FAMILIES)
    subprocess.check_call([sys.executable, str(TOOL / "refresh_native_gear.py")])
    subprocess.check_call([sys.executable, str(TOOL / "derive_armor_material_variants.py")])
    print("done — run py tool/check_paper_doll_facit.py --relock")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
