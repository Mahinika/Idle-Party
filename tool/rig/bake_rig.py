"""Bake a family skeleton from the dressed idle master.

Reads assets/custom/char/<family>/_src/body_idle.png. Writes
assets/custom/rig/<family>.json and previews under tool/out/rig/.
Does not touch live doll PNGs, the facit lock, or the gear build.

    py -3 tool/rig/bake_rig.py warrior
    py -3 tool/rig/bake_rig.py all
"""

from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image

from families import DRAW_PLATE, DRAW_ROBE, FAMILIES, LIMB_PARENT, RACES, SEXES, FamilyCut

ROOT = Path(__file__).resolve().parents[2]
CANVAS = 128
VERSION = 1

PART_COLORS = {
    "head": (232, 196, 120),
    "torso": (90, 110, 140),
    "skirt": (70, 90, 150),
    "pauldron_l": (180, 140, 60),
    "pauldron_r": (200, 160, 70),
    "upper_l": (120, 80, 70),
    "upper_r": (140, 90, 70),
    "fore_l": (90, 140, 90),
    "fore_r": (70, 160, 90),
    "hand_l": (200, 140, 100),
    "hand_r": (220, 160, 110),
    "thigh_l": (80, 80, 120),
    "thigh_r": (90, 80, 140),
    "shin_l": (60, 100, 120),
    "shin_r": (50, 120, 130),
    "foot_l": (140, 100, 80),
    "foot_r": (160, 110, 80),
}


def _runs(px, y: int, w: int) -> list[tuple[int, int]]:
    segs: list[tuple[int, int]] = []
    start = None
    for x in range(w):
        on = px[x, y][3] > 20
        if on and start is None:
            start = x
        elif not on and start is not None:
            segs.append((start, x - 1))
            start = None
    if start is not None:
        segs.append((start, w - 1))
    return segs


def _arm_name(cut: FamilyCut, side: str, y: int) -> str:
    if y < cut.upper_y:
        return f"upper_{side}"
    if y < cut.fore_y:
        return f"fore_{side}"
    return f"hand_{side}"


def _leg_name(cut: FamilyCut, side: str, y: int) -> str:
    if y < cut.thigh_y:
        return f"thigh_{side}"
    if y < cut.shin_y:
        return f"shin_{side}"
    return f"foot_{side}"


def _outer_edge(segs: list[tuple[int, int]], x: int) -> tuple[int, int] | None:
    for start, end in segs:
        if start <= x <= end:
            return start, end
    return None


def _arm_side(cut: FamilyCut, x: int, y: int, segs: list[tuple[int, int]]) -> str | None:
    """Left or right arm, or None when this pixel is body."""
    if y < cut.arm_y:
        return None
    sleeve_end = cut.sleeve_end or cut.leg_y
    if y >= sleeve_end:
        return None
    if len(segs) >= 3 and (x <= segs[0][1] or x >= segs[-1][0]):
        return "l" if x <= segs[0][1] else "r"
    if cut.torso_x1 and (x < cut.torso_x0 or x > cut.torso_x1):
        side = "l" if x < cut.torso_x0 else "r"
        if cut.arm_width:
            edge = _outer_edge(segs, x)
            if edge is None:
                return None
            start, end = edge
            if side == "l" and x > start + cut.arm_width:
                return None
            if side == "r" and x < end - cut.arm_width:
                return None
        return side
    return None


def _name_at(cut: FamilyCut, x: int, y: int, segs: list[tuple[int, int]]) -> str:
    # A hat or hood above the shoulders is the whole head, not a box on the face.
    if cut.skirt and y < cut.arm_y and y <= cut.head_chin_y:
        return "head"
    # The face stays on the head. A robe must not claim the chin.
    if y <= cut.head_y or (y <= cut.head_chin_y and cut.chin_x0 <= x <= cut.chin_x1):
        return "head"
    if y >= cut.leg_y:
        edge = _outer_edge(segs, x)
        leg_in_row = any(
            not (end < cut.torso_x0 or start > cut.torso_x1) for start, end in segs
        )
        # A cloak tip beside the pants stays on the body. The shoes do not.
        if (
            cut.torso_x1
            and leg_in_row
            and edge is not None
            and (edge[1] < cut.torso_x0 or edge[0] > cut.torso_x1)
        ):
            return "torso"
        return _leg_name(cut, "l" if x < cut.leg_split_x else "r", y)
    side = _arm_side(cut, x, y, segs)
    if side:
        return _arm_name(cut, side, y)
    if y < cut.arm_y and x < cut.pauldron_x_l:
        return "pauldron_l"
    if y < cut.arm_y and x > cut.pauldron_x_r:
        return "pauldron_r"
    # The skirt is the cloth below the sleeves. The chest stays the torso.
    waist = cut.sleeve_end or cut.hem_y
    if cut.skirt and waist <= y < cut.hem_y:
        return "skirt"
    return "torso"


