"""Generate DISTINCT 128×128 item model variants (shape + color, not hue-only).

Keep in sync with lib/visual/equipment_model_catalog.dart variant ids.
"""
from __future__ import annotations

import colorsys
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
ANIMS = ("idle", "walk", "attack")
FAMILIES = ("warrior", "healer", "mage", "rogue")

VARIANTS: dict[str, list[str]] = {
    "sword": [
        "sword_t0", "sword_thunderfury", "sword_warglaive", "sword_emberfang",
        "sword_crystalblade", "sword_boneedge", "sword_runebane", "sword_ashcleaver",
        "sword_frostbite", "sword_nightreaver", "sword_sunflare", "sword_voidspike",
    ],
    "staff": [
        "staff_t0", "staff_frostfire", "staff_oakroot", "staff_arcspire",
        "staff_shadowcrook", "staff_emberwand", "staff_tidebranch", "staff_crystalrod",
        "staff_bonespine", "staff_sunshaft", "staff_voidpillar", "staff_stormreed",
    ],
    "dagger": [
        "dagger_t0", "dagger_shadowfang", "dagger_venomtip", "dagger_quicksteel",
        "dagger_bonepin", "dagger_emberknife", "dagger_frostneedle", "dagger_crystalspike",
        "dagger_nightshiv", "dagger_sunblade", "dagger_voidrazor", "dagger_tideedge",
    ],
    "mace": [
        "mace_t0", "mace_ironmaul", "mace_skullcrush", "mace_emberhammer",
        "mace_frostgavel", "mace_crystalhead", "mace_boneclub", "mace_sunmace",
        "mace_voidmallet", "mace_tidecrusher", "mace_runebreaker", "mace_stormflail",
    ],
    "axe": [
        "axe_t0", "axe_warcleave", "axe_bloodbite", "axe_emberhatchet",
        "axe_frostchop", "axe_crystaledge", "axe_bonesaw", "axe_sunaxe",
        "axe_voidhook", "axe_tidebite", "axe_runesplitter", "axe_stormcleaver",
    ],
    "bow": [
        "bow_t0", "bow_longshot", "bow_shadowstring", "bow_emberarc",
        "bow_frostlimb", "bow_crystalbow", "bow_bonebow", "bow_sunarc",
        "bow_voidstring", "bow_tidebow", "bow_runebow", "bow_stormshaft",
    ],
    "shield": [
        "shield_t0", "shield_stormwall", "shield_ironbulwark", "shield_emberguard",
        "shield_frostplate", "shield_crystalward", "shield_boneguard", "shield_sunshield",
        "shield_voidaegis", "shield_tidewall", "shield_runeguard", "shield_towerkite",
    ],
    "frill": [
        "frill_t0", "frill_tome", "frill_orb", "frill_idol",
        "frill_embercharm", "frill_frostsigil", "frill_crystalbauble", "frill_bonerelic",
        "frill_suncharm", "frill_voidtotem", "frill_tidecharm", "frill_runestone",
    ],
    "helm": [
        "helm_t0", "helm_spiked", "helm_visor", "helm_horns", "helm_cowl", "helm_crown",
        "helm_mask", "helm_plume", "helm_winged", "helm_banded", "helm_crest", "helm_hooded",
    ],
    "chest": [
        "chest_t0", "chest_plated", "chest_studded", "chest_robe", "chest_scale",
        "chest_chain", "chest_vest", "chest_tabard", "chest_lamellar", "chest_cuirass",
        "chest_mantle", "chest_brigandine",
    ],
    "legs": [
        "legs_t0", "legs_plated", "legs_padded", "legs_skirt", "legs_scale", "legs_chain",
        "legs_wraps", "legs_greaves", "legs_tassets", "legs_hose", "legs_kilt", "legs_cuisses",
    ],
    "cloak": [
        "cloak_t0", "cloak_cape", "cloak_mantle", "cloak_shawl", "cloak_winged",
        "cloak_ragged", "cloak_fur", "cloak_silk", "cloak_tabard", "cloak_hooded",
        "cloak_banner", "cloak_veil",
    ],
    "hands": [
        "hands_t0", "hands_gauntlets", "hands_gloves", "hands_wraps", "hands_bracers",
        "hands_claws", "hands_mitts", "hands_studded", "hands_scale", "hands_chain",
        "hands_silk", "hands_bone",
    ],
}

SHARED_BASES = ("sword", "staff", "dagger", "mace", "axe", "bow", "shield", "frill")
FAMILY_BASES = ("helm", "chest", "legs", "cloak", "hands")

PRESERVE_AUTHORED = {"sword_thunderfury", "sword_warglaive"}


def seed_int(set_id: str) -> int:
    return int(hashlib.md5(set_id.encode()).hexdigest()[:8], 16)


