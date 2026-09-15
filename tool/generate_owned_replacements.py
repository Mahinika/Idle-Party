#!/usr/bin/env py
"""Owned replacements for leftover Kenney runtime art (CC0 Kenney stays on disk).

Run: py tool/generate_owned_replacements.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
CUSTOM = ROOT / "assets" / "custom"
sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_dungeon_art import Generator  # noqa: E402


def _save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)} ({path.stat().st_size} B)")


def _px(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        if len(c) == 3:
            c = (*c, 255)
        img.putpixel((x, y), c)


def dungeon_fallback() -> None:
    out = CUSTOM / "dungeon" / "fallback"
    gob = Generator("goblin")
    sand = Generator("sandy")
    king = Generator("king")
    tide = Generator("tide")

    _save(gob.tile_floor(0), out / "tiles/floor_dirt.png")
    _save(gob.tile_floor(1), out / "tiles/floor_dirt_detail.png")
    _save(sand.tile_floor(0), out / "tiles/floor_sand.png")
    _save(sand.tile_floor(1), out / "tiles/floor_sand_worn.png")
    _save(king.tile_floor(0), out / "tiles/floor_stone.png")
    _save(king.tile_wall(0), out / "tiles/wall_stone.png")
    banner = king.tile_wall(1)
    draw = ImageDraw.Draw(banner)
    draw.rectangle((5, 2, 10, 9), fill=(0x70, 0x28, 0x28, 255))
    draw.rectangle((6, 3, 9, 7), fill=(0xC0, 0x48, 0x40, 255))
    _save(banner, out / "tiles/wall_banner.png")
    _save(king.tile_stairs(False), out / "tiles/stairs.png")
    _save(king.tile_stairs(True), out / "tiles/stairs_boss.png")
    _save(king.tile_door(False), out / "tiles/door_closed.png")
    _save(king.tile_door(True), out / "tiles/door_open.png")
    arch = king.tile_door(True).copy()
    ImageDraw.Draw(arch).arc((1, 1, 14, 12), 200, 340, fill=(0x18, 0x14, 0x10, 255))
    _save(arch, out / "tiles/door_arch.png")

    for name in (
        "barrel",
        "crate",
        "table",
        "stool",
        "torch",
        "torch_alt",
        "gravestone",
        "fountain",
        "trap",
        "pot",
        "bones",
        "skull",
        "hatch",
        "water",
        "lava",
        "anvil",
        "shelf",
        "fence",
        "pillar",
        "rubble",
        "chest",
    ):
        _save(king.prop_by_name(name), out / f"props/{name}.png")

    chest_open = king.prop_chest()
    ImageDraw.Draw(chest_open).rectangle((10, 4, 22, 10), fill=(0xE8, 0xC8, 0x50, 255))
    _save(chest_open, out / "props/chest_open.png")
    mimic = king.prop_chest()
    ImageDraw.Draw(mimic).rectangle((12, 18, 20, 22), fill=(0xC0, 0x30, 0x28, 255))
    _save(mimic, out / "props/chest_mimic.png")

    fx_on = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    ImageDraw.Draw(fx_on).rectangle((4, 4, 11, 11), fill=(0xE8, 0xD0, 0x70, 255))
    _save(fx_on, out / "tiles/fx_target.png")
    fx_off = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    ImageDraw.Draw(fx_off).rectangle((5, 5, 10, 10), fill=(0x60, 0x58, 0x48, 180))
    _save(fx_off, out / "tiles/fx_idle.png")
    slash = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    ImageDraw.Draw(slash).line((3, 12, 12, 3), fill=(0xF0, 0xF0, 0xE0, 255), width=2)
    _save(slash, out / "tiles/fx_slash.png")
    claw = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(claw)
    d.line((4, 11, 6, 3), fill=(0xE0, 0xC0, 0x90, 255), width=1)
    d.line((8, 12, 8, 2), fill=(0xE0, 0xC0, 0x90, 255), width=1)
    d.line((12, 11, 10, 3), fill=(0xE0, 0xC0, 0x90, 255), width=1)
    _save(claw, out / "tiles/fx_claw.png")

    _save(tide.prop_water(), out / "props/water.png")
    _save(tide.hub_icon(), out / "hub_icon.png")


def snake() -> None:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    body = (0x48, 0x88, 0x38)
    hi = (0x78, 0xC0, 0x50)
    lo = (0x28, 0x50, 0x20)
    ink = (0x10, 0x18, 0x0C)
    eye = (0xE8, 0xE0, 0x40)
    # Coiled S from above — not a spider silhouette.
    pts = []
    for i in range(28):
        t = i / 27
        ang = t * 4.8
        r = 18 - t * 10
        x = int(32 + r * __import__("math").cos(ang))
        y = int(36 + r * __import__("math").sin(ang) * 0.85)
        pts.append((x, y))
    for x, y in pts:
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                if dx * dx + dy * dy <= 9:
                    c = hi if dx + dy < 0 else body
                    if dx * dx + dy * dy >= 8:
                        c = ink
                    _px(img, x + dx, y + dy, c)
    head = pts[-1]
    for dx in range(-5, 6):
        for dy in range(-5, 6):
            if dx * dx + dy * dy <= 16:
                _px(img, head[0] + dx, head[1] + dy - 1, hi if dy < 0 else body)
    _px(img, head[0] - 2, head[1] - 2, eye)
    _px(img, head[0] + 2, head[1] - 2, eye)
    _px(img, head[0], head[1] + 4, (0xC0, 0x40, 0x38))
    _save(img, CUSTOM / "enemies/snake.png")


def flask_grey() -> None:
    src = Image.open(CUSTOM / "icons/flask.png").convert("RGBA")
    grey = ImageEnhance.Color(src).enhance(0.05)
    grey = ImageEnhance.Brightness(grey).enhance(1.05)
    _save(grey, CUSTOM / "icons/flask_grey.png")


def _chrome_panel(w: int, h: int, fill, edge, inset=None) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=4, fill=edge)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius=3, fill=fill)
    if inset:
        d.rounded_rectangle((3, 3, w - 4, h - 4), radius=2, outline=inset)
    return img


def ui_chrome() -> None:
    chrome = CUSTOM / "ui/chrome"
    brown = (0x5A, 0x3C, 0x22, 255)
    brown_d = (0x2E, 0x1C, 0x10, 255)
    beige = (0xC8, 0xB0, 0x7C, 255)
    grey = (0x6A, 0x64, 0x5A, 255)
    red = (0x8A, 0x28, 0x20, 255)
    ink = (0x18, 0x10, 0x0A, 255)

    _save(_chrome_panel(48, 48, brown, brown_d), chrome / "panel_brown.png")
    _save(_chrome_panel(48, 48, beige, brown_d), chrome / "panel_beige.png")
    _save(
        _chrome_panel(48, 48, brown, brown_d, inset=(0x3A, 0x24, 0x14, 255)),
        chrome / "panel_inset_brown.png",
    )
    border = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (0, 0, 47, 47), radius=4, outline=ink, width=2
    )
    _save(border, chrome / "panel_border.png")
    _save(_chrome_panel(48, 20, brown, brown_d), chrome / "button_brown.png")
    _save(_chrome_panel(48, 20, grey, ink), chrome / "button_grey.png")
    _save(_chrome_panel(48, 20, red, ink), chrome / "button_red.png")

    hex_img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    ImageDraw.Draw(hex_img).polygon(
        [(16, 2), (28, 9), (28, 23), (16, 30), (4, 23), (4, 9)],
        fill=brown,
        outline=brown_d,
    )
    _save(hex_img, chrome / "hexagon_brown.png")
    hex_d = hex_img.copy()
    ImageDraw.Draw(hex_d).polygon(
        [(16, 2), (28, 9), (28, 23), (16, 30), (4, 23), (4, 9)],
        fill=brown_d,
    )
    _save(hex_d, chrome / "hexagon_brown_dark.png")

    def bar(fill, name: str) -> None:
        img = Image.new("RGBA", (24, 8), (0, 0, 0, 0))
        ImageDraw.Draw(img).rounded_rectangle((0, 0, 23, 7), radius=2, fill=fill)
        _save(img, chrome / name)

    bar((0x48, 0xC0, 0x58, 255), "progress_green.png")
    bar((0x28, 0x70, 0x30, 255), "progress_green_border.png")
    bar((0xC0, 0x38, 0x30, 255), "progress_red.png")
    bar((0x70, 0x18, 0x14, 255), "progress_red_border.png")
    bar((0x48, 0x88, 0xC8, 255), "progress_blue.png")
    bar((0x20, 0x48, 0x78, 255), "progress_blue_border.png")
    bar((0xE8, 0xE0, 0xD0, 255), "progress_white.png")

    def seg(fill, name: str, cap: str) -> None:
        img = Image.new("RGBA", (12, 8), fill)
        _save(img, chrome / name)

    for color, tag in (
        ((0x28, 0x20, 0x18, 255), "back"),
        ((0x48, 0xC0, 0x58, 255), "green"),
        ((0xC0, 0x38, 0x30, 255), "red"),
        ((0xD0, 0xB0, 0x38, 255), "yellow"),
    ):
        seg(color, f"bar_{tag}_left.png", "L")
        seg(color, f"bar_{tag}_mid.png", "M")
        seg(color, f"bar_{tag}_right.png", "R")


def main() -> None:
    print("Owned Kenney replacements…")
    dungeon_fallback()
    snake()
    flask_grey()
    ui_chrome()
    print("Done.")


if __name__ == "__main__":
    main()
