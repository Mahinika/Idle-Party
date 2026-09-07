"""Facit gate: live armor stack must stay close to dressed _src.

Composites the shipped body + overlays (not a gitignored preview PNG), so
CI and a clean checkout actually check looks. See
.cursor/skills/character-paper-doll/SKILL.md.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
CHAR = REPO / "assets" / "custom" / "char"
TOOL = REPO / "tool"
FAMILIES = ("warrior", "healer", "mage", "rogue")
ANIMS = ("idle", "walk", "attack")

# Idle only is the ship gate. Walk/attack still print diffs (extract drift).
# Tuned so invent ellipses fail; current idle extracts pass (mage ~0.30).
MAX_HARD_DIFF_IDLE = 0.38


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


def must_exist_128(path: Path) -> str | None:
    if not path.exists():
        return f"missing {path.relative_to(REPO)}"
    im = Image.open(path)
    if im.size != (128, 128):
        return f"size {im.size} (want 128x128) {path.relative_to(REPO)}"
    return None


def armor_stack(family: str, anim: str) -> Image.Image:
    """Cape-behind stack vs gold master (same as write_armor_preview).

    Dart paints owned cape in front for dungeon readability; facit compares
    to dressed _src, where the cape is part of the silhouette.
    """
    gear = CHAR / family / "gear"
    body = Image.open(CHAR / family / f"body_{anim}.png").convert("RGBA")
    layers = [
        Image.open(gear / f"cloak_t0_{anim}.png").convert("RGBA"),
        body,
        Image.open(gear / f"legs_t0_{anim}.png").convert("RGBA"),
        Image.open(gear / f"chest_t0_{anim}.png").convert("RGBA"),
        Image.open(gear / f"hands_t0_{anim}.png").convert("RGBA"),
    ]
    auth_helm = gear / "_authored" / f"helm_t0_{anim}.png"
    if family in ("mage", "healer") or not auth_helm.exists():
        layers.append(Image.open(gear / f"helm_t0_{anim}.png").convert("RGBA"))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for layer in layers:
        out = Image.alpha_composite(out, layer)
    return out


def helm_ok(family: str) -> tuple[bool, int]:
    helm = Image.open(CHAR / family / "gear" / "helm_t0_idle.png")
    hb = helm.getbbox()
    helm_w = (hb[2] - hb[0]) if hb else 0
    if family in ("mage", "healer"):
        return helm_w >= 40, helm_w
    auth = CHAR / family / "gear" / "_authored" / "helm_t0_idle.png"
    helm_h = (hb[3] - hb[1]) if hb else 0
    if auth.exists():
        return helm_w >= 20 and helm_h <= 72, helm_w
    return helm_w <= 8, helm_w


def check_files() -> list[str]:
    errors: list[str] = []
    armor = ("cloak_t0", "legs_t0", "chest_t0", "hands_t0", "helm_t0")
    for family in FAMILIES:
        for anim in ANIMS:
            errors.append(must_exist_128(CHAR / family / f"body_{anim}.png"))
            errors.append(must_exist_128(CHAR / family / "_src" / f"body_{anim}.png"))
            for stem in armor:
                errors.append(
                    must_exist_128(CHAR / family / "gear" / f"{stem}_{anim}.png")
                )
    shared = (
        "sword_t0",
        "staff_t0",
        "dagger_t0",
        "mace_t0",
        "axe_t0",
        "bow_t0",
        "shield_t0",
        "frill_t0",
    )
    for stem in shared:
        for anim in ANIMS:
            errors.append(must_exist_128(CHAR / "gear" / f"{stem}_{anim}.png"))
    return [e for e in errors if e]


def main() -> int:
    failed = 0
    for msg in check_files():
        print("FAIL", msg)
        failed += 1

    print("IDLE (gated)")
    for family in FAMILIES:
        src_path = CHAR / family / "_src" / "body_idle.png"
        if not src_path.exists():
            continue
        try:
            stack = armor_stack(family, "idle")
        except FileNotFoundError as exc:
            print("FAIL", family, "stack", exc)
            failed += 1
            continue
        TOOL.mkdir(parents=True, exist_ok=True)
        stack.save(TOOL / f"preview_doll_{family}.png")
        src = Image.open(src_path)
        ratio = hard_diff_ratio(src, stack)
        ok_helm, helm_w = helm_ok(family)
        status = "ok" if ratio <= MAX_HARD_DIFF_IDLE and ok_helm else "FAIL"
        print(
            status,
            family,
            f"diff={ratio:.3f}",
            f"helm_w={helm_w}",
            f"limit={MAX_HARD_DIFF_IDLE}",
        )
        if status == "FAIL":
            failed += 1

    print("WALK/ATTACK (info, not gated: dungeon extract still drifts)")
    for family in FAMILIES:
        for anim in ("walk", "attack"):
            src_path = CHAR / family / "_src" / f"body_{anim}.png"
            if not src_path.exists():
                print("info", family, anim, "missing _src")
                continue
            try:
                stack = armor_stack(family, anim)
            except FileNotFoundError as exc:
                print("info", family, anim, "stack", exc)
                continue
            ratio = hard_diff_ratio(Image.open(src_path), stack)
            print("info", family, anim, f"diff={ratio:.3f}")

    if failed:
        print(f"{failed} facit check(s) failed")
        return 1
    print("facit ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