def load_rgba(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.Resampling.NEAREST)
    return im


def slight_offset(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def opaque_bbox(im: Image.Image):
    px = im.load()
    xs, ys = [], []
    for y in range(128):
        for x in range(128):
            if px[x, y][3] > 40:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def recolor_strong(im: Image.Image, set_id: str) -> Image.Image:
    h_target = (seed_int(set_id) % 1000) / 1000.0
    sat_boost = 0.15 + (seed_int(set_id) % 7) * 0.04
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if vv < 0.1:
                continue
            nh = (hh * 0.25 + h_target * 0.75) % 1.0
            ns = min(1.0, ss * 0.55 + sat_boost)
            nv = min(1.0, vv * (0.88 + (seed_int(set_id) % 6) * 0.035))
            nr, ng, nb = colorsys.hsv_to_rgb(nh, ns, nv)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def scale_about_center(im: Image.Image, sx: float, sy: float) -> Image.Image:
    box = opaque_bbox(im)
    if box is None:
        return im
    x0, y0, x1, y1 = box
    crop = im.crop(box)
    nw = max(1, int((x1 - x0) * sx))
    nh = max(1, int((y1 - y0) * sy))
    resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    ox = max(0, min(128 - nw, cx - nw // 2))
    oy = max(0, min(128 - nh, cy - nh // 2))
    out.paste(resized, (ox, oy), resized)
    return out


def shear_x(im: Image.Image, amount: float) -> Image.Image:
    """Simple nearest shear: shift rows by amount * (y-64)."""
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    sp, dp = im.load(), out.load()
    for y in range(128):
        shift = int(amount * (y - 64))
        for x in range(128):
            sx = x - shift
            if 0 <= sx < 128:
                dp[x, y] = sp[sx, y]
    return out


def add_blade_extra(im: Image.Image, set_id: str, style: int) -> Image.Image:
    """Paint extra geometry so silhouettes diverge hard."""
    out = im.copy()
    d = ImageDraw.Draw(out)
    box = opaque_bbox(im)
    if box is None:
        return out
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    seed = seed_int(set_id)
    # Sample a bright accent from existing art
    px = im.load()
    accent = (200, 210, 220, 255)
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a > 80 and r + g + b > 300:
                accent = (min(255, r + 20), min(255, g + 20), min(255, b + 10), 255)
                break
    dark = (40, 36, 32, 255)
    hi = (min(255, accent[0] + 40), min(255, accent[1] + 40), min(255, accent[2] + 20), 255)

    if style % 6 == 0:
        # Long tip spike
        d.polygon([(cx, y0 - 10), (cx - 3, y0 + 4), (cx + 3, y0 + 4)], fill=hi)
        d.polygon([(cx, y0 - 10), (cx - 1, y0 + 2), (cx + 1, y0 + 2)], fill=accent)
    elif style % 6 == 1:
        # Dual side barbs
        for side in (-1, 1):
            d.polygon(
                [(cx + side * 2, cy - 8), (cx + side * 14, cy - 2), (cx + side * 2, cy + 4)],
                fill=accent,
            )
    elif style % 6 == 2:
        # Thick guard cross
        d.rectangle([cx - 12, cy + 8, cx + 12, cy + 12], fill=hi)
        d.rectangle([cx - 2, cy + 4, cx + 2, cy + 16], fill=dark)
    elif style % 6 == 3:
        # Jagged saw edge along right
        for i in range(5):
            yy = y0 + 6 + i * 8
            d.polygon([(x1 - 2, yy), (x1 + 8, yy + 3), (x1 - 2, yy + 6)], fill=accent)
    elif style % 6 == 4:
        # Glow gem near tip
        d.ellipse([cx - 5, y0 + 6, cx + 5, y0 + 16], fill=hi)
        d.ellipse([cx - 2, y0 + 9, cx + 2, y0 + 13], fill=(255, 255, 220, 255))
    else:
        # Wider pommel / base blob
        d.ellipse([cx - 8, y1 - 10, cx + 8, y1 + 4], fill=dark)
        d.ellipse([cx - 5, y1 - 8, cx + 5, y1], fill=accent)
    return out


def add_armor_trim(im: Image.Image, set_id: str, style: int) -> Image.Image:
    out = im.copy()
    box = opaque_bbox(im)
    if box is None:
        return out
    d = ImageDraw.Draw(out)
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    seed = seed_int(set_id)
    c = (180 + seed % 40, 150 + seed % 50, 60 + seed % 40, 255)
    if style % 5 == 0:
        # Shoulder spikes
        for side in (-1, 1):
            d.polygon(
                [(cx + side * 18, y0 + 8), (cx + side * 28, y0 - 2), (cx + side * 14, y0 + 18)],
                fill=c,
            )
    elif style % 5 == 1:
        # Chest stripe
        d.rectangle([cx - 3, y0 + 10, cx + 3, y1 - 8], fill=c)
    elif style % 5 == 2:
        # Helm horns
        d.polygon([(cx - 8, y0 + 4), (cx - 18, y0 - 12), (cx - 2, y0 + 10)], fill=c)
        d.polygon([(cx + 8, y0 + 4), (cx + 18, y0 - 12), (cx + 2, y0 + 10)], fill=c)
    elif style % 5 == 3:
        # Skirt flare
        d.polygon([(x0, y1 - 6), (x0 - 8, y1 + 6), (x0 + 6, y1)], fill=c)
        d.polygon([(x1, y1 - 6), (x1 + 8, y1 + 6), (x1 - 6, y1)], fill=c)
    else:
        # Cape wing tips
        d.polygon([(x0 + 2, y0 + 20), (x0 - 10, y0 + 40), (x0 + 8, y0 + 36)], fill=c)
        d.polygon([(x1 - 2, y0 + 20), (x1 + 10, y0 + 40), (x1 - 8, y0 + 36)], fill=c)
    return out


def mutate(base: Image.Image, set_id: str, kind: str) -> Image.Image:
    if set_id.endswith("_t0"):
        return base.copy()
    idx = seed_int(set_id)
    style = idx % 12
    # Shape first
    sx = 0.82 + (idx % 5) * 0.08
    sy = 0.85 + ((idx >> 3) % 5) * 0.09
    if kind in SHARED_BASES:
        sx = 0.75 + (idx % 7) * 0.07
        sy = 0.80 + ((idx >> 2) % 7) * 0.07
    im = scale_about_center(base, sx, sy)
    shear = ((idx % 9) - 4) * 0.08
    if abs(shear) > 0.02:
        im = shear_x(im, shear)
    im = recolor_strong(im, set_id)
    if kind in SHARED_BASES:
        im = add_blade_extra(im, set_id, style)
    else:
        im = add_armor_trim(im, set_id, style)
    # Contrast punch so variants read at phone size
    im = ImageEnhance.Contrast(im).enhance(1.18)
    im = ImageEnhance.Color(im).enhance(1.25)
    return im


def save_set(folder: Path, authored: Path, set_id: str, idle: Image.Image) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    authored.mkdir(parents=True, exist_ok=True)
    frames = {
        "idle": idle,
        "walk": slight_offset(idle, 0, 1),
        "attack": slight_offset(idle, 1, -1),
    }
    for anim, frame in frames.items():
        name = f"{set_id}_{anim}.png"
        frame.save(folder / name)
        frame.save(authored / name)


def base_path_shared(base: str) -> Path:
    auth = ROOT / "gear" / "_authored" / f"{base}_t0_idle.png"
    live = ROOT / "gear" / f"{base}_t0_idle.png"
    return auth if auth.exists() else live


def base_path_family(family: str, base: str) -> Path:
    for tier in ("t0", "t2"):
        auth = ROOT / family / "gear" / "_authored" / f"{base}_{tier}_idle.png"
        live = ROOT / family / "gear" / f"{base}_{tier}_idle.png"
        if auth.exists():
            return auth
        if live.exists():
            return live
    return ROOT / family / "gear" / f"{base}_t0_idle.png"


def generate_shared() -> int:
    n = 0
    gear = ROOT / "gear"
    auth = gear / "_authored"
    for base in SHARED_BASES:
        src = base_path_shared(base)
        if not src.exists():
            print("skip missing", src)
            continue
        base_idle = load_rgba(src)
        for set_id in VARIANTS[base]:
            if set_id in PRESERVE_AUTHORED:
                existing = auth / f"{set_id}_idle.png"
                if existing.exists():
                    for anim in ANIMS:
                        s = auth / f"{set_id}_{anim}.png"
                        if s.exists():
                            (gear / f"{set_id}_{anim}.png").write_bytes(s.read_bytes())
                    n += 1
                    continue
            idle = mutate(base_idle, set_id, base)
            save_set(gear, auth, set_id, idle)
            n += 1
        print("shared", base, "ok")
    return n


def generate_family() -> int:
    n = 0
    for family in FAMILIES:
        gear = ROOT / family / "gear"
        auth = gear / "_authored"
        for base in FAMILY_BASES:
            src = base_path_family(family, base)
            if src.exists():
                base_idle = load_rgba(src)
            else:
                base_idle = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            for set_id in VARIANTS[base]:
                idle = mutate(base_idle, set_id, base)
                save_set(gear, auth, set_id, idle)
                n += 1
        print("family", family, "ok")
    return n


def main() -> None:
    a = generate_shared()
    b = generate_family()
    print(f"done: {a} shared + {b} family sets (distinct silhouettes)")


if __name__ == "__main__":
    main()
