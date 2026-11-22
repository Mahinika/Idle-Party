#!/usr/bin/env python3
"""Artifacts for town art review (folk vs yard heroes, lawn tile, clumps)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOWN = ROOT / "assets" / "custom" / "town"
ART = Path("/opt/cursor/artifacts")
GOLDENS = ROOT / "test" / "goldens" / "town"
DOCK = 40  # HeroDollSprite size on A56 town (see town_viewport.dart).


def _scale_nearest(im: Image.Image, w: int, h: int) -> Image.Image:
    return im.resize((w, h), Image.Resampling.NEAREST)


def main() -> None:
    ART.mkdir(parents=True, exist_ok=True)
    ground = Image.open(TOWN / "ground.png")
    folk = Image.open(TOWN / "folk.png")

    w, h = ground.size
    tiled = Image.new("RGB", (w * 4, h * 4))
    for ty in range(4):
        for tx in range(4):
            tiled.paste(ground.convert("RGB"), (tx * w, ty * h))
    tiled.save(ART / "ground_new_4x4.png")

    idle_row = Image.new("RGBA", (96 * 3, 112))
    for i in range(3):
        idle_row.paste(folk.crop((0, i * 112, 96, (i + 1) * 112)), (i * 96, 0))
    idle_big = _scale_nearest(idle_row, 96 * 3 * 3, 112 * 3)
    idle_big.save(ART / "folk_new_three.png")

    for name in ("meadow", "thicket", "wild"):
        src = TOWN / f"{name}.png"
        im = Image.open(src)
        _scale_nearest(im, im.width * 4, im.height * 4).save(ART / f"{name}.png")

    Image.open(TOWN / "ground.png").save(ART / "ground.png")
    Image.open(TOWN / "folk.png").save(ART / "folk.png")

    after = Image.open(GOLDENS / "home_shell_town_a56.png").convert("RGBA")
    before = Image.open(ART / "town_before_a56.png").convert("RGBA")
    combo = Image.new("RGBA", (after.width * 2, after.height), (32, 24, 36, 255))
    combo.paste(before, (0, 0))
    combo.paste(after, (after.width, 0))
    combo.save(ART / "town_a56_before_after.png")

    # Party row from the town golden (live HeroDollSprite at yard scale).
    party = after.crop((70, after.height - 130, 290, after.height - 24))
    folk_guard = folk.crop((0, 0, 96, 112))
    folk_h = DOCK + 16
    folk_w = int(folk_h * (96 / 112))
    folk_scaled = _scale_nearest(folk_guard, folk_w, folk_h)
    panel_w = max(party.width, folk_w * 2 + 24)
    panel_h = max(party.height, folk_h) + 8
    compare = Image.new("RGBA", (panel_w, panel_h), (48, 40, 52, 255))
    compare.paste(party, (8, 8))
    compare.paste(folk_scaled, (party.width + 16, 8))
    compare.save(ART / "folk_vs_party_yard_scale.png")
    _scale_nearest(compare, compare.width * 2, compare.height * 2).save(
        ART / "folk_vs_party_yard_scale_2x.png"
    )
    print(f"wrote artifacts under {ART}")


if __name__ == "__main__":
    main()