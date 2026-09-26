#!/usr/bin/env python3
"""Record short A56 fight clips for the Play preview (crawl, Gauntlet, GR, Hell).

Uses the same save inject as capture_shorts_shots.py. Restores the emulator
save when it finishes. Raw mp4s stay gitignored under preview/.
"""

from __future__ import annotations

import re
import subprocess
import sys
import time
from pathlib import Path

from capture_shorts_shots import SERIAL, adb, god_hand_taps, inject
import threading

ROOT = Path(__file__).resolve().parents[2]
PREVIEW = Path(__file__).resolve().parent / "preview"
BACKUP = PREVIEW / "_prefs_backup.xml"
SHOTS = [
    ("preview_crawl.json", "gameplay_crawl_raw.mp4"),
    ("preview_gauntlet.json", "gameplay_gauntlet_raw.mp4"),
    ("preview_greater_rift.json", "gameplay_gr_raw.mp4"),
    ("preview_hell.json", "gameplay_hell_raw.mp4"),
]


def backup_prefs() -> None:
    result = adb(
        "exec-out",
        "run-as",
        "com.idleparty.app",
        "cat",
        "shared_prefs/FlutterSharedPreferences.xml",
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip().startswith("<?xml"):
        BACKUP.write_text(result.stdout, encoding="utf-8")
        print("backed up prefs", BACKUP.stat().st_size)
    else:
        print("no prefs backup", result.returncode, result.stderr[:200])


def restore_prefs() -> None:
    if not BACKUP.exists():
        return
    adb("push", str(BACKUP), "/data/local/tmp/showcase_prefs.xml")
    adb(
        "shell",
        "run-as",
        "com.idleparty.app",
        "cp",
        "/data/local/tmp/showcase_prefs.xml",
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    print("restored prefs")


def screen_text() -> str:
    adb("shell", "rm", "-f", "/sdcard/ui.xml", check=False)
    dumped = adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
    blob = f"{dumped.stdout}\n{dumped.stderr}"
    if "dumped" not in blob.lower():
        return ""
    raw = subprocess.run(
        ["adb", "-s", SERIAL, "exec-out", "cat", "/sdcard/ui.xml"],
        capture_output=True,
        check=False,
    ).stdout.decode("utf-8", errors="replace")
    return raw.replace("&#10;", " ")


def tap_desc(text: str, label: str) -> bool:
    match = re.search(
        rf'content-desc="{re.escape(label)}"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        text,
    )
    if match is None:
        return False
    x1, y1, x2, y2 = (int(v) for v in match.groups())
    adb(
        "shell",
        "input",
        "tap",
        str((x1 + x2) // 2),
        str((y1 + y2) // 2),
        check=False,
    )
    return True


def wait_fight() -> bool:
    deadline = time.time() + 45
    seen_leave = 0
    while time.time() < deadline:
        text = screen_text()
        if not text:
            time.sleep(0.4)
            continue
        if "LEAVE" in text and "CONTINUE" not in text and "SKIP" not in text:
            seen_leave += 1
            if seen_leave >= 2:
                time.sleep(2.0)
                return True
            time.sleep(0.6)
            continue
        seen_leave = 0
        if (
            tap_desc(text, "SKIP")
            or tap_desc(text, "CONTINUE")
            or tap_desc(text, "GOT IT")
            or tap_desc(text, "NOT NOW")
        ):
            time.sleep(0.8)
            continue
        time.sleep(0.4)
    print("fight wait missed")
    return False


def capture_one(save_json: Path, dest_mp4: Path) -> None:
    print("inject", save_json.name)
    inject(save_json)
    if not wait_fight():
        raise SystemExit(f"never reached a fight for {save_json.name}")
    remote = "/sdcard/preview_beat.mp4"
    adb("shell", "rm", "-f", remote, check=False)
    tapper = threading.Thread(target=god_hand_taps, daemon=True)
    tapper.start()
    print("record", dest_mp4.name)
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
            "8",
            remote,
        ],
        check=True,
    )
    tapper.join(timeout=1)
    dest_mp4.parent.mkdir(parents=True, exist_ok=True)
    adb("pull", remote, str(dest_mp4))
    print("wrote", dest_mp4.name, dest_mp4.stat().st_size)


def main() -> int:
    backup_prefs()
    try:
        wanted = {arg.lower() for arg in sys.argv[1:]}
        shots = SHOTS
        if wanted:
            shots = [
                pair
                for pair in SHOTS
                if any(arg in pair[0].lower() or arg in pair[1].lower() for arg in wanted)
            ]
        for save_name, mp4_name in shots:
            capture_one(PREVIEW / save_name, PREVIEW / mp4_name)
    finally:
        restore_prefs()
    return 0


if __name__ == "__main__":
    sys.exit(main())
