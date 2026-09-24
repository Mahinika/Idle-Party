"""Cross-material armor overlays (authored-first). Called by the gear build.

Paper-doll rule: material must read without tooltip — silhouette before color.

Priority order per slot and cut (t0, t2, short, broad):
1. `gear/_authored/{slot}_{material}_{cut}_idle.png`
2. The donor family that owns the material's shape (warrior plate for plate
   and mail, rogue leather for leather), moved onto the body by landmarks
3. Structured material ramp on the native piece (last resort)

Also writes boots_*_{material}_t*_icon.png foot-band crops.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

from build_owned_gear_layers import (
    bbox,
    load128,
    rarefy_armor,
    register_helm_to_head,
    register_to_body,
    sample_face,
)
from paper_doll_manifest import (
    CUTS,
    FAMILIES,
    MATERIALS as MATERIAL_MATRIX,
    NATIVE_MATERIAL,
    SLOTS,
    TIERS,
)
from paper_doll_paths import CHAR as ROOT

OVERLAY_ANIMS = ("idle",)


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
    """Steel mail ramp — cool grey-blue with highlight sheen."""
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
            nr = int(40 + lum * 150)
            ng = int(48 + lum * 155)
            nb = int(58 + lum * 165)
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


def to_leather(im: Image.Image) -> Image.Image:
    """Cloth/plate → warm leather (rogue palette family)."""
    out = thicken(im, passes=1)
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
            nr = int(52 + lum * 118)
            ng = int(40 + lum * 88)
            nb = int(28 + lum * 52)
            px[x, y] = (nr, ng, nb, a)
    return ImageEnhance.Contrast(out).enhance(1.08)


CONVERTERS = {
    "mail": to_mail,
    "plate": to_plate,
    "leather": to_leather,
}


def authored_path(
    family: str, slot: str, material: str, tier: str, anim: str
) -> Path | None:
    gear = ROOT / family / "gear"
    for name in (
        f"{slot}_{material}_{tier}_{anim}.png",
        f"{slot}_{material}_{tier}.png",
    ):
        p = gear / "_authored" / name
        if p.exists():
            return p
    return None


def family_src(family: str) -> tuple[Image.Image, tuple[int, int, int, int], tuple[int, int, int]]:
    src = load128(ROOT / family / "_src" / "body_idle.png")
    box = bbox(src)
    face = sample_face(src, box, family)
    return src, box, face


def remap_source_family(material: str, family: str) -> str:
    """Pick a donor family with the right material shape language."""
    if material == "mail":
        return "warrior"  # plate silhouette reads as mail coif/pauldrons
    if material == "leather":
        return "rogue"
    if material == "plate":
        return "warrior"
    return family


def load_native(family: str, slot: str, tier: str, anim: str) -> Image.Image:
    path = ROOT / family / "gear" / f"{slot}_{tier}_{anim}.png"
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGBA")


def load_donor(
    donor: str, slot: str, tier: str, anim: str, material: str
) -> Image.Image:
    """Load donor overlay — prefer existing material PNG on donor if present."""
    gear = ROOT / donor / "gear"
    mat_path = gear / f"{slot}_{material}_{tier}_{anim}.png"
    if mat_path.exists():
        return Image.open(mat_path).convert("RGBA")
    native = gear / f"{slot}_{tier}_{anim}.png"
    if not native.exists():
        raise FileNotFoundError(native)
    return Image.open(native).convert("RGBA")


def derive_slot(
    family: str,
    slot: str,
    material: str,
    tier: str,
    anim: str,
) -> Image.Image:
    auth = authored_path(family, slot, material, tier, anim)
    if auth is None and tier == "t2" and authored_path(family, slot, material, "t0", anim):
        # A hand-drawn plain cut owns the shape; the late cut grows from it.
        return rarefy_armor(derive_slot(family, slot, material, "t0", anim))
    if auth is not None:
        im = Image.open(auth).convert("RGBA")
        if slot == "helm":
            src, box, face = family_src(family)
            im = register_helm_to_head(im, src, face, box)
        return im

    convert = CONVERTERS[material]
    donor = remap_source_family(material, family)
    if donor != family:
        donor_im = load_donor(donor, slot, tier, anim, material)
        return convert(register_to_body(donor_im, donor, family, slot))
    return convert(load_native(family, slot, tier, anim))


def write_boots_icon(legs: Image.Image, dest: Path) -> None:
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


def derive_family_material(family: str, material: str) -> int:
    if material == NATIVE_MATERIAL[family]:
        return 0
    gear = ROOT / family / "gear"
    n = 0
    for slot in SLOTS:
        for cut in CUTS:
            for anim in OVERLAY_ANIMS:
                out = derive_slot(family, slot, material, cut, anim)
                out.save(gear / f"{slot}_{material}_{cut}_{anim}.png")
                n += 1
            if slot == "legs" and cut in TIERS:
                legs = Image.open(gear / f"legs_{material}_{cut}_idle.png").convert("RGBA")
                write_boots_icon(legs, gear / f"boots_{material}_{cut}_icon.png")
                n += 1
    return n


def derive_all() -> int:
    n = 0
    for family in FAMILIES:
        for material in MATERIAL_MATRIX[family]:
            n += derive_family_material(family, material)
    return n


if __name__ == "__main__":
    raise SystemExit("run py tool/build_owned_gear_layers.py — materials are one of its steps")
