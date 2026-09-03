"""Generate owned 128×128 item model variant overlays from base t0 art.

Writes named variants for:
- shared weapons/shields under assets/custom/char/gear/
- family armor under assets/custom/char/<family>/gear/

Also mirrors into each folder's _authored/ for rebuild safety.
Idempotent: overwrites known variant stems only.
"""
from __future__ import annotations

import colorsys
import hashlib
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
ANIMS = ("idle", "walk", "attack")
FAMILIES = ("warrior", "healer", "mage", "rogue")

# Must stay in sync with lib/visual/equipment_model_catalog.dart
VARIANTS: dict[str, list[str]] = {
    "sword": [
        "sword_t0",
        "sword_thunderfury",
        "sword_warglaive",
        "sword_emberfang",
        "sword_crystalblade",
        "sword_boneedge",
        "sword_runebane",
        "sword_ashcleaver",
        "sword_frostbite",
        "sword_nightreaver",
        "sword_sunflare",
        "sword_voidspike",
    ],
    "staff": [
        "staff_t0",
        "staff_frostfire",
        "staff_oakroot",
        "staff_arcspire",
        "staff_shadowcrook",
        "staff_emberwand",
        "staff_tidebranch",
        "staff_crystalrod",
        "staff_bonespine",
        "staff_sunshaft",
        "staff_voidpillar",
        "staff_stormreed",
    ],
    "dagger": [
        "dagger_t0",
        "dagger_shadowfang",
        "dagger_venomtip",
        "dagger_quicksteel",
        "dagger_bonepin",
        "dagger_emberknife",
        "dagger_frostneedle",
        "dagger_crystalspike",
        "dagger_nightshiv",
        "dagger_sunblade",
        "dagger_voidrazor",
        "dagger_tideedge",
    ],
    "mace": [
        "mace_t0",
        "mace_ironmaul",
        "mace_skullcrush",
        "mace_emberhammer",
        "mace_frostgavel",
        "mace_crystalhead",
        "mace_boneclub",
        "mace_sunmace",
        "mace_voidmallet",
        "mace_tidecrusher",
        "mace_runebreaker",
        "mace_stormflail",
    ],
    "axe": [
        "axe_t0",
        "axe_warcleave",
        "axe_bloodbite",
        "axe_emberhatchet",
        "axe_frostchop",
        "axe_crystaledge",
        "axe_bonesaw",
        "axe_sunaxe",
        "axe_voidhook",
        "axe_tidebite",
        "axe_runesplitter",
        "axe_stormcleaver",
    ],
    "bow": [
        "bow_t0",
        "bow_longshot",
        "bow_shadowstring",
        "bow_emberarc",
        "bow_frostlimb",
        "bow_crystalbow",
        "bow_bonebow",
        "bow_sunarc",
        "bow_voidstring",
        "bow_tidebow",
        "bow_runebow",
        "bow_stormshaft",
    ],
    "shield": [
        "shield_t0",
        "shield_stormwall",
        "shield_ironbulwark",
        "shield_emberguard",
        "shield_frostplate",
        "shield_crystalward",
        "shield_boneguard",
        "shield_sunshield",
        "shield_voidaegis",
        "shield_tidewall",
        "shield_runeguard",
        "shield_towerkite",
    ],
    "frill": [
        "frill_t0",
        "frill_tome",
        "frill_orb",
        "frill_idol",
        "frill_embercharm",
        "frill_frostsigil",
        "frill_crystalbauble",
        "frill_bonerelic",
        "frill_suncharm",
        "frill_voidtotem",
        "frill_tidecharm",
        "frill_runestone",
    ],
    "helm": [
        "helm_t0",
        "helm_spiked",
        "helm_visor",
        "helm_horns",
        "helm_cowl",
        "helm_crown",
        "helm_mask",
        "helm_plume",
        "helm_winged",
        "helm_banded",
        "helm_crest",
        "helm_hooded",
    ],
    "chest": [
        "chest_t0",
        "chest_plated",
        "chest_studded",
        "chest_robe",
        "chest_scale",
        "chest_chain",
        "chest_vest",
        "chest_tabard",
        "chest_lamellar",
        "chest_cuirass",
        "chest_mantle",
        "chest_brigandine",
    ],
    "legs": [
        "legs_t0",
        "legs_plated",
        "legs_padded",
        "legs_skirt",
        "legs_scale",
        "legs_chain",
        "legs_wraps",
        "legs_greaves",
        "legs_tassets",
        "legs_hose",
        "legs_kilt",
        "legs_cuisses",
    ],
    "cloak": [
        "cloak_t0",
        "cloak_cape",
        "cloak_mantle",
        "cloak_shawl",
        "cloak_winged",
        "cloak_ragged",
        "cloak_fur",
        "cloak_silk",
        "cloak_tabard",
        "cloak_hooded",
        "cloak_banner",
        "cloak_veil",
    ],
    "hands": [
        "hands_t0",
        "hands_gauntlets",
        "hands_gloves",
        "hands_wraps",
        "hands_bracers",
        "hands_claws",
        "hands_mitts",
        "hands_studded",
        "hands_scale",
        "hands_chain",
        "hands_silk",
        "hands_bone",
    ],
}

