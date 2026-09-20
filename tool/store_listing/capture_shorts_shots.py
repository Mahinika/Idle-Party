#!/usr/bin/env python3
"""Inject a showcase combat save and screenrecord ~9s on the A56 emulator."""

from __future__ import annotations

import html
import json
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PREVIEW = Path(__file__).resolve().parent / "preview"
SERIAL = "emulator-5554"
PKG = "com.idleparty.app"


def adb(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", "-s", SERIAL, *args],
        check=check,
        text=True,
        capture_output=True,
    )


def write_prefs(save_json: Path, dest_xml: Path) -> None:
    data = json.loads(save_json.read_text(encoding="utf-8"))
    # Future stamp so boot cannot open Welcome Back over the crawl.
    data["lastUpdated"] = (
        datetime.now(timezone.utc) + timedelta(minutes=15)
    ).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    data["dungeonZoom"] = "close"
    data["soundMuted"] = True
    data["dungeonMode"] = "push"
    raw = json.dumps(data, separators=(",", ":"))
    xml = (
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n"
        f'<string name="flutter.idle_party_save_v2">{html.escape(raw, quote=False)}</string>\n'
        "</map>\n"
    )
    dest_xml.write_text(xml, encoding="utf-8")


def inject(save_json: Path) -> None:
    xml_path = PREVIEW / "showcase_entered_prefs.xml"
    write_prefs(save_json, xml_path)
    adb("shell", "am", "force-stop", PKG)
    adb("push", str(xml_path), "/data/local/tmp/showcase_prefs.xml")
    adb(
        "shell",
        "run-as",
        PKG,
        "cp",
        "/data/local/tmp/showcase_prefs.xml",
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    adb("logcat", "-c", check=False)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")


def god_hand_taps() -> None:
    taps = [
        (0.7, 620, 980),
        (2.2, 480, 900),
        (4.0, 700, 1050),
        (6.0, 540, 920),
    ]
    t0 = time.time()
    for wait, x, y in taps:
        delay = wait - (time.time() - t0)
        if delay > 0:
            time.sleep(delay)
        adb("shell", "input", "tap", str(x), str(y), check=False)


def wait_continue() -> None:
    deadline = time.time() + 22
    while time.time() < deadline:
        adb("shell", "input", "tap", "540", "2100", check=False)  # SKIP
        time.sleep(0.45)
        adb("shell", "input", "tap", "540", "1856", check=False)  # CONTINUE
        log = subprocess.run(
            ["adb", "-s", SERIAL, "logcat", "-d", "-s", "flutter"],
            capture_output=True,
            check=False,
        ).stdout.decode("utf-8", errors="replace")
        if "continue" in log and "dungeon" in log:
            time.sleep(1.6)
            return
        time.sleep(0.35)
    raise SystemExit("did not reach dungeon continue")


def capture_one(save_json: Path, dest_mp4: Path) -> None:
    print("inject", save_json.name)
    inject(save_json)
    wait_continue()
    remote = "/sdcard/gameplay_shorts_raw.mp4"
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
    print("wrote", dest_mp4, dest_mp4.stat().st_size)


def main() -> int:
    shots = [
        ("showcase_entered_hell.json", "gameplay_shorts_hell_raw.mp4"),
        ("showcase_entered_crystal.json", "gameplay_shorts_crystal_raw.mp4"),
        ("showcase_entered_veil.json", "gameplay_shorts_veil_raw.mp4"),
    ]
    if len(sys.argv) == 3:
        shots = [(sys.argv[1], sys.argv[2])]
    for save_name, mp4_name in shots:
        capture_one(PREVIEW / save_name, PREVIEW / mp4_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
