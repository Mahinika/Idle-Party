"""Cut a generated sprite down to the shape the game paints.

Idle Party enemy sprites are 96x96 RGBA with a transparent background; pets are
64x64. Art that arrives as an opaque square (black or white matte) paints as a
visible box on the dungeon floor, so every sprite goes through here before it
lands in assets/custom/.

Usage:
    py -3 tool/sprite_cutout.py <src.png> <dst.png> [--size 96] [--pad 4]
                               [--matte black|white|auto] [--tol 40]
"""

from __future__ import annotations

import argparse
import os

from PIL import Image


def _matte_color(img: Image.Image, mode: str) -> tuple[int, int, int]:
    if mode == "black":
        return (0, 0, 0)
    if mode == "white":
        return (255, 255, 255)
    w, h = img.size
    corners = [
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1)),
    ]
    corners = [c[:3] for c in corners]
    # Majority corner wins; ties fall back to the top-left pixel.
    best = max(set(corners), key=corners.count)
    return best


def cutout(
    src: str,
    dst: str,
    size: int = 96,
    pad: int = 4,
    matte: str = "auto",
    tol: int = 40,
) -> None:
    img = Image.open(src).convert("RGBA")

    if img.getchannel("A").getextrema()[0] == 255:
        # Fully opaque: knock out the matte so the sprite stops painting a box.
        key = _matte_color(img, matte)
        px = img.load()
        w, h = img.size
        for y in range(h):
            for x in range(w):
                r, g, b, _ = px[x, y]
                d = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
                if d <= tol:
                    px[x, y] = (r, g, b, 0)
                elif d <= tol * 2:
                    px[x, y] = (r, g, b, int(255 * (d - tol) / tol))

    box = img.getbbox()
    if box:
        img = img.crop(box)

    inner = max(1, size - pad * 2)
    w, h = img.size
    scale = min(inner / w, inner / h)
    img = img.resize(
        (max(1, round(w * scale)), max(1, round(h * scale))),
        # Nearest keeps pixel edges crisp — the game paints with FilterQuality.none.
        Image.NEAREST if scale >= 1 else Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img)

    # Drop nearly-transparent fringe pixels so edges read as pixel art.
    px = canvas.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            if a < 24:
                px[x, y] = (0, 0, 0, 0)
            elif a < 200:
                px[x, y] = (r, g, b, 255 if a > 110 else 0)

    canvas = canvas.quantize(colors=64, method=Image.FASTOCTREE).convert("RGBA")
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    canvas.save(dst, optimize=True)
    print(f"{os.path.basename(dst)}: {canvas.size} {os.path.getsize(dst)} bytes")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--size", type=int, default=96)
    ap.add_argument("--pad", type=int, default=4)
    ap.add_argument("--matte", default="auto", choices=["auto", "black", "white"])
    ap.add_argument("--tol", type=int, default=40)
    args = ap.parse_args()
    cutout(args.src, args.dst, args.size, args.pad, args.matte, args.tol)


if __name__ == "__main__":
    main()
