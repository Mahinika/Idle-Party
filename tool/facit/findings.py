"""Stable facit findings and the shrink-only debt list."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

from paper_doll_paths import TOOL

DEBT = TOOL / "facit_known_debt.json"
_FLOAT = re.compile(r"\d+\.\d+")


@dataclass(frozen=True)
class Finding:
    check: str
    file: str
    key: str

    def as_dict(self) -> dict[str, str]:
        return {"check": self.check, "file": self.file, "key": self.key}


def stable_key(message: str) -> str:
    return _FLOAT.sub("#", message)


def wrap(check: str, messages: list[str], file: str = "") -> list[Finding]:
    return [Finding(check, file, stable_key(msg)) for msg in messages]


def load_debt() -> list[Finding]:
    if not DEBT.exists():
        return []
    raw = json.loads(DEBT.read_text(encoding="utf-8"))
    return [Finding(d["check"], d["file"], d["key"]) for d in raw]


def save_debt(findings: list[Finding]) -> None:
    payload = [f.as_dict() for f in sorted(findings, key=lambda f: (f.check, f.file, f.key))]
    DEBT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def apply_debt(
    findings: list[Finding],
    *,
    write: bool,
    prune: bool,
) -> tuple[list[Finding], list[Finding]]:
    """Return (failures, debt).

    Failures are new findings plus debt entries that the art no longer
    produces. [write] replaces the list (one-shot snapshot). [prune] drops
    resolved entries and never adds.
    """
    current = {(f.check, f.file, f.key): f for f in findings}
    if write:
        save_debt(list(current.values()))
        return [], list(current.values())
    debt = {(f.check, f.file, f.key): f for f in load_debt()}
    new = [current[k] for k in sorted(set(current) - set(debt))]
    stale = [debt[k] for k in sorted(set(debt) - set(current))]
    if prune:
        kept = [debt[k] for k in sorted(set(debt) & set(current))]
        save_debt(kept)
        debt = {(f.check, f.file, f.key): f for f in kept}
        stale = []
    return new + stale, list(debt.values())
