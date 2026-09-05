"""Import AI-generated idle sprites into assets/custom/char/*/body_idle.png."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

PAIRS = (
    ("assets/warrior_idle_gen.png", "assets/custom/char/warrior/body_idle.png"),
    ("assets/healer_idle_gen.png", "assets/custom/char/healer/body_idle.png"),
    ("assets/mage_idle_gen.png", "assets/custom/char/mage/body_idle.png"),
    ("assets/rogue_idle_gen.png", "assets/custom/char/rogue/body_idle.png"),
)


def strip_checkerboard(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            if r > 228 and g > 228 and b > 228:
                px[x, y] = (0, 0, 0, 0)
            elif 150 <= r <= 215 and 150 <= g <= 215 and 150 <= b <= 215:
                px[x, y] = (0, 0, 0, 0)
    return im


def to_body_idle(src: Path, dst: Path) -> None:
    im = strip_checkerboard(Image.open(src))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    pad = 8
    canvas = Image.new(
        "RGBA",
        (im.width + pad * 2, im.height + pad * 2),
        (0, 0, 0, 0),
    )
    canvas.paste(im, (pad, pad), im)
    canvas = canvas.resize((128, 128), Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst, optimize=True)
    print(dst.relative_to(ROOT), canvas.size)


def main() -> None:
    for src_rel, dst_rel in PAIRS:
        to_body_idle(ROOT / src_rel, ROOT / dst_rel)


if __name__ == "__main__":
    main()
