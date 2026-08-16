"""Rebuild the delegate block for an already-moved bucket.

Reads the members from the target file (source of truth after a move) and
replaces everything from the bucket marker to the end of the source class.
"""

from __future__ import annotations

import io
import json
import re
import sys

sys.path.insert(0, "tool")
from split_static_class import (  # noqa: E402
    _strip_literals,
    delegate_for,
    scan_members,
)


def main() -> None:
    spec = json.load(io.open(sys.argv[1], encoding="utf-8"))
    tgt = io.open(spec["out"], encoding="utf-8").read().split("\n")
    tcl = next(
        i
        for i, ln in enumerate(tgt)
        if re.match(r"^(abstract final class|class) " + spec["target_class"], ln)
    )
    tspans = scan_members(tgt, tcl)

    delegates = []
    for name in spec["members"]:
        if name.startswith("_") or name in spec.get("no_delegate", []):
            continue
        a, b = tspans[name]
        d = delegate_for("\n".join(tgt[a:b]), name, spec["target_class"])
        delegates.append(d if d else f"  // MANUAL DELEGATE NEEDED: {name}\n")

    src = io.open(spec["source"], encoding="utf-8").read().split("\n")
    marker = f"  // —— {spec['bucket']}: moved to {spec['out'].split('/')[-1]} ——"
    scl = next(
        i
        for i, ln in enumerate(src)
        if re.match(r"^(abstract final class|class) " + spec["class"] + r"\b", ln)
    )
    end, depth = scl, 0
    while end < len(src):
        code = _strip_literals(src[end])
        depth += code.count("{") - code.count("}")
        if depth == 0 and end > scl:
            break
        end += 1
    if marker in src:
        start = src.index(marker)
        # Stop at the next bucket's marker so regenerating one bucket does not
        # wipe the delegates of the bucket that was split after it.
        stop = next(
            (
                i
                for i in range(start + 1, end)
                if src[i].startswith("  // —— ") and src[i].endswith(" ——")
            ),
            end,
        )
    else:
        start = stop = end
    block = [marker] + "".join(delegates).rstrip("\n").split("\n")
    src[start:stop] = block
    io.open(spec["source"], "w", encoding="utf-8").write("\n".join(src))
    print(f"{len(delegates)} delegates rebuilt for {spec['target_class']}")


if __name__ == "__main__":
    main()
