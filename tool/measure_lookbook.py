#!/usr/bin/env python3
"""Turn the lookbook pixel counts into marks, flags, and pictures.

The Dart lookbook test paints every doll with the game painter and counts
pixels on the real result (tool/out/lookbook/measure.json). This script
does no placement math. It only judges the numbers and draws pictures:

- measure.txt       first line: better / worse than the last run, then flags
- measure_all.txt   every doll and pose
- flags/*.png       one strip per flagged piece, red dots on the fists
- diff.png          before | after for every doll picture that changed
- fit_poses.png     armed and pair outfits in idle, walk, windup, strike, cast

Marks:
- FACE     weapon over the face standing or walking (> 12 px)
- SWING    weapon parked over the face in windup, strike, or cast (> 40 px)
- SHIELD   shield or tome over the face (> 40 px)
- HAND/OFF the grip misses the fist (< 6 px inside an 8 px disk)
- COVERED  helm hides most of the face (< 35% of it shows)
- LIFT     helm does not touch the head (< 8 px of contact)
- FLOAT    pauldrons hang in the air (> 50% with nothing under them)
- SPILL    armor sits far off the body compared with its t0 cut (+20%)
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from paper_doll_paths import REPO

OUT_DIR = REPO / "tool" / "out" / "lookbook"
DATA = OUT_DIR / "measure.json"
OUT = OUT_DIR / "measure.txt"
OUT_ALL = OUT_DIR / "measure_all.txt"
MARKS = OUT_DIR / "measure_marks.json"
FLAGS = OUT_DIR / "flags"
DOLLS = OUT_DIR / "dolls"
PREV = OUT_DIR / "dolls_prev"
DIFF = OUT_DIR / "diff.png"
POSES_SHEET = OUT_DIR / "fit_poses.png"

POSES = ["idle", "walk", "windup", "strike", "cast"]
SWING = {"windup", "strike", "cast"}
FACE_MAX = 12
# A swing sweeps past the head for a frame. Only a blade parked on the
# face through the swing is a clash.
SWING_FACE_MAX = 40
SHIELD_FACE_MAX = 40
HAND_MIN = 6
OPEN_MIN = 0.35
TOUCH_MIN = 8
FLOAT_MAX = 0.50
SPILL_OVER = 0.20
MARK_NAMES = [
    "FACE",
    "SWING",
    "SHIELD",
    "HAND",
    "OFF",
    "COVERED",
    "LIFT",
    "FLOAT",
    "SPILL",
]
MARK_TEXT = {
    "FACE": "vapen över ansiktet (stå/gå)",
    "SWING": "vapen över ansiktet i slag",
    "SHIELD": "sköld över ansiktet",
    "HAND": "greppet missar handen",
    "OFF": "greppet missar andra handen",
    "COVERED": "hjälmen döljer ansiktet",
    "LIFT": "hjälmen rör inte huvudet",
    "FLOAT": "axelskydd svävar",
    "SPILL": "rustning långt från kroppen",
}
DIFF_MAX_ROWS = 40
DELTA_SHOWN = 8
BG = (22, 20, 28, 255)
GOLD = (230, 195, 106, 255)
RED = (255, 40, 40, 255)


def _font(size: int) -> ImageFont.ImageFont:
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _piece(row: dict) -> str:
    return f"{row['family']} {row['label']}"


def _spill_refs(rows: list[dict]) -> dict[tuple, float]:
    refs: dict[tuple, float] = {}
    for row in rows:
        if row["group"] != "armor" or row["spill"] is None:
            continue
        stem = row["label"].split(" ", 1)[0]
        if not stem.endswith("_t0"):
            continue
        refs[(row["family"], row["pose"], row["base"], row["material"])] = row[
            "spill"
        ]
    return refs


def _marks(row: dict, refs: dict[tuple, float]) -> list[str]:
    marks: list[str] = []
    if row["pose"] in SWING:
        if row["face"] > SWING_FACE_MAX:
            marks.append("SWING")
    elif row["face"] > FACE_MAX:
        marks.append("FACE")
    if row["shield"] is not None and row["shield"] > SHIELD_FACE_MAX:
        marks.append("SHIELD")
    if row["hand"] is not None and row["hand"] < HAND_MIN:
        marks.append("HAND")
    if row["off"] is not None and row["off"] < HAND_MIN:
        marks.append("OFF")
    if row["open"] is not None and row["open"] < OPEN_MIN:
        marks.append("COVERED")
    if row["touch"] is not None and row["touch"] < TOUCH_MIN:
        marks.append("LIFT")
    if row["float"] is not None and row["float"] > FLOAT_MAX:
        marks.append("FLOAT")
    if row["group"] == "armor" and row["spill"] is not None:
        ref = refs.get((row["family"], row["pose"], row["base"], row["material"]))
        if ref is not None and row["spill"] > ref + SPILL_OVER:
            marks.append("SPILL")
    return marks


def _cell(value, ratio: bool = False) -> str:
    if value is None:
        return "   -"
    if ratio:
        return f"{value:4.2f}"
    return f"{int(value):4d}"


def _table_line(row: dict, marks: list[str]) -> str:
    return (
        f"{row['name']:34s} {_cell(row['face'])} {_cell(row['shield'])} "
        f"{_cell(row['hand'])} "
        f"{_cell(row['off'])} {_cell(row['hair'], True)} "
        f"{_cell(row['open'], True)} {_cell(row['touch'])} "
        f"{_cell(row['float'], True)} {_cell(row['spill'], True)}  "
        + " ".join(marks)
    )


def _delta(old: dict[str, list[str]] | None, new: dict[str, list[str]]) -> str:
    if old is None:
        return "jämfört med förra: ingen förra mätning"
    worse: list[str] = []
    better: list[str] = []
    for name in sorted(set(old) | set(new)):
        gained = set(new.get(name, [])) - set(old.get(name, []))
        lost = set(old.get(name, [])) - set(new.get(name, []))
        if gained:
            worse.append(f"{name} +{'+'.join(sorted(gained))}")
        if lost:
            better.append(f"{name} -{'-'.join(sorted(lost))}")
    def some(items: list[str]) -> str:
        head = ", ".join(items[:DELTA_SHOWN])
        more = len(items) - DELTA_SHOWN
        return f"{len(items)} st: {head}" + (f" och {more} till" if more > 0 else "")

    if worse:
        extra = f" ; bättre {some(better)}" if better else ""
        return "jämfört med förra: sämre  " + some(worse) + extra
    if better:
        return "jämfört med förra: bättre  " + some(better)
    return "jämfört med förra: oförändrat"


def _doll(row: dict) -> Image.Image | None:
    path = OUT_DIR / row["file"]
    if not path.exists():
        return None
    return Image.open(path).convert("RGBA")


def _dot(im: Image.Image, point: list[float]) -> None:
    px = im.load()
    cx, cy = int(point[0]), int(point[1])
    for y in range(cy - 1, cy + 2):
        for x in range(cx - 1, cx + 2):
            if 0 <= x < im.width and 0 <= y < im.height:
                px[x, y] = RED


def _save_flag(name: str, rows: list[tuple[dict, list[str]]]) -> None:
    scale = 3
    font = _font(14)
    cells: list[Image.Image] = []
    for row, marks in rows:
        doll = _doll(row)
        if doll is None:
            continue
        if row["hand"] is not None:
            _dot(doll, row["fist"])
        if row["off"] is not None:
            _dot(doll, row["offFist"])
        big = Image.new("RGBA", (128 * scale, 128 * scale + 20), BG)
        big.alpha_composite(
            doll.resize((128 * scale, 128 * scale), Image.NEAREST), (0, 20)
        )
        ImageDraw.Draw(big).text(
            (4, 2), f"{row['pose']}  {' '.join(marks)}", fill=GOLD, font=font
        )
        cells.append(big)
    if not cells:
        return
    strip = Image.new("RGBA", (sum(c.width for c in cells), cells[0].height), BG)
    x = 0
    for cell in cells:
        strip.alpha_composite(cell, (x, 0))
        x += cell.width
    FLAGS.mkdir(parents=True, exist_ok=True)
    strip.save(FLAGS / f"{name.replace(' ', '_')}.png")


def _changed(rows: list[dict]) -> list[dict]:
    if not PREV.exists():
        return []
    out: list[dict] = []
    for row in rows:
        now = OUT_DIR / row["file"]
        before = PREV / Path(row["file"]).name
        if not now.exists() or not before.exists():
            continue
        if now.read_bytes() == before.read_bytes():
            continue
        a = Image.open(before).convert("RGBA")
        b = Image.open(now).convert("RGBA")
        if a.tobytes() != b.tobytes():
            out.append(row)
    return out


def _save_diff(rows: list[dict]) -> None:
    if DIFF.exists():
        DIFF.unlink()
    if not rows:
        return
    scale = 2
    font = _font(14)
    shown = rows[:DIFF_MAX_ROWS]
    cell = 128 * scale
    sheet = Image.new("RGBA", (cell * 2 + 260, len(shown) * cell), BG)
    draw = ImageDraw.Draw(sheet)
    for i, row in enumerate(shown):
        before = Image.open(PREV / Path(row["file"]).name).convert("RGBA")
        after = Image.open(OUT_DIR / row["file"]).convert("RGBA")
        sheet.alpha_composite(before.resize((cell, cell), Image.NEAREST), (0, i * cell))
        sheet.alpha_composite(after.resize((cell, cell), Image.NEAREST), (cell, i * cell))
        draw.text((cell * 2 + 8, i * cell + 8), row["name"], fill=GOLD, font=font)
        draw.text((cell * 2 + 8, i * cell + 28), "före | efter", fill=GOLD, font=font)
    sheet.save(DIFF)


def _save_poses(rows: list[dict]) -> None:
    by_name = {row["name"]: row for row in rows if row["group"] == "outfit"}
    families = sorted({row["family"] for row in by_name.values()},
                      key=["warrior", "healer", "mage", "rogue"].index)
    outfits = ["armed", "pair"]
    scale = 2
    cell = 128 * scale
    head = 24
    left = 130
    font = _font(16)
    sheet = Image.new(
        "RGBA",
        (left + cell * len(POSES), head + cell * len(families) * len(outfits)),
        BG,
    )
    draw = ImageDraw.Draw(sheet)
    for c, pose in enumerate(POSES):
        draw.text((left + c * cell + 8, 4), pose, fill=GOLD, font=font)
    r = 0
    for family in families:
        for outfit in outfits:
            y = head + r * cell
            draw.text((6, y + cell // 2 - 10), f"{family}\n{outfit}", fill=GOLD, font=font)
            for c, pose in enumerate(POSES):
                row = by_name.get(f"{family} {outfit} {pose}")
                doll = _doll(row) if row else None
                if doll is not None:
                    sheet.alpha_composite(
                        doll.resize((cell, cell), Image.NEAREST),
                        (left + c * cell, y),
                    )
            r += 1
    sheet.save(POSES_SHEET)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if not DATA.exists():
        print("measure.json saknas; kör py -3 tool/gear_lookbook.py")
        return 1
    rows = json.loads(DATA.read_text(encoding="utf-8"))["dolls"]
    refs = _spill_refs(rows)
    old = json.loads(MARKS.read_text(encoding="utf-8")) if MARKS.exists() else None
    if FLAGS.exists():
        shutil.rmtree(FLAGS)

    header = (
        "doll                                face shld hand  off hair open "
        "touch float spill  marks"
    )
    lines_all = [header]
    per_piece: dict[str, list[tuple[dict, list[str]]]] = {}
    groups: dict[str, int] = {}
    for row in rows:
        marks = _marks(row, refs)
        groups[row["group"]] = groups.get(row["group"], 0) + 1
        lines_all.append(_table_line(row, marks))
        if marks:
            per_piece.setdefault(_piece(row), []).append((row, marks))

    new_marks = {
        name: sorted({m for _, marks in hits for m in marks})
        for name, hits in per_piece.items()
    }
    for name, hits in per_piece.items():
        _save_flag(name, hits)
    changed = _changed(rows)
    _save_diff(changed)
    _save_poses(rows)

    lines = [
        _delta(old, new_marks),
        f"{len(rows)} dockbilder: "
        + ", ".join(f"{k} {v}" for k, v in sorted(groups.items()))
        + f"; {len(per_piece)} plagg flaggade",
    ]
    if changed:
        more = f" (visar {DIFF_MAX_ROWS})" if len(changed) > DIFF_MAX_ROWS else ""
        lines.append(f"{len(changed)} bilder ändrade sedan förra: diff.png{more}")
    elif PREV.exists():
        lines.append("inga bilder ändrade sedan förra")
    by_mark: dict[str, dict[str, list[str]]] = {}
    for name, hits in per_piece.items():
        for row, marks in hits:
            for mark in marks:
                by_mark.setdefault(mark, {}).setdefault(name, []).append(row["pose"])
    for mark in MARK_NAMES:
        pieces = by_mark.get(mark)
        if not pieces:
            continue
        lines.append(f"{mark} {MARK_TEXT[mark]}: {len(pieces)} plagg")
        items = []
        for name in sorted(pieces):
            poses = pieces[name]
            where = "" if poses == ["idle"] else f" ({','.join(poses)})"
            items.append(f"{name}{where}")
        line = " "
        for item in items:
            if len(line) + len(item) > 110:
                lines.append(line.rstrip(", "))
                line = " "
            line += f" {item},"
        lines.append(line.rstrip(", "))
    if per_piece:
        lines.append(f"felbilder i {FLAGS.relative_to(REPO)}")
    lines.append("alla rader: measure_all.txt; poser: fit_poses.png")

    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    OUT_ALL.write_text("\n".join(lines_all) + "\n", encoding="utf-8")
    MARKS.write_text(json.dumps(new_marks, indent=1), encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
