#!/usr/bin/env python3
"""Audit owned/Kenney anchors + weapon grips vs body art."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CHAR = ROOT / "assets" / "custom" / "char"
GEAR = CHAR / "gear"
OUT = ROOT / "tool"

OWNED_IDLE = {
    "head": (0.0, -0.30),
    "body": (0.0, 0.0),
    "back": (0.0, -0.08),
    "feet": (0.0, 0.40),
    "mainHand": (0.28, 0.14),
    "offHand": (-0.28, 0.14),
}

OWNED_ATTACK = {
    "mainHand": (0.25, 0.20),
    "offHand": (-0.24, 0.21),
}


def to_uv(nx: float, ny: float) -> tuple[float, float]:
    return (0.5 + nx, 0.5 + ny)


def grip_uv(im: Image.Image, *, off_hand: bool) -> tuple[float, float] | None:
    bbox = im.getbbox()
    if bbox is None:
        return None
    left, top, right, bottom = bbox
    cx = (left + right) / 2 / 128.0
    if off_hand:
        return (cx, (top + bottom) / 2 / 128.0)
    return (cx, max(0.0, (bottom - 5) / 128.0))


def nearest_opaque(
    im: Image.Image, target_uv: tuple[float, float], alpha: int = 32
) -> tuple[tuple[float, float] | None, float | None]:
    px = im.load()
    w, h = im.size
    tx, ty = target_uv[0] * w, target_uv[1] * h
    best = None
    best_d = 1e18
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < alpha:
                continue
            d = (x + 0.5 - tx) ** 2 + (y + 0.5 - ty) ** 2
            if d < best_d:
                best_d = d
                best = (x, y)
    if best is None:
        return None, None
    return ((best[0] + 0.5) / w, (best[1] + 0.5) / h), math.sqrt(best_d)


def region_centroid(
    im: Image.Image,
    x0: int,
    x1: int,
    y0: int,
    y1: int,
    alpha: int = 180,
) -> tuple[float, float] | None:
    px = im.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y][3] >= alpha:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (sum(xs) / len(xs) / 128.0, sum(ys) / len(ys) / 128.0)


def main() -> None:
    print("=== BODY vs OWNED ANCHORS (idle) ===")
    print(
        f"{'family':8s} {'side':5s} {'bodyUV':14s} {'anchorUV':14s} "
        f"{'dx':7s} {'dy':7s} {'dist':6s}"
    )
    body_findings: list[str] = []
    for fam in ["warrior", "rogue", "mage", "healer"]:
        im = Image.open(CHAR / fam / "body_idle.png").convert("RGBA")
        for side, x0, x1, aname in [
            ("main", 85, 120, "mainHand"),
            ("off", 8, 45, "offHand"),
        ]:
            c = region_centroid(im, x0, x1, 70, 105)
            ax, ay = to_uv(*OWNED_IDLE[aname])
            if c is None:
                print(fam, side, "NO PIXELS")
                continue
            dx, dy = c[0] - ax, c[1] - ay
            dist = math.hypot(dx, dy)
            print(
                f"{fam:8s} {side:5s} ({c[0]:.3f},{c[1]:.3f})  "
                f"({ax:.3f},{ay:.3f})  {dx:+.3f}  {dy:+.3f}  {dist:.3f}"
            )
            if dist > 0.06:
                body_findings.append(
                    f"{fam} {side} hand mass vs anchor dist={dist:.3f}"
                )
        c = region_centroid(im, 40, 88, 8, 40, alpha=100)
        ax, ay = to_uv(*OWNED_IDLE["head"])
        if c:
            dist = math.hypot(c[0] - ax, c[1] - ay)
            print(
                f"{fam:8s} head  ({c[0]:.3f},{c[1]:.3f})  "
                f"({ax:.3f},{ay:.3f})  {c[0]-ax:+.3f}  {c[1]-ay:+.3f}  {dist:.3f}"
            )
            if dist > 0.10:
                body_findings.append(f"{fam} head mass vs anchor dist={dist:.3f}")

    print()
    print("=== WALK/ATTACK body drift vs matching owned anchors ===")
    anim_findings: list[str] = []
    for fam in ["warrior", "rogue", "mage", "healer"]:
        for anim in ["walk", "attack"]:
            path = CHAR / fam / f"body_{anim}.png"
            if not path.exists():
                continue
            im = Image.open(path).convert("RGBA")
            table = OWNED_ATTACK if anim == "attack" else OWNED_IDLE
            for side, x0, x1, aname in [
                ("main", 85, 120, "mainHand"),
                ("off", 8, 45, "offHand"),
            ]:
                c = region_centroid(im, x0, x1, 65, 110)
                ax, ay = to_uv(*table[aname])
                if not c:
                    continue
                dist = math.hypot(c[0] - ax, c[1] - ay)
                mark = " !" if dist > 0.08 else ""
                print(
                    f"{fam:8s} {anim:7s} {side:5s} "
                    f"body=({c[0]:.3f},{c[1]:.3f}) "
                    f"anc=({ax:.3f},{ay:.3f}) d={dist:.3f}{mark}"
                )
                if dist > 0.08:
                    anim_findings.append(
                        f"{fam}/{anim}/{side} drift={dist:.3f}"
                    )

    print()
    print("=== GRIP AUDIT (shift to land on owned idle hand) ===")
    grip_findings: list[tuple[str, float, float, str]] = []
    for path in sorted(GEAR.glob("*_idle.png")):
        stem = path.name.removesuffix("_idle.png")
        im = Image.open(path).convert("RGBA")
        off = stem.startswith(("shield_", "frill_"))
        want = OWNED_IDLE["offHand"] if off else OWNED_IDLE["mainHand"]
        target_uv = to_uv(*want)
        grip = grip_uv(im, off_hand=off)
        if not grip:
            continue
        land_x, land_y = grip[0] - 0.5, grip[1] - 0.5
        sx, sy = want[0] - land_x, want[1] - land_y
        mag = math.hypot(sx, sy)
        dhand = math.hypot(grip[0] - target_uv[0], grip[1] - target_uv[1])
        flags: list[str] = []
        if mag > 0.12:
            flags.append("BIG_SHIFT")
        elif mag > 0.05:
            flags.append("shift")
        if dhand > 0.18:
            flags.append("FAR_FROM_HAND_SOCKET")
        flag = " ".join(flags)
        print(
            f"{stem:28s} grip=({grip[0]:.3f},{grip[1]:.3f}) "
            f"shift=({sx:+.3f},{sy:+.3f}) |s|={mag:.3f} artD={dhand:.3f} {flag}"
        )
        if flags:
            grip_findings.append((stem, mag, dhand, flag))

    print()
    print("=== CODE WIRING (static checklist) ===")
    wiring = [
        "owned paintOwnedHero: mainHand/offHand grip-aligned (YES)",
        "owned paintOwnedHero: head/back/feet anchors UNUSED (armor is full blit)",
        "owned GearOverlayScales.owned: Kenney-fallback only (owned uses full 128)",
        "CharacterVisualPose.anchorProfile set per resolve path (owned/kenney)",
        "owned attackLean hand UVs measured from body_attack centroids",
        "Kenney path: uses AnchorTables + GearOverlayScales (fallback dolls)",
    ]
    for line in wiring:
        print(" -", line)

    # Visual board
    cols, rows, cell, pad = 5, 5, 140, 8
    board = Image.new("RGBA", (cols * cell, rows * cell), (30, 32, 40, 255))
    warrior = (
        Image.open(CHAR / "warrior" / "body_idle.png")
        .convert("RGBA")
        .resize((128, 128), Image.NEAREST)
    )
    for i, path in enumerate(sorted(GEAR.glob("*_idle.png"))[:25]):
        stem = path.name.removesuffix("_idle.png")
        off = stem.startswith(("shield_", "frill_"))
        want = OWNED_IDLE["offHand"] if off else OWNED_IDLE["mainHand"]
        want_uv = to_uv(*want)
        weap = Image.open(path).convert("RGBA")
        grip = grip_uv(weap, off_hand=off)
        canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        canvas.alpha_composite(warrior)
        if grip:
            ax = 64 + want[0] * 128
            ay = 64 + want[1] * 128
            gx = grip[0] * 128
            gy = grip[1] * 128
            dx = int(round(ax - gx))
            dy = int(round(ay - gy))
            layer = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            layer.paste(weap, (dx, dy), weap)
            canvas.alpha_composite(layer)
            draw = ImageDraw.Draw(canvas)
            draw.ellipse([ax - 2, ay - 2, ax + 2, ay + 2], outline=(255, 60, 60, 255))
            draw.ellipse(
                [gx + dx - 2, gy + dy - 2, gx + dx + 2, gy + dy + 2],
                outline=(60, 255, 60, 255),
            )
        r, c = divmod(i, cols)
        board.paste(
            canvas.resize((128, 128), Image.NEAREST),
            (c * cell + pad, r * cell + pad),
        )
    board_path = OUT / "audit_anchors_board.png"
    board.save(board_path)

    # Overlay anchors on each family body
    strip = Image.new("RGBA", (128 * 4 + 24, 128 + 16), (24, 26, 32, 255))
    for i, fam in enumerate(["warrior", "rogue", "mage", "healer"]):
        im = Image.open(CHAR / fam / "body_idle.png").convert("RGBA")
        draw = ImageDraw.Draw(im)
        for name, (nx, ny) in OWNED_IDLE.items():
            if name in ("body", "back"):
                continue
            x = 64 + nx * 128
            y = 64 + ny * 128
            color = {
                "mainHand": (255, 80, 80, 255),
                "offHand": (80, 255, 120, 255),
                "head": (80, 180, 255, 255),
                "feet": (255, 220, 80, 255),
            }[name]
            draw.ellipse([x - 3, y - 3, x + 3, y + 3], outline=color, width=2)
        strip.paste(im, (i * 132 + 8, 8))
    strip_path = OUT / "audit_anchors_on_bodies.png"
    strip.save(strip_path)

    print()
    print("=== FINDINGS ===")
    if not body_findings and not anim_findings and not grip_findings:
        print(" (none above thresholds)")
    for f in body_findings:
        print(" BODY:", f)
    for f in anim_findings:
        print(" ANIM:", f)
    for stem, mag, dhand, flag in sorted(grip_findings, key=lambda t: -t[1]):
        print(f" GRIP: {stem:28s} |shift|={mag:.3f} artD={dhand:.3f} {flag}")
    print(f"wrote {board_path.relative_to(ROOT)}")
    print(f"wrote {strip_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
