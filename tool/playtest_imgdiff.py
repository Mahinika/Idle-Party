"""Tile diff for /playtest baselines.

A tile counts as changed when its unmasked pixels differ. Moving parts
(the fight, particles) and number labels (gold, timers) are passed in as
rectangles and ignored. Pixel art is compared without smoothing.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

TILE = 36
# Mean absolute channel difference, 0–255, before a tile counts as changed.
TILE_DELTA = 24
# A tile this covered by a mask is skipped.
MASK_COVER = 0.50


def diff_images(
    current_path: Path,
    baseline_path: Path,
    dest: Path,
    mask_rects: list[tuple[int, int, int, int]] | None = None,
) -> dict:
    current = Image.open(current_path).convert("RGB")
    baseline = Image.open(baseline_path).convert("RGB")
    if baseline.size != current.size:
        baseline = baseline.resize(current.size, Image.Resampling.NEAREST)
    masks = list(mask_rects or [])
    changed, total = _changed_tiles(current, baseline, masks)
    frac = (len(changed) / total) if total else 0.0
    marked = current.copy()
    draw = ImageDraw.Draw(marked)
    width, height = current.size
    for x, y in changed:
        x2 = min(width - 1, x + TILE - 1)
        y2 = min(height - 1, y + TILE - 1)
        draw.rectangle([x, y, x2, y2], outline=(255, 48, 48))
    dest.parent.mkdir(parents=True, exist_ok=True)
    marked.save(dest)
    return {
        "changed_frac": round(frac, 4),
        "changed_tiles": len(changed),
        "diff": str(dest),
    }


def contact_sheet(paths: list[Path], dest: Path, cols: int = 3, cell_w: int = 360) -> Path:
    frames = [Image.open(p).convert("RGB") for p in paths if p.exists()]
    if not frames:
        raise SystemExit("contact sheet needs at least one image")
    thumbs = []
    for frame in frames:
        height = max(1, round(frame.height * (cell_w / frame.width)))
        thumbs.append(frame.resize((cell_w, height), Image.Resampling.NEAREST))
    cell_h = max(t.height for t in thumbs)
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (16, 16, 16))
    for i, thumb in enumerate(thumbs):
        sheet.paste(thumb, ((i % cols) * cell_w, (i // cols) * cell_h))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)
    return dest


def scale_rect(
    frac: list[float] | tuple[float, float, float, float],
    width: int,
    height: int,
) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = frac
    return (
        int(x1 * width),
        int(y1 * height),
        int(x2 * width),
        int(y2 * height),
    )


def _changed_tiles(
    current: Image.Image,
    baseline: Image.Image,
    masks: list[tuple[int, int, int, int]],
) -> tuple[list[tuple[int, int]], int]:
    """Average each tile, then compare. Masked tiles are skipped."""
    width, height = current.size
    cols = (width + TILE - 1) // TILE
    rows = (height + TILE - 1) // TILE
    covered = _mask_grid(cols, rows, masks)
    left = _average_tiles(current, cols, rows)
    right = _average_tiles(baseline, cols, rows)
    changed: list[tuple[int, int]] = []
    total = 0
    for row in range(rows):
        for col in range(cols):
            if covered[row][col]:
                continue
            total += 1
            a = left.getpixel((col, row))
            b = right.getpixel((col, row))
            delta = (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])) / 3
            if delta > TILE_DELTA:
                changed.append((col * TILE, row * TILE))
    return changed, total


def _average_tiles(image: Image.Image, cols: int, rows: int) -> Image.Image:
    canvas = Image.new("RGB", (cols * TILE, rows * TILE))
    canvas.paste(image, (0, 0))
    return canvas.resize((cols, rows), Image.Resampling.BOX)


def _mask_grid(
    cols: int,
    rows: int,
    masks: list[tuple[int, int, int, int]],
) -> list[list[bool]]:
    grid = [[False for _ in range(cols)] for _ in range(rows)]
    if not masks:
        return grid
    ink = Image.new("L", (cols * TILE, rows * TILE), 0)
    draw = ImageDraw.Draw(ink)
    for rect in masks:
        draw.rectangle([rect[0], rect[1], rect[2] - 1, rect[3] - 1], fill=255)
    small = ink.resize((cols, rows), Image.Resampling.BOX)
    for row in range(rows):
        for col in range(cols):
            # BOX average above half means the tile is mostly masked.
            grid[row][col] = small.getpixel((col, row)) >= int(255 * MASK_COVER)
    return grid
