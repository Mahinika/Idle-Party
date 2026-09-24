"""Refresh native helms that are not tied to dressed _src facit.

Body slots must stay _src extracts (facit idle diff vs gold master). This
script only upgrades authored helms where _src has no hat (rogue leather).

Rogue leather helm: warrior coif → leather cowl (visor softened, ≠ mail).
"""
from __future__ import annotations

from PIL import Image

from build_owned_gear_layers import (
    bbox,
    load128,
    punch_face_visor,
    register_helm_to_head,
    sample_face,
)
from derive_armor_material_variants import CONVERTERS
from paper_doll_paths import LIVE_CHAR as ROOT, REPO

DONOR = "warrior"


def soften_to_leather_hood(helm: Image.Image) -> Image.Image:
    """Plate coif → leather cowl: drop visor bar, round crown."""
    out = CONVERTERS["leather"](helm)
    px = out.load()
    bb = out.getbbox()
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    mid_y = (y0 + y1) // 2
    for y in range(y0, min(128, mid_y + 6)):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            if y <= mid_y - 2 and abs(x - (x0 + x1) // 2) < (x1 - x0) * 0.42:
                px[x, y] = (
                    max(0, r - 18),
                    max(0, g - 14),
                    max(0, b - 10),
                    max(0, a - 30),
                )
    for y in range(mid_y - 4, min(128, y1 + 4)):
        for x in range(max(0, x0 - 2), min(128, x1 + 2)):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            edge = x <= x0 + 3 or x >= x1 - 4
            if edge and y >= mid_y:
                px[x, y] = (
                    min(255, r + 6),
                    min(255, g + 4),
                    min(255, b + 2),
                    min(255, a + 12),
                )
    return out


def build_leather_helm(family: str) -> Image.Image:
    warrior_helm = Image.open(
        ROOT / DONOR / "gear" / "helm_t0_idle.png"
    ).convert("RGBA")
    src, box, face = family_src(family)
    hood = soften_to_leather_hood(warrior_helm)
    placed = register_helm_to_head(hood, src, face, box)
    punch_face_visor(placed, src, face, box)
    return placed


def family_src(family: str):
    src = load128(ROOT / family / "_src" / "body_idle.png")
    box = bbox(src)
    face = sample_face(src, box, family)
    return src, box, face


def refresh_rogue_leather_helm() -> None:
    """Rewrite the authored master only; the gear build ships it."""
    auth = ROOT / "rogue" / "gear" / "_authored" / "helm_t0_idle.png"
    auth.parent.mkdir(parents=True, exist_ok=True)
    build_leather_helm("rogue").save(auth)
    print("authored", auth.relative_to(REPO))


def main() -> int:
    refresh_rogue_leather_helm()
    print("done — run py tool/build_owned_gear_layers.py --publish")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
