"""Contact sheet and per-check failure sheets under tool/out/facit/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from facit.findings import Finding
from paper_doll_manifest import FAMILIES
from paper_doll_paths import CHAR, TOOL


def _cell(path: Path, size: int) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    bb = im.getbbox()
    canvas = Image.new("RGBA", (size, size), (24, 26, 32, 255))
    if bb is None:
        return canvas
    crop = im.crop(bb)
    side = max(crop.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2), crop)
    fitted = square.resize((size - 4, size - 4), Image.Resampling.NEAREST)
    canvas.paste(fitted, (2, 2), fitted)
    return canvas


def write_contact_sheet() -> Path:
    import json

    catalog = json.loads((TOOL / "active_gear_models.json").read_text(encoding="utf-8"))
    rows: list[tuple[str, list[Path]]] = []
    for base, ids in catalog["shared"].items():
        rows.append((base, [CHAR / "gear" / f"{stem}_idle.png" for stem in ids]))
    for slot, ids in catalog["family"].items():
        for family in FAMILIES:
            rows.append(
                (
                    f"{family[:1]}/{slot}",
                    [CHAR / family / "gear" / f"{stem}_idle.png" for stem in ids],
                )
            )
    cell = 72
    label = 64
    width = label + max(len(paths) for _, paths in rows) * cell
    height = len(rows) * cell
    sheet = Image.new("RGBA", (width, height), (16, 18, 22, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (name, paths) in enumerate(rows):
        draw.text((4, r * cell + 28), name, fill=(220, 210, 180, 255))
        for c, path in enumerate(paths):
            if not path.exists():
                continue
            sheet.paste(_cell(path, cell - 4), (label + c * cell, r * cell + 2))
    out = TOOL / "out" / "facit" / "contact_sheet.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return out


def write_failures(findings: list[Finding]) -> None:
    out_dir = TOOL / "out" / "facit"
    out_dir.mkdir(parents=True, exist_ok=True)
    by_check: dict[str, list[Finding]] = {}
    for f in findings:
        by_check.setdefault(f.check, []).append(f)
    lines = []
    for check, items in sorted(by_check.items()):
        lines.append(f"{check}: {len(items)}")
        sheet = Image.new("RGBA", (640, max(40, 16 * min(len(items), 40))), (20, 20, 24, 255))
        draw = ImageDraw.Draw(sheet)
        for i, f in enumerate(items[:40]):
            draw.text((8, 4 + i * 16), f"{f.key}  {f.file}"[:90], fill=(230, 220, 200, 255))
        sheet.save(out_dir / f"fail_{check}.png")
    (out_dir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
