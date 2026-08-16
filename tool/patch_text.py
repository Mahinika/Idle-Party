"""One-off text patches while splitting GameLogic (kept re-runnable)."""

import io
import sys

path, pairs = sys.argv[1], sys.argv[2:]
src = io.open(path, encoding="utf-8").read()
for i in range(0, len(pairs), 2):
    a, b = pairs[i], pairs[i + 1]
    print(f"{src.count(a):4d}  {a}  ->  {b}")
    src = src.replace(a, b)
io.open(path, "w", encoding="utf-8").write(src)