def assign_opaque(px, cut: FamilyCut) -> dict[tuple[int, int], str]:
    labels: dict[tuple[int, int], str] = {}
    for y in range(CANVAS):
        segs = _runs(px, y, CANVAS)
        for x in range(CANVAS):
            if px[x, y][3] <= 20:
                continue
            labels[(x, y)] = _name_at(cut, x, y, segs)
    return labels


def flood_primary(opaque: dict[tuple[int, int], str]) -> list[list[str]]:
    """Every canvas pixel gets exactly one label, nearest opaque part."""
    grid = [[""] * CANVAS for _ in range(CANVAS)]
    q: deque[tuple[int, int]] = deque()
    for (x, y), name in opaque.items():
        grid[y][x] = name
        q.append((x, y))
    while q:
        x, y = q.popleft()
        name = grid[y][x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < CANVAS and 0 <= ny < CANVAS and grid[ny][nx] == "":
                grid[ny][nx] = name
                q.append((nx, ny))
    missing = sum(1 for y in range(CANVAS) for x in range(CANVAS) if grid[y][x] == "")
    if missing:
        raise SystemExit(f"unlabeled pixels: {missing}")
    return grid


def _top_center(pts: set[tuple[int, int]]) -> tuple[float, float]:
    top = min(y for _, y in pts)
    xs = [x for x, y in pts if y <= top + 1]
    return (sum(xs) / len(xs), float(top))


def _bottom_center(pts: set[tuple[int, int]]) -> tuple[float, float]:
    bot = max(y for _, y in pts)
    xs = [x for x, y in pts if y >= bot - 1]
    return (sum(xs) / len(xs), float(bot))


def bone_rests(parts: dict[str, set[tuple[int, int]]]) -> dict[str, tuple[float, float]]:
    waist = (64.0, _bottom_center(parts["torso"])[1])
    rests = {
        "root": waist,
        "torso": waist,
        "head": _bottom_center(parts["head"]),
        "pauldron_l": _top_center(parts["upper_l"]),
        "pauldron_r": _top_center(parts["upper_r"]),
        "upper_l": _top_center(parts["upper_l"]),
        "upper_r": _top_center(parts["upper_r"]),
        "fore_l": _top_center(parts["fore_l"]),
        "fore_r": _top_center(parts["fore_r"]),
        "hand_l": _top_center(parts["hand_l"]),
        "hand_r": _top_center(parts["hand_r"]),
        "thigh_l": _top_center(parts["thigh_l"]),
        "thigh_r": _top_center(parts["thigh_r"]),
        "shin_l": _top_center(parts["shin_l"]),
        "shin_r": _top_center(parts["shin_r"]),
        "foot_l": _top_center(parts["foot_l"]),
        "foot_r": _top_center(parts["foot_r"]),
    }
    if "skirt" in parts and parts["skirt"]:
        rests["skirt"] = _top_center(parts["skirt"])
    return rests


def _rle(pts: set[tuple[int, int]]) -> list[list[int]]:
    rows: dict[int, list[int]] = {}
    for x, y in pts:
        rows.setdefault(y, []).append(x)
    out: list[list[int]] = []
    for y in sorted(rows):
        xs = sorted(rows[y])
        spans: list[int] = [y]
        start = prev = xs[0]
        for x in xs[1:]:
            if x == prev + 1:
                prev = x
                continue
            spans.extend((start, prev))
            start = prev = x
        spans.extend((start, prev))
        out.append(spans)
    return out


def _fist_pixel(frac: tuple[float, float]) -> tuple[int, int]:
    return (int(round(64 + frac[0] * CANVAS)), int(round(64 + frac[1] * CANVAS)))


def _parents(draw: list[str]) -> dict[str, str | None]:
    parents: dict[str, str | None] = {"root": None, "torso": "root"}
    for name in draw:
        if name == "torso":
            continue
        parents[name] = LIMB_PARENT[name][0]
    return parents


def bake(cut: FamilyCut) -> dict:
    src_path = ROOT / "assets" / "custom" / "char" / cut.name / "_src" / "body_idle.png"
    src = Image.open(src_path).convert("RGBA")
    if src.size != (CANVAS, CANVAS):
        raise SystemExit(f"{src_path} is {src.size}, expected {CANVAS}")
    px = src.load()
    opaque = assign_opaque(px, cut)
    grid = flood_primary(opaque)
    draw = DRAW_ROBE if cut.skirt else DRAW_PLATE
    primary_parts: dict[str, set[tuple[int, int]]] = {name: set() for name in draw}
    # Every canvas pixel belongs to the nearest body part, so a thinner
    # undertunic still has a bone where the plate had a gap.
    for y in range(CANVAS):
        for x in range(CANVAS):
            name = grid[y][x]
            if name in primary_parts:
                primary_parts[name].add((x, y))
    opaque_parts = {name: {p for p in pts if p in opaque} for name, pts in primary_parts.items()}
    for name, pts in opaque_parts.items():
        if pts:
            continue
        if name.startswith("pauldron_"):
            continue
        raise SystemExit(f"{cut.name} part {name} is empty")
    rests = bone_rests(opaque_parts)
    # One label per pixel. A joint pad would paint soft cloth twice and darken it.
    masks = {name: set(pts) for name, pts in primary_parts.items()}
    parents = _parents(draw)
    bones = {
        name: {
            "parent": parents[name],
            "rest": [round(rests[name][0], 2), round(rests[name][1], 2)],
        }
        for name in parents
    }
    main_px = _fist_pixel(cut.main_fist)
    off_px = _fist_pixel(cut.off_fist)
    meta = {
        "version": VERSION,
        "canvas": [CANVAS, CANVAS],
        "bones": bones,
        "parts": {name: _rle(masks[name]) for name in draw},
        "primary": {name: _rle(opaque_parts[name]) for name in draw},
        "drawOrder": draw,
        "rigidLayers": {"cape": "torso"},
        "handBones": {
            "main": grid[main_px[1]][main_px[0]],
            "off": grid[off_px[1]][off_px[0]],
        },
    }
    out_dir = ROOT / "assets" / "custom" / "rig"
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{cut.name}.json"
    path.write_text(json.dumps(meta, separators=(",", ":")), encoding="utf-8")
    _preview(cut, src, grid, primary_parts)
    opaque_n = sum(len(pts) for pts in opaque_parts.values())
    print(
        f"{cut.name} opaque {len(opaque)} labeled {opaque_n} "
        f"hands {meta['handBones']} -> {path}"
    )
    if opaque_n != len(opaque):
        raise SystemExit(f"{cut.name} primary labels {opaque_n} != opaque {len(opaque)}")
    return meta


def _preview(
    cut: FamilyCut,
    src: Image.Image,
    grid: list[list[str]],
    parts: dict[str, set[tuple[int, int]]],
) -> None:
    out = ROOT / "tool" / "out" / "rig"
    out.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (CANVAS, CANVAS), (22, 16, 14, 255))
    sp = sheet.load()
    src_px = src.load()
    for y in range(CANVAS):
        for x in range(CANVAS):
            r, g, b, a = src_px[x, y]
            if a <= 20:
                continue
            color = PART_COLORS.get(grid[y][x], (255, 0, 255))
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CANVAS and 0 <= ny < CANVAS and grid[ny][nx] != grid[y][x]:
                    if src_px[nx, ny][3] > 20:
                        edge = True
                        break
            if edge:
                sp[x, y] = (
                    (r + color[0]) // 2,
                    (g + color[1]) // 2,
                    (b + color[2]) // 2,
                    255,
                )
            else:
                sp[x, y] = (
                    (r * 2 + color[0]) // 3,
                    (g * 2 + color[1]) // 3,
                    (b * 2 + color[2]) // 3,
                    255,
                )
    big = sheet.resize((CANVAS * 8, CANVAS * 8), Image.Resampling.NEAREST)
    big.save(out / f"{cut.name}_parts.png")
    _race_sheet(cut, grid, out)


