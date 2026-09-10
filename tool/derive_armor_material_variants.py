"""Derive cross-material armor overlays (authored-first).

Paper-doll rule: material must read without tooltip — silhouette before color.

Priority order per slot:
1. `gear/_authored/{slot}_{material}_{tier}_{anim}.png`
2. Cross-family remap (warrior plate → mail on cloth bodies; rogue leather →
   leather on non-rogue druids)
3. Structured material ramp on native extract (last resort; must pass facit)

Also writes boots_*_{material}_t*_icon.png foot-band crops.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

from build_owned_gear_layers import (
    bbox,
    face_region,
    load128,
    punch_face_visor,
    register_helm_to_head,
    sample_face,
)

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char"
TOOL = REPO / "tool"
OVERLAY_ANIMS = ("idle",)
SLOTS = ("helm", "chest", "legs", "cloak", "hands")
TIERS = ("t0", "t2")
FAMILIES = ("warrior", "healer", "mage", "rogue")

# Native look per body family (no suffix on disk).
NATIVE_MATERIAL = {
    "warrior": "plate",
    "rogue": "leather",
    "mage": "cloth",
    "healer": "cloth",
}

# Allowed non-native materials per family (from HeroSpecs armorTypes).
MATERIAL_MATRIX: dict[str, tuple[str, ...]] = {
    "warrior": ("leather",),  # guardian druid
    "rogue": ("mail",),  # hunter 40+, enhancement shaman
    "mage": ("mail", "leather"),  # elemental; druid
    "healer": ("plate", "mail", "leather"),  # holy; resto; druid
}


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


def remap_overlay(
    im: Image.Image,
    dest_box: tuple[int, int, int, int],
    y_anchor: float = 0.0,
) -> Image.Image:
    """Scale overlay bbox to dest body box; y_anchor 0=top, 1=bottom."""
    bb = im.getbbox()
    if bb is None:
        return Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    x0, y0, x1, y1 = dest_box
    bw, bh = max(1, x1 - x0), max(1, y1 - y0)
    hx0, hy0, hx1, hy1 = bb
    hw, hh = max(1, hx1 - hx0), max(1, hy1 - hy0)
    scale = min(bw / hw, bh / hh) * 0.92
    nw = max(1, int(hw * scale))
    nh = max(1, int(hh * scale))
    crop = im.crop(bb).resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    px = x0 + (bw - nw) // 2
    py = int(y0 + (bh - nh) * y_anchor)
    px = max(0, min(128 - nw, px))
    py = max(0, min(128 - nh, py))
    out.paste(crop, (px, py), crop)
    return out


def slot_y_anchor(slot: str) -> float:
    return {
        "helm": 0.0,
        "chest": 0.18,
        "hands": 0.22,
        "cloak": 0.0,
        "legs": 0.52,
    }.get(slot, 0.2)


def remap_source_family(material: str, family: str) -> str:
    """Pick a donor family with the right material shape language."""
    if material == "mail":
        return "warrior"  # plate silhouette reads as mail coif/pauldrons
    if material == "leather":
        return "rogue"
    if material == "plate":
        return "warrior"
    return family


def build_mail_helm_authored(family: str) -> Image.Image:
    """Mail coif from warrior plate helm — distinct from leather hood."""
    warrior_helm = Image.open(
        ROOT / "warrior" / "gear" / "helm_t0_idle.png"
    ).convert("RGBA")
    src, box, face = family_src(family)
    placed = register_helm_to_head(warrior_helm, src, face, box)
    return to_mail(placed)


def ensure_authored_mail_helms() -> int:
    """Write _authored mail helm masters when missing."""
    n = 0
    for family in FAMILIES:
        if "mail" not in MATERIAL_MATRIX.get(family, ()):
            continue
        dest = ROOT / family / "gear" / "_authored" / "helm_mail_t0_idle.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            continue
        helm = build_mail_helm_authored(family)
        helm.save(dest)
        print("authored", dest.relative_to(REPO))
        n += 1
    return n


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
    if auth is not None:
        im = Image.open(auth).convert("RGBA")
        if slot == "helm":
            src, box, face = family_src(family)
            im = register_helm_to_head(im, src, face, box)
        return im

    convert = CONVERTERS[material]
    src_body, dest_box, face = family_src(family)

    if slot == "helm" and material == "mail":
        return build_mail_helm_authored(family)

    donor = remap_source_family(material, family)
    if donor != family:
        donor_im = load_donor(donor, slot, tier, anim, material)
        if slot == "helm":
            donor_src, donor_box, donor_face = family_src(donor)
            donor_im = register_helm_to_head(donor_im, donor_src, donor_face, donor_box)
            placed = remap_overlay(donor_im, dest_box, y_anchor=0.0)
            punch_face_visor(placed, src_body, face, dest_box)
            return convert(placed)
        placed = remap_overlay(donor_im, dest_box, y_anchor=slot_y_anchor(slot))
        return convert(placed)

    native = load_native(family, slot, tier, anim)
    if slot == "helm" and material == "mail":
        return build_mail_helm_authored(family)
    return convert(native)


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


def derive_family_material(
    family: str,
    material: str,
    tiers: tuple[str, ...] = TIERS,
) -> int:
    if material == NATIVE_MATERIAL[family]:
        return 0
    gear = ROOT / family / "gear"
    gear.mkdir(parents=True, exist_ok=True)
    (gear / "_authored").mkdir(parents=True, exist_ok=True)
    n = 0
    for slot in SLOTS:
        for tier in tiers:
            for anim in OVERLAY_ANIMS:
                out = derive_slot(family, slot, material, tier, anim)
                dest = gear / f"{slot}_{material}_{tier}_{anim}.png"
                out.save(dest)
                n += 1
            if slot == "legs":
                idle = gear / f"legs_{material}_{tier}_idle.png"
                legs = Image.open(idle).convert("RGBA")
                write_boots_icon(legs, gear / f"boots_{material}_{tier}_icon.png")
                n += 1
    return n


def main() -> None:
    tiers: tuple[str, ...] = ("t2",) if "--t2-only" in sys.argv else TIERS
    n_auth = ensure_authored_mail_helms()
    n = n_auth
    for family, materials in MATERIAL_MATRIX.items():
        for material in materials:
            n += derive_family_material(family, material, tiers)
    print(f"wrote {n} material frames/icons")
    icon_args = [sys.executable, str(TOOL / "make_gear_slot_icons.py")]
    if "--t2-only" in sys.argv:
        icon_args.append("--t2-only")
    subprocess.check_call(icon_args)


if __name__ == "__main__":
    main()
