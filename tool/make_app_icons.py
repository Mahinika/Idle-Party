"""Android launcher + splash icons from owned app_icon art.

Fills the adaptive-icon circle with the cave painting (dark plate, no white
ring). Run after changing tool/art_backups/app_icon.png:

    py -3 tool/make_app_icons.py
"""
from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError as e:
    raise SystemExit("Pillow required: py -3 -m pip install pillow") from e

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tool" / "art_backups" / "app_icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Legacy launcher sizes (px). Adaptive XML takes over on API 26+.
MIPMAPS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# nodpi so Android does not treat the PNG as mdpi and upscale it.
FOREGROUND = RES / "drawable-nodpi" / "ic_launcher_foreground.png"
FOREGROUND_SIZE = 1024
# Android 12 splash center-crops ~2/3 of the drawable. Keep the whole party
# inside that safe zone so the circle is cave, not a zoomed crop.
SPLASH = RES / "drawable-nodpi" / "splash_icon.png"
SPLASH_CAVE_FRACTION = 0.66


def _resize(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def _circle(im: Image.Image, size: int) -> Image.Image:
    square = _resize(im, size)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(square, (0, 0), mask)
    return out


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")
    src = Image.open(SRC).convert("RGBA")

    FOREGROUND.parent.mkdir(parents=True, exist_ok=True)
    fg = _resize(src, FOREGROUND_SIZE)
    fg.save(FOREGROUND, format="PNG", optimize=True)
    print("wrote", FOREGROUND, fg.size)

    splash = Image.new("RGBA", (FOREGROUND_SIZE, FOREGROUND_SIZE), (6, 8, 12, 255))
    inner = max(1, int(FOREGROUND_SIZE * SPLASH_CAVE_FRACTION))
    cave = _resize(src, inner)
    off = (FOREGROUND_SIZE - inner) // 2
    splash.paste(cave, (off, off))
    splash.save(SPLASH, format="PNG", optimize=True)
    print("wrote", SPLASH, splash.size, f"cave={inner}px")

    for folder, size in MIPMAPS.items():
        dest_dir = RES / folder
        dest_dir.mkdir(parents=True, exist_ok=True)
        square = _resize(src, size)
        square_path = dest_dir / "ic_launcher.png"
        square.save(square_path, format="PNG", optimize=True)
        print("wrote", square_path, square.size)
        round_path = dest_dir / "ic_launcher_round.png"
        rounded = _circle(src, size)
        rounded.save(round_path, format="PNG", optimize=True)
        print("wrote", round_path, rounded.size)


if __name__ == "__main__":
    main()
