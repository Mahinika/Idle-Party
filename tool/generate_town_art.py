#!/usr/bin/env python3
"""Idle Party town art — owned pixel buildings for the out-of-dungeon hub.

Same legal path as generate_floor_props.py: authored in this repo with PIL,
warm ink, upper-left light, no foreign packs. Run from repo root:

    python3 tool/generate_town_art.py
    python3 tool/generate_town_art.py --preview /opt/cursor/artifacts

Outputs live under assets/custom/town/.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

TOOL_DIR = Path(__file__).resolve().parent
ASSETS_DIR = TOOL_DIR.parent / "assets" / "custom" / "town"

INK = (32, 22, 18, 255)
INK_SOFT = (52, 42, 38, 255)

P = {
    "sky_top": (124, 156, 188),
    "sky_mid": (176, 188, 204),
    "sky_bottom": (214, 198, 178),
    "hill_far": (98, 118, 104),
    "hill_near": (78, 98, 84),
    "tree": (52, 78, 54),
    "tree_hi": (78, 108, 72),
    "ground": (142, 108, 76),
    "ground_hi": (168, 132, 94),
    "ground_lo": (108, 80, 56),
    "cobble": (132, 128, 124),
    "cobble_hi": (164, 158, 150),
    "cobble_lo": (96, 92, 88),
    "stone": (128, 122, 116),
    "stone_hi": (164, 156, 146),
    "stone_lo": (92, 86, 80),
    "stone_pale": (168, 162, 154),
    "mortar": (86, 78, 70),
    "wood": (118, 74, 38),
    "wood_hi": (156, 108, 56),
    "wood_lo": (72, 44, 24),
    "roof": (148, 58, 40),
    "roof_hi": (186, 86, 58),
    "roof_lo": (108, 38, 26),
    "roof_blue": (58, 82, 128),
    "thatch": (186, 150, 88),
    "thatch_hi": (216, 184, 118),
    "thatch_lo": (138, 104, 58),
    "metal": (92, 96, 104),
    "metal_hi": (148, 152, 160),
    "metal_lo": (58, 62, 68),
    "fire": (232, 148, 48),
    "fire_hi": (252, 204, 96),
    "fire_lo": (188, 72, 28),
    "awning": (176, 48, 40),
    "awning_hi": (210, 84, 62),
    "awning_lo": (128, 28, 26),
    "awning2": (48, 92, 78),
    "sign": (96, 62, 32),
    "sign_hi": (132, 92, 48),
    "door": (62, 40, 26),
    "door_hi": (92, 62, 38),
    "window": (48, 78, 108),
    "window_hi": (168, 204, 220),
    "crate": (128, 86, 44),
    "crate_hi": (164, 118, 64),
    "anvil": (72, 76, 84),
    "anvil_hi": (118, 122, 130),
    "path": (168, 140, 102),
    "paper": (228, 214, 186),
    "flower": (196, 72, 96),
    "flower2": (72, 140, 88),
    "banner": (176, 48, 40),
    "banner2": (201, 162, 74),
    "gold": (212, 168, 72),
}


def c(name: str, a: int = 255) -> tuple[int, int, int, int]:
    r, g, b = P[name]
    return (r, g, b, a)


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def brick_wall(
    d: ImageDraw.ImageDraw,
    img: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    pale: bool = False,
) -> None:
    fill = c("stone_pale") if pale else c("stone")
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=INK)
    d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=c("stone_hi"))
    row_h = 7
    for i, y in enumerate(range(y0 + 5, y1 - 2, row_h)):
        d.line([(x0 + 1, y), (x1 - 1, y)], fill=c("mortar"))
        shift = 5 if i % 2 else 0
        for x in range(x0 + 4 + shift, x1 - 2, 10):
            d.line([(x, y - 4), (x, y)], fill=c("mortar"))
    d.line([(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], fill=c("stone_lo"))


def timber_wall(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    d.rectangle([x0, y0, x1, y1], fill=c("wood"), outline=INK)
    d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=c("wood_hi"))
    for y in range(y0 + 7, y1 - 2, 8):
        d.line([(x0 + 1, y), (x1 - 1, y)], fill=c("wood_lo"))
    d.rectangle([x0, y0, x0 + 4, y1], fill=c("wood_lo"), outline=INK)
    d.rectangle([x1 - 4, y0, x1, y1], fill=c("wood_lo"), outline=INK)


def tiled_roof(
    d: ImageDraw.ImageDraw,
    peak: tuple[int, int],
    left: tuple[int, int],
    right: tuple[int, int],
    blue: bool = False,
) -> None:
    fill = c("roof_blue") if blue else c("roof")
    d.polygon([left, peak, right], fill=fill, outline=INK)
    d.line([left, peak], fill=c("roof_hi"))
    for i in range(5):
        y = left[1] - 4 - i * 7
        if y <= peak[1] + 2:
            break
        inset = 8 + i * 6
        d.line([(left[0] + inset, y), (right[0] - inset, y)], fill=c("roof_lo"))


def thatch_roof(d: ImageDraw.ImageDraw, peak: tuple[int, int], left: tuple[int, int], right: tuple[int, int]) -> None:
    d.polygon([left, peak, right], fill=c("thatch"), outline=INK)
    d.line([left, peak], fill=c("thatch_hi"))
    mid = peak[0]
    for x in range(left[0] + 8, right[0] - 6, 7):
        drop = abs(x - mid) // 4
        d.line([(x, left[1] - 4 - drop), (x + 4, left[1])], fill=c("thatch_lo"))


def window(d: ImageDraw.ImageDraw, img: Image.Image, x: int, y: int, w: int = 16, h: int = 14, lit: bool = False) -> None:
    d.rectangle([x, y, x + w, y + h], fill=c("window"), outline=INK)
    d.line([(x + w // 2, y + 1), (x + w // 2, y + h - 1)], fill=INK_SOFT)
    d.line([(x + 1, y + h // 2), (x + w - 1, y + h // 2)], fill=INK_SOFT)
    hi = c("fire_hi") if lit else c("window_hi")
    px(img, x + 2, y + 2, hi)
    px(img, x + 3, y + 3, hi)


def door(d: ImageDraw.ImageDraw, x: int, y: int, w: int = 22, h: int = 36) -> None:
    d.rectangle([x, y, x + w, y + h], fill=c("door"), outline=INK)
    d.line([(x + 2, y + 2), (x + 2, y + h - 2)], fill=c("door_hi"))
    d.rectangle([x + 5, y + 5, x + w - 5, y + 16], fill=c("window"), outline=INK)
    d.ellipse([x + w - 8, y + h // 2 + 2, x + w - 4, y + h // 2 + 6], fill=c("metal_hi"))


def lantern(d: ImageDraw.ImageDraw, img: Image.Image, x: int, y: int) -> None:
    d.rectangle([x + 3, y, x + 5, y + 6], fill=c("wood_lo"), outline=INK)
    d.rectangle([x, y + 6, x + 8, y + 16], fill=c("fire_lo"), outline=INK)
    d.rectangle([x + 2, y + 8, x + 6, y + 14], fill=c("fire"))
    px(img, x + 3, y + 9, c("fire_hi"))


def flowers(d: ImageDraw.ImageDraw, x: int, y: int, w: int = 18) -> None:
    d.rectangle([x, y + 6, x + w, y + 12], fill=c("wood_lo"), outline=INK)
    d.ellipse([x + 2, y, x + 8, y + 8], fill=c("flower"), outline=INK)
    d.ellipse([x + 10, y + 1, x + 16, y + 8], fill=c("flower2"), outline=INK)


def pennant(d: ImageDraw.ImageDraw, x: int, y: int, gold: bool = False) -> None:
    fill = c("banner2") if gold else c("banner")
    d.polygon([(x, y), (x + 10, y), (x + 5, y + 16)], fill=fill, outline=INK)


def sill(d: ImageDraw.ImageDraw, x0: int, y: int, x1: int) -> None:
    d.rectangle([x0, y, x1, y + 4], fill=c("stone_pale"), outline=INK)


def generate_backdrop() -> Image.Image:
    img = Image.new("RGBA", (360, 520), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(220):
        t = y / 220.0
        r = int(P["sky_top"][0] * (1 - t) + P["sky_bottom"][0] * t)
        g = int(P["sky_top"][1] * (1 - t) + P["sky_bottom"][1] * t)
        b = int(P["sky_top"][2] * (1 - t) + P["sky_bottom"][2] * t)
        d.line([(0, y), (359, y)], fill=(r, g, b, 255))
    d.polygon(
        [(0, 188), (48, 148), (96, 170), (150, 138), (210, 162),
         (268, 142), (320, 168), (359, 152), (359, 220), (0, 220)],
        fill=c("hill_far"),
    )
    d.polygon(
        [(0, 198), (70, 178), (130, 194), (200, 170), (270, 188),
         (330, 174), (359, 190), (359, 250), (0, 250)],
        fill=c("hill_near"),
    )
    for tx, ty in ((28, 188), (310, 184), (338, 192)):
        d.polygon([(tx, ty + 22), (tx + 8, ty), (tx + 16, ty + 22)], fill=c("tree"))
        d.rectangle([tx + 6, ty + 20, tx + 10, ty + 28], fill=c("wood_lo"))
        px(img, tx + 9, ty + 6, c("tree_hi"))
    d.ellipse([268, 22, 308, 62], fill=(236, 214, 160, 255), outline=INK_SOFT)
    d.ellipse([276, 30, 298, 52], fill=(252, 236, 196, 255))
    for y in range(210, 520):
        t = (y - 210) / 310.0
        r = int(P["ground"][0] * (1 - t) + P["ground_lo"][0] * t)
        g = int(P["ground"][1] * (1 - t) + P["ground_lo"][1] * t)
        b = int(P["ground"][2] * (1 - t) + P["ground_lo"][2] * t)
        d.line([(0, y), (359, y)], fill=(r, g, b, 255))
    d.polygon([(24, 280), (180, 258), (336, 280), (348, 519), (12, 519)], fill=c("path"))
    d.line([(36, 282), (180, 262)], fill=c("ground_hi"))
    return img


def generate_ground() -> Image.Image:
    img = Image.new("RGBA", (360, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 359, 63], fill=c("ground"))
    for row in range(4):
        y = row * 16
        offset = (row % 2) * 10
        for x in range(-10 + offset, 370, 20):
            d.rectangle([x, y, x + 16, y + 13], fill=c("cobble"), outline=INK_SOFT)
            d.line([(x + 1, y + 2), (x + 15, y + 2)], fill=c("cobble_hi"))
            d.line([(x + 1, y + 11), (x + 15, y + 11)], fill=c("cobble_lo"))
    return img


def generate_well() -> Image.Image:
    img = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 28, 42, 52], fill=c("stone_lo"), outline=INK)
    d.ellipse([10, 24, 38, 46], fill=c("stone"), outline=INK)
    d.ellipse([14, 28, 34, 42], fill=c("window"), outline=INK)
    d.rectangle([21, 8, 27, 30], fill=c("wood_lo"), outline=INK)
    d.rectangle([8, 8, 40, 14], fill=c("wood"), outline=INK)
    d.line([(10, 10), (38, 10)], fill=c("wood_hi"))
    d.ellipse([20, 2, 28, 10], fill=c("metal"), outline=INK)
    return img


def generate_forge(tier: int) -> Image.Image:
    img = Image.new("RGBA", (128, 176), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([18, 164, 114, 174], fill=c("stone_lo"), outline=INK)
    pale = tier >= 1
    brick_wall(d, img, 16, 70, 112, 164, pale=pale)
    tiled_roof(d, (64, 18), (4, 74), (124, 74), blue=tier >= 2)
    d.rectangle([92, 8, 114, 70], fill=c("stone"), outline=INK)
    d.rectangle([88, 4, 118, 14], fill=c("stone_lo"), outline=INK)
    d.rectangle([98, 12, 108, 28], fill=c("stone_lo"))
    for i, (sx, sy) in enumerate(((94, 0), (100, 2), (106, 1), (90, 3))):
        px(img, sx, sy, (160, 160, 164, 140 - i * 20))
    if tier >= 1:
        sill(d, 16, 68, 112)
        lantern(d, img, 20, 108)
    window(d, img, 26, 84, lit=True)
    window(d, img, 82, 84, lit=tier >= 1)
    door(d, 52, 122, 24, 42)
    d.polygon([(22, 156), (40, 140), (58, 156), (50, 162), (30, 162)], fill=c("anvil"), outline=INK)
    d.line([(24, 154), (40, 142)], fill=c("anvil_hi"))
    d.ellipse([16, 148, 30, 162], fill=c("fire_lo"), outline=INK)
    d.ellipse([18, 150, 28, 160], fill=c("fire"))
    px(img, 22, 152, c("fire_hi"))
    d.rectangle([78, 138, 86, 164], fill=c("wood_lo"), outline=INK)
    d.line([(68, 144), (96, 132)], fill=c("metal"), width=3)
    if tier >= 2:
        pennant(d, 56, 28)
        flowers(d, 18, 150)
        d.rectangle([84, 96, 108, 112], fill=c("sign"), outline=INK)
        d.line([(86, 98), (106, 98)], fill=c("sign_hi"))
    return img


def generate_market(tier: int) -> Image.Image:
    img = Image.new("RGBA", (128, 176), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([12, 164, 116, 174], fill=c("wood_lo"), outline=INK)
    if tier == 0:
        timber_wall(d, 16, 78, 112, 164)
    else:
        brick_wall(d, img, 16, 78, 112, 164, pale=True)
    awn = c("awning2") if tier >= 2 else c("awning")
    d.polygon([(2, 56), (64, 22), (126, 56), (126, 78), (2, 78)], fill=awn, outline=INK)
    d.line([(8, 58), (64, 26)], fill=c("awning_hi"))
    for x in range(12, 116, 12):
        drop = abs(x - 64) // 8
        d.line([(x, 56 + drop), (x, 76)], fill=c("awning_lo"))
    if tier >= 1:
        sill(d, 16, 76, 112)
        lantern(d, img, 20, 118)
    window(d, img, 26, 90, 14, 12, lit=tier >= 1)
    window(d, img, 86, 90, 14, 12)
    door(d, 52, 118, 24, 46)
    for box, y, w in ((8, 142, 20), (96, 136, 22), (102, 122, 16)):
        d.rectangle([box, y, box + w, 164], fill=c("crate"), outline=INK)
        d.line([(box + 2, y + 2), (box + w - 2, y + 2)], fill=c("crate_hi"))
        d.line([(box + w // 2, y), (box + w // 2, 164)], fill=c("wood_lo"))
    d.ellipse([14, 134, 24, 144], fill=c("awning"), outline=INK)
    d.ellipse([26, 136, 34, 144], fill=c("flower2"), outline=INK)
    if tier >= 2:
        pennant(d, 58, 24, gold=True)
        flowers(d, 88, 150)
        d.ellipse([16, 128, 26, 138], fill=c("gold"), outline=INK)
    return img


def generate_inn(tier: int) -> Image.Image:
    img = Image.new("RGBA", (128, 176), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([16, 164, 114, 174], fill=c("stone_lo"), outline=INK)
    brick_wall(d, img, 18, 68, 110, 164, pale=tier >= 1)
    if tier == 0:
        thatch_roof(d, (64, 12), (6, 72), (122, 72))
    else:
        tiled_roof(d, (64, 12), (6, 72), (122, 72), blue=tier >= 2)
    if tier >= 1:
        sill(d, 18, 66, 110)
        lantern(d, img, 24, 110)
    window(d, img, 28, 82, lit=True)
    window(d, img, 82, 82, lit=True)
    door(d, 52, 118, 24, 46)
    d.rectangle([4, 74, 32, 98], fill=c("sign"), outline=INK)
    d.line([(6, 76), (30, 76)], fill=c("sign_hi"))
    d.rectangle([16, 60, 20, 74], fill=c("wood"), outline=INK)
    d.ellipse([8, 78, 28, 94], fill=c("fire"), outline=INK)
    d.rectangle([16, 84, 20, 96], fill=c("fire_lo"))
    d.rectangle([94, 122, 104, 164], fill=c("wood_lo"), outline=INK)
    d.ellipse([90, 110, 108, 126], fill=c("fire_lo"), outline=INK)
    px(img, 98, 116, c("fire_hi"))
    if tier >= 2:
        pennant(d, 60, 20)
        flowers(d, 20, 150)
        flowers(d, 90, 150)
    return img


def generate_guild(tier: int) -> Image.Image:
    img = Image.new("RGBA", (152, 204), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([12, 192, 140, 202], fill=c("stone_lo"), outline=INK)
    if tier == 0:
        timber_wall(d, 18, 88, 134, 192)
    else:
        brick_wall(d, img, 18, 88, 134, 192, pale=tier >= 1)
    tiled_roof(d, (76, 18), (4, 92), (148, 92), blue=tier >= 2)
    d.rectangle([58, 8, 94, 70], fill=c("stone"), outline=INK)
    d.polygon([(50, 12), (76, 0), (102, 12), (94, 18), (58, 18)], fill=c("roof"), outline=INK)
    window(d, img, 64, 28, 24, 18, lit=True)
    if tier >= 1:
        sill(d, 18, 86, 134)
        lantern(d, img, 24, 130)
        lantern(d, img, 120, 130)
    # Job board
    d.rectangle([28, 108, 70, 148], fill=c("wood_lo"), outline=INK)
    for i, (px0, py0) in enumerate(((32, 112), (48, 116), (36, 128), (50, 132))):
        d.rectangle([px0, py0, px0 + 12, py0 + 10], fill=c("paper"), outline=INK)
    window(d, img, 86, 108, 18, 14, lit=tier >= 1)
    door(d, 64, 148, 26, 44)
    if tier >= 2:
        pennant(d, 40, 40)
        pennant(d, 100, 40, gold=True)
        flowers(d, 22, 176)
        flowers(d, 112, 176)
        d.rectangle([96, 128, 128, 146], fill=c("sign"), outline=INK)
        d.line([(98, 130), (126, 130)], fill=c("sign_hi"))
    return img


def generate_vault(open_lid: bool) -> Image.Image:
    img = Image.new("RGBA", (88, 112), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 100, 80, 110], fill=c("stone_lo"), outline=INK)
    d.rectangle([14, 48, 74, 100], fill=c("stone"), outline=INK)
    d.line([(16, 50), (72, 50)], fill=c("stone_hi"))
    d.rectangle([20, 56, 68, 94], fill=c("gold") if open_lid else c("wood_lo"), outline=INK)
    if open_lid:
        d.polygon([(20, 56), (68, 56), (74, 28), (14, 28)], fill=c("gold"), outline=INK)
        d.line([(22, 54), (66, 54)], fill=c("fire_hi"))
        d.ellipse([38, 68, 50, 80], fill=c("fire"), outline=INK)
    else:
        d.rectangle([38, 70, 50, 82], fill=c("metal"), outline=INK)
        d.ellipse([40, 72, 48, 80], fill=c("metal_hi"), outline=INK)
        d.line([(24, 64), (64, 64)], fill=c("metal_lo"))
    d.rectangle([36, 36, 52, 48], fill=c("stone_pale"), outline=INK)
    return img


def generate_preview() -> Image.Image:
    """360×780 layout composite (not a Flutter screenshot)."""
    preview = Image.new("RGBA", (360, 780), P["sky_top"] + (255,))
    backdrop = generate_backdrop().resize((360, 520), Image.NEAREST)
    preview.paste(backdrop, (0, 0), backdrop)
    ground = generate_ground()
    preview.paste(ground, (0, 500), ground)
    guild = generate_guild(1).resize((140, 188), Image.NEAREST)
    vault = generate_vault(False)
    forge = generate_forge(1)
    market = generate_market(1)
    inn = generate_inn(1)
    well = generate_well()
    preview.paste(guild, (18, 70), guild)
    preview.paste(vault, (250, 150), vault)
    preview.paste(well, (156, 280), well)
    preview.paste(forge, (8, 340), forge)
    preview.paste(market, (116, 340), market)
    preview.paste(inn, (224, 340), inn)
    d = ImageDraw.Draw(preview)
    d.rectangle([12, 620, 347, 768], fill=(24, 32, 40, 255), outline=INK)
    d.text((110, 628), "Stone town · banners at Ascend 5", fill=(180, 188, 200, 255))
    d.text((118, 648), "SANDY CAVERNS", fill=(236, 232, 223, 255))
    d.rectangle([40, 700, 319, 748], fill=(107, 78, 46, 255), outline=(201, 162, 74, 255))
    d.text((148, 716), "ENTER", fill=(255, 226, 168, 255))
    return preview


def generate_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (520, 420), (12, 16, 22, 255))
    d = ImageDraw.Draw(sheet)
    d.text((8, 6), "Idle Party town  (owned pixel art, three painted tiers)", fill=(228, 176, 74, 255))
    kinds = (
        ("FORGE", generate_forge),
        ("MARKET", generate_market),
        ("INN", generate_inn),
        ("GUILD", generate_guild),
    )
    for col, (name, fn) in enumerate(kinds):
        for tier in range(3):
            sprite = fn(tier)
            sprite = sprite.resize((int(sprite.width * 0.7), int(sprite.height * 0.7)), Image.NEAREST)
            x = 8 + col * 128
            y = 24 + tier * 128
            sheet.paste(sprite, (x, y), sprite)
        d.text((8 + col * 128 + 28, 404), name, fill=(236, 232, 223, 255))
    vault_s = generate_vault(False)
    vault_o = generate_vault(True)
    sheet.paste(vault_s, (430, 40), vault_s)
    sheet.paste(vault_o, (430, 170), vault_o)
    d.text((438, 150), "SHUT", fill=(236, 232, 223, 255))
    d.text((438, 280), "OPEN", fill=(236, 232, 223, 255))
    return sheet


README = """# Town assets

