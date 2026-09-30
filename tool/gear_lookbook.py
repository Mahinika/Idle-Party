"""Write gear-lookbook PNGs the agent can open and look at.

Same dolls as MORE → SETTINGS → DEV: GEAR LOOKBOOK. No emulator, no browser.
Pictures land in tool/out/lookbook/.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    # flutter on Windows is a .bat. CreateProcess will not run it unless
    # the command goes through the shell.
    result = subprocess.run(
        "flutter test test/visual/gear_lookbook_sheet_test.dart --dart-define=LOOKBOOK=true",
        cwd=ROOT,
        shell=True,
    )
    out = ROOT / "tool" / "out" / "lookbook"
    if result.returncode != 0:
        return result.returncode
    print(f"sheets in {out}")
    # Same outfits, four sit counts each. Numbers next to the pictures.
    measured = subprocess.run(
        "py -3 tool/measure_lookbook.py",
        cwd=ROOT,
        shell=True,
    )
    return measured.returncode


if __name__ == "__main__":
    sys.exit(main())
