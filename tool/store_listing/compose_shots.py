"""Compose Play Store phone screenshots: real UI + short caption bar.

Usage:
  py -3 tool/store_listing/compose_shots.py

Reads PNGs from tool/store_listing/raw/, writes 1080x1920 JPEG/PNG to out/.
"""
from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    raise SystemExit("Pillow required: py -3 -m pip install pillow") from e

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tool" / "store_listing" / "raw"
OUT = ROOT / "tool" / "store_listing" / "out"

# Order matters for Play carousel.
SHOTS = [
    ("01_hub.png", "Always know today’s chase"),
    ("02_combat.png", "Your party keeps fighting"),
    ("03_gear.png", "Grow stronger every floor"),
    ("04_meta.png", "Keep power when you Ascend"),
    ("05_zone.png", "15 zones · World Path"),
    ("06_power.png", "Free · no ads · no paid store"),
]

W, H = 1080, 1920
CAPTION_H = 160


def fit_cover(im: Image.Image, tw: int, th: int) -> Image.Image:
    im = im.convert("RGB")
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def font(size: int):
    for name in (
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ):
        p = Path(name)
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def compose(src: Path, caption: str, dest: Path) -> None:
    base = Image.open(src)
    # Leave room for caption bar at bottom.
    play = fit_cover(base, W, H - CAPTION_H)
    canvas = Image.new("RGB", (W, H), (12, 14, 18))
    canvas.paste(play, (0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, H - CAPTION_H, W, H), fill=(18, 22, 28))
    draw.rectangle((0, H - CAPTION_H, W, H - CAPTION_H + 4), fill=(96, 192, 112))
    f = font(42)
    # Center caption.
    bbox = draw.textbbox((0, 0), caption, font=f)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (W - tw) // 2
    y = H - CAPTION_H + (CAPTION_H - th) // 2 - 4
    draw.text((x, y), caption, fill=(235, 240, 245), font=f)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, format="PNG", optimize=True)
    print("wrote", dest.name, canvas.size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    meta = []
    for i, (name, caption) in enumerate(SHOTS, start=1):
        src = RAW / name
        if not src.exists():
            print("skip missing", src)
            continue
        dest = OUT / f"{i:02d}_{src.stem}.png"
        compose(src, caption, dest)
        meta.append({"file": dest.name, "caption": caption})
    (OUT / "manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print("done", len(meta), "shots")


if __name__ == "__main__":
    main()
