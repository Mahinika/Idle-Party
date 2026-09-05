#!/usr/bin/env python3
"""Undo bake_owned_hand_grips shifts using the recorded shift table, then stop."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEAR = ROOT / "assets" / "custom" / "char" / "gear"
AUTH = GEAR / "_authored"

# From bake log (live gear). Apply opposite to restore pre-bake placement.
SHIFTS: dict[str, tuple[float, float]] = {
    "axe_bloodhowl_attack": (2.3, 1.4),
    "axe_bloodhowl_idle": (3.3, 8.4),
    "axe_bloodhowl_walk": (3.3, 5.4),
    "axe_goreblade_attack": (2.3, 1.4),
    "axe_goreblade_idle": (9.3, 0.4),
    "axe_goreblade_walk": (7.3, 0.4),
    "bow_eagle_attack": (21.3, 19.4),
    "bow_eagle_idle": (-0.7, 32.4),
    "bow_eagle_walk": (-5.7, 29.4),
    "bow_windpierce_attack": (8.3, 21.4),
    "bow_windpierce_idle": (21.3, 17.4),
    "bow_windpierce_walk": (18.3, 17.4),
    "dagger_nightbite_idle": (6.3, 2.4),
    "dagger_nightbite_walk": (3.3, 2.4),
    "dagger_shadowfang_idle": (7.3, 0.4),
    "dagger_shadowfang_walk": (5.3, 0.4),
    "frill_prism_attack": (-24.3, 2.4),
    "frill_prism_idle": (-20.3, 0.4),
    "frill_prism_walk": (-21.3, 0.4),
    "frill_soulcodex_attack": (-21.3, 0.4),
    "frill_soulcodex_idle": (-18.3, 0.4),
    "frill_soulcodex_walk": (-19.3, 0.4),
    "mace_dawnbreak_attack": (2.3, 1.4),
    "mace_dawnbreak_idle": (9.3, 0.4),
    "mace_dawnbreak_walk": (7.3, 0.4),
    "mace_lightbringer_attack": (2.3, 1.4),
    "mace_lightbringer_idle": (9.3, 0.4),
    "mace_lightbringer_walk": (7.3, 0.4),
    "shield_aegis_attack": (-32.3, 1.4),
    "shield_aegis_idle": (-17.3, 9.4),
    "shield_aegis_walk": (-20.3, 10.4),
    "shield_ironwall_attack": (-21.3, 0.4),
    "shield_ironwall_idle": (-18.3, 0.4),
    "shield_ironwall_walk": (-19.3, 0.4),
    "staff_frostfire_attack": (4.3, 1.4),
    "staff_frostfire_idle": (10.3, 4.4),
    "staff_frostfire_walk": (8.3, 3.4),
    "staff_nethercore_attack": (4.3, 4.4),
    "staff_nethercore_idle": (12.3, 2.4),
    "staff_nethercore_walk": (10.3, 1.4),
    "sword_runebound_attack": (1.3, 1.4),
    "sword_runebound_idle": (6.3, 3.4),
    "sword_runebound_walk": (4.3, 1.4),
}


def undo(path: Path, dx: float, dy: float) -> None:
    im = Image.open(path).convert("RGBA")
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (int(round(-dx)), int(round(-dy))), im)
    out.save(path)


def main() -> None:
    n = 0
    for folder in (GEAR, AUTH):
        for stem, (dx, dy) in SHIFTS.items():
            path = folder / f"{stem}.png"
            if not path.exists():
                continue
            undo(path, dx, dy)
            n += 1
            print(f"undo {path.relative_to(ROOT)} ({-dx:+.1f},{-dy:+.1f})")
    print(f"done undid={n}")


if __name__ == "__main__":
    main()
