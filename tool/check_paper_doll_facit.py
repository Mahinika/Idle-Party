"""Facit gate: live armor stack must stay close to dressed _src.

Composites the shipped body + overlays (not a gitignored preview PNG), so
CI and a clean checkout actually check looks. See
.cursor/skills/character-paper-doll/SKILL.md.

Also gates the parts the looks facit cannot judge:
- t2 / rogue-mail / healer-plate overlays exist, are 128x128, and differ from
  their t0 peer without losing the silhouette;
- every shared weapon / shield has pixels under its declared grip point;
- `tool/paper_doll_lock.json` pins a hash per shipped PNG, so a re-run of any
  generator that quietly reshapes art fails instead of shipping.

Run with `--relock` after a deliberate art change.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
CHAR = REPO / "assets" / "custom" / "char"
TOOL = REPO / "tool"
LOCK = TOOL / "paper_doll_lock.json"
GRIPS_DART = REPO / "lib" / "visual" / "owned_gear_grips.dart"
FAMILIES = ("warrior", "healer", "mage", "rogue")

# Idle facit gate vs dressed _src. Walk/attack dungeon uses idle overlays on
# poser body clips — not a separate armor extract per anim.
MAX_HARD_DIFF_IDLE = 0.38
BODY_ANIMS = ("idle", "walk", "attack")
OVERLAY_ANIM = "idle"


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


def armor_stack(family: str, body_anim: str = "idle") -> Image.Image:
    """Idle overlays on [body_anim] undertunic (facit idle uses body_idle)."""
    gear = CHAR / family / "gear"
    body = Image.open(CHAR / family / f"body_{body_anim}.png").convert("RGBA")
    layers = [
        Image.open(gear / f"cloak_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        body,
        Image.open(gear / f"legs_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        Image.open(gear / f"chest_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        Image.open(gear / f"hands_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
    ]
    auth_helm = gear / "_authored" / f"helm_t0_{OVERLAY_ANIM}.png"
    if family in ("mage", "healer") or not auth_helm.exists():
        layers.append(Image.open(gear / f"helm_t0_{OVERLAY_ANIM}.png").convert("RGBA"))
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
        for anim in BODY_ANIMS:
            errors.append(must_exist_128(CHAR / family / f"body_{anim}.png"))
            errors.append(must_exist_128(CHAR / family / "_src" / f"body_{anim}.png"))
        for stem in armor:
            errors.append(
                must_exist_128(
                    CHAR / family / "gear" / f"{stem}_{OVERLAY_ANIM}.png"
                )
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
        errors.append(must_exist_128(CHAR / "gear" / f"{stem}_{OVERLAY_ANIM}.png"))
    return [e for e in errors if e]


MATERIAL_BY_FAMILY = {"rogue": "mail", "healer": "plate"}
ARMOR_STEMS = ("helm", "chest", "legs", "cloak", "hands")


def shipped_pngs() -> list[Path]:
    """Every PNG pubspec bundles (registered dirs are non-recursive)."""
    dirs = [CHAR / fam for fam in FAMILIES]
    dirs += [CHAR / fam / "gear" for fam in FAMILIES]
    dirs.append(CHAR / "gear")
    out: list[Path] = []
    for d in dirs:
        if not d.exists():
            continue
        out += [p for p in sorted(d.iterdir()) if p.is_file() and p.suffix == ".png"]
    return out


def alpha_ratio(im: Image.Image) -> float:
    px = im.convert("RGBA").load()
    opaque = 0
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] >= 40:
                opaque += 1
    return opaque / float(im.width * im.height)


def silhouette_diff(a: Image.Image, b: Image.Image) -> float:
    """Share of pixels where exactly one of the two images is opaque."""
    pa = a.convert("RGBA").load()
    pb = b.convert("RGBA").load()
    union = 0
    only = 0
    for y in range(128):
        for x in range(128):
            oa = pa[x, y][3] >= 40
            ob = pb[x, y][3] >= 40
            if not (oa or ob):
                continue
            union += 1
            if oa != ob:
                only += 1
    return only / max(1, union)


def check_tiers_and_materials() -> list[str]:
    """t2 and material variants must exist and read as their own armor."""
    errors: list[str] = []
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        variants = [""]
        material = MATERIAL_BY_FAMILY.get(family)
        if material:
            variants.append(f"_{material}")
        for var in variants:
            for stem in ARMOR_STEMS:
                t0 = gear / f"{stem}{var}_t0_idle.png"
                t2 = gear / f"{stem}{var}_t2_idle.png"
                for path in (t0, t2):
                    err = must_exist_128(path)
                    if err:
                        errors.append(err)
                if errors and (not t0.exists() or not t2.exists()):
                    continue
                im0 = Image.open(t0)
                im2 = Image.open(t2)
                if alpha_ratio(im2) < 0.002 and alpha_ratio(im0) >= 0.002:
                    errors.append(
                        f"empty t2 {t2.relative_to(REPO)} (t0 has pixels)"
                    )
                    continue
                if var and alpha_ratio(im0) < 0.002:
                    errors.append(f"empty material {t0.relative_to(REPO)}")
                    continue
                shift = silhouette_diff(im0, im2)
                if shift > 0.55:
                    errors.append(
                        f"t2 silhouette drifted {shift:.2f} "
                        f"{t2.relative_to(REPO)} (want <= 0.55)"
                    )
    return errors


def parse_grips() -> dict[str, tuple[float, float]]:
    text = GRIPS_DART.read_text(encoding="utf-8")
    out: dict[str, tuple[float, float]] = {}
    for m in re.finditer(
        r"'([a-z0-9_]+)':\s*Offset\(([0-9.]+),\s*([0-9.]+)\)", text
    ):
        out[m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return out


def check_hand_items() -> list[str]:
    """Each weapon/shield needs pixels where the code grabs it."""
    errors: list[str] = []
    grips = parse_grips()
    if not grips:
        return ["no grips parsed from owned_gear_grips.dart"]
    for set_id, (gx, gy) in sorted(grips.items()):
        path = CHAR / "gear" / f"{set_id}_idle.png"
        err = must_exist_128(path)
        if err:
            errors.append(err)
            continue
        im = Image.open(path).convert("RGBA")
        px = im.load()
        cx, cy = int(gx * 128), int(gy * 128)
        near = 0
        for y in range(max(0, cy - 6), min(128, cy + 7)):
            for x in range(max(0, cx - 6), min(128, cx + 7)):
                if px[x, y][3] >= 40:
                    near += 1
        if near == 0:
            errors.append(
                f"grip ({gx:.3f},{gy:.3f}) hits empty pixels in "
                f"{path.relative_to(REPO)}"
            )
    return errors


def check_lock(relock: bool) -> list[str]:
    """Pin art bytes so a stray generator run cannot ship silently."""
    current = {
        str(p.relative_to(REPO)).replace("\\", "/"): hashlib.sha256(
            p.read_bytes()
        ).hexdigest()
        for p in shipped_pngs()
    }
    if relock or not LOCK.exists():
        LOCK.write_text(
            json.dumps(current, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"{'relocked' if relock else 'wrote'} {LOCK.relative_to(REPO)} "
              f"({len(current)} files)")
        return []
    locked = json.loads(LOCK.read_text(encoding="utf-8"))
    errors: list[str] = []
    for name, digest in sorted(locked.items()):
        if name not in current:
            errors.append(f"art removed: {name}")
        elif current[name] != digest:
            errors.append(f"art changed without --relock: {name}")
    for name in sorted(set(current) - set(locked)):
        errors.append(f"art added without --relock: {name}")
    return errors


def main() -> int:
    relock = "--relock" in sys.argv
    failed = 0
    for msg in check_files():
        print("FAIL", msg)
        failed += 1
    for msg in check_tiers_and_materials():
        print("FAIL", msg)
        failed += 1
    for msg in check_hand_items():
        print("FAIL", msg)
        failed += 1
    for msg in check_lock(relock):
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

    if failed:
        print(f"{failed} facit check(s) failed")
        return 1
    print("facit ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