def _race_sheet(cut: FamilyCut, grid: list[list[str]], out: Path) -> None:
    cell = 64
    cols = 6
    paths = []
    folder = ROOT / "assets" / "custom" / "char" / cut.name
    for race in RACES:
        for sex in SEXES:
            path = folder / f"{race}_{sex}_body_idle.png"
            if path.exists():
                paths.append(path)
    if not paths:
        return
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (22, 16, 14))
    for i, path in enumerate(paths):
        im = Image.open(path).convert("RGBA").resize((cell, cell), Image.Resampling.NEAREST)
        scale = cell / CANVAS
        # Border pixels where the part changes.
        px = im.load()
        for y in range(CANVAS):
            for x in range(CANVAS):
                name = grid[y][x]
                edge = False
                for dx, dy in ((1, 0), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if nx < CANVAS and ny < CANVAS and grid[ny][nx] != name:
                        edge = True
                        break
                if edge:
                    sx, sy = int(x * scale), int(y * scale)
                    if 0 <= sx < cell and 0 <= sy < cell:
                        px[sx, sy] = (255, 210, 60, 255)
        ox = (i % cols) * cell
        oy = (i // cols) * cell
        sheet.paste(im.convert("RGB"), (ox, oy))
    sheet.save(out / f"{cut.name}_races.png")


def main() -> None:
    names = list(FAMILIES) if len(sys.argv) < 2 or sys.argv[1] == "all" else sys.argv[1:]
    for name in names:
        if name not in FAMILIES:
            raise SystemExit(f"unknown family {name}")
        bake(FAMILIES[name])


if __name__ == "__main__":
    main()