SHARED_BASES = ("sword", "staff", "dagger", "mace", "axe", "bow", "shield", "frill")
FAMILY_BASES = ("helm", "chest", "legs", "cloak", "hands")

# Hue shifts / style tags keyed by name fragment for distinctive looks.
STYLE_HUES: dict[str, float] = {
    "thunder": 0.55,
    "warglaive": 0.33,
    "ember": 0.05,
    "crystal": 0.58,
    "bone": 0.12,
    "rune": 0.72,
    "ash": 0.08,
    "frost": 0.55,
    "night": 0.70,
    "sun": 0.12,
    "void": 0.78,
    "shadow": 0.72,
    "venom": 0.35,
    "quick": 0.0,
    "iron": 0.0,
    "skull": 0.02,
    "war": 0.02,
    "blood": 0.98,
    "long": 0.08,
    "storm": 0.58,
    "tide": 0.52,
    "oak": 0.10,
    "arc": 0.62,
    "tome": 0.65,
    "orb": 0.60,
    "idol": 0.15,
    "spike": 0.0,
    "visor": 0.0,
    "horn": 0.05,
    "cowl": 0.08,
    "crown": 0.12,
    "mask": 0.70,
    "plume": 0.95,
    "wing": 0.58,
    "band": 0.0,
    "crest": 0.10,
    "hood": 0.08,
    "plate": 0.0,
    "stud": 0.05,
    "robe": 0.65,
    "scale": 0.35,
    "chain": 0.0,
    "vest": 0.08,
    "tabard": 0.95,
    "lamellar": 0.10,
    "cuirass": 0.0,
    "mantle": 0.12,
    "brigand": 0.05,
    "pad": 0.08,
    "skirt": 0.65,
    "wrap": 0.10,
    "greave": 0.0,
    "tasset": 0.05,
    "hose": 0.55,
    "kilt": 0.12,
    "cuisse": 0.0,
    "cape": 0.0,
    "shawl": 0.55,
    "ragged": 0.08,
    "fur": 0.10,
    "silk": 0.65,
    "banner": 0.95,
    "veil": 0.70,
    "gaunt": 0.0,
    "glove": 0.08,
    "bracer": 0.05,
    "claw": 0.35,
    "mitt": 0.10,
}


def load_rgba(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.Resampling.NEAREST)
    return im


