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
    # Stop the app first. A running session autosaves the injected crawl
    # over the file we just put back.
    adb("shell", "am", "force-stop", "com.idleparty.app", check=False)
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
    for _ in range(4):
        adb("shell", "rm", "-f", "/sdcard/ui.xml", check=False)
        dumped = adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
        blob = f"{dumped.stdout}\n{dumped.stderr}"
        if "dumped" not in blob.lower():
            time.sleep(0.35)
            continue
        raw = subprocess.run(
            ["adb", "-s", SERIAL, "exec-out", "cat", "/sdcard/ui.xml"],
            capture_output=True,
            check=False,
        ).stdout.decode("utf-8", errors="replace")
        text = raw.replace("&#10;", " ")
        if text.strip():
            return text
        time.sleep(0.35)
    return ""


def _node_blob(node: str) -> str:
    parts = re.findall(r'(?:content-desc|text)="([^"]*)"', node)
    return " ".join(part for part in parts if part)


def _tap_bounds(node: str) -> bool:
    match = re.search(
        r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        node,
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


def tap_desc(text: str, label: str) -> bool:
    # Attribute order in the dump is not stable, so match the whole node.
    for node in re.findall(r"<node\b[^>]*>", text):
        if (
            f'content-desc="{label}"' not in node
            and f'text="{label}"' not in node
        ):
            continue
        if _tap_bounds(node):
            return True
    return False


def tap_save_one(text: str) -> bool:
    """Open SAVE 1. Prefer the big row, not the small caption inside it."""
    best: tuple[int, int, int] | None = None
    for node in re.findall(r"<node\b[^>]*>", text):
        blob = _node_blob(node)
        if "ERASE" in blob or "SAVE 1" not in blob:
            continue
        match = re.search(
            r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
            node,
        )
        if match is None:
            continue
        x1, y1, x2, y2 = (int(v) for v in match.groups())
        area = max(0, x2 - x1) * max(0, y2 - y1)
        if best is None or area > best[0]:
            best = (area, (x1 + x2) // 2, (y1 + y2) // 2)
    if best is None:
        return False
    adb(
        "shell",
        "input",
        "tap",
        str(best[1]),
        str(best[2]),
        check=False,
    )
    print("tap SAVE 1", best[1], best[2], "area", best[0])
    return True


def tap_contains(text: str, label: str) -> bool:
    for node in re.findall(r"<node\b[^>]*>", text):
        blob = _node_blob(node)
        if label not in blob or "ERASE" in blob:
            continue
        if _tap_bounds(node):
            print("tap", label)
            return True
    return False


def _dismiss_boot(text: str) -> bool:
    if "CHOOSE SAVE" in text or "SAVE 1" in text:
        return tap_save_one(text)
    for label in ("SKIP", "CONTINUE", "GOT IT", "NOT NOW", "MAYBE LATER"):
        if tap_desc(text, label):
            print("tap", label)
            return True
    return False


def wait_fight() -> bool:
    deadline = time.time() + 50
    seen_leave = 0
    while time.time() < deadline:
        text = screen_text()
        if not text:
            time.sleep(0.4)
            continue
        in_fight = (
            "LEAVE" in text
            and "CONTINUE" not in text
            and "SKIP" not in text
            and "CHOOSE SAVE" not in text
            and "Return to hub" not in text
        )
        if in_fight:
            seen_leave += 1
            if seen_leave >= 2:
                time.sleep(1.2)
                return True
            time.sleep(0.6)
            continue
        seen_leave = 0
        if _dismiss_boot(text):
            time.sleep(1.6)
            continue
        time.sleep(0.4)
    print("fight wait missed")
    return False


def wait_hub() -> str:
    """Title → SAVE 1 → hub. Returns the hub dump, or empty."""
    deadline = time.time() + 50
    last = ""
    while time.time() < deadline:
        text = screen_text()
        if not text:
            time.sleep(0.4)
            continue
        last = text
        on_hub = (
            ("GEAR" in text or "Next job" in text)
            and "CHOOSE SAVE" not in text
            and "CONTINUE" not in text
            and "Return to hub" not in text
        )
        if on_hub:
            return text
        if _dismiss_boot(text):
            time.sleep(1.6)
            continue
        time.sleep(0.4)
    print("hub wait missed")
    bits = re.findall(r'(?:content-desc|text)="([^"]+)"', last)
    seen: list[str] = []
    for bit in bits:
        if bit not in seen:
            seen.append(bit)
    print("screen:", " | ".join(seen[:20]))
    return ""


def crawl_story() -> None:
    """One Sandy take: fight, leave, a beat of TODAY, back in the same cave.

    Taps are coordinates. The hub dump stays blank while the torch animates,
    so a label search misses LEAVE and ENTER and the clip never returns.
    Timings match BEATS in build_preview_video.py.
    """
    time.sleep(13.2)
    # First-hour bar is GEAR / GOLD / MORE / LEAVE. LEAVE is the right slot.
    adb("shell", "input", "tap", "945", "2257", check=False)
    print("tap LEAVE")
    time.sleep(0.9)
    # RETURN is the gold button on the leave card.
    adb("shell", "input", "tap", "540", "1460", check=False)
    print("tap RETURN")
    time.sleep(1.6)
    # ENTER DUNGEON on the first-minute hub.
    adb("shell", "input", "tap", "540", "2060", check=False)
    print("tap ENTER")
    time.sleep(8)


def capture_one(save_json: Path, dest_mp4: Path) -> None:
    print("inject", save_json.name)
    inject(save_json)
    if not wait_fight():
        raise SystemExit(f"never reached a fight for {save_json.name}")
    remote = "/sdcard/preview_beat.mp4"
    adb("shell", "rm", "-f", remote, check=False)
    crawl = "crawl" in dest_mp4.name
    story = threading.Thread(
        target=crawl_story if crawl else god_hand_taps,
        daemon=True,
    )
    story.start()
    limit = "28" if crawl else "8"
    print("record", dest_mp4.name, limit + "s")
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
            limit,
            remote,
        ],
        check=True,
    )
    story.join(timeout=2)
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
