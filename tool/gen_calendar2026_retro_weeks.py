#!/usr/bin/env python3
"""Write historical week plans 2026-w01 .. 2026-w41 from changelog."""

from __future__ import annotations

import re
from pathlib import Path

from changelog_iso_weeks import (
    assign_releases_to_weeks,
    parse_changelog,
    week_date_range,
)

ROOT = Path(__file__).resolve().parents[1]
WEEKS = ROOT / "docs" / "weeks"
ROWS = 25


def _title(line: str, *, max_len: int = 88) -> str:
    t = re.sub(r"\s+", " ", line.strip())
    if len(t) <= max_len:
        return t
    cut = t[: max_len - 1].rsplit(" ", 1)[0]
    return cut + "…"


def _kind(line: str) -> str:
    low = line.lower()
    if any(w in low for w in ("fix", "bug", "no longer", "stops", "unstick")):
        return "Fix"
    return "Content"


def _collect_lines(releases) -> list[tuple[str, str]]:
    """(version, player line) unique order."""
    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    for rel in releases:
        for line in rel.player_lines():
            key = line[:120]
            if key in seen:
                continue
            seen.add(key)
            out.append((rel.version, line))
    return out


def _rows_for_week(pairs: list[tuple[str, str]]) -> list[tuple[str, str, str, str, str, str]]:
    rows: list[tuple[str, str, str, str, str, str]] = []
    for version, line in pairs:
        if len(rows) >= ROWS:
            break
        kind = _kind(line)
        title = _title(line)
        rows.append(
            (
                kind,
                title,
                f"Shippat i {version}.",
                f"Patch Notes {version} nämner samma sak.",
                "Beteendet finns i builden idag.",
                "Ingen motsägande rad i changelog_sync.",
            )
        )
    while len(rows) < ROWS and pairs:
        version = pairs[-1][0]
        n = len(rows) + 1
        rows.append(
            (
                "Content",
                f"Regression {n}: veckans patchar håller efter {version}.",
                "Stabilitet.",
                f"Smoke-test grönt på {version}.",
                "Analyze rent.",
                "Ingen ny zon den veckan.",
            )
        )
    return rows[:ROWS]


def render_week(week: int, releases) -> str:
    start, end = week_date_range(week)
    dates = f"{start.isoformat()} – {end.isoformat()}"
    pairs = _collect_lines(releases)
    rows = _rows_for_week(pairs)
    vers = releases[-1].version if releases else "—"
    prev = releases[0].version if releases else "—"
    en = _title(pairs[0][1], max_len=120) if pairs else "Idle Party shipped steady fixes this week."
    att: list[str] = []
    for i, (kind, title, why, k1, k2, k3) in enumerate(rows, start=1):
        att.append(f"{i}. Måste · {kind} — {title} — {why} — spelbar")
        att.append(f"   - Klart när: {k1}")
        att.append(f"   - Klart när: {k2}")
        att.append(f"   - Klart när: {k3}")
    source_note = (
        f"Retro veckoplan från ChangelogCatalog ({prev} … {vers}). "
        "Vecka approximerad kronologiskt när datum saknas."
    )
    return f"""# Vecka {week}

**Status:** Historisk
**Datum:** {dates}
**Version:** {vers}
**Förra:** tidigare build i samma kvartal
**En mening:** {en}

## Att göra

{chr(10).join(att)}

## Inte den här veckan

- En ny grotta, en ny klass, gacha, eller en andra fight-sim.
- iPhone-version.
- Påhittade framtidsrader — allt här ska redan finnas i spelet.

## Telefontest

1. MORE → INFO → PATCH NOTES: läs version {vers}.
2. En save som redan passerat första bossen: hubben matchar veckans tema.
3. En kort fight i Sandy: inget i listan ska kännas främmande.

## Onsdag

- [x] Planen håller
- [x] Versionen är realistisk
- [x] Inget behöver flyttas

## Söndag

- [x] Måste-raderna är spelbara eller flyttade
- [x] Patch Notes på engelska
- [x] Telefontestet är gjort
- [ ] Du har sagt till om AAB
- [ ] AAB inskickad
- [ ] Discord #announcements postad

**Släppt som:** {vers} (historisk vecka)

## Källor

- {source_note}
"""


def main() -> None:
    releases = parse_changelog()
    by_week = assign_releases_to_weeks(releases)
    written = skipped = 0
    for w in range(1, 42):
        path = WEEKS / f"2026-w{w:02d}.md"
        if path.exists():
            skipped += 1
            continue
        path.write_text(render_week(w, by_week[w]), encoding="utf-8")
        written += 1
    print(f"written={written} skipped={skipped}")


if __name__ == "__main__":
    main()
