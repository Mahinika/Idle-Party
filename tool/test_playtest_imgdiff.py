"""Image diff for /playtest. Draws tiny pictures; no emulator."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw

from playtest_imgdiff import TILE, diff_images, overflow_banner


def _solid(path: Path, color: tuple[int, int, int], box=None, fill=(255, 255, 255)) -> None:
    image = Image.new("RGB", (TILE * 2, TILE * 2), color)
    if box is not None:
        ImageDraw.Draw(image).rectangle(box, fill=fill)
    image.save(path)


def test_identical_images_are_quiet():
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        left = root / "a.png"
        right = root / "b.png"
        _solid(left, (10, 10, 10))
        _solid(right, (10, 10, 10))
        result = diff_images(left, right, root / "diff.png")
        assert result["changed_tiles"] == 0
        assert result["changed_frac"] == 0
        assert Path(result["diff"]).exists()


def test_a_changed_block_is_flagged():
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        left = root / "a.png"
        right = root / "b.png"
        _solid(left, (0, 0, 0))
        _solid(right, (0, 0, 0), box=[TILE, TILE, TILE * 2 - 1, TILE * 2 - 1], fill=(255, 255, 255))
        result = diff_images(left, right, root / "diff.png")
        assert result["changed_tiles"] >= 1
        assert result["changed_frac"] > 0


def test_overflow_stripes_count_and_a_gold_block_does_not():
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        stripe = root / "stripe.png"
        image = Image.new("RGB", (80, 40), (255, 235, 0))
        draw = ImageDraw.Draw(image)
        for offset in range(-40, 80, 6):
            draw.line([(offset, 0), (offset + 40, 40)], fill=(0, 0, 0), width=2)
        image.save(stripe)
        assert overflow_banner(stripe) is True

        dark = root / "dark.png"
        Image.new("RGB", (80, 40), (10, 10, 10)).save(dark)
        assert overflow_banner(dark) is False

        gold = root / "gold.png"
        Image.new("RGB", (80, 40), (255, 180, 40)).save(gold)
        assert overflow_banner(gold) is False

        gold_btn = root / "gold_btn.png"
        btn = Image.new("RGB", (80, 40), (10, 10, 10))
        ImageDraw.Draw(btn).rectangle([10, 10, 70, 30], fill=(255, 235, 0))
        btn.save(gold_btn)
        assert overflow_banner(gold_btn) is False


def test_a_masked_change_is_ignored():
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        left = root / "a.png"
        right = root / "b.png"
        _solid(left, (0, 0, 0))
        _solid(right, (0, 0, 0), box=[TILE, TILE, TILE * 2 - 1, TILE * 2 - 1], fill=(255, 255, 255))
        mask = [(TILE, TILE, TILE * 2, TILE * 2)]
        result = diff_images(left, right, root / "diff.png", mask_rects=mask)
        assert result["changed_tiles"] == 0


if __name__ == "__main__":
    failed = 0
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        try:
            test()
        except Exception as error:
            failed += 1
            print(f"FAIL {test.__name__}: {error}")
        else:
            print(f"ok {test.__name__}")
    raise SystemExit(failed)
