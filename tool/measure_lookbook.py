#!/usr/bin/env python3
"""Score several sit checks on every multi-item lookbook doll.

Same outfits as fit_compare.png and fit_weapons.png. One pass per doll
counts four things:

- face: weapon pixels on the face (want 0)
- hand: weapon pixels on the main hand (want some, when a weapon is worn)
- off: off-hand pixels on the other hand
- hair / open: helm covering the hair, face still showing

Writes tool/out/lookbook/measure.txt. Pictures stay the judge of shape.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image

from paper_doll_paths import CHAR, REPO

ROOT = REPO
W = 128
ALPHA = 40
OUT = ROOT / "tool" / "out" / "lookbook" / "measure.txt"
HAND_R = 8
# A few pixels of a thin blade can graze the cheek. More than this is a clash.
FACE_MAX = 12
# A grip that misses the fist leaves this disk empty.
HAND_MIN = 6
HAIR_MIN = 0.40
OPEN_MIN = 0.35

TWO_HAND = {"staff", "polearm", "bow", "gun", "crossbow"}
ARMOR = {"helm", "chest", "legs", "cloak", "hands", "shoulder"}
OFF_ITEM = {"shield", "frill"}

# Keep these lists in step with test/visual/gear_lookbook_sheet_test.dart.
ARMOR_IDS = ["helm_t0", "chest_t0", "legs_t0"]
LAYER_IDS = [*ARMOR_IDS, "shoulder_t0", "cloak_t0", "hands_t0"]
DRESS_IDS = ["helm_t0", "chest_t0", "hands_t0"]
WEAPON_IDS = [
    "sword_t0",
    "dagger_t0",
    "staff_t0",
    "bow_t0",
    "wand_t0",
    "gun_t0",
    "polearm_t0",
    "shield_t0",
    "frill_t0",
]
FAMILY_WEAPON = {
    "warrior": "sword_t0",
    "healer": "wand_t0",
    "mage": "staff_t0",
    "rogue": "dagger_t0",
}


def _base(stem: str) -> str:
    return stem.split("_", 1)[0]


def _fists() -> dict[str, tuple[tuple[float, float], tuple[float, float]]]:
    text = (ROOT / "lib" / "visual" / "anchor_table.dart").read_text(encoding="utf-8")
    out: dict[str, tuple[tuple[float, float], tuple[float, float]]] = {}
    for m in re.finditer(
        r"BodyFamily\.(\w+):\s*_FamilyFists\((.*?)\n    \),",
        text,
        re.S,
    ):
        pairs = {
            key: (float(x), float(y))
            for key, x, y in re.findall(
                r"(idleMain|idleOff):\s*\(([-\d.]+),\s*([-\d.]+)\)",
                m.group(2),
            )
        }
        out[m.group(1)] = (pairs["idleMain"], pairs["idleOff"])
    return out


def _grips() -> tuple[dict[str, tuple[float, float]], dict[str, float], dict[str, float]]:
    text = (ROOT / "lib" / "visual" / "owned_gear_grips.dart").read_text(
        encoding="utf-8"
    )
    grips = {
        m.group(1): (float(m.group(2)) * W, float(m.group(3)) * W)
        for m in re.finditer(
            r"'([a-z0-9_]+)': Offset\(([0-9.]+), ([0-9.]+)\)",
            text,
        )
    }
    rest = _rest_map(text, "restByVisualSetId")
    rest_off = _rest_map(text, "restOffByVisualSetId")
    return grips, rest, rest_off


def _rest_map(text: str, name: str) -> dict[str, float]:
    block = re.search(rf"{name} = \{{(.*?)\n  \}};", text, re.S)
    if block is None:
        return {}
    return {
        m.group(1): float(m.group(2))
        for m in re.finditer(r"'([a-z0-9_]+)': ([-\d.]+),", block.group(1))
    }


def _art(family: str, stem: str) -> Path | None:
    shared = CHAR / "gear" / f"{stem}_idle.png"
    if shared.exists():
        return shared
    local = CHAR / family / "gear" / f"{stem}_idle.png"
    if local.exists():
        return local
    return None


def _opaque(im: Image.Image) -> list[tuple[int, int]]:
    px = im.load()
    return [
        (x, y)
        for y in range(W)
        for x in range(W)
        if px[x, y][3] >= ALPHA
    ]


def _head_masks(body: Image.Image) -> tuple[set[tuple[int, int]], set[tuple[int, int]]]:
    """Hair is the top of the head. The face is the lower middle of it."""
    # The neck on these bodies sits just under y=52. Wider rows above
    # that are the head, not the shoulders.
    pts = [(x, y) for x, y in _opaque(body) if y <= 52]
    head = pts
    if not head:
        head = _opaque(body)
    hy0 = min(y for _, y in head)
    hy1 = max(y for _, y in head)
    span = max(1, hy1 - hy0)
    xs = [x for x, _ in head]
    x0, x1 = min(xs), max(xs)
    inset = (x1 - x0) * 0.28
    # Crown only. The eye band is the middle of the head, not the jaw.
    hair = {(x, y) for x, y in head if y <= hy0 + span * 0.32}
    face = {
        (x, y)
        for x, y in head
        if hy0 + span * 0.38 <= y <= hy0 + span * 0.72
        and x0 + inset <= x <= x1 - inset
    }
    return hair, face


def _placed(
    pts: list[tuple[int, int]],
    grip: tuple[float, float],
    rot: float,
    hand: tuple[float, float],
) -> list[tuple[float, float]]:
    ax = 64 + hand[0] * W
    ay = 64 + hand[1] * W
    gx, gy = grip
    c, s = math.cos(rot), math.sin(rot)
    out: list[tuple[float, float]] = []
    for x, y in pts:
        dx = (x + (ax - gx)) - ax
        dy = (y + (ay - gy)) - ay
        out.append((ax + c * dx - s * dy, ay + s * dx + c * dy))
    return out


def _near(pts: list[tuple[float, float]], hand: tuple[float, float]) -> int:
    ax = 64 + hand[0] * W
    ay = 64 + hand[1] * W
    r2 = HAND_R * HAND_R
    return sum(1 for x, y in pts if (x - ax) ** 2 + (y - ay) ** 2 <= r2)


def _on(pts: list[tuple[float, float]], mask: set[tuple[int, int]]) -> int:
    return sum(1 for x, y in pts if (int(x), int(y)) in mask)


def _outfits() -> list[tuple[str, str, list[str], str | None]]:
    """family, label, pieces, off-hand weapon stem."""
    rows: list[tuple[str, str, list[str], str | None]] = []
    families = ["warrior", "healer", "mage", "rogue"]
    for fam in families:
        rows.append((fam, "bare", [], None))
        rows.append((fam, "armor", list(ARMOR_IDS), None))
        rows.append((fam, "layers", list(LAYER_IDS), None))
        rows.append((fam, "armed", [*LAYER_IDS, FAMILY_WEAPON[fam]], None))
        if fam == "warrior":
            rows.append((fam, "pair", [*LAYER_IDS, "sword_t0", "shield_t0"], None))
        elif fam == "rogue":
            rows.append((fam, "pair", [*LAYER_IDS, "dagger_t0"], "dagger_t0"))
        else:
            rows.append((fam, "pair", [*LAYER_IDS, "wand_t0", "frill_t0"], None))
        for wid in WEAPON_IDS:
            rows.append((fam, wid, [*DRESS_IDS, wid], None))
    return rows


def _score_one(
    family: str,
    pieces: list[str],
    off_weapon: str | None,
    fists: dict[str, tuple[tuple[float, float], tuple[float, float]]],
    grips: dict[str, tuple[float, float]],
    rest: dict[str, float],
    rest_off: dict[str, float],
    masks: dict[str, tuple[set[tuple[int, int]], set[tuple[int, int]]]],
) -> dict[str, float | None]:
    main_hand, off_hand = fists[family]
    hair, face = masks[family]
    mains: list[str] = []
    offs: list[str] = []
    helm: str | None = None
    for stem in pieces:
        kind = _base(stem)
        if kind == "helm":
            helm = stem
        elif kind in OFF_ITEM:
            offs.append(stem)
        elif kind in ARMOR:
            continue
        else:
            mains.append(stem)
    if off_weapon:
        offs.append(off_weapon)
    if any(_base(stem) in TWO_HAND for stem in mains):
        offs = []

    face_n = 0
    hand_n = 0
    off_n = 0
    for stem in mains:
        path = _art(family, stem)
        if path is None or stem not in grips:
            continue
        placed = _placed(
            _opaque(Image.open(path).convert("RGBA")),
            grips[stem],
            rest.get(stem, 0.0),
            main_hand,
        )
        face_n += _on(placed, face)
        hand_n += _near(placed, main_hand)
    for stem in offs:
        path = _art(family, stem)
        if path is None or stem not in grips:
            continue
        rot = rest_off.get(stem, 0.0) if off_weapon and stem == off_weapon else 0.0
        placed = _placed(
            _opaque(Image.open(path).convert("RGBA")),
            grips[stem],
            rot,
            off_hand,
        )
        face_n += _on(placed, face)
        off_n += _near(placed, off_hand)

    hair_cover: float | None = None
    face_open: float | None = None
    if helm:
        path = _art(family, helm)
        if path is not None and hair and face:
            helm_pts = set(_opaque(Image.open(path).convert("RGBA")))
            hair_cover = len(helm_pts & hair) / len(hair)
            face_open = len(face - helm_pts) / len(face)
    return {
        "face": float(face_n),
        "hand": float(hand_n) if mains else None,
        "off": float(off_n) if offs else None,
        "hair": hair_cover,
        "open": face_open,
    }


def _marks(row: dict[str, float | None]) -> str:
    marks: list[str] = []
    if row["face"] is not None and row["face"] > FACE_MAX:
        marks.append("FACE")
    if row["hand"] is not None and row["hand"] < HAND_MIN:
        marks.append("HAND")
    if row["off"] is not None and row["off"] < HAND_MIN:
        marks.append("OFF")
    hair = row["hair"]
    if hair is not None and hair < HAIR_MIN:
        marks.append("HAIR")
    open_ = row["open"]
    if open_ is not None and open_ < OPEN_MIN:
        marks.append("COVERED")
    return " ".join(marks)


def _cell(value: float | None, ratio: bool = False) -> str:
    if value is None:
        return "  - "
    if ratio:
        return f"{value:4.2f}"
    return f"{int(value):4d}"


def main() -> int:
    fists = _fists()
    grips, rest, rest_off = _grips()
    masks = {
        fam: _head_masks(Image.open(CHAR / fam / "body_idle.png").convert("RGBA"))
        for fam in fists
    }
    lines = [
        "doll                  face  hand   off  hair  open  marks",
    ]
    flagged = 0
    for family, label, pieces, off_weapon in _outfits():
        row = _score_one(
            family, pieces, off_weapon, fists, grips, rest, rest_off, masks
        )
        marks = _marks(row)
        if marks:
            flagged += 1
        name = f"{family} {label}"
        lines.append(
            f"{name:20s}  {_cell(row['face'])}  {_cell(row['hand'])}  "
            f"{_cell(row['off'])}  {_cell(row['hair'], True)}  "
            f"{_cell(row['open'], True)}  {marks}"
        )
    lines.append(f"{flagged} dolls flagged")
    text = "\n".join(lines) + "\n"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(text, end="")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
