"""Screenshot + optional tap for Brick Inc competitor research (Play emu).

Do not tap purchase, summon, claim, or ticket-spend buttons — owner rule.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "competitor_research" / "brick_inc_idle_breaker" / "screens"
LOG = ROOT / "docs" / "competitor_research" / "brick_inc_idle_breaker" / "SESSION_LOG.md"
SERIAL = "emulator-5554"


def adb(*args: str) -> None:
    cmd = ["adb", "-s", SERIAL, *args]
    r = subprocess.run(cmd, capture_output=True)
    if r.returncode != 0:
        err = (r.stderr or r.stdout or b"").decode(errors="replace")
        raise SystemExit(f"adb failed: {' '.join(cmd)}\n{err}")


def shot(name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with path.open("wb") as f:
        subprocess.check_call(["adb", "-s", SERIAL, "exec-out", "screencap", "-p"], stdout=f)
    return path


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def log_line(text: str) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    line = f"- **{stamp}** — {text}\n"
    if LOG.exists():
        LOG.write_text(LOG.read_text(encoding="utf-8") + line, encoding="utf-8")
    else:
        LOG.write_text(f"# Session log\n\n{line}", encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("name", help="screenshot filename, e.g. 01_main.png")
    p.add_argument("--tap", nargs=2, type=int, metavar=("X", "Y"))
    p.add_argument("--wait", type=float, default=1.2)
    p.add_argument("--note", default="")
    args = p.parse_args()
    if args.tap:
        tap(args.tap[0], args.tap[1])
        time.sleep(args.wait)
    path = shot(args.name)
    note = args.note or f"screenshot `{path.name}`"
    if args.tap:
        note = f"tap ({args.tap[0]},{args.tap[1]}) → {note}"
    log_line(note)
    print(path)


if __name__ == "__main__":
    main()