def slight_offset(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def style_key(set_id: str) -> str:
    # sword_emberfang -> emberfang fragments
    parts = set_id.split("_")[1:]
    name = "_".join(parts)
    for key in STYLE_HUES:
        if key in name:
            return key
    # Stable fallback from hash
    h = int(hashlib.md5(set_id.encode()).hexdigest()[:4], 16)
    return f"hash_{h % 12}"


def hue_for(set_id: str) -> float:
    key = style_key(set_id)
    if key in STYLE_HUES:
        return STYLE_HUES[key]
    # hash_* keys
    idx = int(key.split("_")[-1]) if "_" in key else 0
    return (idx * 0.083) % 1.0


def recolor(im: Image.Image, set_id: str, strength: float = 0.55) -> Image.Image:
    """Shift non-transparent pixels toward a style hue; keep alpha."""
    target = hue_for(set_id)
    out = im.copy()
    px = out.load()
    # Extra contrast / brightness keyed by name for more separation.
    bright = 1.0 + ((int(hashlib.md5(set_id.encode()).hexdigest()[4:6], 16) % 9) - 4) * 0.03
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            # Skip near-black outlines
            if v < 0.12:
                continue
            nh = (h * (1.0 - strength) + target * strength) % 1.0
            ns = min(1.0, s * 0.85 + 0.12)
            nv = min(1.0, v * bright)
            nr, ng, nb = colorsys.hsv_to_rgb(nh, ns, nv)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def add_accent_pixels(im: Image.Image, set_id: str) -> Image.Image:
    """Sprinkle a few accent pixels along the silhouette for uniqueness."""
    out = im.copy()
    px = out.load()
    seed = int(hashlib.md5(set_id.encode()).hexdigest()[:8], 16)
    accent_h = hue_for(set_id)
    ar, ag, ab = colorsys.hsv_to_rgb(accent_h, 0.85, 1.0)
    accent = (int(ar * 255), int(ag * 255), int(ab * 255), 255)
    # Collect opaque edge-ish pixels
    pts: list[tuple[int, int]] = []
    for y in range(1, 127):
        for x in range(1, 127):
            if px[x, y][3] < 40:
                continue
            if (
                px[x - 1, y][3] < 40
                or px[x + 1, y][3] < 40
                or px[x, y - 1][3] < 40
                or px[x, y + 1][3] < 40
            ):
                pts.append((x, y))
    if not pts:
        return out
    n = min(18, max(6, len(pts) // 40))
    for i in range(n):
        idx = (seed + i * 97) % len(pts)
        x, y = pts[idx]
        px[x, y] = accent
        if i % 3 == 0 and 0 <= x + 1 < 128 and px[x + 1, y][3] > 40:
            px[x + 1, y] = accent
    return out


def add_spikes(im: Image.Image, set_id: str) -> Image.Image:
    """For helm/shield-ish names containing spike/horn/wing — paint small spikes."""
    name = set_id.lower()
    if not any(k in name for k in ("spike", "horn", "wing", "crest", "plume")):
        return im
    out = im.copy()
    px = out.load()
    # Find top opaque band
    top_y = None
    xs: list[int] = []
    for y in range(128):
        row = [x for x in range(128) if px[x, y][3] > 40]
        if row:
            top_y = y
            xs = row
            break
    if top_y is None or not xs:
        return out
    cx = sum(xs) // len(xs)
    color = (210, 210, 220, 255)
    for dx, h in ((-10, 8), (0, 11), (10, 8)):
        x0 = cx + dx
        for i in range(h):
            y = top_y - 1 - i
            if y < 0:
                break
            for w in range(max(1, 3 - i // 3)):
                x = x0 + w - 1
                if 0 <= x < 128:
                    px[x, y] = color
    return out


def mutate(base: Image.Image, set_id: str) -> Image.Image:
    if set_id.endswith("_t0"):
        return base.copy()
    im = recolor(base, set_id)
    im = add_accent_pixels(im, set_id)
    im = add_spikes(im, set_id)
    # Slight sharpen / contrast for separation
    im = ImageEnhance.Contrast(im).enhance(1.08)
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


def base_path_shared(base: str, anim: str) -> Path:
    auth = ROOT / "gear" / "_authored" / f"{base}_t0_{anim}.png"
    live = ROOT / "gear" / f"{base}_t0_{anim}.png"
    if auth.exists():
        return auth
    return live


def base_path_family(family: str, base: str, anim: str) -> Path:
    # Prefer t0; fall back to t2 if only that exists (rare for hands).
    for tier in ("t0", "t2"):
        auth = ROOT / family / "gear" / "_authored" / f"{base}_{tier}_{anim}.png"
        live = ROOT / family / "gear" / f"{base}_{tier}_{anim}.png"
        if auth.exists():
            return auth
        if live.exists():
            return live
    return ROOT / family / "gear" / f"{base}_t0_{anim}.png"


def generate_shared() -> int:
    n = 0
    gear = ROOT / "gear"
    auth = gear / "_authored"
    for base in SHARED_BASES:
        idle_src = base_path_shared(base, "idle")
        if not idle_src.exists():
            print("skip shared missing base", idle_src)
            continue
        base_idle = load_rgba(idle_src)
        for set_id in VARIANTS[base]:
            # Keep hand-authored thunderfury/warglaive if already present and non-_t0.
            if set_id in ("sword_thunderfury", "sword_warglaive"):
                existing = auth / f"{set_id}_idle.png"
                if existing.exists():
                    for anim in ANIMS:
                        src = auth / f"{set_id}_{anim}.png"
                        if src.exists():
                            dst = gear / f"{set_id}_{anim}.png"
                            dst.write_bytes(src.read_bytes())
                    n += 1
                    continue
            idle = mutate(base_idle, set_id)
            save_set(gear, auth, set_id, idle)
            n += 1
            print("shared", set_id)
    return n


def generate_family() -> int:
    n = 0
    for family in FAMILIES:
        gear = ROOT / family / "gear"
        auth = gear / "_authored"
        for base in FAMILY_BASES:
            idle_src = base_path_family(family, base, "idle")
            if not idle_src.exists():
                # Transparent placeholder so path exists (warrior helm can be empty).
                base_idle = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
                print("warn empty base", family, base)
            else:
                base_idle = load_rgba(idle_src)
            for set_id in VARIANTS[base]:
                idle = mutate(base_idle, set_id)
                # If base is fully transparent, still write empty variants.
                save_set(gear, auth, set_id, idle)
                n += 1
            print("family", family, base, "x", len(VARIANTS[base]))
    return n


def main() -> None:
    a = generate_shared()
    b = generate_family()
    print(f"done: {a} shared sets, {b} family sets")


if __name__ == "__main__":
    main()
