"""Do NOT overwrite generated/hand _authored warrior gear.

Authored PNGs win via build_owned_gear_layers.maybe_authored.
To regenerate placeholders, delete specific files under gear/_authored/ first.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")


def main() -> None:
    w = list((ROOT / "warrior" / "gear" / "_authored").glob("*.png"))
    g = [
        p
        for p in (ROOT / "gear" / "_authored").glob("*.png")
        if p.name.startswith(("sword_t0", "shield_t0"))
    ]
    print("skip invent — authored files present:")
    for p in sorted(w + g):
        print(" ", p.relative_to(ROOT))
    if not w and not g:
        print("no authored warrior gear yet — run tool/process_warrior_gen_art.py")


if __name__ == "__main__":
    main()
