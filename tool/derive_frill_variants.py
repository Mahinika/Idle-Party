#!/usr/bin/env python3
"""Derive frill_prism / frill_soulcodex from frill_t0 (real book), not ImageDraw stubs."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEAR = ROOT / "assets" / "custom" / "char" / "gear"
AUTH = GEAR / "_authored"


def recolor(im: Image.Image, mode: str) -> Image.Image:
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            # Skip near-black empty
            if r + g + b < 20:
                op[x, y] = (r, g, b, a)
                continue
            if mode == "prism":
                # Purple wash — keep gold trim relatively warm
                if r > 160 and g > 120 and b < 100:
                    op[x, y] = (r, g, b, a)  # gold
                elif r > 180 and g > 170 and b > 140:
                    op[x, y] = (r, g, b, a)  # pages
                else:
                    nr = int(min(255, r * 0.55 + 70))
                    ng = int(min(255, g * 0.35 + 40))
                    nb = int(min(255, b * 0.85 + 90))
                    op[x, y] = (nr, ng, nb, a)
            else:  # soulcodex — teal/void
                if r > 160 and g > 120 and b < 100:
                    op[x, y] = (int(r * 0.5), int(g * 0.7 + 40), int(min(255, b + 80)), a)
                elif r > 180 and g > 170 and b > 140:
                    op[x, y] = (int(r * 0.7), int(g * 0.85), int(min(255, b + 30)), a)
                else:
                    nr = int(min(255, r * 0.25 + 20))
                    ng = int(min(255, g * 0.45 + 50))
                    nb = int(min(255, b * 0.75 + 70))
                    op[x, y] = (nr, ng, nb, a)
    return out


def crop_icon(im: Image.Image, size: int = 64) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    # Pad to square
    cw, ch = cropped.size
    side = max(cw, ch)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
    return sq.resize((size, size), Image.Resampling.NEAREST)


def write_set(stem: str, idle: Image.Image) -> None:
    # Mild pose variants without inventing geometry
    walk = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    walk.paste(idle, (0, 1), idle)
    attack = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    attack.paste(idle, (1, -1), idle)
    icon = crop_icon(idle)
    for folder in (GEAR, AUTH):
        folder.mkdir(parents=True, exist_ok=True)
        idle.save(folder / f"{stem}_idle.png")
        walk.save(folder / f"{stem}_walk.png")
        attack.save(folder / f"{stem}_attack.png")
    icon.save(GEAR / f"{stem}_icon.png")
    print(f"wrote {stem} overlays + icon")


def main() -> None:
    base = Image.open(GEAR / "frill_t0_idle.png").convert("RGBA")
    write_set("frill_prism", recolor(base, "prism"))
    write_set("frill_soulcodex", recolor(base, "soulcodex"))


if __name__ == "__main__":
    main()
