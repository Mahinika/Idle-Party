#!/usr/bin/env python3
"""Play feature graphic 1024x500 from the first Sandy phone shot.

A 1024x500 window of the raw phone shot is too short: the pack sits near
the top and the starter party near the bottom, so one crop cuts one of
them. This drops the empty floor between them, then fits that band under
the title plate.

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
# Pack (bat and the purple brute) then the starter party. The gap between
# these rows is empty hallway, measured on raw/01_combat_a.png.
PACK = (470, 900)
PARTY = (1060, 1660)


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
    pack = im.crop((0, PACK[0], im.width, PACK[1]))
    party = im.crop((0, PARTY[0], im.width, PARTY[1]))
    band = Image.new("RGB", (im.width, pack.height + party.height))
    band.paste(pack, (0, 0))
    band.paste(party, (0, pack.height))

    title_h = 112
    avail = H - title_h - 10
    scale = avail / band.height
    fight = band.resize(
        (max(1, int(band.width * scale)), max(1, int(band.height * scale))),
        Image.Resampling.LANCZOS,
    )
    # Continue the cave wall into the side margins. The left edge of this
    # shot is rock, not HUD.
    wall = fight.crop((0, 0, 28, fight.height)).resize(
        (W, fight.height),
        Image.Resampling.NEAREST,
    )
    # The stretched wall is only a margin. Keep it darker than the hallway.
    dark = wall.point(lambda p: int(p * 0.45))
    wall = dark
    canvas = Image.new("RGB", (W, H))
    top_fill = wall.crop((0, 0, W, 4)).resize((W, title_h), Image.Resampling.NEAREST)
    canvas.paste(top_fill, (0, 0))
    canvas.paste(wall, (0, title_h))
    bottom = title_h + fight.height
    if bottom < H:
        bot_fill = wall.crop((0, fight.height - 4, W, fight.height)).resize(
            (W, H - bottom),
            Image.Resampling.NEAREST,
        )
        canvas.paste(bot_fill, (0, bottom))
    canvas.paste(fight, ((W - fight.width) // 2, title_h))

    draw = ImageDraw.Draw(canvas)
    title = "IDLE PARTY"
    line = "Party fights AFK"
    title_font = font(54)
    line_font = font(26)
    tb = draw.textbbox((0, 0), title, font=title_font)
    lb = draw.textbbox((0, 0), line, font=line_font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    lw, lh = lb[2] - lb[0], lb[3] - lb[1]
    cx = W // 2
    title_y = 16
    draw.rounded_rectangle(
        (
            cx - max(tw, lw) // 2 - 24,
            title_y - 8,
            cx + max(tw, lw) // 2 + 24,
            title_y + th + lh + 16,
        ),
        radius=16,
        fill=(16, 12, 10),
    )
    draw.text(((W - tw) / 2, title_y), title, font=title_font, fill=(245, 230, 200))
    draw.text(
        ((W - lw) / 2, title_y + th + 4),
        line,
        font=line_font,
        fill=(214, 168, 72),
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, format="PNG", optimize=True)
    print("wrote", OUT, canvas.size)


if __name__ == "__main__":
    main()
