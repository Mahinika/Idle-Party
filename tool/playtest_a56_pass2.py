"""~15–20 min A56 exploratory play — screenshot + [IP] notes (no uiautomator)."""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

OUT = Path("tool/out/polish_30")
OUT.mkdir(parents=True, exist_ok=True)
notes: list[str] = []
findings: list[str] = []
oks: list[str] = []
n = 0


def sh(*args: str) -> str:
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def ip_tail(k: int = 30) -> list[str]:
    raw = sh("adb", "-s", "emulator-5554", "logcat", "-d")
    lines = [ln for ln in raw.splitlines() if "[IP]" in ln]
    return lines[-k:]


def shot(tag: str) -> Path:
    global n
    n += 1
    name = f"p2_{n:02d}_{tag}.png"
    path = OUT / name
    sh("adb", "-s", "emulator-5554", "shell", "screencap", "-p", f"/sdcard/{name}")
    sh("adb", "-s", "emulator-5554", "pull", f"/sdcard/{name}", str(path))
    notes.append(f"shot {name} ({path.stat().st_size if path.exists() else 0}b)")
    return path


def tap(x: int, y: int, wait: float = 1.2) -> None:
    sh("adb", "-s", "emulator-5554", "shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def back(wait: float = 0.8) -> None:
    sh("adb", "-s", "emulator-5554", "shell", "input", "keyevent", "4")
    time.sleep(wait)


def flag(msg: str) -> None:
    findings.append(msg)
    print("FIND:", msg)


def ok(msg: str) -> None:
    oks.append(msg)
    print("OK:", msg)


def main() -> int:
    sh("adb", "-s", "emulator-5554", "logcat", "-c")
    shot("start")
    # CONTINUE
    for _ in range(4):
        tap(540, 1858, 1.5)
        time.sleep(1.0)
        ips = "\n".join(ip_tail(8))
        if "continue" in ips or "nav ·" in ips or "enter ·" in ips:
            break
    time.sleep(2)
    shot("hub_or_dungeon")
    ips = ip_tail(15)
    notes.append("after continue: " + " | ".join(ips[-5:]))

    # If offline / tips overlays — tap likely dismiss spots
    for _ in range(5):
        tap(540, 2000, 0.7)
        tap(540, 1700, 0.5)

    shot("hub")
    # Bottom tabs tour (1080x2340): GEAR GOLD SHOP ESSENCE MORE [KEY if endgame]
    tabs = [
        ("GEAR", 108),
        ("GOLD", 324),
        ("SHOP", 540),
        ("ESSENCE", 756),
        ("MORE", 972),
    ]
    for name, x in tabs:
        tap(x, 2200, 1.6)
        shot(f"tab_{name.lower()}")
        ips = ip_tail(6)
        notes.append(f"{name}: " + " | ".join(ips[-3:]))
        # close via BACK (safer than CLOSE miss)
        back(0.9)
        # if still open, tap tab again
        tap(x, 2200, 0.8)
        time.sleep(0.5)

    shot("hub_after_tabs")

    # TODAY / ASCEND / ENTER — mid hub buttons
    tap(540, 1550, 1.2)  # possible ASCEND
    shot("after_ascend_tap")
    back(0.8)
    tap(540, 1780, 1.5)  # ENTER DUNGEON
    time.sleep(2)
    shot("enter_attempt")
    ips = ip_tail(12)
    notes.append("enter: " + " | ".join(ips[-6:]))
    entered = any("enter ·" in ln for ln in ips[-8:])
    if entered:
        ok("entered dungeon")
    else:
        # maybe already in dungeon from boot
        if any("dungeon" in ln for ln in ips[-8:]):
            ok("already / still in dungeon")
            entered = True
        else:
            flag("Could not confirm dungeon enter")

    if entered:
        # Fight loop — God Hand area + wait for clear
        for i in range(28):
            tap(920, 1080, 0.35)
            time.sleep(1.7)
            if i in (0, 8, 16, 24):
                shot(f"fight_{i}")
            ips = ip_tail(10)
            blob = "\n".join(ips).lower()
            if "wipe" in blob:
                shot("wipe")
                notes.append("wipe ips: " + " | ".join(ips[-5:]))
                if "forge" in blob and "power" not in blob:
                    flag("Wipe tip says FORGE without POWER")
                break
            # clear often shows in UI not IP — screenshot mid
        shot("fight_end")
        # HOLD top-right
        tap(980, 220, 1.5)
        shot("after_hold")
        notes.append("after HOLD: " + " | ".join(ip_tail(8)[-5:]))
        # LEAVE
        tap(970, 2200, 1.2)
        shot("leave_dialog")
        # outside tap dismiss
        tap(540, 200, 1.0)
        shot("leave_after_outside")
        ips = ip_tail(8)
        notes.append("leave dismiss: " + " | ".join(ips[-4:]))
        # open leave again and RETURN
        tap(970, 2200, 1.0)
        tap(540, 1450, 1.5)  # RETURN-ish
        shot("after_leave")

    shot("final")
    # Collect IP digest
    all_ip = ip_tail(80)
    (OUT / "P2_IP.txt").write_text("\n".join(all_ip), encoding="utf-8")
    toast_lines = [ln for ln in all_ip if "toast ·" in ln]
    # duplicate consecutive toasts
    for a, b in zip(toast_lines, toast_lines[1:]):
        if a.split("toast ·", 1)[-1] == b.split("toast ·", 1)[-1]:
            flag("Duplicate toast in log: " + a.split("toast ·", 1)[-1][:80])
            break

    report = OUT / "P2_PLAYTEST_NOTES.md"
    lines = (
        ["# A56 playtest pass 2 — findings", "", "## OK"]
        + [f"- {x}" for x in oks]
        + ["", "## Needs work"]
        + [f"- {f}" for f in findings]
        + ["", "## Log"]
        + [f"- {n}" for n in notes]
    )
    report.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {report} oks={len(oks)} findings={len(findings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
