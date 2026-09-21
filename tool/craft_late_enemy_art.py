#!/usr/bin/env py
"""Late-zone enemy silhouettes that used to be the same oval.

32×32, 1 px outline, nearest-neighbor. Crystal wraith stays authored.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "custom" / "enemies"
OUT = (0x12, 0x0C, 0x10, 255)


def _blank() -> Image.Image:
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))


def _rim(img: Image.Image) -> None:
    w, h = img.size
    extra: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] == 0:
                    extra.append((nx, ny))
    for x, y in extra:
        if img.getpixel((x, y))[3] == 0:
            img.putpixel((x, y), OUT)


def _save(img: Image.Image, name: str) -> None:
    _rim(img)
    path = OUT_DIR / name
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def storm_wraith() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 2), (28, 14), (22, 14), (30, 28), (16, 18), (2, 28), (10, 14), (4, 14)], fill=(0xC8, 0xE8, 0xFF))
    d.polygon([(16, 6), (22, 14), (16, 20), (10, 14)], fill=(0x68, 0x40, 0xC0))
    d.ellipse([13, 10, 16, 13], fill=(0xFF, 0xFF, 0xFF))
    d.ellipse([17, 10, 20, 13], fill=(0xFF, 0xFF, 0xFF))
    return img


def rime_wraith() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 1), (20, 14), (16, 30), (12, 14)], fill=(0xF4, 0xFC, 0xFF))
    d.polygon([(2, 12), (14, 16), (2, 20)], fill=(0x70, 0xE8, 0xF8))
    d.polygon([(30, 12), (18, 16), (30, 20)], fill=(0x70, 0xE8, 0xF8))
    d.rectangle([14, 8, 18, 14], fill=(0x48, 0x78, 0x98))
    d.point((15, 10), fill=(0x12, 0x18, 0x28))
    return img


def ember_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([4, 10, 28, 30], fill=(0x48, 0x22, 0x10))
    d.polygon([(6, 16), (10, 4), (16, 14)], fill=(0xF0, 0x88, 0x20))
    d.polygon([(16, 14), (22, 4), (26, 16)], fill=(0xFF, 0xB0, 0x30))
    d.rectangle([13, 16, 19, 26], fill=(0xFF, 0xE0, 0x60))
    d.ellipse([11, 18, 14, 21], fill=(0x3A, 0x14, 0x08))
    d.ellipse([18, 18, 21, 21], fill=(0x3A, 0x14, 0x08))
    return img


def ember_brute() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.rectangle([2, 14, 30, 28], fill=(0x5A, 0x28, 0x10))
    d.polygon([(2, 16), (8, 6), (14, 16)], fill=(0xC8, 0x60, 0x18))
    d.polygon([(18, 16), (24, 6), (30, 16)], fill=(0xC8, 0x60, 0x18))
    d.rectangle([12, 18, 20, 26], fill=(0xFF, 0xA0, 0x20))
    return img


def tide_brute() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([1, 14, 31, 30], fill=(0x1A, 0x58, 0x70))
    d.polygon([(4, 18), (10, 6), (16, 16)], fill=(0xE8, 0xA8, 0x78))
    d.polygon([(16, 16), (22, 6), (28, 18)], fill=(0xC8, 0x78, 0x58))
    d.ellipse([8, 18, 13, 23], fill=(0xFF, 0xE8, 0xC8))
    d.ellipse([19, 18, 24, 23], fill=(0xFF, 0xE8, 0xC8))
    d.rectangle([14, 22, 18, 26], fill=(0x28, 0xA0, 0xB8))
    return img


def grove_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([3, 12, 29, 30], fill=(0x2A, 0x48, 0x22))
    d.polygon([(8, 16), (16, 2), (24, 16)], fill=(0x48, 0xA0, 0x38))
    d.line([(6, 22), (1, 28)], fill=(0x5A, 0x3A, 0x22), width=2)
    d.line([(26, 22), (31, 28)], fill=(0x5A, 0x3A, 0x22), width=2)
    d.ellipse([12, 16, 15, 19], fill=(0xE8, 0xF0, 0xC0))
    d.ellipse([17, 16, 20, 19], fill=(0xE8, 0xF0, 0xC0))
    return img


def grove_brute() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([4, 16, 28, 28], fill=(0x5A, 0x3A, 0x22))
    d.polygon([(6, 18), (2, 6), (12, 16)], fill=(0x3A, 0x28, 0x14))
    d.polygon([(20, 16), (30, 6), (26, 18)], fill=(0x3A, 0x28, 0x14))
    d.rectangle([14, 18, 18, 24], fill=(0x48, 0xA0, 0x38))
    d.ellipse([10, 19, 13, 22], fill=(0xE0, 0xC8, 0x70))
    d.ellipse([19, 19, 22, 22], fill=(0xE0, 0xC8, 0x70))
    return img


def fen_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([2, 16, 30, 30], fill=(0x3A, 0x38, 0x14))
    d.line([(8, 18), (6, 4)], fill=(0xC8, 0xD8, 0x48), width=2)
    d.line([(16, 16), (16, 2)], fill=(0xE8, 0xF0, 0x80), width=2)
    d.line([(24, 18), (26, 4)], fill=(0xC8, 0xD8, 0x48), width=2)
    d.ellipse([11, 20, 14, 23], fill=(0xE8, 0xF0, 0xA0))
    d.ellipse([18, 20, 21, 23], fill=(0xE8, 0xF0, 0xA0))
    return img


def brass_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.rectangle([6, 8, 26, 28], fill=(0xC8, 0x98, 0x30))
    d.rectangle([2, 12, 8, 22], fill=(0xE0, 0xC0, 0x48))
    d.rectangle([24, 12, 30, 22], fill=(0xE0, 0xC0, 0x48))
    d.ellipse([8, 4, 24, 14], fill=(0xF0, 0xD8, 0x60))
    d.rectangle([14, 16, 18, 24], fill=(0x3A, 0x28, 0x10))
    d.point((12, 8), fill=(0x20, 0x14, 0x08))
    d.point((20, 8), fill=(0x20, 0x14, 0x08))
    return img


def veil_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 12), (30, 6), (26, 16), (30, 26), (16, 20)], fill=(0xE8, 0xC8, 0xF0))
    d.polygon([(16, 12), (2, 6), (6, 16), (2, 26), (16, 20)], fill=(0xC8, 0xA0, 0xD8))
    d.ellipse([12, 12, 20, 20], fill=(0x3A, 0x28, 0x40))
    d.ellipse([13, 15, 15, 17], fill=(0xF8, 0xF0, 0xFF))
    d.ellipse([17, 15, 19, 17], fill=(0xF8, 0xF0, 0xFF))
    return img


def main() -> None:
    sprites = {
        "storm_wraith.png": storm_wraith,
        "rime_wraith.png": rime_wraith,
        "ember_elite.png": ember_elite,
        "ember_brute.png": ember_brute,
        "tide_brute.png": tide_brute,
        "grove_elite.png": grove_elite,
        "grove_brute.png": grove_brute,
        "fen_elite.png": fen_elite,
        "brass_elite.png": brass_elite,
        "veil_elite.png": veil_elite,
    }
    for name, fn in sprites.items():
        _save(fn(), name)
    print(f"late enemy art: {len(sprites)} sprites")


if __name__ == "__main__":
    main()
