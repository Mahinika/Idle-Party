"""Read-only measurements of gold-master bodies. Prints style constants.

Does not write doll art. Numbers feed tool/gear_style.py by hand.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CHAR = ROOT / "assets" / "custom" / "char"


def edge_mask(alpha: np.ndarray) -> np.ndarray:
    m = alpha > 40
    pad = np.pad(m, 1)
    return m & ~(
        pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    )


def main() -> None:
    for fam in ("warrior", "healer", "mage", "rogue"):
        im = np.array(Image.open(CHAR / fam / "_src" / "body_idle.png").convert("RGBA"))
        a = im[..., 3]
        m = a > 40
        rgb = im[..., :3]
        edge = edge_mask(a)
        ink = np.median(rgb[edge], axis=0)
        lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
        ys, xs = np.nonzero(m)
        cy, cx = ys.mean(), xs.mean()
        l = lum[m]
        dx = xs - cx
        dy = ys - cy
        # Positive tl means brighter toward upper-left (negative x and y).
        tl = np.corrcoef(l, -(dx + dy))[0, 1]
        pure_black = ((rgb[edge].max(axis=1) < 20).mean())
        print(
            f"{fam:8} ink={tuple(int(v) for v in ink)} "
            f"edgeL={lum[edge].mean():.0f} inL={lum[m & ~edge].mean():.0f} "
            f"tl={tl:.2f} blackEdge={pure_black:.2f} "
            f"colors={len({tuple(c) for c in rgb[m]})}"
        )
    print("--- shared t0 bbox ---")
    for name in (
        "dagger_t0",
        "sword_t0",
        "axe_t0",
        "mace_t0",
        "bow_t0",
        "staff_t0",
        "shield_t0",
        "frill_t0",
    ):
        im = Image.open(CHAR / "gear" / f"{name}_idle.png")
        bb = im.getbbox()
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        print(f"{name:12} {w}x{h} bbox={bb}")


if __name__ == "__main__":
    main()
