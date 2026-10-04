#!/usr/bin/env python3
"""Phone screenshots for the Play listing, from the Samsung A56.

Shots 1–3 use the new-save Sandy crawl (first_minute_save.json).
Shots 4–8 use the AL3 showcase hub (showcase_save.json).
The emulator save is restored when this finishes, including on failure.

  py -3 tool/store_listing/capture_a56_shots.py

Raw PNGs land in tool/store_listing/raw/ at 1080x2340.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

from capture_preview_beats import (
    backup_prefs,
    restore_prefs,
    screen_text,
    tap_contains,
    tap_desc,
    tap_save_one,
    wait_fight,
    wait_hub,
)
from capture_shorts_shots import SERIAL, adb, inject

ROOT = Path(__file__).resolve().parents[2]
LISTING = Path(__file__).resolve().parent
RAW = LISTING / "raw"
FIRST = LISTING / "first_minute_save.json"
SHOWCASE = LISTING / "showcase_save.json"
STABLE = LISTING / "showcase_stable.json"


def tap_node(xml: str, label: str) -> bool:
    for node in re.findall(r"<node\b[^>]*>", xml):
        if f'content-desc="{label}"' not in node and f'text="{label}"' not in node:
            continue
        bounds = re.search(
            r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
            node,
        )
        if bounds is None:
            continue
        x1, y1, x2, y2 = (int(v) for v in bounds.groups())
        adb(
            "shell",
            "input",
            "tap",
            str((x1 + x2) // 2),
            str((y1 + y2) // 2),
            check=False,
        )
        print("tap", label)
        return True
    return False


def dismiss(xml: str) -> bool:
    for label in ("SKIP", "CONTINUE", "GOT IT", "NOT NOW", "MAYBE LATER", "SKIP ALL TIPS"):
        if tap_node(xml, label):
            return True
    return False


def wait_any(labels: tuple[str, ...], timeout: float = 40) -> str:
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        xml = screen_text()
        if not xml:
            time.sleep(0.4)
            continue
        last = xml
        if any(label in xml for label in labels):
            return xml
        if dismiss(xml):
            time.sleep(0.7)
            continue
        time.sleep(0.4)
    print("wait missed", labels)
    _print_labels(last)
    return ""


def _print_labels(xml: str) -> None:
    found: list[str] = []
    for node in re.findall(r"<node\b[^>]*>", xml):
        for key in ("content-desc", "text"):
            match = re.search(rf'{key}="([^"]+)"', node)
            if match and match.group(1) not in found:
                found.append(match.group(1))
    print("screen:", " | ".join(found[:20]))


def screencap(name: str) -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    dest = RAW / name
    raw = subprocess.run(
        ["adb", "-s", SERIAL, "exec-out", "screencap", "-p"],
        check=True,
        capture_output=True,
    ).stdout
    # A clean exec-out PNG already has the real signature. Only undo a
    # Windows CRLF translation, then put the signature's CR back.
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raw = raw.replace(b"\r\n", b"\n")
        if raw.startswith(b"\x89PNG\n\x1a\n"):
            raw = b"\x89PNG\r\n\x1a\n" + raw[len(b"\x89PNG\n\x1a\n") :]
    if not raw.startswith(b"\x89PNG"):
        raise SystemExit(f"screencap was not a PNG ({len(raw)} bytes) for {name}")
    dest.write_bytes(raw)
    print("wrote", dest.name, dest.stat().st_size)


def open_played_slot(timeout: float = 35) -> None:
    """Title → CONTINUE → SAVE 1. The hub animates, so the dump often goes blank."""
    deadline = time.time() + timeout
    opened = False
    while time.time() < deadline:
        xml = screen_text()
        if opened and not xml:
            time.sleep(2.0)
            return
        if not xml:
            time.sleep(0.4)
            continue
        if "Welcome back" in xml or 'text="NICE"' in xml or 'content-desc="NICE"' in xml:
            return
        if ("GEAR" in xml or "Next job" in xml) and "CHOOSE SAVE" not in xml:
            return
        if "CHOOSE SAVE" in xml:
            if tap_save_one(xml):
                opened = True
                time.sleep(2.0)
            continue
        if dismiss(xml):
            time.sleep(1.0)
            continue
        time.sleep(0.4)
    if not opened:
        raise SystemExit("could not open SAVE 1")


def shoot_first_minute() -> None:
    print("inject first minute")
    inject(FIRST)
    if not wait_fight():
        raise SystemExit("first-minute save never reached a fight")
    time.sleep(0.8)
    screencap("01_combat_a.png")
    time.sleep(3.0)
    screencap("02_combat_b.png")
    xml = screen_text()
    if not tap_node(xml, "LEAVE"):
        raise SystemExit("LEAVE not on the fight")
    xml = wait_any(("RETURN",), timeout=12)
    if not xml or not tap_node(screen_text() or xml, "RETURN"):
        raise SystemExit("RETURN not on the leave confirm")
    time.sleep(2.5)
    screencap("03_hub_today.png")


def showcase_for_shoot(bosses: int) -> Path:
    """Hub save that survives a second phone load without moving the clock.

    showcase_stable.json was already passed through stateFromJson, so opening
    it does not add heroes or restamp lastUpdated. Boss kills are the only
    knob: 0 keeps Ascend off the gear and map shots, 4 makes Ascend real.
    """
    if not STABLE.exists():
        raise SystemExit(
            "missing showcase_stable.json — run: "
            "flutter test tool/store_listing/export_showcase_save_test.dart "
            "--name \"export load-stable\""
        )
    data = json.loads(STABLE.read_text(encoding="utf-8"))
    data["bossVictories"] = bosses
    depth = data.get("metaDepth")
    if isinstance(depth, dict):
        depth["pendingHeroReveals"] = []
        data["metaDepth"] = depth
    dest = LISTING / "preview" / "_showcase_shoot.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    return dest


def shoot_showcase() -> None:
    # Flutter still animates, but system scales stop the dump from waiting forever.
    for key in (
        "animator_duration_scale",
        "transition_animation_scale",
        "window_animation_scale",
    ):
        adb("shell", "settings", "put", "global", key, "0", check=False)
    print("inject showcase hub")
    inject(showcase_for_shoot(0), ahead_minutes=30)
    open_played_slot()
    time.sleep(1.0)
    adb("shell", "input", "tap", "112", "2257", check=False)
    print("tap GEAR")
    time.sleep(1.4)
    screencap("04_gear.png")
    # Party list is the ROSTER tab on that sheet.
    adb("shell", "input", "tap", "496", "400", check=False)
    print("tap ROSTER")
    time.sleep(1.0)
    screencap("05_party.png")
    adb("shell", "input", "keyevent", "4", check=False)
    time.sleep(0.9)
    screencap("06_path.png")

    print("inject showcase welcome-back")
    inject(showcase_for_shoot(4), ahead_minutes=-180)
    open_played_slot()
    time.sleep(0.8)
    screencap("07_return.png")
    # NICE is the lower button on Welcome Back. ASCEND +16e sits between
    # ENTER DUNGEON (label ~1800) and DAILY RUN (~2064).
    adb("shell", "input", "tap", "540", "1670", check=False)
    print("tap NICE")
    time.sleep(1.1)
    adb("shell", "input", "tap", "540", "1948", check=False)
    print("tap ASCEND")
    time.sleep(0.8)
    screencap("08_ascend.png")


def main() -> int:
    if not FIRST.exists() or not SHOWCASE.exists() or not STABLE.exists():
        raise SystemExit(
            "missing save json — run: "
            "flutter test tool/store_listing/export_showcase_save_test.dart"
        )
    backup_prefs()
    try:
        shoot_first_minute()
        shoot_showcase()
    finally:
        restore_prefs()
    return 0


if __name__ == "__main__":
    sys.exit(main())