Owned Idle Party pixel art for the out-of-dungeon town hub.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL), same path as `generate_floor_props.py` |
| External packs | None. No Kenney, no marketplace, no paid downloads |
| License | Same as the rest of `assets/custom/` — original game art |

Three **painted** facade tiers (timber / stone / banners). AL10 pennants and
AL20 lantern arcade are drawn in Flutter on top of these sprites.

Regenerate:

```
python3 tool/generate_town_art.py
```

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×520 | Sky, hills, dirt square |
| ground.png | 360×64 | Cobble strip |
| well.png | 48×56 | Square well (non-interactive) |
| forge_t0/t1/t2.png | 128×176 | Forge facades |
| market_t0/t1/t2.png | 128×176 | Market facades |
| inn_t0/t1/t2.png | 128×176 | Inn facades |
| guild_t0/t1/t2.png | 152×204 | Guild hall facades |
| vault_shut.png / vault_open.png | 88×112 | Daily Vault chest |
| preview_a56.png | 360×780 | Layout composite (not a Flutter screenshot) |
| buildings_sheet.png | 520×420 | Tier strip for review |

Paint with `FilterQuality.none` via `CustomAssets.town*`.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preview",
        default="",
        help="Also copy preview PNGs to this directory",
    )
    args = parser.parse_args()
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    assets: list[tuple[str, Image.Image]] = [
        ("backdrop.png", generate_backdrop()),
        ("ground.png", generate_ground()),
        ("well.png", generate_well()),
        ("vault_shut.png", generate_vault(False)),
        ("vault_open.png", generate_vault(True)),
        ("preview_a56.png", generate_preview()),
        ("buildings_sheet.png", generate_sheet()),
    ]
    for t in range(3):
        assets.extend(
            [
                (f"forge_t{t}.png", generate_forge(t)),
                (f"market_t{t}.png", generate_market(t)),
                (f"inn_t{t}.png", generate_inn(t)),
                (f"guild_t{t}.png", generate_guild(t)),
            ]
        )
    for name, img in assets:
        path = ASSETS_DIR / name
        img.save(path)
        print(f"Wrote {path}")

    (ASSETS_DIR / "README.md").write_text(README)
    print(f"Wrote {ASSETS_DIR / 'README.md'}")

    # Drop superseded 96×128 v1 names so the folder only holds current art.
    for stale in (
        "building_forge.png",
        "building_market.png",
        "building_inn.png",
    ):
        stale_path = ASSETS_DIR / stale
        if stale_path.exists():
            stale_path.unlink()
            print(f"Removed {stale_path}")

    if args.preview:
        dest = Path(args.preview)
        dest.mkdir(parents=True, exist_ok=True)
        for name in (
            "preview_a56.png",
            "buildings_sheet.png",
            "forge_t0.png",
            "forge_t1.png",
            "forge_t2.png",
            "market_t1.png",
            "inn_t1.png",
            "guild_t1.png",
            "vault_shut.png",
            "vault_open.png",
            "backdrop.png",
            "well.png",
        ):
            data = (ASSETS_DIR / name).read_bytes()
            (dest / f"town_{name}").write_bytes(data)
            print(f"Copied {dest / ('town_' + name)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
