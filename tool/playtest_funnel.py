"""Time a fresh install on the Samsung A56 and write a funnel timeline.

    py -3 tool/playtest_funnel.py measure
    py -3 tool/playtest_funnel.py nextday
    py -3 tool/playtest_funnel.py restore
    py -3 tool/playtest_funnel.py self-test

`measure` backs up the emulator save, uninstalls, and runs a new game the
way a stranger would: tap the obvious button, leave GEAR / GOLD / MORE
alone, and wait while the party fights. `nextday` moves the emulator clock
forward to check Welcome Back and the day-2 event, then puts the clock back.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

import adb_see

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.idleparty.app"
ACTIVITY = "com.idleparty.app/.MainActivity"
SHOTS = ROOT / "playshots"
BACKUP = SHOTS / "funnel-save-backup.xml"

FUNNEL_RE = re.compile(r"\[IP\] funnel · (.+)$")
IP_RE = re.compile(r"\[IP\] (\w+) · (.*)$")

# A stranger taps the filled button. These are the ones that move the first
# session forward. Anything else is recorded, not pressed.
FORWARD = (
    "SKIP",
    "Consent",
    "GOT IT",
    "NOT NOW",
    "LATER",
    "PLAY",
    "START",
    "ENTER DUNGEON",
    "ENTER",
    "OPEN BAG",
    "OPEN GEAR",
    "OPEN GOLD",
    "RETRY",
    "Tap to continue",
)
# Never press these during a measure. They are the leak if they show up
# before the first boss.
DISTRACTIONS = ("GOLD", "SHOP", "ESSENCE", "KEY", "ASCEND", "LEAVE", "MORE", "GEAR")


def _stamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def _adb(serial: str, *args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    return adb_see.adb(serial, *args, check=check)


def backup_save(serial: str, dest: Path) -> str | None:
    if dest.exists() and dest.stat().st_size > 200:
        return None
    try:
        proc = subprocess.run(
            [
                "adb", "-s", serial, "exec-out", "run-as", PACKAGE,
                "cat", "shared_prefs/FlutterSharedPreferences.xml",
            ],
            capture_output=True,
            timeout=12,
        )
    except subprocess.TimeoutExpired:
        return "save backup timed out"
    data = proc.stdout or b""
    if b"<map" not in data and b"<?xml" not in data:
        err = (proc.stderr or data or b"").decode("utf-8", "replace").strip()
        return err[:400] or "no save to back up"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return None


def restore_save(serial: str, src: Path) -> str | None:
    if not src.exists():
        return f"missing {src}"
    _adb(serial, "shell", "am", "force-stop", PACKAGE)
    time.sleep(0.4)
    remote = "/data/local/tmp/ip_save_restore.xml"
    pushed = subprocess.run(
        ["adb", "-s", serial, "push", str(src), remote],
        capture_output=True,
    )
    if pushed.returncode != 0:
        err = (pushed.stderr or pushed.stdout or b"").decode("utf-8", "replace")
        return err[:400] or "push failed"
    _adb(serial, "shell", "chmod", "644", remote)
    proc = subprocess.run(
        [
            "adb", "-s", serial, "shell", "run-as", PACKAGE,
            "cp", remote, "shared_prefs/FlutterSharedPreferences.xml",
        ],
        capture_output=True,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or b"").decode("utf-8", "replace").strip()
        return err[:400] or "restore failed"
    return None


def log_lines(serial: str, extra: Path | None = None) -> list[str]:
    # Flutter lines only. The main buffer fills with binder noise and drops [IP].
    raw = _adb(serial, "logcat", "-d", "-t", "1500", "-s", "flutter")
    lines = [ln for ln in (raw.stdout or "").splitlines() if "[IP]" in ln]
    if extra is not None and extra.exists():
        lines.extend(
            ln for ln in extra.read_text(encoding="utf-8", errors="replace").splitlines()
            if "[IP]" in ln
        )
    return lines


def parse_funnel(lines: list[str]) -> list[dict[str, str]]:
    hits: list[dict[str, str]] = []
    for ln in lines:
        match = FUNNEL_RE.search(ln)
        if not match:
            continue
        body = match.group(1).strip()
        name, _, rest = body.partition(" ")
        hits.append({"name": name, "detail": rest, "raw": body})
    return hits


def visible_distractions(nodes: list[adb_see.Node]) -> list[str]:
    found: list[str] = []
    for node in nodes:
        if not node.clickable:
            continue
        label = node.label.strip().upper()
        for word in DISTRACTIONS:
            if label == word or label.startswith(word + " "):
                if word not in found:
                    found.append(word)
    return found


def pick_forward(nodes: list[adb_see.Node]) -> adb_see.Node | None:
    clickable = [n for n in nodes if n.clickable]
    for word in FORWARD:
        needle = word.casefold()
        hits = [n for n in clickable if needle in n.label.casefold()]
        if hits:
            hits.sort(key=lambda n: (n.area, n.y1))
            return hits[0]
    return None


def _wait_boot(serial: str, seconds: int = 120) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        prop = _adb(serial, "shell", "getprop", "sys.boot_completed")
        if (prop.stdout or "").strip() == "1":
            return True
        time.sleep(2)
    return False


def _launch_app(serial: str) -> None:
    _adb(serial, "shell", "am", "start", "-n", ACTIVITY)


def _flutter_run(serial: str, log_path: Path) -> subprocess.Popen[str]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    handle = open(log_path, "w", encoding="utf-8", errors="replace")
    # flutter is a .bat on Windows. CreateProcess will not run the bare name.
    proc = subprocess.Popen(
        f'flutter run -d {serial}',
        cwd=ROOT,
        stdin=subprocess.PIPE,
        stdout=handle,
        stderr=subprocess.STDOUT,
        text=True,
        shell=True,
    )
    return proc


def _wait_flutter(log_path: Path, proc: subprocess.Popen[str], seconds: int = 420) -> str:
    deadline = time.time() + seconds
    ready = ("Flutter run key commands", "Syncing files to device", "A Dart VM Service")
    while time.time() < deadline:
        if proc.poll() is not None:
            text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
            return f"flutter run exited {proc.returncode}\n{text[-1500:]}"
        if log_path.exists():
            text = log_path.read_text(encoding="utf-8", errors="replace")
            if any(mark in text for mark in ready):
                return ""
        time.sleep(3)
    return "flutter run did not become ready"


def _shot(serial: str, dest: Path) -> None:
    try:
        adb_see.do_shot(serial, str(dest))
    except SystemExit as err:
        dest.write_text(str(err), encoding="utf-8")


def _write_report(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    print(path)


def measure(serial: str, timeout_sec: int) -> int:
    if not _wait_boot(serial):
        print("emulator did not finish booting")
        return 1
    folder = SHOTS / f"funnel_{_stamp()}"
    folder.mkdir(parents=True, exist_ok=True)
    backup_note = backup_save(serial, BACKUP)
    if backup_note:
        (folder / "backup-note.txt").write_text(backup_note, encoding="utf-8")
        print("save backup skipped:", backup_note)
    else:
        print("save backed up")
    _adb(serial, "uninstall", PACKAGE)
    _adb(serial, "logcat", "-c")
    flutter_log = folder / "flutter.txt"
    proc = _flutter_run(serial, flutter_log)
    failed = _wait_flutter(flutter_log, proc)
    if failed:
        print(failed)
        return 1
    time.sleep(2)
    started = time.time()
    taps = 0
    timeline: list[str] = []
    seen: set[str] = set()
    distractions: list[str] = []
    last_shot = 0.0
    stuck = 0
    boss = False
    while time.time() - started < timeout_sec:
        lines = log_lines(serial, flutter_log)
        for hit in parse_funnel(lines):
            key = hit["raw"]
            if key in seen:
                continue
            seen.add(key)
            elapsed = int(time.time() - started)
            timeline.append(f"{elapsed}s  {hit['raw']}")
            print(timeline[-1])
            _shot(serial, folder / f"{elapsed:04d}-{hit['name']}.png")
            if hit["name"] == "first_boss":
                boss = True
        if boss:
            break
        try:
            nodes = adb_see.parse_nodes(adb_see.dump_xml(serial))
        except SystemExit:
            nodes = []
        if nodes:
            for word in visible_distractions(nodes):
                if word not in distractions:
                    distractions.append(word)
                    elapsed = int(time.time() - started)
                    timeline.append(f"{elapsed}s  tab {word} visible")
                    print(timeline[-1])
            choice = pick_forward(nodes)
            in_fight = any(h["name"] in ("first_enter", "time_to_combat") for h in parse_funnel(lines))
            # Once the party is fighting, only tap a forward button that is
            # a wipe or a dialog. Do not open menus.
            if choice is not None:
                label = choice.label
                upper = label.upper()
                fight_ok = upper.startswith("RETRY") or upper.startswith("OPEN ") or "GOT IT" in upper or "NOT NOW" in upper
                if not in_fight or fight_ok:
                    print(f"tap {label[:80]}")
                    _adb(serial, "shell", "input", "tap", str(choice.cx), str(choice.cy))
                    taps += 1
                    stuck = 0
                    time.sleep(1.2)
                    continue
            stuck += 1
        if time.time() - last_shot > 45:
            _shot(serial, folder / f"{int(time.time() - started):04d}-wait.png")
            last_shot = time.time()
        time.sleep(4)
    elapsed = int(time.time() - started)
    _shot(serial, folder / f"{elapsed:04d}-end.png")
    report = folder / "report.md"
    lines_out = [
        f"# Funnel {folder.name}",
        "",
        f"- seconds: {elapsed}",
        f"- taps: {taps}",
        f"- first boss: {'yes' if boss else 'no'}",
        f"- tabs seen: {', '.join(distractions) if distractions else '(none)'}",
        "",
        "## Timeline",
        "",
    ]
    lines_out.extend(f"- {row}" for row in timeline)
    if not timeline:
        lines_out.append("- (no funnel lines)")
    _write_report(report, "\n".join(lines_out) + "\n")
    # Leave flutter run attached so later steps can hot-restart.
    (folder / "flutter.pid").write_text(str(proc.pid), encoding="utf-8")
    return 0 if boss else 2


def _set_clock(serial: str, when: str) -> str:
    """`when` is MMDDhhmmYYYY. Requires adb root on the emulator."""
    _adb(serial, "root")
    time.sleep(1.5)
    # date on toybox wants MMDDhhmm[[CC]YY][.ss]
    proc = _adb(serial, "shell", "date", when)
    return ((proc.stdout or "") + (proc.stderr or "")).strip()


def nextday(serial: str) -> int:
    if not _wait_boot(serial, 30):
        print("emulator not booted")
        return 1
    folder = SHOTS / f"funnel_nextday_{_stamp()}"
    folder.mkdir(parents=True, exist_ok=True)
    _adb(serial, "logcat", "-c")
    # One day and two hours ahead of the emulator clock.
    shifted = _set_clock(serial, time.strftime("%m%d%H%M%Y", time.localtime(time.time() + 26 * 3600)))
    (folder / "clock.txt").write_text(shifted + "\n", encoding="utf-8")
    _adb(serial, "shell", "am", "force-stop", PACKAGE)
    time.sleep(1)
    _launch_app(serial)
    cold = _watch(serial, folder, "cold", seconds=90)
    # Background path: leave the process alive, move the clock, come back.
    _adb(serial, "shell", "input", "keyevent", "3")
    time.sleep(2)
    _set_clock(serial, time.strftime("%m%d%H%M%Y", time.localtime(time.time() + 50 * 3600)))
    time.sleep(3)
    _launch_app(serial)
    back = _watch(serial, folder, "resume", seconds=60)
    # Put the clock back so the emulator is usable.
    restored = _set_clock(serial, time.strftime("%m%d%H%M%Y"))
    (folder / "clock-restored.txt").write_text(restored + "\n", encoding="utf-8")
    body = ["# Next day", "", "## Cold start", "", *cold, "", "## Resume", "", *back, ""]
    _write_report(folder / "report.md", "\n".join(body))
    return 0


def _watch(serial: str, folder: Path, tag: str, seconds: int) -> list[str]:
    deadline = time.time() + seconds
    seen: set[str] = set()
    rows: list[str] = []
    while time.time() < deadline:
        for hit in parse_funnel(log_lines(serial)):
            if hit["raw"] in seen:
                continue
            seen.add(hit["raw"])
            rows.append(f"- {tag}: {hit['raw']}")
            print(rows[-1])
        time.sleep(3)
    try:
        nodes = adb_see.parse_nodes(adb_see.dump_xml(serial))
    except SystemExit:
        nodes = []
    labels = [n.label for n in nodes if n.label]
    welcome = any("welcome" in label.casefold() for label in labels)
    today = any("today" in label.casefold() or "grow" in label.casefold() for label in labels)
    rows.append(f"- welcome back visible: {'yes' if welcome else 'no'}")
    rows.append(f"- today-like label: {'yes' if today else 'no'}")
    _shot(serial, folder / f"{tag}.png")
    return rows


def self_test() -> int:
    sample = [
        "I/flutter: [IP] funnel · first_enter dungeon_id=sandy seconds_to_combat=11",
        "I/flutter: [IP] funnel · first_boss",
        "I/flutter: [IP] nav · hub",
        "I/flutter: [IP] funnel · party_wipe dungeon_id=sandy floor=3 streak=1",
    ]
    hits = parse_funnel(sample)
    assert [h["name"] for h in hits] == ["first_enter", "first_boss", "party_wipe"], hits
    assert "seconds_to_combat=11" in hits[0]["detail"]
    xml = """
    <hierarchy>
      <node text="" content-desc="ENTER DUNGEON" class="android.widget.Button"
            clickable="true" bounds="[40,1400][1040,1560]" />
      <node text="" content-desc="GOLD" class="android.widget.Button"
            clickable="true" bounds="[200,2100][400,2300]" />
      <node text="" content-desc="GEAR" class="android.widget.Button"
            clickable="true" bounds="[0,2100][180,2300]" />
    </hierarchy>
    """
    nodes = adb_see.parse_nodes(xml)
    assert pick_forward(nodes).label == "ENTER DUNGEON"
    assert visible_distractions(nodes) == ["GEAR", "GOLD"]
    print("playtest_funnel self-test ok")
    return 0


def main(argv: list[str] | None = None) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="A56 funnel measure")
    parser.add_argument("--serial", default=None)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("cmd", choices=("measure", "nextday", "restore", "self-test"))
    args = parser.parse_args(argv)
    if args.cmd == "self-test":
        return self_test()
    serial = adb_see.resolve_serial(args.serial)
    if args.cmd == "measure":
        return measure(serial, args.timeout)
    if args.cmd == "nextday":
        return nextday(serial)
    err = restore_save(serial, BACKUP)
    if err:
        print(err)
        return 1
    print("save restored")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
