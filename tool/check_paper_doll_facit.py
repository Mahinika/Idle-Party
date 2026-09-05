"""Facit gate: armor stack preview must stay close to dressed _src.

Fails the build if we drift into invent-art territory (grey blob heads, etc.).
See .cursor/skills/character-paper-doll/SKILL.md.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
TOOL = Path(r"d:\Projects\Personal\idle party\Idle-Party\tool")
FAMILIES = ("warrior", "healer", "mage", "rogue")

# Max fraction of opaque _src pixels that differ hard from the armor preview.
# Tuned so invent ellipses fail; extract stacks pass.
MAX_HARD_DIFF = 0.45


def hard_diff_ratio(src: Image.Image, prev: Image.Image) -> float:
    a = src.convert("RGBA").load()
    b = prev.convert("RGBA").load()
    opaque = 0
    hard = 0
    for y in range(128):
        for x in range(128):
            r, g, b_, aa = a[x, y]
            if aa < 40:
                continue
            opaque += 1
            rr, gg, bb, ab = b[x, y]
            if ab < 20:
                hard += 1
                continue
            if abs(r - rr) + abs(g - gg) + abs(b_ - bb) > 90:
                hard += 1
    return hard / max(1, opaque)


def main() -> int:
    failed = 0
    for family in FAMILIES:
        src_path = ROOT / family / "_src" / "body_idle.png"
        prev_path = TOOL / f"preview_doll_{family}.png"
        if not src_path.exists():
            print("FAIL", family, "missing", src_path)
            failed += 1
            continue
        if not prev_path.exists():
            print("FAIL", family, "missing preview — run build_owned_gear_layers.py")
            failed += 1
            continue
        src = Image.open(src_path)
        prev = Image.open(prev_path)
        ratio = hard_diff_ratio(src, prev)
        helm = Image.open(ROOT / family / "gear" / "helm_t0_idle.png")
        hb = helm.getbbox()
        helm_w = (hb[2] - hb[0]) if hb else 0
        # Invented grey mushroom was ~80–100px wide; hair stamp stays tighter.
        ok_helm = True
        if family in ("mage", "healer"):
            ok_helm = helm_w >= 40  # hat/hood must extract
        else:
            # Warrior/rogue: empty until authored (no invent stamp).
            # Authored must be head-sized, not a full-canvas icon (~108px tall).
            auth = ROOT / family / "gear" / "_authored" / "helm_t0_idle.png"
            helm_h = (hb[3] - hb[1]) if hb else 0
            if auth.exists():
                ok_helm = helm_w >= 20 and helm_h <= 72
            else:
                ok_helm = helm_w <= 8
        status = "ok" if ratio <= MAX_HARD_DIFF and ok_helm else "FAIL"
        print(
            status,
            family,
            f"diff={ratio:.3f}",
            f"helm_w={helm_w}",
            f"limit={MAX_HARD_DIFF}",
        )
        if status == "FAIL":
            failed += 1
    if failed:
        print(f"{failed} family facit check(s) failed")
        return 1
    print("facit ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
