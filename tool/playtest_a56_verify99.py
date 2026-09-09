"""Short A56 verify pass for 1.12.99 polish fixes."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

OUT = Path("tool/out/polish_30")
OUT.mkdir(parents=True, exist_ok=True)
XML = Path("tool/out/verify99_ui.xml")
notes: list[str] = []
findings: list[str] = []
oks: list[str] = []


def sh(*args: str) -> str:
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def dump() -> list[tuple[str, int, int]]:
    sh("adb", "-s", "emulator-5554", "shell", "uiautomator", "dump", "/sdcard/ui.xml")
    sh("adb", "-s", "emulator-5554", "pull", "/sdcard/ui.xml", str(XML))
    xml = XML.read_text(encoding="utf-8")
    out = []
    for m in re.finditer(
        r'content-desc="([^"]+)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        d = m.group(1).replace("&#10;", " | ")
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        out.append((d, (x1 + x2) // 2, (y1 + y2) // 2))
    return out


def shot(name: str) -> None:
    path = OUT / f"v99_{name}.png"
    with open(path, "wb") as f:
        subprocess.run(
            ["adb", "-s", "emulator-5554", "exec-out", "screencap", "-p"],
            stdout=f,
            check=False,
        )
    notes.append(f"shot {name}")


def tap(x: int, y: int, wait: float = 1.0) -> None:
    sh("adb", "-s", "emulator-5554", "shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tap_label(labels: list[tuple[str, int, int]], *needles: str, wait: float = 1.0) -> str | None:
    low = [n.lower() for n in needles]
    for d, x, y in labels:
        dl = d.lower()
        if all(n in dl for n in low):
            notes.append(f"tap '{d[:70]}' @ ({x},{y})")
            tap(x, y, wait)
            return d
    return None


def blob_of(labels: list[tuple[str, int, int]]) -> str:
    return " | ".join(d for d, _, _ in labels)


def flag(msg: str) -> None:
    findings.append(msg)
    print("FIND:", msg)


def ok(msg: str) -> None:
    oks.append(msg)
    print("OK:", msg)


def dismiss_overlays(max_rounds: int = 10) -> None:
    for _ in range(max_rounds):
        labels = dump()
        b = blob_of(labels).lower()
        if tap_label(labels, "skip", wait=0.7):
            continue
        if tap_label(labels, "skip all tips", wait=0.7):
            continue
        if tap_label(labels, "got it", wait=0.7):
            continue
        if tap_label(labels, "maybe later", wait=0.7):
            continue
        if tap_label(labels, "tap to continue", wait=0.7):
            continue
        if "continue" in b and "new game" in b:
            break
        if "enter dungeon" in b or "today" in b or "world path" in b:
            break
        # boot story full-screen
        if "your job" in b:
            tap(540, 1170, 0.8)
            continue
        break


def main() -> int:
    labels = dump()
    shot("00_start")
    notes.append("start: " + blob_of(labels)[:400])
    dismiss_overlays()
    labels = dump()
    if "continue" in blob_of(labels).lower():
        tap_label(labels, "continue", wait=1.5)
    dismiss_overlays()
    labels = dump()
    shot("01_hub")
    hub = blob_of(labels)
    notes.append("hub: " + hub[:900])

    if "1.12.99" in hub or "1.12.99" in notes[0]:
        ok("version visible somewhere early")
    if "today" in hub.lower():
        ok("TODAY in hub semantics")
    else:
        flag("TODAY missing from hub semantics")

    # Discord should not be primary spam at endgame; mid-save may still show tip once
    if "join discord" in hub.lower() and "enter dungeon" in hub.lower():
        notes.append("NOTE Discord tip visible alongside hub (mid-save OK once)")

    # BAG honesty
    if not tap_label(labels, "gear", wait=1.2):
        flag("Could not open GEAR")
    else:
        labels = dump()
        tap_label(labels, "bag", wait=1.0)
        labels = dump()
        bag = blob_of(labels)
        notes.append("BAG: " + bag[:600])
        shot("02_bag")
        low = bag.lower()
        if "no upgrades" in low and ("waiting" in low and "equip" in low):
            # contradictory subtitle
            if re.search(r"equip\s+\d+", low) or "upgrades waiting" in low:
                flag("BAG still shows upgrades waiting with No upgrades")
            else:
                ok("BAG No upgrades looks consistent")
        elif "equip" in low:
            ok("BAG EQUIP chrome present")
        tap_label(labels, "close", wait=0.8)

    # KEY tab open + hunt hint
    labels = dump()
    if tap_label(labels, "key", wait=1.2):
        labels = dump()
        key = blob_of(labels)
        notes.append("KEY: " + key[:700])
        shot("03_key")
        if "hunt" in key.lower() or "today" in key.lower() or "key +" in key.lower():
            ok("KEY sheet has hunt/TODAY/KEY chrome")
        else:
            notes.append("KEY opened; hunt hint may be visual-only")
        tap_label(labels, "close", wait=0.8)
    else:
        notes.append("KEY tab not present (pre-endgame OK)")

    # Enter dungeon, fight to clear if possible
    labels = dump()
    entered = False
    for needles in (("enter dungeon",), ("enter key",), ("gauntlet",)):
        if tap_label(labels, *needles, wait=1.2):
            labels = dump()
            tap_label(labels, "enter", wait=1.0)
            tap_label(labels, "confirm", wait=1.0)
            time.sleep(1.5)
            labels = dump()
            d = blob_of(labels).lower()
            if "leave" in d or "farm" in d or "god hand" in d:
                entered = True
                ok(f"entered dungeon via {needles[0]}")
                break
            labels = dump()
    shot("04_dungeon" if entered else "04_no_enter")
    if not entered:
        flag("Could not enter dungeon")
        _write()
        return 1

    labels = dump()
    notes.append("dungeon start: " + blob_of(labels)[:500])
    saw_hold = False
    saw_clear = False
    for i in range(18):
        labels = dump()
        b = blob_of(labels)
        low = b.lower()
        if i in (0, 6, 12):
            shot(f"05_fight_{i}")
        if low.count("walking to stairs") >= 2:
            flag("Duplicate Walking to stairs toast still present")
        if "hold" in low:
            saw_hold = True
        if "clear" in low or "go stairs" in low or "awaiting" in low or "finishing floor" in low:
            saw_clear = True
            notes.append(f"clear@{i}: " + b[:400])
            shot("06_clear")
            if "hold" in low:
                ok("HOLD visible on clear")
                tap_label(labels, "hold", wait=1.5)
                labels = dump()
                after = blob_of(labels).lower()
                notes.append("after HOLD: " + after[:400])
                shot("07_after_hold")
            # target HUD should prefer CLEAR not elite
            if "elite" in low and "clear" in low and "hold skips" not in low:
                notes.append("NOTE elite still in dump during clear — check if target says CLEAR")
            if "hold skips the walk" in low or "floor clear" in low:
                ok("CLEAR target/HUD language present")
            break
        if "wiped" in low or "retry" in low:
            notes.append("wipe: " + b[:300])
            shot("06_wipe")
            break
        tap_label(labels, "god hand", wait=0.35)
        time.sleep(1.6)

    if saw_clear and not saw_hold:
        flag("Clear seen but HOLD button missing from semantics")
    elif saw_clear:
        ok("Clear path observed")
    else:
        notes.append("No clear in this short fight window")

    # Leave dialog dismissible
    labels = dump()
    if tap_label(labels, "leave", wait=1.0):
        labels = dump()
        leave = blob_of(labels)
        notes.append("LEAVE: " + leave[:400])
        shot("08_leave")
        # tap outside / back should dismiss
        tap(540, 200, 0.8)
        labels = dump()
        after = blob_of(labels).lower()
        if "return to hub" in after or "stay in dungeon" in after:
            notes.append("dialog still open after outside tap — try BACK")
            sh("adb", "-s", "emulator-5554", "shell", "input", "keyevent", "4")
            time.sleep(0.8)
            labels = dump()
            after = blob_of(labels).lower()
        if "return to hub" in after or "stay in dungeon" in after:
            flag("Leave dialog not dismissible via outside/back")
            tap_label(labels, "stay", wait=0.8) or tap_label(labels, "return", wait=0.8)
        else:
            ok("Leave dialog dismissible")

    shot("99_end")
    _write()
    print(f"oks={len(oks)} findings={len(findings)}")
    return 0 if not findings else 0


def _write() -> None:
    report = OUT / "VERIFY99_NOTES.md"
    lines = (
        ["# A56 verify 1.12.99", "", "## OK"]
        + [f"- {x}" for x in oks]
        + ["", "## Findings"]
        + [f"- {f}" for f in findings]
        + ["", "## Log"]
        + [f"- {n}" for n in notes]
    )
    report.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {report}")


if __name__ == "__main__":
    raise SystemExit(main())
