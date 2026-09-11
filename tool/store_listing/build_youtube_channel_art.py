"""Build Cognifox Studio YouTube avatar + banner.

Avatar defaults to the owner's GitHub profile photo (Mahinika), matching
the git/GitHub identity — not the Idle Party app icon.
"""

from __future__ import annotations

import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "youtube"
# Same photo as https://github.com/Mahinika
GITHUB_AVATAR_URL = "https://avatars.githubusercontent.com/u/217390085?s=800&v=4"
FEATURE = (
    ROOT
    / "tool"
    / "store_listing"
    / "marketing"
    / "01_feature_graphic_1024x500.png"
)


def _avatar_800_for_yt_circle(src: Image.Image) -> Image.Image:
    """Pad logo so the full art stays inside YouTube's circular crop."""
    rgba = src.convert("RGBA")
    bbox = rgba.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    size = 800
    # ~68% of canvas so ears + STUDIO clear YouTube's circular crop
    safe = int(size * 0.68)
    canvas = Image.new("RGBA", (size, size), (10, 12, 28, 255))
    w, h = rgba.size
    scale = min(safe / w, safe / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    logo = rgba.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - nw) // 2, (size - nh) // 2), logo)
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    raw_path = OUT / "github_avatar_src.png"
    urllib.request.urlretrieve(GITHUB_AVATAR_URL, raw_path)
    avatar = _avatar_800_for_yt_circle(Image.open(raw_path))
    feat = Image.open(FEATURE).convert("RGBA")

    avatar_path = OUT / "channel_avatar_800.png"
    avatar.convert("RGB").save(avatar_path, quality=95)

    banner = Image.new("RGBA", (2560, 1440), (12, 10, 22, 255))
    draw = ImageDraw.Draw(banner)
    for y in range(1440):
        a = int(36 * (1 - abs(y - 720) / 720))
        draw.line([(0, y), (2560, y)], fill=(30, 22, 48, a))

    target_w = 1800
    ratio = target_w / feat.width
    fg = feat.resize((target_w, int(feat.height * ratio)), Image.Resampling.LANCZOS)
    bx = (2560 - fg.width) // 2
    by = (1440 - fg.height) // 2
    banner.paste(fg, (bx, by), fg)

    try:
        font = ImageFont.truetype("arial.ttf", 48)
    except OSError:
        font = ImageFont.load_default()
    label = "Cognifox Studio"
    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(
        ((2560 - tw) // 2, by + fg.height + 36),
        label,
        fill=(230, 220, 245, 255),
        font=font,
    )

    banner_path = OUT / "channel_banner_2560x1440.jpg"
    banner.convert("RGB").save(banner_path, quality=92)
    print(f"wrote {avatar_path}")
    print(f"wrote {banner_path}")


if __name__ == "__main__":
    main()
