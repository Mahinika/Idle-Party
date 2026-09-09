"""Drive A56 emulator through hub/menus/dungeon for polish notes."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

OUT = Path("tool/out/polish_30")
OUT.mkdir(parents=True, exist_ok=True)
XML = Path("tool/out/polish_30_a56_ui.xml")
notes: list[str] = []
findings: list[str] = []


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
    path = OUT / f"a56_{name}.png"
    with open(path, "wb") as f:
        subprocess.run(
            ["adb", "-s", "emulator-5554", "exec-out", "screencap", "-p"],
            stdout=f,
            check=False,
        )
    notes.append(f"shot {name}")


def tap(x: int, y: int, wait: float = 1.2) -> None:
    sh("adb", "-s", "emulator-5554", "shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tap_label(labels: list[tuple[str, int, int]], *needles: str, wait: float = 1.2) -> str | None:
    low = [n.lower() for n in needles]
    for d, x, y in labels:
        dl = d.lower()
        if all(n in dl for n in low):
            notes.append(f"tap '{d[:60]}' @ ({x},{y})")
            tap(x, y, wait)
            return d
    return None


def flag(msg: str) -> None:
    findings.append(msg)
    print("FIND:", msg)


def main() -> int:
    labels = dump()
    notes.append("start: " + " || ".join(d[:40] for d, _, _ in labels[:12]))
    shot("00_start")
    if not tap_label(labels, "continue"):
        flag("No CONTINUE on start")
        return 1
    time.sleep(2)
    labels = dump()
    # tips / whats new
    for _ in range(8):
        if tap_label(labels, "skip all tips", wait=0.8):
            labels = dump()
            continue
        if tap_label(labels, "got it", wait=0.8):
            labels = dump()
            continue
        if tap_label(labels, "maybe later", wait=0.8):
            labels = dump()
            continue
        break
    shot("01_hub")
    labels = dump()
    hub_text = " | ".join(d for d, _, _ in labels)
    notes.append("hub labels: " + hub_text[:800])
    if "today" not in hub_text.lower():
        flag("TODAY word missing from hub semantics")
    else:
        notes.append("OK TODAY present")
    if "enter dungeon" in hub_text.lower() or "enter key" in hub_text.lower() or "gauntlet" in hub_text.lower() or "boards" in hub_text.lower():
        notes.append("OK primary chase/enter CTA present")
    if "al 20" in hub_text.lower() or "al20" in hub_text.lower():
        notes.append("OK AL20 in hub")
    # Tour bottom bar
    for tab in ("GEAR", "GOLD", "SHOP", "ESSENCE", "MORE", "KEY"):
        labels = dump()
        hit = tap_label(labels, tab.lower(), wait=1.4)
        if not hit:
            flag(f"Could not open {tab}")
            continue
        shot(f"02_{tab.lower()}")
        labels = dump()
        blob = " | ".join(d for d, _, _ in labels)
        notes.append(f"{tab}: " + blob[:500])
        if tab == "GEAR":
            tap_label(labels, "bag", wait=1.0)
            labels = dump()
            bag = " | ".join(d for d, _, _ in labels)
            notes.append("BAG: " + bag[:500])
            if "scrap" in bag.lower() or "sell junk" in bag.lower() or "loadouts" in bag.lower():
                flag("Dead chrome in BAG/GEAR: " + bag[:200])
            if "equip" in bag.lower():
                notes.append("OK EQUIP visible in BAG")
            if "auto equip" in bag.lower() and "equip " in bag.lower():
                # both may be ok if one is tip
                notes.append("NOTE AUTO EQUIP / EQUIP wording: check shot")
        if tab == "GOLD":
            tap_label(labels, "market", wait=1.0)
            labels = dump()
            m = " | ".join(d for d, _, _ in labels)
            notes.append("MARKET: " + m[:400])
            if "upgrade" in m.lower():
                notes.append("OK UPGRADE on market")
            else:
                flag("No UPGRADE badge text on market listings (may be empty stock)")
        if tab == "SHOP":
            if "coming later" in blob.lower():
                notes.append("OK SHOP Coming later")
            else:
                flag("SHOP may look purchaseable / missing Coming later")
        if tab == "MORE":
            if tap_label(labels, "what", wait=1.0) or tap_label(labels, "new", wait=1.0):
                labels = dump()
                wn = " | ".join(d for d, _, _ in labels)
                notes.append("WHATSNEW: " + wn[:400])
                if "1.12.98" not in wn:
                    flag("What's New may not show 1.12.98 in semantics")
                tap_label(labels, "got it", wait=0.8) or tap_label(labels, "close", wait=0.8)
            labels = dump()
            if tap_label(labels, "guide", wait=1.0):
                labels = dump()
                g = " | ".join(d for d, _, _ in labels)
                notes.append("GUIDE: " + g[:400])
                if "lifetime gold" in g.lower():
                    flag("Guide still mentions lifetime gold")
                tap_label(labels, "close", wait=0.8)
        if tab == "KEY":
            if "affix" in blob.lower() or "key +" in blob.lower() or "dial" in blob.lower():
                notes.append("OK KEY dial/affix chrome")
        # close sheet
        labels = dump()
        tap_label(labels, "close", wait=0.8)
        # toggle tab off if still open
        labels = dump()
        if any(tab.lower() in d.lower() and "tab" in d.lower() for d, _, _ in labels):
            tap_label(labels, tab.lower(), wait=0.8)

    # Enter dungeon
    labels = dump()
    shot("03_pre_enter")
    entered = False
    for needles in (
        ("enter key",),
        ("gauntlet",),
        ("greater rift",),
        ("rift",),
        ("ashen",),
        ("enter dungeon",),
    ):
        if tap_label(labels, *needles, wait=1.2):
            labels = dump()
            tap_label(labels, "enter", wait=1.0)
            tap_label(labels, "confirm", wait=1.0)
            time.sleep(1.5)
            labels = dump()
            blob = " | ".join(d for d, _, _ in labels)
            if "leave" in blob.lower() or "farm" in blob.lower() or "god hand" in blob.lower():
                notes.append(f"entered via {needles}")
                entered = True
                break
            labels = dump()
    shot("04_dungeon" if entered else "04_no_enter")
    if entered:
        labels = dump()
        blob = " | ".join(d for d, _, _ in labels)
        notes.append("dungeon: " + blob[:700])
        if "god hand" in blob.lower():
            notes.append("OK God Hand present")
        if "farm" in blob.lower() and "push" in blob.lower():
            notes.append("OK FARM/PUSH")
        # fight a bit + god hand
        for i in range(12):
            labels = dump()
            tap_label(labels, "god hand", wait=0.4)
            time.sleep(2.0)
            labels = dump()
            blob = " | ".join(d for d, _, _ in labels)
            if "wiped" in blob.lower() or "retry" in blob.lower():
                notes.append("wipe seen: " + blob[:300])
                shot("05_wipe")
                if "forge" in blob.lower() and "power" not in blob.lower():
                    flag("Wipe tip says FORGE")
                if "power" in blob.lower() or "open power" in blob.lower():
                    notes.append("OK wipe POWER language")
                break
            if "go stairs" in blob.lower() or "clear" in blob.lower():
                notes.append("clear/stairs: " + blob[:300])
                shot("05_clear")
                if blob.lower().count("walking to stairs") >= 2:
                    flag("Duplicate 'Walking to stairs' toast")
                break
            if i == 5:
                shot("05_midfight")
        # leave
        labels = dump()
        if tap_label(labels, "leave", wait=1.0):
            labels = dump()
            leave = " | ".join(d for d, _, _ in labels)
            notes.append("LEAVE: " + leave[:300])
            shot("06_leave")
            if "floor is clear" in leave.lower() or "stairs ready" in leave.lower():
                notes.append("OK LEAVE clear copy")
            elif "farm loop" in leave.lower() or "fight progress" in leave.lower() or "key run ends" in leave.lower():
                notes.append("OK LEAVE mode-specific copy")
            else:
                flag("LEAVE copy generic/unclear: " + leave[:180])
            tap_label(labels, "return", wait=1.2)
    else:
        flag("Could not enter dungeon from hub")

    shot("99_end")
    report = OUT / "A56_NOTES.md"
    lines = ["# A56 polish playtest", "", "## Findings"] + [f"- {f}" for f in findings] + ["", "## Log"] + [f"- {n}" for n in notes]
    report.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {report} findings={len(findings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
