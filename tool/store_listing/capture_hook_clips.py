#!/usr/bin/env python3
"""Screenrecord longer A56 combat for FYP hook clips (not the 13s feed ad).

Backs up emulator SharedPreferences, captures ~16s, restores the save.

  py -3 tool/store_listing/capture_hook_clips.py
"""

from __future__ import annotations

import subprocess
import sys
import threading
import time
from pathlib import Path

_LISTING = Path(__file__).resolve().parent
if str(_LISTING) not in sys.path:
    sys.path.insert(0, str(_LISTING))

from capture_shorts_shots import (
    PREVIEW,
    SERIAL,
    adb,
    god_hand_taps,
    inject,
    wait_continue,
)

LISTING = Path(__file__).resolve().parent
ROOT = LISTING.parent.parent
FIRST_MINUTE = LISTING / "first_minute_save.json"
BACKUP = PREVIEW / "hook_capture_prefs_backup.xml"
REMOTE_PREFS = "shared_prefs/FlutterSharedPreferences.xml"
PKG = "com.idleparty.app"


def backup_prefs() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    pulled = adb(
        "shell",
        "run-as",
        PKG,
        "cat",
        REMOTE_PREFS,
        check=False,
    )
    if pulled.returncode == 0 and pulled.stdout.strip():
        BACKUP.write_text(pulled.stdout, encoding="utf-8")
        print("backed up prefs", BACKUP)


def restore_prefs() -> None:
    if not BACKUP.exists():
        print("no prefs backup; skip restore")
        return
    adb("shell", "am", "force-stop", PKG)
    adb("push", str(BACKUP), "/data/local/tmp/hook_prefs_restore.xml")
    adb(
        "shell",
        "run-as",
        PKG,
        "cp",
        "/data/local/tmp/hook_prefs_restore.xml",
        REMOTE_PREFS,
    )
    print("restored prefs")


def record(dest: Path, seconds: int, tap: bool) -> None:
    remote = "/sdcard/gameplay_hook_raw.mp4"
    adb("shell", "rm", "-f", remote, check=False)
    tapper = None
    if tap:
        tapper = threading.Thread(target=god_hand_taps, daemon=True)
        tapper.start()
    print("record", dest.name, f"{seconds}s")
    subprocess.run(
        [
            "adb",
            "-s",
            SERIAL,
            "shell",
            "screenrecord",
            "--size",
            "1080x2340",
            "--bit-rate",
            "20000000",
            "--time-limit",
            str(seconds),
            remote,
        ],
        check=True,
    )
    if tapper:
        tapper.join(timeout=1)
    dest.parent.mkdir(parents=True, exist_ok=True)
    adb("pull", remote, str(dest))
    print("wrote", dest, dest.stat().st_size)


def capture_job(save: Path, dest: Path, *, seconds: int, tap: bool) -> None:
    inject(save)
    wait_continue()
    # Let the party walk a beat before the record so frame 0 is combat.
    time.sleep(1.2)
    record(dest, seconds, tap)


def main() -> int:
    hell = PREVIEW / "showcase_entered_hell.json"
    entered = PREVIEW / "showcase_entered.json"
    jobs: list[tuple[Path, Path, int, bool]] = []
    if entered.exists():
        jobs.append(
            (entered, PREVIEW / "hook_entered_raw.mp4", 16, False),
        )
    if hell.exists():
        jobs.append((hell, PREVIEW / "hook_hell_raw.mp4", 16, True))
    if FIRST_MINUTE.exists():
        jobs.append(
            (FIRST_MINUTE, PREVIEW / "hook_sandy_raw.mp4", 16, False),
        )
    if not jobs:
        print("no save JSON to inject", file=sys.stderr)
        return 1
    backup_prefs()
    failed = 0
    try:
        for save, dest, seconds, tap in jobs:
            if not save.exists():
                print("skip missing", save)
                continue
            try:
                capture_job(save, dest, seconds=seconds, tap=tap)
            except BaseException as err:
                if isinstance(err, KeyboardInterrupt):
                    raise
                print("capture failed", save.name, err)
                failed += 1
    finally:
        restore_prefs()
    return 1 if failed and failed == len(jobs) else 0


if __name__ == "__main__":
    raise SystemExit(main())
