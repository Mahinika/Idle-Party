"""Prefix bare references to members that stayed on GameLogic.

Moved code says `random.nextDouble()` / `roomCombatBudget(...)`; from a new
class those must read `GameLogic.random` / `GameLogic.roomCombatBudget`.
Skips anything already qualified, named arguments (`foo: x`) and declarations.
"""

import io
import re
import sys

path, owner, names = sys.argv[1], sys.argv[2], sys.argv[3:]
src = io.open(path, encoding="utf-8").read()
for name in names:
    pat = re.compile(r"(?<![\w.$'\"])" + re.escape(name) + r"\b(?!\s*:)")
    src, n = pat.subn(f"{owner}.{name}", src)
    print(f"{n:4d}  {name}")
io.open(path, "w", encoding="utf-8").write(src)
