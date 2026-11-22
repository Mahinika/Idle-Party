#!/usr/bin/env python3
"""QA PNGs for town lawn + folk PRs. Owned art only."""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOWN = ROOT / "assets" / "custom" / "town"
HERO_ASSET = ROOT / "assets" / "custom" / "heroes" / "knight.png"
ARTIFACTS = Path("/opt/cursor/artifacts")
BASE_SHA = "87f626ddea05f189acec359637972b948fcf826e"
A56_PARTY_DOLL = 40.0
FOLK_YARD_H = A56_PARTY_DOLL * 56 / 40
UPSCALE = 4
NEUTRAL_BG = (40, 38, 44, 255)


def _alpha_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    return im.split()[3].getbbox()


def _load_hero(yard_h: int) -> Image.Image:
    """Starter warrior body used by HeroDollSprite fallback (knight.png)."""
    hero = Image.open(HERO_ASSET).convert("RGBA")
    bb = _alpha_bbox(hero)
    if bb is None:
        raise RuntimeError(f"empty hero asset {HERO_ASSET}")
    hero = hero.crop(bb)
    return hero.resize((yard_h, yard_h), Image.Resampling.NEAREST)


def grass_4x4() -> None:
    tile = Image.open(TOWN / "ground.png").convert("RGBA")
    w, h = tile.size
    native = Image.new("RGBA", (w * 4, h * 4))
    for ty in range(4):
        for tx in range(4):
            native.paste(tile, (tx * w, ty * h))
    zoom = native.resize(
        (native.width * UPSCALE, native.height * UPSCALE), Image.Resampling.NEAREST
    )
    gap = 8
    sheet = Image.new(
        "RGBA",
        (native.width + zoom.width + gap, max(native.height, zoom.height)),
        (24, 20, 28, 255),
    )
    sheet.paste(native, (0, 0))
    sheet.paste(zoom, (native.width + gap, 0))
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    out = ARTIFACTS / "grass_4x4.png"
    sheet.save(out)
    print(f"wrote {out} tile={w}")


def grass_closeup_4x() -> None:
    tile = Image.open(TOWN / "ground.png").convert("RGBA")
    big = tile.resize(
        (tile.width * UPSCALE * 2, tile.height * UPSCALE * 2),
        Image.Resampling.NEAREST,
    )
    out = ARTIFACTS / "grass_closeup_4x.png"
    big.save(out)
    print(f"wrote {out}")


def folk_sheet_4x() -> None:
    folk = Image.open(TOWN / "folk.png").convert("RGBA")
    big = folk.resize(
        (folk.width * UPSCALE, folk.height * UPSCALE), Image.Resampling.NEAREST
    )
    out = ARTIFACTS / "folk_sheet_4x.png"
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    big.save(out)
    print(f"wrote {out}")


def folk_vs_hero() -> None:
    folk = Image.open(TOWN / "folk.png").convert("RGBA")
    yard_h = int(FOLK_YARD_H)
    yard_w = int(yard_h * 96 / 112)
    cells = []
    for person in range(3):
        cell = folk.crop((0, person * 112, 96, (person + 1) * 112))
        cells.append(cell.resize((yard_w, yard_h), Image.Resampling.NEAREST))

    hero = _load_hero(yard_h)

    pad = 12
    row_h = yard_h + pad * 2
    row_w = yard_w * 3 + hero.width + pad * 5
    row = Image.new("RGBA", (row_w, row_h), NEUTRAL_BG)
    x = pad
    for cell in cells:
        row.paste(cell, (x, pad), cell)
        x += yard_w + pad
    row.paste(hero, (x, pad), hero)
    upscaled = row.resize((row_w * UPSCALE, row_h * UPSCALE), Image.Resampling.NEAREST)
    out = ARTIFACTS / "folk_vs_hero.png"
    upscaled.save(out)
    print(f"wrote {out} hero={HERO_ASSET.name} yard_h={yard_h}")


def stone_house_closeup() -> None:
    """Inn facade + path strip for stone/roof depth check."""
    inn = Image.open(TOWN / "inn_t1.png").convert("RGBA")
    path = Image.open(TOWN / "path.png").convert("RGBA")
    crop_w, crop_h = 120, 110
    sheet = Image.new("RGBA", (crop_w, crop_h), (28, 26, 32, 255))
    inn_part = inn.crop((0, 18, crop_w, min(inn.height, 18 + crop_h - 28)))
    sheet.paste(inn_part, (0, 0), inn_part)
    path_strip = path.crop((40, 0, 180, 36))
    sheet.paste(path_strip, (8, crop_h - 40), path_strip)
    contact = Image.open(TOWN / "contact.png").convert("RGBA")
    contact_small = contact.resize((80, 16), Image.Resampling.NEAREST)
    sheet.paste(contact_small, (30, crop_h - 48), contact_small)
    big = sheet.resize((crop_w * UPSCALE, crop_h * UPSCALE), Image.Resampling.NEAREST)
    out = ARTIFACTS / "stone_house_closeup.png"
    big.save(out)
    print(f"wrote {out}")


def town_before_after() -> None:
    golden_after = ROOT / "test" / "goldens" / "town" / "town_preview_a56.png"
    if not golden_after.exists():
        raise SystemExit("run town goldens before artifacts")
    before_path = ARTIFACTS / "_town_preview_base.png"
    with before_path.open("wb") as fh:
        subprocess.run(
            ["git", "show", f"{BASE_SHA}:test/goldens/town/town_preview_a56.png"],
            cwd=ROOT,
            check=True,
            stdout=fh,
        )
    before = Image.open(before_path).convert("RGBA")
    after = Image.open(golden_after).convert("RGBA")
    h = max(before.height, after.height)
    if before.height != h:
        before = before.resize((before.width, h), Image.Resampling.NEAREST)
    if after.height != h:
        after = after.resize((after.width, h), Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", (before.width + after.width + 4, h))
    sheet.paste(before, (0, 0))
    sheet.paste(after, (before.width + 4, 0))
    out = ARTIFACTS / "town_A56_before_after.png"
    sheet.save(out)
    print(f"wrote {out}")


def main() -> int:
    grass_4x4()
    grass_closeup_4x()
    folk_sheet_4x()
    folk_vs_hero()
    stone_house_closeup()
    town_before_after()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())