#!/usr/bin/env python3
"""QA PNGs for town lawn + folk PRs. Owned art only."""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOWN = ROOT / "assets" / "custom" / "town"
ARTIFACTS = Path("/opt/cursor/artifacts")
BASE_SHA = "022192cbfe5aa9210861d280c749580ee52ebcf6"
A56_PARTY_DOLL = 40.0
FOLK_YARD_H = A56_PARTY_DOLL * 56 / 40
UPSCALE = 4


def _alpha_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    return im.split()[3].getbbox()


def _crop_hero(im: Image.Image) -> Image.Image:
    """Center party hero from home shell town golden (shell_golden_harness A56)."""
    w, h = im.size
    # Measured on test/goldens/town/home_shell_town_a56.png — middle doll in party row.
    boxes: dict[tuple[int, int], tuple[int, int, int, int]] = {
        (360, 780): (120, 430, 160, 482),
    }
    box = boxes.get((w, h))
    if box is None:
        raise RuntimeError(f"no hero crop table for {w}x{h}")
    hero = im.crop(box)
    bb = _alpha_bbox(hero)
    if bb is None:
        raise RuntimeError("party hero crop is empty")
    hero = hero.crop(bb)
    return hero.resize((int(FOLK_YARD_H), int(FOLK_YARD_H)), Image.Resampling.NEAREST)


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

    golden = ROOT / "test" / "goldens" / "town" / "home_shell_town_a56.png"
    if not golden.exists():
        raise RuntimeError(f"missing {golden}")
    hero = _crop_hero(Image.open(golden))

    pad = 12
    row_h = yard_h + pad * 2
    row_w = yard_w * 3 + hero.width + pad * 5
    row = Image.new("RGBA", (row_w, row_h), (0, 0, 0, 255))
    x = pad
    for cell in cells:
        row.paste(cell, (x, pad), cell)
        x += yard_w + pad
    row.paste(hero, (x, pad), hero)
    upscaled = row.resize((row_w * UPSCALE, row_h * UPSCALE), Image.Resampling.NEAREST)
    out = ARTIFACTS / "folk_vs_hero.png"
    upscaled.save(out)
    print(f"wrote {out} logical {row_w}x{row_h} yard_h={yard_h}")


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
    folk_sheet_4x()
    folk_vs_hero()
    town_before_after()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())