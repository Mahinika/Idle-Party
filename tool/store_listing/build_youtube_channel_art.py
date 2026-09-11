"""Build Cognifox Studio YouTube avatar + banner from owned store art."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "youtube"
ICON = ROOT / "tool" / "art_backups" / "app_icon.png"
FEATURE = (
    ROOT
    / "tool"
    / "store_listing"
    / "marketing"
    / "01_feature_graphic_1024x500.png"
)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ICON).convert("RGBA")
    feat = Image.open(FEATURE).convert("RGBA")

    prof = Image.new("RGBA", (800, 800), (18, 14, 28, 255))
    ic = icon.copy()
    ic.thumbnail((720, 720), Image.Resampling.LANCZOS)
    prof.paste(ic, ((800 - ic.width) // 2, (800 - ic.height) // 2), ic)
    avatar_path = OUT / "channel_avatar_800.png"
    prof.convert("RGB").save(avatar_path, quality=95)

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
