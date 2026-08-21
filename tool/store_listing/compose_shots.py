"""Compose Play Store phone screenshots: real UI + readable caption.

Usage:
  py -3 tool/store_listing/compose_shots.py

Reads PNGs from tool/store_listing/raw/, writes 1080x1920 PNG to out/.

Design notes (Play CRO):
- First shots sell the promise; captions ≤ ~8 words, large, high contrast.
- Caption stays in a top band (does not cover the hero of the UI).
- Smart vertical crop keeps headers / action in frame (phone 1080x2340 → 9:16).
"""
from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError as e:
    raise SystemExit("Pillow required: py -3 -m pip install pillow") from e

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tool" / "store_listing" / "raw"
OUT = ROOT / "tool" / "store_listing" / "out"

# (raw_name, caption, crop_bias_y) — bias 0=top, 1=bottom of source.
SHOTS = [
    ("01_hub.png", "Always know today’s chase", 0.28),
    ("02_combat.png", "Your party keeps fighting", 0.42),
    ("03_gear.png", "Grow stronger every floor", 0.08),
    ("04_meta.png", "Keep power when you Ascend", 0.08),
    ("05_zone.png", "15 zones · World Path", 0.32),
    ("06_power.png", "See your gold per minute", 0.08),
]

W, H = 1080, 1920
# Top caption band (~11% — under Play’s ~20% text guidance).
CAPTION_H = 210
ACCENT = (214, 168, 72)  # warm torch gold, matches game chrome
BG = (10, 12, 16)
CAPTION_BG = (14, 17, 22)
TEXT = (245, 242, 235)


def fit_cover(im: Image.Image, tw: int, th: int, bias_y: float = 0.5) -> Image.Image:
    im = im.convert("RGB")
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale + 0.5), int(im.height * scale + 0.5)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - tw) // 2)
    max_top = max(0, nh - th)
    top = int(max_top * max(0.0, min(1.0, bias_y)))
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


def compose(src: Path, caption: str, dest: Path, bias_y: float) -> None:
    base = Image.open(src)
    play_h = H - CAPTION_H
    play = fit_cover(base, W, play_h, bias_y=bias_y)

    canvas = Image.new("RGB", (W, H), BG)
    canvas.paste(play, (0, CAPTION_H))

    # Soft shadow under caption so the join doesn't look hard-cut.
    shadow = Image.new("RGB", (W, 28), BG)
    canvas.paste(shadow, (0, CAPTION_H))
    fade = play.crop((0, 0, W, 36)).filter(ImageFilter.GaussianBlur(6))
    canvas.paste(fade, (0, CAPTION_H))

    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, W, CAPTION_H), fill=CAPTION_BG)
    draw.rectangle((0, CAPTION_H - 5, W, CAPTION_H), fill=ACCENT)

    # Word-wrap if needed (rare for our short captions).
    f = font(48)
    words = caption.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textbbox((0, 0), trial, font=f)[2] <= W - 72:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    if not lines:
        lines = [caption]

    total_h = 0
    sizes = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=f)
        sizes.append((bbox[2] - bbox[0], bbox[3] - bbox[1]))
        total_h += sizes[-1][1]
    total_h += 10 * (len(lines) - 1)
    y = (CAPTION_H - 5 - total_h) // 2
    for i, line in enumerate(lines):
        tw, th = sizes[i]
        x = (W - tw) // 2
        draw.text((x, y), line, fill=TEXT, font=f)
        y += th + 10

    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, format="PNG", optimize=True)
    print("wrote", dest.name, canvas.size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    meta = []
    for i, (name, caption, bias) in enumerate(SHOTS, start=1):
        src = RAW / name
        if not src.exists():
            print("skip missing", src)
            continue
        dest = OUT / f"{i:02d}_{src.stem}.png"
        compose(src, caption, dest, bias)
        meta.append({"file": dest.name, "caption": caption, "bias_y": bias})
    (OUT / "manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print("done", len(meta), "shots")


if __name__ == "__main__":
    main()
