"""Upgrade native body armor via dressed _src gold masters.

Hunter-quality silhouettes come from warrior plate remapped per family material.
We bake them into `_src/body_idle.png`, then re-run `build_owned_gear_layers`
so extracts + facit idle stack stay aligned.

Rogue helm stays authored (`refresh_native_gear.py`) — not painted into _src.
Mage and healer keep gold-master hat pixels on the new master.
Pass the family name; a bare run does not rewrite art.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

from build_owned_gear_layers import TUNIC, recolor_to_cloth, register_to_body
from derive_armor_material_variants import CONVERTERS, load_donor
from paper_doll_manifest import NATIVE_MATERIAL
from paper_doll_paths import LIVE_CHAR as ROOT, REPO, TOOL
DONOR = "warrior"
# Hat pixels from the gold master are pasted back on top. Rogue has none.
# Re-running a family composites the current undertunic again, so only pass
# a family when that bake is intentional.
UPGRADE_FAMILIES = ("rogue", "mage", "healer")
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
    donor_im = load_donor(DONOR, slot, "t0", "idle", NATIVE_MATERIAL[DONOR])
    return convert_native(register_to_body(donor_im, DONOR, family, slot), family)


def gold_hat(family: str) -> Image.Image:
    """Helm pixels from the current gold master, before it is replaced."""
    from paper_doll_classify import HELM, classify_src

    clf = classify_src(family, "idle")
    src = clf.src
    hat = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    sp, hp = src.load(), hat.load()
    for y in range(128):
        for x in range(128):
            if clf.labels[y][x] == HELM:
                hp[x, y] = sp[x, y]
    return hat


def composite_dressed_src(family: str) -> Image.Image:
    body = Image.open(ROOT / family / "body_idle.png").convert("RGBA")
    layers = {slot: native_slot_overlay(family, slot) for slot in BODY_SLOTS}
    hat = gold_hat(family)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for slot in ("cloak", "body", "legs", "chest", "hands"):
        if slot == "body":
            out = Image.alpha_composite(out, body)
        else:
            out = Image.alpha_composite(out, layers[slot])
    if hat.getbbox():
        out = Image.alpha_composite(out, hat)
    return out


def upgrade_family(family: str) -> None:
    src_path = ROOT / family / "_src" / "body_idle.png"
    backup = src_path.with_suffix(".png.bak")
    if not backup.exists():
        shutil.copyfile(src_path, backup)
    dressed = composite_dressed_src(family)
    dressed.save(src_path)
    print("upgraded _src", src_path.relative_to(REPO))


def main() -> int:
    wanted = tuple(a for a in sys.argv[1:] if a in UPGRADE_FAMILIES)
    if not wanted:
        print(
            "pass a family: "
            + " ".join(UPGRADE_FAMILIES)
            + " — hat pixels are kept; the gold master is replaced"
        )
        return 2
    for family in wanted:
        upgrade_family(family)
    if "rogue" in wanted:
        subprocess.check_call(
            [sys.executable, str(TOOL / "refresh_native_gear.py")]
        )
    print("done — gold master updated; run py tool/build_owned_gear_layers.py --publish")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
