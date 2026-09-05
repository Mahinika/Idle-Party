"""Build a clearer rogue helm_t2 from helm_t0 authored (mutate, don't invent).

Adds gold crest, brighter brow plate, gem, and gold ear tips so rare helms
read differently from common on the doll and in BAG.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageChops

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char\rogue\gear")
AUTH = ROOT / "_authored"
ANIMS = ("idle", "walk", "attack")


def goldify_strong(im: Image.Image) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (
                min(255, int(r * 0.55 + 110)),
                min(255, int(g * 0.50 + 78)),
                min(255, int(b * 0.35 + 18)),
                a,
            )
    return ImageEnhance.Contrast(out).enhance(1.12)


def rarefy_helm(base: Image.Image) -> Image.Image:
    """Keep t0 silhouette; push rare identity with crest + gold accents."""
    out = goldify_strong(base)
    bb = out.getbbox()
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    cx = (x0 + x1) // 2
    d = ImageDraw.Draw(out)
    # Tall gold crest on crown
    crest_top = max(2, y0 - 10)
    d.polygon(
        [
            (cx - 3, y0 + 4),
            (cx, crest_top),
            (cx + 3, y0 + 4),
            (cx + 2, y0 + 10),
            (cx - 2, y0 + 10),
        ],
        fill=(220, 180, 64, 255),
    )
    d.line([(cx, crest_top + 1), (cx, y0 + 8)], fill=(255, 230, 140, 255), width=1)
    # Wider / brighter brow plate + gem
    brow_y = y0 + max(6, (y1 - y0) // 3)
    d.rectangle([cx - 10, brow_y, cx + 10, brow_y + 5], fill=(230, 190, 70, 255))
    d.rectangle([cx - 8, brow_y + 1, cx + 8, brow_y + 4], fill=(255, 220, 120, 255))
    d.ellipse([cx - 2, brow_y, cx + 2, brow_y + 5], fill=(80, 200, 255, 255))
    # Gold tips on ear flaps
    for side in (-1, 1):
        ex = cx + side * ((x1 - x0) // 2 - 2)
        ey = y1 - 4
        d.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=(210, 170, 55, 255))
        d.ellipse([ex - 1, ey - 1, ex + 1, ey + 1], fill=(255, 230, 140, 255))
    return out


def main() -> None:
    for anim in ANIMS:
        src = AUTH / f"helm_t0_{anim}.png"
        if not src.exists():
            raise SystemExit(f"missing {src}")
        base = Image.open(src).convert("RGBA")
        rare = rarefy_helm(base)
        dest_auth = AUTH / f"helm_t2_{anim}.png"
        dest_live = ROOT / f"helm_t2_{anim}.png"
        rare.save(dest_auth)
        rare.save(dest_live)
        diff = ImageChops.difference(base, rare)
        n = sum(1 for p in diff.getdata() if any(p[:3]) or p[3])
        print(f"wrote helm_t2_{anim} diff_vs_t0={n}")


if __name__ == "__main__":
    main()
