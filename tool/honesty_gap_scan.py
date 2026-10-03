#!/usr/bin/env python3
"""Heuristic scan for player-facing copy that often diverges from SpatialCombat."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KITS = ROOT / "lib" / "models" / "kits"

# (pattern in description, gap template if no negation nearby)
RULES = [
    (r"\bchannel\b", "Says channel — often instant cast"),
    (r"\bfear\b", "Says fear — often root/slow only"),
    (r"\bflee\b", "Says flee — heroes do not flee"),
    (r"\bpet\b", "Mentions pet — may be hero hit or self buff only"),
    (r"\bsummon\b", "Says summon — may be ground patch or buff only"),
    (r"\bDoT\b", "Says DoT — verify maintainDot/bleed path"),
    (r"\bHoT\b", "Says HoT — verify isHot ticks"),
    (r"\bcone\b", "Says cone — may be full circle or ground disc"),
    (r"\bexecute\b", "Says execute — verify HP gate"),
    (r"\bfinisher\b", "Says finisher — verify combo spend"),
    (r"\binstant next\b", "Instant next cast — often haste or emergency heal"),
    (r"\bequaliz", "Equalize HP — often party heal pulse"),
    (r"\bflurry\b", "Flurry — often one pulse"),
    (r"\bexplosion\b", "Explosion — often single target bolt"),
    (r"\bpop\b", "Pop — often plain nuke"),
    (r"\bdeath form\b", "Death form — often heal amp only"),
    (r"\bdemon form\b", "Demon form — often damage amp only"),
    (r"\baround you\b", "Around you — may anchor on focus pack"),
    (r"\bnearest\b", "Nearest — often focus only"),
    (r"\branged\b", "Ranged — often melee under 2.2 range"),
]

NAME_RE = re.compile(
    r"name: '((?:\\'|[^'])*)',\s*\n\s*shortLabel:[^\n]+\n\s*description:\s*"
    r"'((?:\\'|[^'])*)'",
    re.MULTILINE,
)


def main() -> None:
    gaps: list[tuple[str, str, str]] = []
    for path in sorted(KITS.glob("*.dart")):
        text = path.read_text(encoding="utf-8")
        for name, desc in NAME_RE.findall(text):
            name = name.replace("\\'", "'")
            desc = desc.replace("\\'", "'")
            blob = (name + " " + desc).lower()
            for pat, claim in RULES:
                if re.search(pat, blob, re.I):
                    gaps.append((path.name, name, f"{claim} · «{desc[:55]}…»" if len(desc) > 55 else f"{claim} · «{desc}»"))
                    break

    print(f"kit_heuristic={len(gaps)}")
    for g in gaps[:120]:
        print("|".join(g))


if __name__ == "__main__":
    main()
