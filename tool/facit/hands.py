"""Grips land on pixels, and the anchor audit's findings fail the build."""
from __future__ import annotations

import math

from PIL import Image

from audit_anchors import glove_palm, shipped_fists, shipped_grips
from facit.checks_v1 import check_hand_items
from facit.findings import Finding
from paper_doll_paths import CHAR

__all__ = ["check_hand_items", "check_hand_anchor", "check_proportions"]


def check_hand_anchor() -> list[Finding]:
    """Idle/walk/attack fists and grips. Overhang past the hero box is not a bug."""
    out: list[Finding] = []
    fists = shipped_fists()
    for fam in ("warrior", "rogue", "mage", "healer"):
        table = fists[fam]
        for anim, main_key, off_key in (
            ("idle", "idleMain", "idleOff"),
            ("walk", "walkMain", "walkOff"),
            ("attack", "attackMain", "attackOff"),
        ):
            for side, key, hand in (
                ("main", main_key, "R"),
                ("off", off_key, "L"),
            ):
                measured = glove_palm(fam, hand)
                where = f"{fam}/{anim}/{side}"
                if measured is None:
                    out.append(Finding("hand_anchor", where, "no-fist"))
                    continue
                ax, ay = table[key]
                if math.hypot(measured[0] - ax, measured[1] - ay) > 0.02:
                    out.append(Finding("hand_anchor", where, "fist-drift"))
    gear = CHAR / "gear"
    grips = shipped_grips()
    for path in sorted(gear.glob("*_idle.png")):
        stem = path.name.removesuffix("_idle.png")
        if stem not in grips:
            out.append(Finding("hand_anchor", f"gear/{stem}", "no-grip"))
            continue
        im = Image.open(path).convert("RGBA")
        px = im.load()
        gx, gy = int(grips[stem][0] * 128), int(grips[stem][1] * 128)
        on_art = any(
            px[min(127, max(0, gx + dx)), min(127, max(0, gy + dy))][3] >= 40
            for dx in range(-4, 5)
            for dy in range(-4, 5)
        )
        if not on_art:
            out.append(Finding("hand_anchor", f"gear/{stem}", "grip-empty"))
    return out


def proportion_key(base: str, width: int, height: int) -> str | None:
    from gear_style import PROPORTIONS, WIDTH_TYPES

    if base not in PROPORTIONS:
        return None
    measure = width if base in WIDTH_TYPES else max(width, height)
    lo, hi = PROPORTIONS[base]
    if measure < lo:
        return "too-short"
    if measure > hi:
        return "too-long"
    return None


def check_proportions() -> list[Finding]:
    out: list[Finding] = []
    gear = CHAR / "gear"
    for path in sorted(gear.glob("*_idle.png")):
        stem = path.name.removesuffix("_idle.png")
        base = stem.split("_", 1)[0]
        bb = Image.open(path).getbbox()
        if bb is None:
            out.append(Finding("proportion", f"gear/{stem}", "empty"))
            continue
        key = proportion_key(base, bb[2] - bb[0], bb[3] - bb[1])
        if key:
            out.append(Finding("proportion", f"gear/{stem}", key))
    return out
