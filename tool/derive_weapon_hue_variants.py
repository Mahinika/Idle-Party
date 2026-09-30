"""Derive named weapon looks by recoloring existing authored idle masters.

Paper-doll rule: recolor existing alpha — do not invent geometry.
Writes idle overlays + BAG icons under gear/ and gear/_authored/.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char" / "gear"
AUTH = ROOT / "_authored"

# (new_id, source_id, hue_fn_name)
# Flat ImageDraw stubs use the same recipe: keep the painted t0 alpha,
# shift hue. Do not invent a second silhouette.
VARIANTS: list[tuple[str, str, str]] = [
    ("sword_emberfang", "sword_t0", "ember"),
    ("staff_voidspire", "staff_t0", "void"),
    ("bow_ashflight", "bow_t0", "ash"),
    ("axe_stormcleave", "axe_t0", "storm"),
    ("mace_soulhammer", "mace_t0", "soul"),
    ("dagger_venomkiss", "dagger_t0", "venom"),
    ("shield_frostwall", "shield_t0", "frost"),
    ("frill_embercodex", "frill_t0", "ember"),
    ("sword_thunderfury", "sword_t0", "storm"),
    ("sword_warglaive", "sword_t0", "fel"),
    ("sword_runebound", "sword_t0", "rune"),
    ("axe_bloodhowl", "axe_t0", "blood"),
    ("axe_goreblade", "axe_t0", "gore"),
    ("mace_dawnbreak", "mace_t0", "dawn"),
    ("dagger_shadowfang", "dagger_t0", "shadow"),
    ("dagger_nightbite", "dagger_t0", "night"),
    ("staff_frostfire", "staff_t0", "frost"),
    ("staff_nethercore", "staff_t0", "nether"),
    ("bow_eagle", "bow_t0", "eagle"),
    ("bow_windpierce", "bow_t0", "wind"),
    ("shield_ironwall", "shield_t0", "iron"),
]

# Already painted in the plate language. A hue pass would flatten them.
SKIP_WRITE = {"mace_lightbringer", "shield_aegis"}


def recolor(im: Image.Image, mode: str) -> Image.Image:
    out = im.copy().convert("RGBA")
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
            if mode == "ember":
                nr = int(50 + lum * 205)
                ng = int(28 + lum * 110)
                nb = int(18 + lum * 55)
            elif mode == "void":
                nr = int(48 + lum * 120)
                ng = int(28 + lum * 70)
                nb = int(70 + lum * 185)
            elif mode == "nether":
                # Dark charcoal with a crimson core — darker and warmer than void.
                nr = int(22 + lum * 95)
                ng = int(10 + lum * 36)
                nb = int(14 + lum * 48)
                if lum > 0.55:
                    nr = min(255, nr + 85)
                    ng = min(255, ng + 22)
            elif mode == "ash":
                nr = int(42 + lum * 150)
                ng = int(40 + lum * 130)
                nb = int(36 + lum * 100)
                if lum > 0.55:
                    nr = min(255, nr + 40)
                    ng = min(255, ng + 18)
            elif mode == "storm":
                nr = int(30 + lum * 90)
                ng = int(48 + lum * 150)
                nb = int(70 + lum * 185)
            elif mode == "soul":
                nr = int(36 + lum * 100)
                ng = int(70 + lum * 170)
                nb = int(80 + lum * 175)
                if lum > 0.6:
                    nr = min(255, nr + 50)
                    ng = min(255, ng + 40)
            elif mode == "venom":
                nr = int(28 + lum * 80)
                ng = int(70 + lum * 185)
                nb = int(36 + lum * 90)
            elif mode == "frost":
                nr = int(40 + lum * 120)
                ng = int(70 + lum * 165)
                nb = int(95 + lum * 160)
            elif mode == "fel":
                nr = int(36 + lum * 120)
                ng = int(88 + lum * 160)
                nb = int(28 + lum * 55)
            elif mode == "rune":
                nr = int(64 + lum * 130)
                ng = int(28 + lum * 55)
                nb = int(100 + lum * 140)
            elif mode == "blood":
                nr = int(48 + lum * 190)
                ng = int(12 + lum * 36)
                nb = int(16 + lum * 32)
            elif mode == "gore":
                nr = int(96 + lum * 150)
                ng = int(22 + lum * 48)
                nb = int(18 + lum * 28)
            elif mode == "dawn":
                nr = int(88 + lum * 160)
                ng = int(58 + lum * 140)
                nb = int(16 + lum * 42)
            elif mode == "shadow":
                nr = int(24 + lum * 60)
                ng = int(16 + lum * 36)
                nb = int(42 + lum * 80)
            elif mode == "night":
                nr = int(18 + lum * 50)
                ng = int(72 + lum * 140)
                nb = int(88 + lum * 130)
            elif mode == "eagle":
                nr = int(28 + lum * 70)
                ng = int(58 + lum * 130)
                nb = int(96 + lum * 145)
            elif mode == "wind":
                nr = int(48 + lum * 130)
                ng = int(86 + lum * 145)
                nb = int(108 + lum * 140)
            elif mode == "iron":
                nr = int(36 + lum * 145)
                ng = int(40 + lum * 150)
                nb = int(48 + lum * 155)
            else:
                nr, ng, nb = r, g, b
            px[x, y] = (
                max(0, min(255, nr)),
                max(0, min(255, ng)),
                max(0, min(255, nb)),
                a,
            )
    return out


# ImageDraw stubs. Everything else in VARIANTS is already a painted recolor.
FLAT_IDS = {
    "sword_thunderfury",
    "sword_warglaive",
    "sword_runebound",
    "axe_bloodhowl",
    "axe_goreblade",
    "mace_dawnbreak",
    "dagger_shadowfang",
    "dagger_nightbite",
    "staff_frostfire",
    "staff_nethercore",
    "bow_eagle",
    "bow_windpierce",
    "shield_ironwall",
}


def write_one(new_id: str, src_id: str, mode: str) -> None:
    from make_gear_slot_icons import make_icon

    src = AUTH / f"{src_id}_idle.png"
    if not src.exists():
        src = ROOT / f"{src_id}_idle.png"
    if not src.exists():
        raise SystemExit(f"missing source {src_id} for {new_id}")
    idle = recolor(Image.open(src).convert("RGBA"), mode)
    AUTH.mkdir(parents=True, exist_ok=True)
    for anim in ("idle", "walk", "attack"):
        idle.save(AUTH / f"{new_id}_{anim}.png")
    idle.save(ROOT / f"{new_id}_idle.png")
    icon = make_icon(idle)
    if icon is None:
        raise SystemExit(f"empty icon for {new_id}")
    icon.save(ROOT / f"{new_id}_icon.png")
    print(f"wrote {new_id} from {src_id} ({mode})")


def main() -> None:
    from paper_doll_paths import refuse_live_writer

    # A hue shift is not a new weapon. Recipes live in author_gear_standard.
    refuse_live_writer("derive_weapon_hue_variants.py")


if __name__ == "__main__":
    main()
