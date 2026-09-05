#!/usr/bin/env python3
"""One-shot: add Completion status + Status column to docs/FEEL_AUDIT_500.md."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "FEEL_AUDIT_500.md"

# Structural / needs owner redesign — honest Won't fix.
WONT_FIX = {
    163, 165, 208, 373, 374, 375, 376, 473,
}

# Partial polish — light fix only (kit fantasy depth, residual reuse, P2 chrome).
LIGHT = set(range(145, 179))  # kit P1 HUD depth
LIGHT |= set(range(260, 373))  # P2 hub/dungeon/menus (partial waves)
LIGHT |= set(range(377, 452))  # kit P2 acronym/fantasy
LIGHT |= {209, 210, 483}  # sprite reuse / landmarks / grove canopy grammar

# Everything else in 001-500 shipped across feel waves 61-67 (incl. zone sweep).
SHIPPED = {i for i in range(1, 501)} - WONT_FIX - LIGHT


def status_for(item_id: int) -> str:
    if item_id in WONT_FIX:
        return "⏸ Won't fix"
    if item_id in LIGHT:
        return "~ Light"
    return "✅ Shipped"


def main() -> None:
    text = DOC.read_text(encoding="utf-8")

    # Header status line.
    text = re.sub(
        r"\*\*Status:\*\*[^\n]+",
        "**Status:** **1.12.67** — final sweep in progress (zone roster/blurbs + audit "
        "status table). Waves 61–66 shipped hub/dungeon/guides/menus; 67 finishes zone "
        "leftovers.",
        text,
        count=1,
    )

    # Top 20 — prefix each numbered item with checkmark.
    def top20_repl(m: re.Match[str]) -> str:
        num = m.group(1)
        rest = m.group(2)
        if rest.startswith("✅"):
            return m.group(0)
        return f"{num}. ✅ {rest}"

    text = re.sub(
        r"(?m)^(\d+)\. (\*\*P\d\*\* ·)",
        top20_repl,
        text,
        count=20,
    )

    # Table header + rows.
    old_header = (
        "| ID | Allvar | Yta | Problem | Fil |\n"
        "|----|--------|-----|---------|-----|"
    )
    new_header = (
        "| ID | Status | Allvar | Yta | Problem | Fil |\n"
        "|----|--------|--------|-----|---------|-----|"
    )
    if old_header not in text:
        raise SystemExit("table header not found")
    text = text.replace(old_header, new_header, 1)

    def row_repl(m: re.Match[str]) -> str:
        item_id = int(m.group(1))
        if m.group(2).startswith(("✅", "~", "⏸")):
            return m.group(0)
        st = status_for(item_id)
        return f"| {item_id:03d} | {st} | {m.group(2)} | {m.group(3)} | {m.group(4)} | {m.group(5)} |"

    text = re.sub(
        r"^\| (\d{3}) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| (`[^`]+`) \|$",
        row_repl,
        text,
        flags=re.MULTILINE,
    )

    shipped_n = sum(1 for i in range(1, 501) if status_for(i).startswith("✅"))
    light_n = sum(1 for i in range(1, 501) if status_for(i).startswith("~"))
    wont_n = sum(1 for i in range(1, 501) if status_for(i).startswith("⏸"))

    completion = f"""## Completion status

| Outcome | Count | Notes |
|---------|------:|-------|
| ✅ Shipped | {shipped_n} | Fixed in feel waves **1.12.61–1.12.67** (hub, dungeon, guides, menus, zone art/blurbs/layoutKind/chest tweaks). |
| ~ Light | {light_n} | Partial polish — kit HUD depth, P2 chrome, residual Kenney reuse; better but not full fantasy redesign. |
| ⏸ Won't fix | {wont_n} | Needs owner ask: menu architecture (373–376), new zone sprites / layoutKind expansion (208), full DK rune engine (163), pet panel (165), Gauntlet≠Spire art (473). |

"""

    if "## Completion status" not in text:
        text = text.replace("## Top 20 (börja här)\n", completion + "## Top 20 (börja här)\n", 1)
    else:
        text = re.sub(
            r"## Completion status\n\n\| Outcome \|.*?\n\n(?=## Top 20)",
            completion,
            text,
            flags=re.DOTALL,
        )

    DOC.write_text(text, encoding="utf-8")
    print(f"Updated {DOC.name}: shipped={shipped_n} light={light_n} wont={wont_n}")


if __name__ == "__main__":
    main()
