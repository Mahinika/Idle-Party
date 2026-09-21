#!/usr/bin/env py
"""Owned silhouettes for early-zone packs that still shared a sprite.

32×32 enemies, 16×16 King's Fort wall rims. 1 px outline, nearest-neighbor.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom"
ENEMIES = ROOT / "enemies"
OUT = (0x14, 0x10, 0x0C, 255)


def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


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


def _blank() -> Image.Image:
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))


def sandy_brute() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([4, 14, 28, 28], fill=(0xC8, 0x88, 0x40))
    d.polygon([(8, 16), (12, 6), (16, 16)], fill=(0xE0, 0xB0, 0x68))
    d.polygon([(16, 16), (20, 6), (24, 16)], fill=(0xA0, 0x68, 0x30))
    d.ellipse([10, 18, 14, 22], fill=(0x3A, 0x24, 0x14))
    d.ellipse([18, 18, 22, 22], fill=(0x3A, 0x24, 0x14))
    _rim(img)
    return img


def sandy_tank() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([3, 8, 29, 30], fill=(0x8A, 0x64, 0x38))
    d.rectangle([8, 12, 24, 22], fill=(0x5A, 0x40, 0x24))
    d.ellipse([11, 14, 15, 18], fill=(0xE0, 0xC0, 0x70))
    d.ellipse([17, 14, 21, 18], fill=(0xE0, 0xC0, 0x70))
    _rim(img)
    return img


def sandy_ranged() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([10, 6, 22, 16], fill=(0xE0, 0xC8, 0x78))
    d.polygon([(12, 16), (20, 16), (18, 28), (14, 28)], fill=(0xC8, 0x98, 0x48))
    d.ellipse([20, 10, 28, 16], fill=(0xF0, 0xE0, 0xA0))
    d.ellipse([13, 9, 15, 11], fill=(0x3A, 0x24, 0x14))
    _rim(img)
    return img


def goblin_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([10, 4, 22, 14], fill=(0x48, 0xB0, 0x48))
    d.polygon([(6, 8), (10, 6), (10, 12)], fill=(0x2A, 0x70, 0x30))
    d.polygon([(22, 6), (26, 8), (22, 12)], fill=(0x2A, 0x70, 0x30))
    d.rectangle([11, 14, 21, 26], fill=(0x38, 0x88, 0x38))
    d.line([(22, 16), (29, 8)], fill=(0x8A, 0x5A, 0x30), width=2)
    d.ellipse([12, 7, 14, 9], fill=(0x10, 0x20, 0x10))
    d.ellipse([18, 7, 20, 9], fill=(0x10, 0x20, 0x10))
    _rim(img)
    return img


def goblin_tank() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([6, 8, 26, 28], fill=(0x2E, 0x78, 0x34))
    d.rectangle([4, 12, 12, 26], fill=(0x6A, 0x50, 0x30))
    d.ellipse([12, 12, 16, 16], fill=(0xE0, 0xE8, 0x40))
    d.ellipse([17, 12, 21, 16], fill=(0xE0, 0xE8, 0x40))
    _rim(img)
    return img


def goblin_ranged() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([12, 4, 20, 12], fill=(0x70, 0xC8, 0x50))
    d.polygon([(13, 12), (19, 12), (17, 26), (15, 26)], fill=(0x3A, 0x90, 0x38))
    d.ellipse([20, 14, 28, 20], fill=(0x80, 0x70, 0x60))
    d.line([(18, 16), (24, 16)], fill=(0xC8, 0xB0, 0x70), width=1)
    _rim(img)
    return img


def king_guard() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.rectangle([11, 4, 21, 10], fill=(0xC8, 0xC0, 0xB0))
    d.rectangle([10, 10, 22, 26], fill=(0x30, 0x48, 0x88))
    d.rectangle([14, 12, 18, 22], fill=(0xE0, 0xC0, 0x40))
    d.rectangle([8, 14, 10, 24], fill=(0x70, 0x78, 0x88))
    _rim(img)
    return img


def king_tank() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.rectangle([8, 4, 24, 12], fill=(0xD0, 0xD4, 0xE0))
    d.rectangle([7, 12, 25, 28], fill=(0x20, 0x30, 0x68))
    d.rectangle([2, 10, 10, 26], fill=(0x88, 0x90, 0xA8))
    d.rectangle([12, 16, 16, 18], fill=(0xE8, 0xD0, 0x50))
    _rim(img)
    return img


def underworld_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.ellipse([6, 6, 26, 26], fill=(0x48, 0x28, 0x78))
    d.ellipse([12, 11, 20, 19], fill=(0xF0, 0xE0, 0x40))
    d.ellipse([15, 14, 17, 16], fill=(0x18, 0x08, 0x20))
    d.polygon([(8, 20), (4, 28), (12, 24)], fill=(0x70, 0x40, 0xA0))
    d.polygon([(20, 20), (28, 28), (20, 24)], fill=(0x70, 0x40, 0xA0))
    _rim(img)
    return img


def dead_swarm() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    bone = (0xD8, 0xE0, 0xC8)
    for box in ((4, 14, 14, 24), (12, 8, 22, 18), (18, 16, 28, 26)):
        d.ellipse(box, fill=bone)
    d.ellipse([7, 17, 9, 19], fill=(0x20, 0x28, 0x20))
    d.ellipse([15, 11, 17, 13], fill=(0x20, 0x28, 0x20))
    d.ellipse([21, 19, 23, 21], fill=(0x20, 0x28, 0x20))
    _rim(img)
    return img


def dead_support() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 4), (24, 12), (8, 12)], fill=(0x48, 0x68, 0x58))
    d.polygon([(10, 12), (22, 12), (20, 28), (12, 28)], fill=(0x30, 0x48, 0x40))
    d.line([(22, 10), (28, 4)], fill=(0xC8, 0xD0, 0xB0), width=2)
    d.ellipse([13, 14, 15, 16], fill=(0xA0, 0xE0, 0x80))
    d.ellipse([17, 14, 19, 16], fill=(0xA0, 0xE0, 0x80))
    _rim(img)
    return img


def hell_elite() -> Image.Image:
    img = _blank()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 2), (20, 10), (12, 10)], fill=(0xE8, 0x40, 0x28))
    d.ellipse([8, 10, 24, 26], fill=(0xA0, 0x18, 0x14))
    d.polygon([(8, 12), (2, 6), (10, 16)], fill=(0x60, 0x10, 0x0C))
    d.polygon([(24, 12), (30, 6), (22, 16)], fill=(0x60, 0x10, 0x0C))
    d.ellipse([12, 14, 15, 17], fill=(0xFF, 0xE0, 0x40))
    d.ellipse([17, 14, 20, 17], fill=(0xFF, 0xE0, 0x40))
    _rim(img)
    return img


def king_wall(variant: int) -> Image.Image:
    img = Image.new("RGB", (16, 16), (0x18, 0x22, 0x38))
    d = ImageDraw.Draw(img)
    for x in range(16):
        img.putpixel((x, 0), (0x70, 0x80, 0xA0))
        img.putpixel((x, 1), (0x38, 0x48, 0x68))
        img.putpixel((x, 15), (0x08, 0x0C, 0x16))
    for y in range(3, 14, 4):
        d.line([(0, y), (15, y)], fill=(0x0C, 0x14, 0x24))
    # Banner cloth hanging on the stone.
    x0 = 5 if variant == 0 else 9
    d.rectangle([x0, 2, x0 + 3, 12], fill=(0xC8, 0x3A, 0x48))
    d.line([(x0, 6), (x0 + 3, 6)], fill=(0xE8, 0xC8, 0x40))
    return img


def main() -> None:
    sprites = {
        "sandy_brute.png": sandy_brute,
        "sandy_tank.png": sandy_tank,
        "sandy_ranged.png": sandy_ranged,
        "goblin_elite.png": goblin_elite,
        "goblin_tank.png": goblin_tank,
        "goblin_ranged.png": goblin_ranged,
        "king_guard.png": king_guard,
        "king_tank.png": king_tank,
        "underworld_elite.png": underworld_elite,
        "dead_swarm.png": dead_swarm,
        "dead_support.png": dead_support,
        "hell_elite.png": hell_elite,
    }
    for name, fn in sprites.items():
        _save(fn(), ENEMIES / name)
    king = ROOT / "dungeon" / "king" / "tiles"
    _save(king_wall(0), king / "wall_a.png")
    _save(king_wall(1), king / "wall_b.png")
    print(f"early enemy art: {len(sprites)} sprites + king walls")


if __name__ == "__main__":
    main()
