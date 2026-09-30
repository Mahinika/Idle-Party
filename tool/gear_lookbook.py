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
    result = subprocess.run(
        [
            "flutter",
            "test",
            "test/visual/gear_lookbook_sheet_test.dart",
            "--dart-define=LOOKBOOK=true",
        ],
        cwd=ROOT,
    )
    out = ROOT / "tool" / "out" / "lookbook"
    if result.returncode == 0:
        print(f"sheets in {out}")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
