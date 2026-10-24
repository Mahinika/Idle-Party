#!/usr/bin/env python3
"""Parse ChangelogCatalog.releases and map them to ISO weeks in 2026."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG = ROOT / "lib" / "core" / "changelog.dart"

MONTHS = {
    "Jan": 1,
    "Feb": 2,
    "Mar": 3,
    "Apr": 4,
    "May": 5,
    "Jun": 6,
    "Jul": 7,
    "Aug": 8,
    "Sep": 9,
    "Oct": 10,
    "Nov": 11,
    "Dec": 12,
}

BOILERPLATE_SNIPPETS = (
    "PATH still runs Sandy through Mothveil",
    "PATH still Sandy through Mothveil",
    "At party Lv100, MORE → CRAFT still runs",
    "Race still locks after New Game START",
    "KEY waits until every active hero is Lv100",
    "Ranked GR packs still scale with rank only",
    "Ascend still says Rebuild your bag",
    "Ascend still Rebuild your bag",
)


@dataclass
class Release:
    version: str
    date: date | None
    summary: str
    lines: list[str] = field(default_factory=list)

    def player_lines(self) -> list[str]:
        out: list[str] = []
        if self.summary.strip():
            out.append(self.summary.strip())
        for line in self.lines:
            t = line.strip()
            if not t or _is_boilerplate(t):
                continue
            out.append(t)
        return out


def _is_boilerplate(text: str) -> bool:
    return any(snippet in text for snippet in BOILERPLATE_SNIPPETS)


def _parse_date(raw: str | None) -> date | None:
    if not raw:
        return None
    m = re.match(r"^([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})$", raw.strip())
    if not m:
        return None
    month = MONTHS.get(m.group(1))
    if month is None:
        return None
    return date(int(m.group(3)), month, int(m.group(2)))


def _version_key(version: str) -> tuple[int, ...]:
    parts = version.split(".")
    nums: list[int] = []
    for p in parts:
        try:
            nums.append(int(p))
        except ValueError:
            nums.append(0)
    return tuple(nums)


def _extract_quoted_strings(block: str, field_name: str) -> list[str]:
    pattern = rf"{field_name}:\s*<String>\[\s*(.*?)\s*\],"
    m = re.search(pattern, block, re.DOTALL)
    if not m:
        return []
    inner = m.group(1)
    return [s.replace("\\'", "'") for s in re.findall(r"'((?:\\'|[^'])*)'", inner)]


def parse_changelog(path: Path = CHANGELOG) -> list[Release]:
    text = path.read_text(encoding="utf-8")
    m = re.search(
        r"static const List<ChangelogRelease> releases = <ChangelogRelease>\[(.*)\n  \];",
        text,
        re.DOTALL,
    )
    if not m:
        raise SystemExit("releases list not found")
    chunk = m.group(1)
    blocks = re.split(r"\n    ChangelogRelease\(", chunk)[1:]
    releases: list[Release] = []
    seen: set[str] = set()
    for block in blocks:
        vm = re.search(r"version:\s*'([^']+)'", block)
        if not vm:
            continue
        version = vm.group(1)
        if version in seen:
            continue
        seen.add(version)
        dm = re.search(r"date:\s*'([^']+)'", block)
        parsed_date = _parse_date(dm.group(1) if dm else None)
        summary = ""
        sm = re.search(r"summary:\s*\n\s*'([^']*(?:\\'[^']*)*)'", block)
        if sm:
            summary = sm.group(1).replace("\\'", "'")
        lines: list[str] = []
        for section in ("added", "changed", "fixed", "technical", "known"):
            lines.extend(_extract_quoted_strings(block, section))
        if not lines:
            bullet_m = re.search(r"bullets:\s*<String>\[\s*(.*?)\s*\],", block, re.DOTALL)
            if bullet_m:
                lines.extend(
                    s.replace("\\'", "'")
                    for s in re.findall(
                        r"'((?:\\'|[^'])*)'", bullet_m.group(1)
                    )
                )
        releases.append(
            Release(version=version, date=parsed_date, summary=summary, lines=lines)
        )
    return releases


def iso_week_2026(d: date) -> int | None:
    if d.year != 2026:
        return None
    return d.isocalendar()[1]


def week_date_range(week: int) -> tuple[date, date]:
    start = date.fromisocalendar(2026, week, 1)
    end = date.fromisocalendar(2026, week, 7)
    return start, end


WEEK_42_START = date(2026, 10, 12)


def retro_release_pool(releases: list[Release]) -> list[Release]:
    """Shipped before ISO week 42 (2026-10-12); catalog is newest-first."""
    pool: list[Release] = []
    for rel in releases:
        if rel.date is not None and rel.date >= WEEK_42_START:
            continue
        if _version_key(rel.version) >= _version_key("1.13.0"):
            continue
        pool.append(rel)
    pool.reverse()
    return pool


def assign_releases_to_weeks(
    releases: list[Release], *, max_week: int = 41
) -> dict[int, list[Release]]:
    """Even chronological buckets for retro weeks 1..max_week."""
    pool = retro_release_pool(releases)
    buckets: dict[int, list[Release]] = {w: [] for w in range(1, max_week + 1)}
    if not pool:
        return buckets
    n = len(pool)
    for i, rel in enumerate(pool):
        w = min(max_week, 1 + (i * max_week) // n)
        buckets[w].append(rel)
    return buckets


def main() -> None:
    releases = parse_changelog()
    print(f"releases={len(releases)} dated={sum(1 for r in releases if r.date)}")
    by_week = assign_releases_to_weeks(releases)
    for w in range(38, 42):
        rs = by_week[w]
        vers = ", ".join(r.version for r in rs)
        print(f"2026-w{w:02d}: {len(rs)} releases [{vers}]")


if __name__ == "__main__":
    main()
