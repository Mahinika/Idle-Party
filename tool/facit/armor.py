"""Armor tiers, styles, face, manifest, material surface, stacks, readability."""
from __future__ import annotations

from facit.checks_v1 import (
    check_face_ownership,
    check_manifest,
    check_styles,
    check_tiers_and_materials,
    face_cutout_ok,
    high_gear_preview,
    squint_silhouette_diff,
)
from facit.findings import Finding

__all__ = [
    "check_face_ownership",
    "check_manifest",
    "check_styles",
    "check_tiers_and_materials",
    "check_material_surface",
    "check_full_stack",
    "check_readability",
]

import json
import re
from pathlib import Path

from PIL import Image

from gear_style import (
    BAG_ICON_PX,
    CLOTH_MAX_DITHER,
    DUNGEON_HERO_PX,
    LEATHER_MAX_HIGHLIGHT,
    LEATHER_MIN_SEAMS,
    MAIL_MIN_DITHER,
    MIN_READ_DIFF,
    PLATE_MAX_DITHER,
    PLATE_MIN_HIGHLIGHT,
    PLATE_MIN_RIVETS,
)
from paper_doll_manifest import FAMILIES, MATERIALS, NATIVE_MATERIAL, SLOTS
from paper_doll_paths import CHAR, REPO, TOOL

_MAT = re.compile(
    r"^(helm|chest|legs|cloak|hands|shoulder)_(leather|mail|plate)_"
    r"(t0|t2|short|broad)_idle\.png$"
)


def surface_stats(im: Image.Image) -> dict[str, float]:
    """Dither, highlight share, rivet dots, and dark seam rows."""
    px = im.convert("RGBA").load()
    w, h = im.size
    opaque = 0
    dither = 0
    highlight = 0
    rivets = 0
    row_lum: dict[int, list[float]] = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            opaque += 1
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            row_lum.setdefault(y, []).append(lum)
            if lum >= 185:
                highlight += 1
            diffs = 0
            bright_nb = 0
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h:
                    continue
                rr, gg, bb, aa = px[nx, ny]
                if aa < 40:
                    continue
                other = 0.299 * rr + 0.587 * gg + 0.114 * bb
                if abs(lum - other) > 18:
                    diffs += 1
                if other >= 185:
                    bright_nb += 1
            if diffs >= 2:
                dither += 1
            if lum >= 190 and bright_nb <= 1:
                rivets += 1
    means = [sum(v) / len(v) for v in row_lum.values() if v]
    image_mean = sum(means) / max(1, len(means))
    seams = sum(1 for m in means if m < image_mean - 22)
    return {
        "dither": dither / max(1, opaque),
        "highlight": highlight / max(1, opaque),
        "rivets": float(rivets),
        "seams": float(seams),
    }


def signature_problems(material: str, stats: dict[str, float]) -> list[str]:
    if material == "mail" and stats["dither"] < MAIL_MIN_DITHER:
        return ["mail-dither"]
    if material == "plate":
        bad = []
        if stats["rivets"] < PLATE_MIN_RIVETS:
            bad.append("plate-rivets")
        if stats["highlight"] < PLATE_MIN_HIGHLIGHT:
            bad.append("plate-highlight")
        if stats["dither"] > PLATE_MAX_DITHER:
            bad.append("plate-dither")
        return bad
    if material == "leather":
        bad = []
        if stats["highlight"] > LEATHER_MAX_HIGHLIGHT:
            bad.append("leather-shine")
        if stats["seams"] < LEATHER_MIN_SEAMS:
            bad.append("leather-seams")
        return bad
    if material == "cloth" and stats["dither"] > CLOTH_MAX_DITHER:
        return ["cloth-dither"]
    return []


def check_material_surface() -> list[Finding]:
    """Cross-material overlays must read as their material, not a recolor."""
    out: list[Finding] = []
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        for path in sorted(gear.glob("*_idle.png")):
            m = _MAT.match(path.name)
            if m is None:
                continue
            material = m.group(2)
            if material == NATIVE_MATERIAL[family]:
                continue
            stats = surface_stats(Image.open(path))
            rel = path.relative_to(REPO).as_posix()
            for key in signature_problems(material, stats):
                out.append(Finding("material", rel, key))
    return out


def _hair(family: str) -> set[tuple[int, int]]:
    from build_owned_gear_layers import idle_classification
    from paper_doll_classify import HAIR

    clf = idle_classification(family)
    return {
        (x, y)
        for y in range(128)
        for x in range(128)
        if clf.at(x, y) == HAIR
    }


def check_full_stack() -> list[Finding]:
    """High and material stacks render, and every helm keeps a face window."""
    out: list[Finding] = []
    for family in FAMILIES:
        try:
            high_gear_preview(family)
            for mat in MATERIALS.get(family, ()):
                high_gear_preview(family, mat)
        except FileNotFoundError as exc:
            out.append(Finding("full_stack", family, f"stack-missing:{exc}"))
        hair = _hair(family)
        gear = CHAR / family / "gear"
        for path in sorted(gear.glob("helm*_idle.png")):
            im = Image.open(path).convert("RGBA")
            rel = path.relative_to(REPO).as_posix()
            if not face_cutout_ok(im, family):
                out.append(Finding("full_stack", rel, "no-face-window"))
            if "short" in path.name:
                continue
            px = im.load()
            covered = sum(1 for x, y in hair if px[x, y][3] >= 40)
            if covered < 12:
                out.append(Finding("full_stack", rel, "hair-uncovered"))
    return out


def _thumb(im: Image.Image, size: int) -> Image.Image:
    bb = im.getbbox()
    if bb is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    crop = im.crop(bb)
    side = max(crop.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2), crop)
    return canvas.resize((size, size), Image.Resampling.NEAREST)


def _reads(a: Image.Image, b: Image.Image) -> bool:
    for size in (BAG_ICON_PX, DUNGEON_HERO_PX):
        if squint_silhouette_diff(_thumb(a, size), _thumb(b, size), size) < MIN_READ_DIFF:
            return False
    return True


def check_readability() -> list[Finding]:
    """t2 and named models must differ from t0 at BAG and dungeon size."""
    out: list[Finding] = []
    catalog = json.loads((TOOL / "active_gear_models.json").read_text(encoding="utf-8"))
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        for slot in list(SLOTS) + ["shoulder"]:
            t0 = gear / f"{slot}_t0_idle.png"
            t2 = gear / f"{slot}_t2_idle.png"
            if t0.exists() and t2.exists():
                if not _reads(Image.open(t0), Image.open(t2)):
                    out.append(
                        Finding(
                            "readability",
                            f"{family}/gear/{slot}",
                            "t2-matches-t0",
                        )
                    )
        for named in catalog["family"].get("helm", []):
            if named.startswith("helm_t"):
                continue
            if named in ("helm_short", "helm_broad"):
                continue
            path = gear / f"{named}_idle.png"
            base = gear / "helm_t0_idle.png"
            if path.exists() and base.exists() and not _reads(Image.open(path), Image.open(base)):
                out.append(Finding("readability", f"{family}/gear/{named}", "matches-t0"))
    shared = CHAR / "gear"
    for base, ids in catalog["shared"].items():
        t0 = shared / f"{base}_t0_idle.png"
        if not t0.exists():
            continue
        t0_im = Image.open(t0)
        for stem in ids:
            if stem == f"{base}_t0":
                continue
            path = shared / f"{stem}_idle.png"
            if path.exists() and not _reads(Image.open(path), t0_im):
                out.append(Finding("readability", f"gear/{stem}", "matches-t0"))
    return out
