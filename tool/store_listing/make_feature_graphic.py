#!/usr/bin/env python3
"""Play feature graphic 1024x500 from the first Sandy phone shot.

The party and the title sit in the middle. Play crops the edges, and this
image is the poster when the preview video does not autoplay.

  py -3 tool/store_listing/make_feature_graphic.py
"""

from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    raise SystemExit("Pillow required: py -3 -m pip install pillow") from e

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tool" / "store_listing" / "raw" / "01_combat_a.png"
OUT = ROOT / "tool" / "store_listing" / "marketing" / "01_feature_graphic_1024x500.png"
W, H = 1024, 500


def font(size: int) -> ImageFont.ImageFont:
    for name in (
        "C:/Windows/Fonts/georgia.ttf",
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
    ):
        path = Path(name)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing {SRC} — shoot the A56 first")
    im = Image.open(SRC).convert("RGB")
    scale = max(W / im.width, H / im.height)
    resized = im.resize(
        (max(1, int(im.width * scale)), max(1, int(im.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - W) // 2)
    # Heroes sit in the middle of a tall phone shot, not under the status bar.
    top = max(0, int((resized.height - H) * 0.42))
    crop = resized.crop((left, top, left + W, top + H))
    draw = ImageDraw.Draw(crop)
    title = "IDLE PARTY"
    line = "Party fights AFK"
    title_font = font(64)
    line_font = font(32)
    tb = draw.textbbox((0, 0), title, font=title_font)
    lb = draw.textbbox((0, 0), line, font=line_font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    lw, lh = lb[2] - lb[0], lb[3] - lb[1]
    cx = W // 2
    # Plate sits above the party so the heroes stay readable in the middle.
    title_y = 48
    # Dark plate so the words stay readable on the cave.
    draw.rounded_rectangle(
        (cx - max(tw, lw) // 2 - 28, title_y - 16, cx + max(tw, lw) // 2 + 28, title_y + th + lh + 28),
        radius=18,
        fill=(16, 12, 10),
    )
    draw.text(((W - tw) / 2, title_y), title, font=title_font, fill=(245, 230, 200))
    draw.text(
        ((W - lw) / 2, title_y + th + 10),
        line,
        font=line_font,
        fill=(214, 168, 72),
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    crop.save(OUT, format="PNG", optimize=True)
    print("wrote", OUT, crop.size)


if __name__ == "__main__":
    main()
