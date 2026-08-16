"""Report what a proposed bucket of GameLogic members needs to be public.

Prints private members of the bucket still referenced by the code that stays,
and members that stay but are referenced by the bucket (fine, they become
`GameLogic.x` calls) — so a split never silently breaks visibility.
"""

from __future__ import annotations

import io
import json
import re
import sys

sys.path.insert(0, "tool")
from split_static_class import scan_members  # noqa: E402

SRC = "lib/core/game_logic.dart"


def main() -> None:
    spec = json.load(io.open(sys.argv[1], encoding="utf-8"))
    bucket = set(spec["members"])
    src = io.open(SRC, encoding="utf-8").read()
    lines = src.split("\n")
    cl = next(
        i
        for i, ln in enumerate(lines)
        if re.match(r"^(abstract final class|class) GameLogic\b", ln)
    )
    spans = scan_members(lines, cl)
    missing = sorted(bucket - set(spans))
    if missing:
        print("NOT FOUND:", missing)

    def body(name: str) -> str:
        a, b = spans[name]
        return "\n".join(lines[a:b])

    bucket_text = "\n".join(body(m) for m in bucket if m in spans)
    stay_text = "\n".join(body(m) for m in spans if m not in bucket)
    stay_text += "\n".join(lines[:cl])

    ident = re.compile(r"(?<![\w.])([A-Za-z_][A-Za-z0-9_]*)")
    bucket_ids = set(ident.findall(bucket_text))
    stay_ids = set(ident.findall(stay_text))

    priv_needed = sorted(
        m for m in bucket if m.startswith("_") and m in stay_ids
    )
    stay_used = sorted(m for m in spans if m not in bucket and m in bucket_ids)
    priv_stay_used = [m for m in stay_used if m.startswith("_")]

    print(f"bucket size: {len(bucket)} members")
    moved_lines = sum(spans[m][1] - spans[m][0] for m in bucket if m in spans)
    print(f"lines moved: {moved_lines}")
    print("PRIVATE in bucket still used by GameLogic (must go public):")
    print("  ", priv_needed or "none")
    print("PRIVATE staying in GameLogic but used by bucket (must go public):")
    print("  ", priv_stay_used or "none")
    print(f"public GameLogic members bucket calls: {len(stay_used) - len(priv_stay_used)}")


if __name__ == "__main__":
    main()
