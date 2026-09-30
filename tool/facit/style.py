"""Palette, outline, light, and pixel-density checks."""
from __future__ import annotations

import re

from PIL import Image

from facit.findings import Finding
from gear_style import (
    AUTHORED_MAX_COLORS,
    EXTRACT_MIN_COLORS,
    INK,
    MAX_BLACK_EDGE,
    MAX_BLOCK,
    MIN_LIGHT,
    PALETTE_MAX_DIST,
    allowed_colors,
)
from paper_doll_manifest import FAMILIES, NATIVE_MATERIAL
from paper_doll_paths import CHAR, REPO

_AUTHORED = re.compile(
    r"^(helm|chest|legs|cloak|hands|shoulder)_(.+)_(t0|t2|short|broad)_idle\.png$"
)
_NATIVE = re.compile(
    r"^(helm|chest|legs|cloak|hands|shoulder)_(t0|t2)_idle\.png$"
)


def _colors(im: Image.Image) -> list[tuple[int, int, int]]:
    px = im.convert("RGBA").load()
    w, h = im.size
    seen: set[tuple[int, int, int]] = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 40:
                seen.add((r, g, b))
    return list(seen)


def _edge_and_light(im: Image.Image) -> tuple[float, float, float]:
    """Black-edge share, upper-left light correlation, 2×2 block share."""
    px = im.convert("RGBA").load()
    w, h = im.size
    edge_n = black = 0
    xs: list[int] = []
    ys: list[int] = []
    lums: list[float] = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            edge = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] < 40:
                    edge = True
                    break
            if edge:
                edge_n += 1
                if max(r, g, b) < 16:
                    black += 1
            xs.append(x)
            ys.append(y)
            lums.append(0.299 * r + 0.587 * g + 0.114 * b)
    if len(lums) < 8 or edge_n == 0:
        return 0.0, 0.0, 0.0
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    mean_l = sum(lums) / len(lums)
    num = den_l = den_p = 0.0
    for x, y, lum in zip(xs, ys, lums):
        # Brighter toward upper-left → positive correlation with -(dx+dy).
        pos = -((x - cx) + (y - cy))
        dl = lum - mean_l
        num += dl * pos
        den_l += dl * dl
        den_p += pos * pos
    light = num / ((den_l * den_p) ** 0.5) if den_l > 0 and den_p > 0 else 0.0
    blocks = hit = 0
    for y in range(0, h - 1, 2):
        for x in range(0, w - 1, 2):
            block = [px[x + dx, y + dy] for dy in (0, 1) for dx in (0, 1)]
            if not any(p[3] >= 40 for p in block):
                continue
            blocks += 1
            if block[0] == block[1] == block[2] == block[3]:
                hit += 1
    return black / edge_n, light, (hit / blocks if blocks else 0.0)


def authored_problems(im: Image.Image, material: str) -> list[str]:
    keys: list[str] = []
    cols = _colors(im)
    if len(cols) > AUTHORED_MAX_COLORS:
        keys.append("too-many-colors")
    allowed = allowed_colors(material)
    off = 0
    for rgb in cols:
        dist = min(
            max(abs(rgb[0] - c[0]), abs(rgb[1] - c[1]), abs(rgb[2] - c[2]))
            for c in allowed
        )
        if dist > PALETTE_MAX_DIST:
            off += 1
    if cols and off / len(cols) > 0.15:
        keys.append("off-palette")
    black, light, blocks = _edge_and_light(im)
    if black > MAX_BLACK_EDGE:
        keys.append("black-outline")
    if light < MIN_LIGHT:
        keys.append("flat-light")
    if blocks > MAX_BLOCK:
        keys.append("upscaled")
    return keys


def extract_problems(im: Image.Image) -> list[str]:
    if len(_colors(im)) < EXTRACT_MIN_COLORS:
        return ["too-flat"]
    return []


def _native_material(path_name: str, family: str) -> str:
    m = _AUTHORED.match(path_name)
    if m is None:
        return NATIVE_MATERIAL[family]
    mid = m.group(2)
    if mid in ("leather", "mail", "plate", "cloth"):
        return mid
    return NATIVE_MATERIAL[family]


def check_style() -> list[Finding]:
    out: list[Finding] = []
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        for path in sorted(gear.glob("*_idle.png")):
            rel = path.relative_to(REPO).as_posix()
            im = Image.open(path)
            if _NATIVE.match(path.name):
                for key in extract_problems(im):
                    out.append(Finding("style", rel, key))
                continue
            # short/broad, materials, class marks, named helms, shoulders.
            if not path.name.endswith("_idle.png"):
                continue
            material = _native_material(path.name, family)
            for key in authored_problems(im, material):
                out.append(Finding("style", rel, key))
    shared = CHAR / "gear"
    for path in sorted(shared.glob("*_idle.png")):
        rel = path.relative_to(REPO).as_posix()
        base = path.name.split("_", 1)[0]
        material = "wood" if base in ("bow", "staff", "wand") else "plate"
        if base == "frill":
            material = "cloth"
        for key in authored_problems(Image.open(path), material):
            out.append(Finding("style", rel, key))
    # INK is part of every allowed palette; keep the import used.
    assert INK[0] > 16
    return out
