#!/usr/bin/env python3
"""Generate owned Idle Party Druid form sprites (moonkin + tree).

Pure procedural PIL art matching the chunky jagged style of
assets/custom/heroes/feral.png and guardian.png. No third-party dumps.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "custom" / "heroes"
SIZE = 96


def _jagged_disk(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r: float,
    fill: tuple[int, int, int, int],
    *,
    seed: int,
    spikes: int = 28,
    jag: float = 2.8,
) -> None:
    """Filled disk with sawtooth perimeter (chunky pixel silhouette)."""
    rng = random.Random(seed)
    pts: list[tuple[float, float]] = []
    steps = max(24, int(spikes * 1.6))
    for i in range(steps):
        ang = (i / steps) * math.tau
        # Alternate jut / dent so edges read serrated like feral/guardian.
        bump = jag if (i % 2 == 0) else -jag * 0.55
        bump += rng.uniform(-0.6, 0.6)
        rr = max(1.5, r + bump)
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    draw.polygon(pts, fill=fill)


def _stamp_blob(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r: float,
    fill: tuple[int, int, int, int],
    *,
    seed: int,
) -> None:
    _jagged_disk(draw, cx, cy, r, fill, seed=seed, spikes=max(16, int(r * 2.2)), jag=max(1.6, r * 0.18))


def _eyes(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    *,
    color: tuple[int, int, int, int],
    spacing: float = 7.0,
    size: float = 2.6,
) -> None:
    for dx in (-spacing * 0.5, spacing * 0.5):
        draw.ellipse(
            (cx + dx - size, cy - size, cx + dx + size, cy + size),
            fill=color,
        )


def gen_moonkin() -> Image.Image:
    """Bipedal owlkin — round owl head, wing cape, pale belly, amber eyes."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    gold = (196, 148, 56, 255)
    gold_lt = (236, 200, 110, 255)
    cream = (248, 230, 180, 255)
    brown = (110, 72, 36, 255)
    brown_dk = (70, 44, 20, 255)
    eye = (255, 230, 80, 255)
    pupil = (40, 24, 8, 255)

    cx, cy = 48.0, 52.0

    # Bird legs (thin) + talons
    _stamp_blob(d, cx - 8, cy + 26, 5.5, brown, seed=11)
    _stamp_blob(d, cx + 8, cy + 26, 5.5, brown, seed=12)
    _stamp_blob(d, cx - 11, cy + 34, 4.2, brown_dk, seed=13)
    _stamp_blob(d, cx + 11, cy + 34, 4.2, brown_dk, seed=14)
    _stamp_blob(d, cx - 14, cy + 36, 2.8, brown_dk, seed=15)
    _stamp_blob(d, cx + 14, cy + 36, 2.8, brown_dk, seed=16)

    # Torso (taller owl, not bear-round)
    _stamp_blob(d, cx, cy + 6, 15.0, gold, seed=20)
    _stamp_blob(d, cx, cy + 8, 9.5, cream, seed=21)

    # Wide wing cape (reads as feathers, not arms-on-hips bear)
    _stamp_blob(d, cx - 24, cy + 2, 12.5, brown, seed=30)
    _stamp_blob(d, cx + 24, cy + 2, 12.5, brown, seed=31)
    _stamp_blob(d, cx - 28, cy + 14, 8.0, brown_dk, seed=32)
    _stamp_blob(d, cx + 28, cy + 14, 8.0, brown_dk, seed=33)
    _stamp_blob(d, cx - 18, cy - 2, 7.0, gold, seed=34)
    _stamp_blob(d, cx + 18, cy - 2, 7.0, gold, seed=35)

    # Round owl head (larger than torso)
    _stamp_blob(d, cx, cy - 18, 16.5, gold, seed=40)
    _stamp_blob(d, cx, cy - 16, 10.0, gold_lt, seed=41)
    # Ear tufts
    _stamp_blob(d, cx - 12, cy - 32, 4.5, brown, seed=42)
    _stamp_blob(d, cx + 12, cy - 32, 4.5, brown, seed=43)
    # Beak (diamond / triangle feel)
    d.polygon(
        [
            (cx, cy - 6),
            (cx - 4.5, cy - 12),
            (cx + 4.5, cy - 12),
        ],
        fill=brown_dk,
    )

    _eyes(d, cx, cy - 20, color=eye, spacing=11.0, size=3.4)
    # Pupils
    for dx in (-5.5, 5.5):
        d.ellipse(
            (cx + dx - 1.2, cy - 20 - 1.2, cx + dx + 1.2, cy - 20 + 1.2),
            fill=pupil,
        )
    return img

def gen_tree() -> Image.Image:
    """Tree of Life — green trunk/foliage humanoid, glowing green eyes."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    bark = (86, 58, 28, 255)
    bark_lt = (120, 84, 40, 255)
    leaf = (48, 140, 56, 255)
    leaf_lt = (88, 188, 78, 255)
    leaf_dk = (28, 96, 40, 255)
    eye = (160, 255, 90, 255)

    cx, cy = 48.0, 50.0

    # Roots / feet
    _stamp_blob(d, cx - 12, cy + 34, 7.0, bark, seed=51)
    _stamp_blob(d, cx + 12, cy + 34, 7.0, bark, seed=52)
    _stamp_blob(d, cx, cy + 36, 6.0, bark_lt, seed=53)

    # Trunk body
    _stamp_blob(d, cx, cy + 10, 14.0, bark, seed=60)
    _stamp_blob(d, cx, cy + 4, 9.0, bark_lt, seed=61)

    # Arm branches
    _stamp_blob(d, cx - 20, cy + 2, 8.0, bark, seed=70)
    _stamp_blob(d, cx + 20, cy + 2, 8.0, bark, seed=71)
    _stamp_blob(d, cx - 26, cy - 4, 6.0, leaf_dk, seed=72)
    _stamp_blob(d, cx + 26, cy - 4, 6.0, leaf_dk, seed=73)

    # Canopy / head foliage
    _stamp_blob(d, cx, cy - 18, 18.0, leaf, seed=80)
    _stamp_blob(d, cx - 10, cy - 24, 9.0, leaf_lt, seed=81)
    _stamp_blob(d, cx + 10, cy - 24, 9.0, leaf_lt, seed=82)
    _stamp_blob(d, cx, cy - 28, 8.0, leaf_dk, seed=83)
    # Face bark patch
    _stamp_blob(d, cx, cy - 14, 8.0, bark_lt, seed=84)

    _eyes(d, cx, cy - 15, color=eye, spacing=8.0, size=2.7)
    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    moonkin = gen_moonkin()
    tree = gen_tree()
    moonkin_path = OUT_DIR / "moonkin.png"
    tree_path = OUT_DIR / "tree.png"
    moonkin.save(moonkin_path)
    tree.save(tree_path)
    print(f"Wrote {moonkin_path.relative_to(ROOT)} ({moonkin.size})")
    print(f"Wrote {tree_path.relative_to(ROOT)} ({tree.size})")


if __name__ == "__main__":
    main()
