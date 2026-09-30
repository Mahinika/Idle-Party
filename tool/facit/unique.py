"""Active models must not share an icon or a paper-doll silhouette."""
from __future__ import annotations

import json

from PIL import Image

from facit.checks_v1 import squint_silhouette_diff
from facit.findings import Finding
from gear_style import BAG_ICON_PX, MIN_UNIQUE_SQUINT, MIN_READ_DIFF
from paper_doll_manifest import FAMILIES
from paper_doll_paths import CHAR, TOOL


def _load(path) -> Image.Image | None:
    if not path.exists():
        return None
    return Image.open(path).convert("RGBA")


def pair_problem(a: Image.Image, b: Image.Image) -> str | None:
    if a.tobytes() == b.tobytes():
        return "same-bytes"
    if squint_silhouette_diff(a, b, 48) < MIN_UNIQUE_SQUINT:
        return "same-squint"
    if squint_silhouette_diff(a, b, BAG_ICON_PX) < MIN_READ_DIFF:
        return "same-read"
    return None


def _pairs(group: str, images: dict[str, Image.Image], kind: str) -> list[Finding]:
    out: list[Finding] = []
    names = sorted(images)
    for i, left in enumerate(names):
        for right in names[i + 1 :]:
            key = pair_problem(images[left], images[right])
            if key is None:
                continue
            out.append(Finding("unique", f"{group}:{kind}:{left}|{right}", key))
    return out


def check_unique() -> list[Finding]:
    catalog = json.loads((TOOL / "active_gear_models.json").read_text(encoding="utf-8"))
    out: list[Finding] = []
    shared = CHAR / "gear"
    for base, ids in catalog["shared"].items():
        idles = {}
        icons = {}
        for stem in ids:
            im = _load(shared / f"{stem}_idle.png")
            icon = _load(shared / f"{stem}_icon.png")
            if im is not None:
                idles[stem] = im
            if icon is not None:
                icons[stem] = icon
        out.extend(_pairs(f"shared/{base}", idles, "doll"))
        out.extend(_pairs(f"shared/{base}", icons, "icon"))
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        for slot, ids in catalog["family"].items():
            idles = {}
            icons = {}
            for stem in ids:
                im = _load(gear / f"{stem}_idle.png")
                icon = _load(gear / f"{stem}_icon.png")
                if im is not None:
                    idles[stem] = im
                if icon is not None:
                    icons[stem] = icon
            out.extend(_pairs(f"{family}/{slot}", idles, "doll"))
            out.extend(_pairs(f"{family}/{slot}", icons, "icon"))
    return out
