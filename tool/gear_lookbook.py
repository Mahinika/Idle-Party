"""Write gear-lookbook PNGs the agent can open and look at.

Same dolls as MORE → SETTINGS → DEV: GEAR LOOKBOOK. No emulator, no browser.
Pictures land in tool/out/lookbook/.

Default is the summary sheet plus the fit counts. The counts always cover
every weapon and armor model, every material, and five poses. Pass --all
for every sheet, or --weapons, --armor, or --body <family> for one slice.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _scope(argv: list[str]) -> str:
    if "--all" in argv:
        return "all"
    if "--weapons" in argv:
        return "weapons"
    if "--armor" in argv:
        return "armor"
    if "--body" in argv:
        index = argv.index("--body")
        if index + 1 >= len(argv):
            print("ange en kropp: warrior, healer, mage eller rogue")
            raise SystemExit(2)
        family = argv[index + 1]
        if family not in {"warrior", "healer", "mage", "rogue"}:
            print(f"okänd kropp: {family}")
            raise SystemExit(2)
        return f"body {family}"
    return "summary"


def _keep_last_dolls(out: Path) -> None:
    """The last run's doll pictures become the 'before' in diff.png."""
    dolls = out / "dolls"
    prev = out / "dolls_prev"
    if not dolls.exists() or not any(dolls.iterdir()):
        return
    if prev.exists():
        shutil.rmtree(prev)
    dolls.rename(prev)


def main() -> int:
    scope = _scope(sys.argv[1:])
    out = ROOT / "tool" / "out" / "lookbook"
    out.mkdir(parents=True, exist_ok=True)
    (out / "scope.txt").write_text(scope + "\n", encoding="utf-8")
    _keep_last_dolls(out)
    # flutter on Windows is a .bat. CreateProcess will not run it unless
    # the command goes through the shell.
    result = subprocess.run(
        "flutter test test/visual/gear_lookbook_sheet_test.dart --dart-define=LOOKBOOK=true",
        cwd=ROOT,
        shell=True,
    )
    if result.returncode != 0:
        return result.returncode
    print(f"sheets in {out}  ({scope})")
    measured = subprocess.run(
        "py -3 tool/measure_lookbook.py",
        cwd=ROOT,
        shell=True,
    )
    return measured.returncode


if __name__ == "__main__":
    sys.exit(main())
