"""Delete every import the analyzer calls unused, then report what it dropped.

Splitting a 7000-line class means guessing imports for the new file; this
removes the guesses that missed instead of hand-editing after each analyze.
"""

import io
import re
import subprocess
import sys

RE = re.compile(r"Unused import: '([^']+)'.* - ([^ ]+\.dart):(\d+):\d+")


def main() -> int:
    out = subprocess.run(
        ["flutter", "analyze", "lib", "test", "--no-fatal-infos"],
        capture_output=True,
        text=True,
        shell=True,
    ).stdout
    hits: dict[str, set[int]] = {}
    for uri, path, line in RE.findall(out):
        hits.setdefault(path.replace("\\", "/"), set()).add(int(line))
        print(f"drop {uri} from {path}")
    for path, lines in hits.items():
        src = io.open(path, encoding="utf-8").read().split("\n")
        for ln in sorted(lines, reverse=True):
            del src[ln - 1]
        io.open(path, "w", encoding="utf-8").write("\n".join(src))
    if not hits:
        print("no unused imports")
    return 0


if __name__ == "__main__":
    sys.exit(main())
