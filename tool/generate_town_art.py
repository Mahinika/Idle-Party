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
    "mortar": (86, 78, 70),
    "wood": (118, 74, 38),
    "wood_hi": (156, 108, 56),
    "wood_lo": (72, 44, 24),
    "roof": (148, 58, 40),
    "roof_hi": (186, 86, 58),
    "roof_lo": (108, 38, 26),
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
}


def c(name: str, a: int = 255) -> tuple[int, int, int, int]:
    r, g, b = P[name]
    return (r, g, b, a)


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def brick_wall(d: ImageDraw.ImageDraw, img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    d.rectangle([x0, y0, x1, y1], fill=c("stone"), outline=INK)
    d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=c("stone_hi"))
    row_h = 6
    for i, y in enumerate(range(y0 + 4, y1 - 2, row_h)):
        d.line([(x0 + 1, y), (x1 - 1, y)], fill=c("mortar"))
        shift = 4 if i % 2 else 0
        for x in range(x0 + 3 + shift, x1 - 2, 8):
            d.line([(x, y - 3), (x, y)], fill=c("mortar"))
    d.line([(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], fill=c("stone_lo"))


def timber_wall(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    d.rectangle([x0, y0, x1, y1], fill=c("wood"), outline=INK)
    d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=c("wood_hi"))
    for y in range(y0 + 6, y1 - 2, 7):
        d.line([(x0 + 1, y), (x1 - 1, y)], fill=c("wood_lo"))
    d.rectangle([x0, y0, x0 + 3, y1], fill=c("wood_lo"), outline=INK)
    d.rectangle([x1 - 3, y0, x1, y1], fill=c("wood_lo"), outline=INK)


def tiled_roof(d: ImageDraw.ImageDraw, peak: tuple[int, int], left: tuple[int, int], right: tuple[int, int]) -> None:
    d.polygon([left, peak, right], fill=c("roof"), outline=INK)
    d.line([left, peak], fill=c("roof_hi"))
    for i in range(4):
        y = left[1] - 4 - i * 6
        if y <= peak[1] + 2:
            break
        inset = 6 + i * 5
        d.line([(left[0] + inset, y), (right[0] - inset, y)], fill=c("roof_lo"))


def window(d: ImageDraw.ImageDraw, img: Image.Image, x: int, y: int, w: int = 14, h: int = 12) -> None:
    d.rectangle([x, y, x + w, y + h], fill=c("window"), outline=INK)
    d.line([(x + w // 2, y + 1), (x + w // 2, y + h - 1)], fill=INK_SOFT)
    d.line([(x + 1, y + h // 2), (x + w - 1, y + h // 2)], fill=INK_SOFT)
    px(img, x + 2, y + 2, c("window_hi"))
    px(img, x + 3, y + 3, c("window_hi"))


def door(d: ImageDraw.ImageDraw, x: int, y: int, w: int = 18, h: int = 28) -> None:
    d.rectangle([x, y, x + w, y + h], fill=c("door"), outline=INK)
    d.line([(x + 2, y + 2), (x + 2, y + h - 2)], fill=c("door_hi"))
    d.rectangle([x + 4, y + 4, x + w - 4, y + 14], fill=c("window"), outline=INK)
    d.ellipse([x + w - 7, y + h // 2 + 2, x + w - 4, y + h // 2 + 5], fill=c("metal_hi"))


def generate_backdrop() -> Image.Image:
    img = Image.new("RGBA", (360, 400), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(180):
        t = y / 180.0
        r = int(P["sky_top"][0] * (1 - t) + P["sky_bottom"][0] * t)
        g = int(P["sky_top"][1] * (1 - t) + P["sky_bottom"][1] * t)
        b = int(P["sky_top"][2] * (1 - t) + P["sky_bottom"][2] * t)
        d.line([(0, y), (359, y)], fill=(r, g, b, 255))
    d.polygon(
        [(0, 168), (48, 128), (96, 150), (150, 118), (210, 142),
         (268, 122), (320, 148), (359, 132), (359, 190), (0, 190)],
        fill=c("hill_far"),
    )
    d.polygon(
        [(0, 178), (70, 158), (130, 174), (200, 150), (270, 168),
         (330, 154), (359, 170), (359, 220), (0, 220)],
        fill=c("hill_near"),
    )
    for tx, ty in ((28, 168), (310, 164), (338, 172)):
        d.polygon([(tx, ty + 22), (tx + 8, ty), (tx + 16, ty + 22)], fill=c("tree"))
        d.rectangle([tx + 6, ty + 20, tx + 10, ty + 28], fill=c("wood_lo"))
        px(img, tx + 9, ty + 6, c("tree_hi"))
    d.ellipse([268, 22, 302, 56], fill=(236, 214, 160, 255), outline=INK_SOFT)
    d.ellipse([274, 28, 292, 46], fill=(252, 236, 196, 255))
    for y in range(190, 400):
        t = (y - 190) / 210.0
        r = int(P["ground"][0] * (1 - t) + P["ground_lo"][0] * t)
        g = int(P["ground"][1] * (1 - t) + P["ground_lo"][1] * t)
        b = int(P["ground"][2] * (1 - t) + P["ground_lo"][2] * t)
        d.line([(0, y), (359, y)], fill=(r, g, b, 255))
    d.polygon([(40, 250), (180, 238), (320, 250), (330, 399), (30, 399)], fill=c("path"))
    d.line([(48, 252), (180, 242)], fill=c("ground_hi"))
    return img


def generate_forge() -> Image.Image:
    img = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([18, 118, 86, 126], fill=c("stone_lo"), outline=INK)
    brick_wall(d, img, 14, 52, 82, 118)
    tiled_roof(d, (48, 18), (6, 54), (90, 54))
    d.rectangle([68, 8, 84, 48], fill=c("stone"), outline=INK)
    d.rectangle([66, 4, 86, 12], fill=c("stone_lo"), outline=INK)
    d.rectangle([72, 10, 80, 22], fill=c("stone_lo"))
    for i, (sx, sy) in enumerate(((70, 0), (74, 2), (78, 1), (66, 3))):
        px(img, sx, sy, (160, 160, 164, 140 - i * 20))
        px(img, sx + 1, sy + 1, (148, 148, 152, 100))
    window(d, img, 20, 60)
    window(d, img, 62, 60)
    door(d, 38, 86, 20, 32)
    d.polygon([(22, 112), (36, 100), (50, 112), (44, 116), (28, 116)], fill=c("anvil"), outline=INK)
    d.line([(24, 110), (36, 102)], fill=c("anvil_hi"))
    d.ellipse([16, 108, 26, 118], fill=c("fire_lo"), outline=INK)
    d.ellipse([18, 110, 24, 116], fill=c("fire"))
    px(img, 20, 111, c("fire_hi"))
    px(img, 21, 110, c("fire_hi"))
    d.rectangle([58, 100, 64, 118], fill=c("wood_lo"), outline=INK)
    d.line([(50, 104), (72, 96)], fill=c("metal"), width=2)
    return img


def generate_market() -> Image.Image:
    img = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([12, 118, 88, 126], fill=c("wood_lo"), outline=INK)
    timber_wall(d, 14, 56, 82, 118)
    d.polygon([(2, 40), (48, 16), (94, 40), (94, 56), (2, 56)], fill=c("awning"), outline=INK)
    d.line([(6, 42), (48, 20)], fill=c("awning_hi"))
    for x in range(10, 86, 10):
        drop = abs(x - 48) // 8
        d.line([(x, 40 + drop), (x, 54)], fill=c("awning_lo"))
    window(d, img, 20, 64, 12, 10)
    window(d, img, 64, 64, 12, 10)
    door(d, 38, 84, 20, 34)
    for box, y, w in ((8, 104, 16), (70, 100, 18), (76, 88, 14)):
        d.rectangle([box, y, box + w, 118], fill=c("crate"), outline=INK)
        d.line([(box + 2, y + 2), (box + w - 2, y + 2)], fill=c("crate_hi"))
        d.line([(box + w // 2, y), (box + w // 2, 118)], fill=c("wood_lo"))
    d.ellipse([12, 98, 20, 106], fill=c("awning"), outline=INK)
    d.ellipse([22, 100, 28, 106], fill=(72, 140, 88, 255), outline=INK)
    return img


def generate_inn() -> Image.Image:
    img = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([16, 118, 86, 126], fill=c("stone_lo"), outline=INK)
    brick_wall(d, img, 16, 48, 82, 118)
    d.polygon([(8, 50), (48, 10), (90, 50)], fill=c("thatch"), outline=INK)
    d.line([(12, 48), (48, 14)], fill=c("thatch_hi"))
    for x in range(16, 80, 6):
        d.line([(x, 46 - abs(x - 48) // 3), (x + 3, 50)], fill=c("thatch_lo"))
    window(d, img, 22, 58)
    window(d, img, 60, 58)
    door(d, 38, 82, 20, 36)
    d.rectangle([4, 54, 28, 74], fill=c("sign"), outline=INK)
    d.line([(6, 56), (26, 56)], fill=c("sign_hi"))
    d.rectangle([14, 42, 18, 54], fill=c("wood"), outline=INK)
    d.ellipse([8, 58, 24, 70], fill=c("fire"), outline=INK)
    d.rectangle([14, 62, 18, 72], fill=c("fire_lo"))
    px(img, 12, 62, c("fire_hi"))
    d.rectangle([70, 86, 78, 118], fill=c("wood_lo"), outline=INK)
    d.ellipse([68, 78, 80, 90], fill=c("fire_lo"), outline=INK)
    px(img, 73, 82, c("fire_hi"))
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


def generate_preview() -> Image.Image:
    """360×780 A56-scale composite. Not a screenshot of Flutter."""
    preview = Image.new("RGBA", (360, 780), P["sky_top"] + (255,))
    backdrop = generate_backdrop().resize((360, 420), Image.NEAREST)
    preview.paste(backdrop, (0, 0), backdrop)
    ground = generate_ground().resize((360, 64), Image.NEAREST)
    preview.paste(ground, (0, 390), ground)
    forge = generate_forge()
    market = generate_market()
    inn = generate_inn()
    preview.paste(forge, (18, 248), forge)
    preview.paste(market, (132, 248), market)
    preview.paste(inn, (246, 248), inn)
    d = ImageDraw.Draw(preview)
    d.rectangle([12, 530, 347, 768], fill=(24, 32, 40, 255), outline=INK)
    d.rectangle([24, 548, 336, 572], fill=(18, 24, 32, 255))
    d.text((130, 552), "SANDY CAVERNS", fill=(236, 232, 223, 255))
    for i, x in enumerate((70, 130, 190, 250)):
        d.rounded_rectangle([x, 588, x + 44, 632], radius=4, fill=(20, 24, 30, 255), outline=INK_SOFT)
    d.rectangle([40, 656, 319, 704], fill=(107, 78, 46, 255), outline=(201, 162, 74, 255))
    d.text((148, 672), "ENTER", fill=(255, 226, 168, 255))
    d.rectangle([18, 248, 18 + 96, 248 + 128], outline=(201, 162, 74, 80))
    d.rectangle([132, 248, 132 + 96, 248 + 128], outline=(201, 162, 74, 80))
    d.rectangle([246, 248, 246 + 96, 248 + 128], outline=(201, 162, 74, 80))
    d.rectangle([28, 372, 104, 388], fill=(24, 32, 40, 230))
    d.text((48, 374), "FORGE", fill=(236, 232, 223, 255))
    d.rectangle([142, 372, 218, 388], fill=(24, 32, 40, 230))
    d.text((156, 374), "MARKET", fill=(236, 232, 223, 255))
    d.rectangle([268, 372, 328, 388], fill=(24, 32, 40, 230))
    d.text((290, 374), "INN", fill=(236, 232, 223, 255))
    return preview


def generate_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (320, 160), (12, 16, 22, 255))
    d = ImageDraw.Draw(sheet)
    d.text((8, 6), "Idle Party town buildings  (owned pixel art)", fill=(228, 176, 74, 255))
    for i, (name, fn) in enumerate(
        (("FORGE", generate_forge), ("MARKET", generate_market), ("INN", generate_inn))
    ):
        sprite = fn()
        x = 12 + i * 104
        sheet.paste(sprite, (x, 24), sprite)
        d.text((x + 28, 154), name, fill=(236, 232, 223, 255))
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

These PNGs are the v1 **shipped** town look (tier 0). Higher-tier facades
in `docs/TOWN_DESIGN.md` are proposals, not extra files.

Regenerate:

```
python3 tool/generate_town_art.py
```

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×400 | Sky, hills, dirt square |
| building_forge.png | 96×128 | Chimney, anvil, fire |
| building_market.png | 96×128 | Awning, crates |
| building_inn.png | 96×128 | Thatch, hanging mug sign |
| ground.png | 360×64 | Cobble strip |
| preview_a56.png | 360×780 | Layout composite (not a Flutter screenshot) |
| buildings_sheet.png | 320×160 | Three facades for review |

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

    assets = [
        ("backdrop.png", generate_backdrop()),
        ("building_forge.png", generate_forge()),
        ("building_market.png", generate_market()),
        ("building_inn.png", generate_inn()),
        ("ground.png", generate_ground()),
        ("preview_a56.png", generate_preview()),
        ("buildings_sheet.png", generate_sheet()),
    ]
    for name, img in assets:
        path = ASSETS_DIR / name
        img.save(path)
        print(f"Wrote {path}")

    (ASSETS_DIR / "README.md").write_text(README)
    print(f"Wrote {ASSETS_DIR / 'README.md'}")

    if args.preview:
        dest = Path(args.preview)
        dest.mkdir(parents=True, exist_ok=True)
        for name in ("preview_a56.png", "buildings_sheet.png", "building_forge.png",
                     "building_market.png", "building_inn.png", "backdrop.png"):
            data = (ASSETS_DIR / name).read_bytes()
            (dest / f"town_{name}").write_bytes(data)
            print(f"Copied {dest / ('town_' + name)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
