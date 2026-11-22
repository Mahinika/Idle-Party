#!/usr/bin/env python3
"""QA PNGs for town lawn + folk PRs. Owned art only."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOWN = ROOT / "assets" / "custom" / "town"
ARTIFACTS = Path("/opt/cursor/artifacts")
BASE_SHA = "022192cbfe5aa9210861d280c749580ee52ebcf6"


def grass_4x4() -> None:
    tile = Image.open(TOWN / "ground.png").convert("RGBA")
    w, h = tile.size
    native = Image.new("RGBA", (w * 4, h * 4))
    for y in range(4):
        for x in range(4):
            native.paste(tile, (x * w, y * h))
    zoom = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", (native.width + zoom.width + 8, max(native.height, zoom.height)), (24, 20, 28, 255))
    sheet.paste(native, (0, 0))
    sheet.paste(zoom, (native.width + 8, 0))
    out = ARTIFACTS / "grass_4x4.png"
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"wrote {out}")


def folk_vs_hero() -> None:
    folk = Image.open(TOWN / "folk.png").convert("RGBA")
    cell = folk.crop((0, 0, 96, 112))
    yard_h = 40
    shown = cell.resize((int(yard_h * 96 / 112), yard_h), Image.Resampling.NEAREST)

    hero_src = ROOT / "test" / "goldens" / "town" / "home_shell_town_a56.png"
    if not hero_src.exists():
        print(f"skip folk_vs_hero: missing {hero_src}", file=sys.stderr)
        return
    town = Image.open(hero_src)
    w, h = town.size
    doll = town.crop((w // 2 - 22, h - 52, w // 2 + 18, h - 8)).resize(
        (yard_h, yard_h), Image.Resampling.NEAREST
    )
    sheet = Image.new("RGBA", (shown.width + doll.width + 24, 60), (0, 0, 0, 255))
    sheet.paste(shown, (0, 4))
    sheet.paste(doll, (shown.width + 24, 4))
    out = ARTIFACTS / "folk_vs_hero.png"
    sheet.save(out)
    print(f"wrote {out}")


def town_before_after() -> None:
    golden_after = ROOT / "test" / "goldens" / "town" / "town_preview_a56.png"
    if not golden_after.exists():
        print("skip town_before_after: run town goldens first", file=sys.stderr)
        return
    before_path = ARTIFACTS / "_town_preview_base.png"
    subprocess.run(
        ["git", "show", f"{BASE_SHA}:test/goldens/town/town_preview_a56.png"],
        cwd=ROOT,
        check=True,
        stdout=before_path.open("wb"),
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
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"wrote {out}")


def main() -> int:
    grass_4x4()
    folk_vs_hero()
    town_before_after()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())