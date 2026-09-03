"""Deprecated mass variant generator.

Paper-doll rule: armor comes from `_src` extract (t0/t2). Weapons are
`*_t0` plus a few authored models (thunderfury / warglaive). Do not
ImageDraw-mutate 12 fake models.

This script only re-syncs authored preserve list into live `gear/` and
rebuilds slot icons.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
TOOL = Path(__file__).resolve().parent
PRESERVE_AUTHORED = {"sword_thunderfury", "sword_warglaive"}
ANIMS = ("idle", "walk", "attack")


def sync_authored() -> int:
    gear = ROOT / "gear"
    auth = gear / "_authored"
    n = 0
    for set_id in PRESERVE_AUTHORED:
        for anim in ANIMS:
            src = auth / f"{set_id}_{anim}.png"
            if src.exists():
                (gear / src.name).write_bytes(src.read_bytes())
                n += 1
    return n


def main() -> None:
    n = sync_authored()
    print(f"synced {n} authored frames")
    subprocess.check_call([sys.executable, str(TOOL / "make_gear_slot_icons.py")])


if __name__ == "__main__":
    main()
