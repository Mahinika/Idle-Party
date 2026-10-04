"""Drive a /playtest session on the Samsung A56.

    py -3 tool/playtest_run.py start
    py -3 tool/playtest_run.py snap [name]
    py -3 tool/playtest_run.py tap LABEL [--expect TEXT]
    py -3 tool/playtest_run.py back
    py -3 tool/playtest_run.py swipe X1 Y1 X2 Y2
    py -3 tool/playtest_run.py fight [seconds]
    py -3 tool/playtest_run.py status
    py -3 tool/playtest_run.py note TEXT --type kod|ux|visuellt --sev blockerar|forvirrar|kosmetiskt
    py -3 tool/playtest_run.py ok SCREEN
    py -3 tool/playtest_run.py good SCREEN "why it is good"
    py -3 tool/playtest_run.py learn "pattern" [--rule id]
    py -3 tool/playtest_run.py report
    py -3 tool/playtest_run.py after FINDING_ID
    py -3 tool/playtest_run.py restore

A round with no extra words continues the save already on the emulator.
The save is copied out before the app is restarted. `restore` puts it back.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import adb_see
from adb_see import Node
from playtest_checks import (
    SCREEN_H,
    SCREEN_W,
    CheckFinding,
    run_checks,
)
from playtest_imgdiff import contact_sheet, diff_images, scale_rect

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "playshots" / "playtest"
CURRENT = SHOTS / "current.txt"
MEMORY_JSON = ROOT / "tool" / "playtest_memory.json"
MEMORY_MD = ROOT / "docs" / "PLAYTEST_MEMORY.md"
SCREENS_JSON = ROOT / "tool" / "playtest_screens.json"
BASELINE = ROOT / "tool" / "playtest_baseline"
PACKAGE = "com.idleparty.app"
ACTIVITY = "com.idleparty.app/.MainActivity"

TARGET_SECONDS = 600
SHORT_SECONDS = 480
MOVE_PX = 120
PIXEL_FLAG = 0.03
FIGHT_EVERY = 20

EMPTY_MEMORY = {"good": [], "learned": [], "ok": []}

_ABSOLUTE = re.compile(r"\[IP\] (boot|continue|new_game|leave)\b")
_GOLD_ABS = re.compile(r"\bgold\s+(\d+)\b")
_ESSENCE_ABS = re.compile(r"\be\s+(\d+)\b")
_AL_ABS = re.compile(r"\bAL(\d+)\b")
_MEAN_ABS = re.compile(r"\bmeanLv\s+(\d+)")
_DUNGEON = re.compile(r"·\s+dungeon\s+\S+")
_HUB = re.compile(r"·\s+hub\s+·")
_DELTA = re.compile(r"\b(gold|e|AL)\s+(\d+)\s*→\s*(\d+)")
_NAV = re.compile(r"\[IP\] nav ·\s*(.+)$")
_LOG_BAD = re.compile(r"E/flutter|FATAL|ANR in|Skipped \d+ frames|Exception")
_FLUTTER_PID = re.compile(r"flutter\s*\(\s*(\d+)\s*\)", re.I)
_LOG_PID = re.compile(r"\(\s*(\d+)\s*\)")
_REFUSE = re.compile(r"\b(overwrite|erase|reborn|redeem|delete)\b", re.I)
_WARN = re.compile(r"\b(ascend|scrap|sell)\b", re.I)
_SAVE_LABEL = re.compile(r"^SAVE [1-5]\b", re.I)

_DELTA_KEY = {"gold": "gold", "e": "essence", "AL": "al"}
_SEV = {
    "state_mismatch": "blockerar",
    "offline_mismatch": "blockerar",
    "dead_end": "forvirrar",
    "jargon": "kosmetiskt",
}
_TYPE = {
    "state_mismatch": "kod",
    "offline_mismatch": "kod",
    "log_error": "kod",
    "dump_failed": "kod",
    "pixels_changed": "visuellt",
    "offscreen": "visuellt",
    "tree_moved": "visuellt",
}


def fold_ip_state(text: str) -> dict:
    """Walk [IP] lines. A continue/boot line sets the save; later deltas update it."""
    state: dict = {}
    for line in text.splitlines():
        if "[IP]" not in line:
            continue
        if _ABSOLUTE.search(line):
            if match := _AL_ABS.search(line):
                state["al"] = int(match.group(1))
            if match := _GOLD_ABS.search(line):
                state["gold"] = int(match.group(1))
            if match := _ESSENCE_ABS.search(line):
                state["essence"] = int(match.group(1))
            if match := _MEAN_ABS.search(line):
                state["mean_lv"] = int(match.group(1))
            if _DUNGEON.search(line):
                state["in_dungeon"] = True
            elif _HUB.search(line):
                state["in_dungeon"] = False
        elif "[IP] enter" in line:
            state["in_dungeon"] = True
        elif "[IP] state" in line:
            for key, _before, after in _DELTA.findall(line):
                state[_DELTA_KEY[key]] = int(after)
    return state


def stage_of(state: dict) -> str:
    al = int(state.get("al") or 0)
    mean = int(state.get("mean_lv") or 0)
    if mean >= 100 or al >= 20:
        return "endgame"
    if al == 0 and mean < 20:
        return "early"
    return "mid"


def wants_jargon(state: dict, stage: str) -> bool:
    return int(state.get("al") or 0) == 0 and stage != "endgame"


def latest_nav(text: str) -> str:
    found = ""
    for line in text.splitlines():
        match = _NAV.search(line.strip())
        if match:
            found = match.group(1).strip()
    return found


def screen_from_nav(nav: str, in_dungeon: bool = False) -> str:
    low = nav.strip().lower()
    if low.startswith("gear/bag"):
        return "bag"
    if low.startswith("gear/"):
        return "gear"
    if low.startswith("gold/"):
        return "gold"
    if low.startswith("essence/"):
        return "essence"
    if low.startswith("more/"):
        return "more"
    if low == "shop":
        return "shop"
    if low == "key":
        return "key"
    if in_dungeon:
        return "dungeon"
    return "hub"


def title_hint(nodes: list[Node]) -> str:
    for node in nodes:
        if node.clickable or " · " not in node.label:
            continue
        return node.label.split(" · ", 1)[0].strip()
    return ""


def pick_save_slot(nodes: list[Node], hint: str = "") -> Node | None:
    saves = [n for n in nodes if _SAVE_LABEL.match(n.label.strip())]
    if not saves:
        return None
    if hint:
        named = [
            n
            for n in nodes
            if hint.casefold() in n.label.casefold() and n not in saves
        ]
        if named:
            target = named[0]
            return min(saves, key=lambda n: abs(n.cy - target.cy))
    erases = [n for n in nodes if n.label.strip().upper().startswith("ERASE")]
    empties = [n for n in nodes if n.label.strip().casefold() == "empty"]

    def near(save: Node, other: Node) -> bool:
        return abs(save.cy - other.cy) < 90

    occupied = [
        save
        for save in saves
        if any(near(save, erase) for erase in erases)
        and not any(near(save, empty) for empty in empties)
    ]
    if not occupied:
        occupied = [
            save
            for save in saves
            if not any(near(save, empty) for empty in empties)
        ]
    pool = occupied or saves
    pool.sort(key=lambda n: (n.y1, n.x1))
    return pool[0]


def offline_notes(before: dict, after: dict, welcome: str) -> list[dict]:
    """Flag only when Welcome back states a number the save did not change by."""
    if "welcome back" not in welcome.lower():
        return []
    notes = []
    checks = (
        ("gold", "gold", r"(?:earned\s+(\d+)\s+gold|\+(\d+)\s*g\b)"),
        ("essence", "essence", r"(?:Essence earned[^\d]*(\d+)|\+(\d+)\s*e\b)"),
    )
    for key, label, pattern in checks:
        if key not in before or key not in after:
            continue
        match = re.search(pattern, welcome, re.I)
        if not match:
            continue
        shown = int(next(group for group in match.groups() if group))
        delta = int(after[key]) - int(before[key])
        slack = max(2, int(0.05 * max(shown, 1)))
        if abs(delta - shown) > slack:
            notes.append(
                {
                    "rule": "offline_mismatch",
                    "screen": "offline",
                    "label": label,
                    "type": "kod",
                    "sev": "blockerar",
                    "message": (
                        f"Welcome back says {shown} {label} "
                        f"but the save changed by {delta}"
                    ),
                }
            )
    return notes


def tree_diff(current: list[dict], baseline: list[dict]) -> list[dict]:
    findings: list[dict] = []
    current_names = {
        n["label"].casefold()
        for n in current
        if n.get("clickable") and not any(ch.isdigit() for ch in n["label"])
    }
    missing = []
    for node in baseline:
        if not node.get("clickable") or any(ch.isdigit() for ch in node["label"]):
            continue
        if node["label"].casefold() not in current_names and node["label"] not in missing:
            missing.append(node["label"])
    for label in missing[:6]:
        findings.append(
            {
                "rule": "tree_missing",
                "label": label,
                "message": f"Button gone since this screen was marked good: {label}",
            }
        )
    base_at = _unique_centers(baseline)
    cur_at = _unique_centers(current)
    for key, (bx, by, label) in base_at.items():
        if key not in cur_at:
            continue
        cx, cy, _label = cur_at[key]
        if ((cx - bx) ** 2 + (cy - by) ** 2) ** 0.5 > MOVE_PX:
            findings.append(
                {
                    "rule": "tree_moved",
                    "label": label,
                    "message": f"{label} moved more than {MOVE_PX}px since the baseline",
                }
            )
    before = _primary(baseline)
    after = _primary(current)
    if before and after and before.casefold() != after.casefold():
        findings.append(
            {
                "rule": "primary_changed",
                "label": after,
                "message": f"Main button was {before} and is now {after}",
            }
        )
    return findings


def _unique_centers(nodes: list[dict]) -> dict[str, tuple[float, float, str]]:
    groups: dict[str, list[dict]] = {}
    for node in nodes:
        if any(ch.isdigit() for ch in node["label"]):
            continue
        groups.setdefault(node["label"].casefold(), []).append(node)
    found = {}
    for key, group in groups.items():
        if len(group) != 1:
            continue
        node = group[0]
        found[key] = (
            (node["x1"] + node["x2"]) / 2,
            (node["y1"] + node["y2"]) / 2,
            node["label"],
        )
    return found


def _primary(nodes: list[dict]) -> str | None:
    candidates = []
    for node in nodes:
        if not node.get("clickable"):
            continue
        area = (node["x2"] - node["x1"]) * (node["y2"] - node["y1"])
        if area <= 0 or area > SCREEN_W * SCREEN_H * 0.5:
            continue
        candidates.append(node)
    if not candidates:
        return None
    best = max(
        candidates,
        key=lambda n: (n["y1"], (n["x2"] - n["x1"]) * (n["y2"] - n["y1"])),
    )
    return best["label"]


def screen_touched(prefixes: list[str], changed: list[str]) -> bool:
    for path in changed:
        path = path.replace("\\", "/")
        for prefix in prefixes:
            if path.startswith(prefix):
                return True
    return False


def extra_screens(ok_rows: list[dict], screens: dict, changed: list[str]) -> list[dict]:
    found = []
    catalog = screens.get("screens", {})
    for row in ok_rows:
        reasons = []
        if int(row.get("streak") or 0) >= 3:
            reasons.append("stale baseline")
        prefixes = catalog.get(row.get("screen", ""), {}).get("files", [])
        if row.get("commit") and screen_touched(prefixes, changed):
            reasons.append("code changed since OK")
        if reasons:
            found.append(
                {
                    "screen": row.get("screen", ""),
                    "stage": row.get("stage", ""),
                    "why": ", ".join(reasons),
                }
            )
    return found


def missing_coverage(stage: str, seen: set[str], screens: dict) -> list[str]:
    need = screens.get("coverage", {}).get(stage) or screens.get("coverage", {}).get("mid", [])
    return [name for name in need if name not in seen]


def seen_screens(session: dict) -> set[str]:
    found: set[str] = set()
    for snap in session.get("snaps", []):
        for name in snap.get("covers") or [snap.get("screen")]:
            if name:
                found.add(name)
    return found


def render_memory(data: dict) -> str:
    lines = [
        "# Playtest memory",
        "",
        "Read this before every `/playtest`. Update it only through",
        "`py -3 tool/playtest_run.py` (`ok`, `good`, `learn`), so the next",
        "round looks for what this round learned.",
        "",
        "An OK is not a skip. Every round still opens that screen.",
        "Baselines live in `tool/playtest_baseline/`.",
        "",
        "## Bra",
        "",
    ]
    good = data.get("good") or []
    if not good:
        lines.append("_None yet._")
    else:
        for item in good:
            lines.append(
                f"- {item['date']} · {item['screen']} · {item['stage']} · "
                f"{item['why']} · `{item['image']}`"
            )
    lines.extend(["", "## Lärt", ""])
    learned = data.get("learned") or []
    if not learned:
        lines.append("_None yet._")
    else:
        for item in learned:
            rule = item.get("rule") or "none"
            lines.append(f"- {item['date']} · {item['pattern']} · rule: {rule}")
    lines.extend(["", "## OK", ""])
    rows = data.get("ok") or []
    if not rows:
        lines.append("_None yet._")
    else:
        lines.append("| Screen | Stage | Date | Commit | Streak |")
        lines.append("| --- | --- | --- | --- | --- |")
        for row in rows:
            lines.append(
                f"| {row['screen']} | {row['stage']} | {row['date']} | "
                f"{row['commit']} | {row['streak']} |"
            )
    lines.append("")
    return "\n".join(lines)


def upsert_ok(data: dict, screen: str, stage: str, commit: str, today: str) -> None:
    for row in data["ok"]:
        if row["screen"] == screen and row["stage"] == stage:
            row["streak"] = int(row.get("streak") or 0) + 1
            row["commit"] = commit
            row["date"] = today
            return
    data["ok"].append(
        {
            "screen": screen,
            "stage": stage,
            "date": today,
            "commit": commit,
            "streak": 1,
        }
    )


def render_report(session: dict, screens: dict, now: float) -> str:
    started = float(session.get("play_started") or session.get("started_ts") or now)
    elapsed = max(0, int(now - started))
    minutes, seconds = divmod(elapsed, 60)
    seen = seen_screens(session)
    missing = missing_coverage(session.get("stage") or "mid", seen, screens)
    lines = [
        "# Playtest report",
        "",
        f"Scope: {session.get('scope') or '(continue the current save)'}",
        f"Stage: {session.get('stage') or 'unknown'}",
        f"Played: {minutes}m {seconds:02d}s",
        "",
    ]
    if elapsed < SHORT_SECONDS:
        lines.append("WARNING: round was under 8 minutes.")
        lines.append("")
    extra = session.get("look_extra") or []
    if extra:
        lines.append("Look extra:")
        for item in extra:
            lines.append(f"- {item['screen']} ({item['why']})")
    else:
        lines.append("Look extra: none")
    lines.append("")
    if missing:
        lines.append("Not opened: " + ", ".join(missing))
    else:
        lines.append("Coverage: every screen on the list was opened.")
    lines.append("")
    welcome = session.get("welcome") or ""
    if welcome:
        lines.append("Welcome back was on screen. Compare it with the save above.")
    else:
        lines.append("No Welcome back (away was too short, or nothing was earned).")
    lines.append("")
    lines.append("## Screens")
    lines.append("")
    by_screen: dict[str, list[dict]] = {}
    for finding in session.get("findings", []):
        by_screen.setdefault(finding.get("screen") or "?", []).append(finding)
    names = list(dict.fromkeys(
        [snap.get("screen") or "?" for snap in session.get("snaps", [])]
        + list(by_screen)
    ))
    if not names:
        lines.append("_No screens yet._")
    for name in names:
        items = by_screen.get(name, [])
        if items:
            lines.append(f"### {name}")
            for item in items:
                count = item.get("count", 1)
                suffix = f" ×{count}" if count > 1 else ""
                lines.append(
                    f"- {item.get('id')} · {item.get('type')} · {item.get('sev')} · "
                    f"{item.get('rule')}{suffix}: {item.get('message')}"
                )
            lines.append("")
        else:
            lines.append(f"### {name}")
            lines.append("- OK (nothing flagged on this visit)")
            lines.append("")
    sheet = session.get("fight_sheet")
    if sheet:
        lines.append(f"Fight sheet: `{sheet}`")
        lines.append("")
    lines.append("Open the PNG only when a finding names pixels, gear, the party, or the fight.")
    lines.append("")
    return "\n".join(lines)


def add_finding(session: dict, **item) -> str:
    kind = item.get("kind", "auto")
    count = int(item.get("count") or 1)
    if kind == "auto":
        for prev in session["findings"]:
            if (
                prev.get("kind") == "auto"
                and prev.get("rule") == item.get("rule")
                and prev.get("screen") == item.get("screen")
                and prev.get("label") == item.get("label")
            ):
                prev["count"] = int(prev.get("count") or 1) + count
                return prev["id"]
    finding_id = f"f{int(session.get('next_id') or 1):03d}"
    session["next_id"] = int(session.get("next_id") or 1) + 1
    session["findings"].append(
        {
            "id": finding_id,
            "kind": kind,
            "rule": item.get("rule", "note"),
            "screen": item.get("screen", ""),
            "label": item.get("label", ""),
            "type": item.get("type", "ux"),
            "sev": item.get("sev", "forvirrar"),
            "message": item.get("message", ""),
            "count": count,
            "snap": item.get("snap", ""),
        }
    )
    return finding_id


def load_screens() -> dict:
    return json.loads(SCREENS_JSON.read_text(encoding="utf-8"))


def load_memory() -> dict:
    if not MEMORY_JSON.exists():
        return json.loads(json.dumps(EMPTY_MEMORY))
    data = json.loads(MEMORY_JSON.read_text(encoding="utf-8"))
    for key in EMPTY_MEMORY:
        data.setdefault(key, [])
    return data


def write_memory(data: dict) -> None:
    MEMORY_JSON.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    MEMORY_MD.write_text(render_memory(data), encoding="utf-8")


def head_commit() -> str:
    proc = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return (proc.stdout or "").strip() or "unknown"


def git_changed(since: str) -> list[str]:
    if not since or since in {"unknown", "—"}:
        return []
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{since}..HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        return []
    return [
        line.strip().replace("\\", "/")
        for line in (proc.stdout or "").splitlines()
        if line.strip()
    ]


def look_extra(memory: dict, screens: dict) -> list[dict]:
    found = []
    seen: set[tuple[str, str]] = set()
    for row in memory.get("ok", []):
        changed = git_changed(str(row.get("commit") or ""))
        for item in extra_screens([row], screens, changed):
            key = (item["screen"], item["stage"])
            if key in seen:
                continue
            seen.add(key)
            found.append(item)
    return found


def load_session(folder: Path) -> dict:
    return json.loads((folder / "session.json").read_text(encoding="utf-8"))


def save_session(folder: Path, data: dict) -> None:
    dest = folder / "session.json"
    tmp = folder / "session.json.tmp"
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    tmp.replace(dest)


def update_session(folder: Path, mutate) -> dict:
    lock = folder / ".lock"
    for _ in range(80):
        if lock.exists() and time.time() - lock.stat().st_mtime > 20:
            lock.unlink(missing_ok=True)
        try:
            fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            time.sleep(0.05)
    else:
        raise SystemExit("Playtest session is locked. Wait a moment and retry.")
    try:
        data = load_session(folder)
        mutate(data)
        save_session(folder, data)
        return data
    finally:
        os.close(fd)
        lock.unlink(missing_ok=True)


def current_dir() -> Path:
    if not CURRENT.exists():
        raise SystemExit("No playtest in progress. Run: py -3 tool/playtest_run.py start")
    folder = Path(CURRENT.read_text(encoding="utf-8").strip())
    if not (folder / "session.json").exists():
        raise SystemExit(f"Playtest session is missing: {folder}")
    return folder


def node_dict(node: Node) -> dict:
    return {
        "label": node.label,
        "clickable": node.clickable,
        "scrollable": node.scrollable,
        "kind": node.kind,
        "x1": node.x1,
        "y1": node.y1,
        "x2": node.x2,
        "y2": node.y2,
    }


def node_from_dict(raw: dict) -> Node:
    return Node(
        raw["label"],
        bool(raw.get("clickable")),
        bool(raw.get("scrollable")),
        raw.get("kind") or "View",
        int(raw["x1"]),
        int(raw["y1"]),
        int(raw["x2"]),
        int(raw["y2"]),
    )


def png_bytes(raw: bytes) -> bytes:
    """Some Windows adb builds turn every LF into CRLF, which doubles the
    PNG signature's own CRLF. A healthy signature is left alone."""
    broken = b"\x89PNG\r\r\n\x1a\r\n"
    if raw.startswith(broken):
        raw = raw.replace(b"\r\n", b"\n")
        raw = b"\x89PNG\r\n\x1a\n" + raw[len(b"\x89PNG\n\x1a\n") :]
    return raw


def capture_png(serial: str, dest: Path) -> bool:
    proc = subprocess.run(
        ["adb", "-s", serial, "exec-out", "screencap", "-p"],
        capture_output=True,
    )
    data = png_bytes(proc.stdout or b"")
    if not data.startswith(b"\x89PNG"):
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return True


_SEM_NODE = re.compile(r"SemanticsNode#\d+")
_SEM_RECT = re.compile(
    r"Rect\.fromLTRB\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)"
)
_SEM_SCALE = re.compile(r"scaled by\s+([0-9.]+)x")
_SEM_LABEL = re.compile(r'label:\s*"(.*?)"', re.S)
_SEM_ACTIONS = re.compile(r"actions:\s*([^\n]+)")
_BOX = re.compile(r"^[\s│├└┬┤┼╭╮╯╰─]+")
_VM_URL = re.compile(r"http://127\.0\.0\.1:(\d+)/([^/\s]+)/")


def _plain_semantics(part: str) -> str:
    return "\n".join(_BOX.sub("", line) for line in part.splitlines())


def parse_semantics(text: str) -> list[Node]:
    """Turn a Flutter semantics dump into the same nodes the UI dump uses.

    Child rects are in logical pixels. A "scaled by 3.0x" line is the phone's
    pixel ratio, so bounds come out in the 1080×2340 space the checks expect.
    """
    scale = 1.0
    found: list[Node] = []
    for part in _SEM_NODE.split(text)[1:]:
        plain = _plain_semantics(part)
        rect = _SEM_RECT.search(plain)
        if rect is None:
            continue
        if match := _SEM_SCALE.search(plain):
            scale = float(match.group(1)) or 1.0
        label_match = _SEM_LABEL.search(plain)
        label = " ".join(label_match.group(1).split()) if label_match else ""
        if not label:
            continue
        actions = _SEM_ACTIONS.search(plain)
        clickable = actions is not None and "tap" in actions.group(1)
        box = tuple(int(round(float(rect.group(i)) * scale)) for i in range(1, 5))
        found.append(
            Node(label, clickable, False, "Semantics", box[0], box[1], box[2], box[3])
        )
    return _drop_nested_same_label(adb_see._dedupe(found))


def _drop_nested_same_label(nodes: list[Node]) -> list[Node]:
    """A button and the text inside it share a label. Keep the outer one."""
    kept: list[Node] = []
    for node in nodes:
        buried = False
        for other in nodes:
            if other is node or other.label.casefold() != node.label.casefold():
                continue
            if (
                other.area > node.area
                and other.x1 <= node.x1
                and other.y1 <= node.y1
                and other.x2 >= node.x2
                and other.y2 >= node.y2
            ):
                buried = True
                break
        if not buried:
            kept.append(node)
    return kept


def flutter_log(serial: str) -> str:
    """Flutter lines only. The mixed log buffer drops [IP] under wifi noise."""
    raw = adb_see.adb(serial, "logcat", "-d", "-s", "flutter:I", check=False)
    return raw.stdout or ""


def _vm_from_log(serial: str) -> tuple[int, str] | None:
    hits = _VM_URL.findall(flutter_log(serial))
    if not hits:
        return None
    port, auth = hits[-1]
    return int(port), auth


def remember_vm(serial: str, folder: Path) -> None:
    """The VM url is printed once. Wifi noise pushes it out of the log."""
    found = _vm_from_log(serial)
    if found is None:
        return
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "vm-endpoint.txt").write_text(f"{found[0]} {found[1]}\n", encoding="utf-8")


def _vm_endpoint(serial: str, folder: Path | None = None) -> tuple[int, str] | None:
    found = _vm_from_log(serial)
    if found is not None:
        return found
    path = None if folder is None else folder / "vm-endpoint.txt"
    if path is not None and path.exists():
        parts = path.read_text(encoding="utf-8").split()
        if len(parts) >= 2:
            return int(parts[0]), parts[1]
    return None


def _ws_rpc(serial: str, port: int, auth: str, method: str, params: dict) -> dict | None:
    adb_see.adb(serial, "forward", f"tcp:{port}", f"tcp:{port}", check=False)
    try:
        sock = socket.create_connection(("127.0.0.1", port), timeout=8)
    except OSError:
        return None
    sock.settimeout(8)
    try:
        key = base64.b64encode(os.urandom(16)).decode()
        sock.sendall(
            (
                f"GET /{auth}/ws HTTP/1.1\r\n"
                "Host: 127.0.0.1\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        inbox = bytearray()
        while b"\r\n\r\n" not in inbox:
            chunk = sock.recv(4096)
            if not chunk:
                return None
            inbox.extend(chunk)
        head, _, rest = bytes(inbox).partition(b"\r\n\r\n")
        if b" 101 " not in head:
            return None
        inbox = bytearray(rest)

        def send_frame(opcode: int, payload: bytes) -> None:
            mask = os.urandom(4)
            header = bytearray([0x80 | opcode])
            length = len(payload)
            if length < 126:
                header.append(0x80 | length)
            elif length < 65536:
                header.append(0x80 | 126)
                header.extend(length.to_bytes(2, "big"))
            else:
                header.append(0x80 | 127)
                header.extend(length.to_bytes(8, "big"))
            header.extend(mask)
            sock.sendall(bytes(header) + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

        def recvn(n: int) -> bytes:
            while len(inbox) < n:
                chunk = sock.recv(max(n - len(inbox), 1))
                if not chunk:
                    raise OSError("socket closed")
                inbox.extend(chunk)
            data = bytes(inbox[:n])
            del inbox[:n]
            return data

        def read_text() -> str:
            parts: list[str] = []
            while True:
                b0, b1 = recvn(2)
                opcode = b0 & 0x0F
                length = b1 & 0x7F
                if length == 126:
                    length = int.from_bytes(recvn(2), "big")
                elif length == 127:
                    length = int.from_bytes(recvn(8), "big")
                payload = recvn(length)
                if opcode == 9:
                    send_frame(0xA, payload)
                    continue
                if opcode == 8:
                    raise OSError("socket closed")
                if opcode == 1:
                    parts.append(payload.decode("utf-8", "replace"))
                    if b0 & 0x80:
                        return "".join(parts)

        send_frame(1, json.dumps({"jsonrpc": "2.0", "id": "1", "method": method, "params": params}).encode())
        while True:
            msg = json.loads(read_text())
            if msg.get("id") == "1":
                return msg
    except (OSError, json.JSONDecodeError, TimeoutError):
        return None
    finally:
        sock.close()


def _semantics_text(serial: str, folder: Path | None = None) -> str:
    """Read the semantics tree while uiautomator is connected.

    Flutter only builds that tree when something asks (a dump does). The dump
    itself then gives up, because the hub and a fight never sit still.
    """
    found = _vm_endpoint(serial, folder)
    if found is None:
        return ""
    port, auth = found
    proc = subprocess.Popen(
        [
            "adb", "-s", serial, "shell", "timeout", "8",
            "uiautomator", "dump", "--compressed", "/sdcard/idle_party_ui.xml",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(2.2)
        text = ""
        for _ in range(3):
            vm = _ws_rpc(serial, port, auth, "getVM", {})
            isolates = ((vm or {}).get("result") or {}).get("isolates") or []
            if not isolates:
                time.sleep(1.2)
                continue
            isolate = next((item["id"] for item in isolates if item.get("name") == "main"), isolates[0]["id"])
            tree = _ws_rpc(
                serial,
                port,
                auth,
                "ext.flutter.debugDumpSemanticsTreeInTraversalOrder",
                {"isolateId": isolate},
            )
            result = (tree or {}).get("result") or {}
            text = result.get("data") or result.get("result") or ""
            if isinstance(text, dict):
                text = ""
            if text and "Semantics not generated" not in text:
                break
            time.sleep(1.2)
        return text if isinstance(text, str) else ""
    finally:
        adb_see.adb(serial, "shell", "pkill", "-f", "uiautomator", check=False)
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()


def _uiautomator_nodes(serial: str, dest: Path) -> list[Node] | None:
    remote = "/sdcard/idle_party_ui.xml"
    adb_see.adb(serial, "shell", "rm", "-f", remote, check=False)
    dumped = adb_see.adb(
        serial, "shell", "uiautomator", "dump", "--compressed", remote, check=False
    )
    text = f"{dumped.stdout or ''} {dumped.stderr or ''}".lower()
    if "dumped" not in text:
        return None
    if dest.exists():
        dest.unlink()
    adb_see.adb(serial, "pull", remote, str(dest), check=False)
    if dest.exists() and dest.stat().st_size > 0:
        xml = dest.read_text(encoding="utf-8", errors="replace")
        if "<hierarchy" in xml or "<node" in xml:
            return adb_see.parse_nodes(xml)
    return None


def capture_tree(serial: str, dest: Path) -> list[Node] | None:
    remember_vm(serial, dest.parent)
    marker = dest.parent / "tree-mode.txt"
    prefer_vm = marker.exists() and marker.read_text(encoding="utf-8").strip() == "vm"
    if not prefer_vm:
        nodes = _uiautomator_nodes(serial, dest)
        if nodes is not None:
            return nodes
    text = _semantics_text(serial, dest.parent)
    nodes = parse_semantics(text) if text else []
    if nodes:
        dest.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text("vm", encoding="utf-8")
        return nodes
    if prefer_vm:
        nodes = _uiautomator_nodes(serial, dest)
        if nodes is not None:
            marker.unlink(missing_ok=True)
            return nodes
    return None


def grab(serial: str, folder: Path) -> list[Node]:
    return capture_tree(serial, folder / "live.xml") or []


def has_any(nodes: list[Node], *words: str) -> bool:
    blob = "\n".join(node.label for node in nodes).casefold()
    return any(word.casefold() in blob for word in words)


def find_label(nodes: list[Node], *words: str, exact: bool = False) -> Node | None:
    need = [word.casefold() for word in words if word.strip()]
    if not need:
        return None
    phrase = " ".join(need)

    def is_exact(node: Node) -> bool:
        label = node.label.casefold().strip()
        head = label.split("|", 1)[0].strip()
        parts = phrase.split()
        if label == phrase or head == phrase:
            return True
        # "SAVE 1 The Party…" counts as SAVE 1. A single word must match
        # the whole label so story text does not look like the PLAY button.
        if len(parts) > 1 and head.split()[: len(parts)] == parts:
            return True
        return False

    exacts = [node for node in nodes if is_exact(node)]
    if exacts:
        hits = exacts
    elif exact:
        return None
    else:
        hits = [
            node
            for node in nodes
            if all(word in node.label.casefold() for word in need)
        ]
    if not hits:
        return None
    hits.sort(key=lambda node: (not node.clickable, node.area, node.y1))
    return hits[0]


def tap_node(serial: str, node: Node) -> None:
    adb_see.adb(
        serial, "shell", "input", "tap", str(node.cx), str(node.cy), check=False
    )
    time.sleep(0.8)


def wait_for(serial: str, folder: Path, seconds: float, ready) -> list[Node]:
    deadline = time.time() + seconds
    last: list[Node] = []
    while time.time() < deadline:
        last = grab(serial, folder)
        if last and ready(last):
            return last
        time.sleep(0.7)
    return last


def joined(nodes: list[Node]) -> str:
    return "\n".join(node.label for node in nodes)


def end_logcat(pid: int | None) -> None:
    if not pid:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            capture_output=True,
            text=True,
        )
        return
    try:
        os.kill(pid, 15)
    except OSError:
        return


def begin_logcat(serial: str, folder: Path) -> int:
    path = folder / "logcat.txt"
    handle = open(path, "w", encoding="utf-8", errors="replace")
    flags = {}
    if os.name == "nt":
        flags["creationflags"] = 0x00000008 | 0x00000200
    else:
        flags["start_new_session"] = True
    proc = subprocess.Popen(
        ["adb", "-s", serial, "logcat", "-v", "time"],
        stdout=handle,
        stderr=subprocess.STDOUT,
        **flags,
    )
    handle.close()
    return proc.pid


def backup_save(serial: str, dest: Path) -> str | None:
    proc = subprocess.run(
        [
            "adb", "-s", serial, "exec-out", "run-as", PACKAGE,
            "cat", "shared_prefs/FlutterSharedPreferences.xml",
        ],
        capture_output=True,
    )
    data = proc.stdout or b""
    if b"<map" not in data and b"<?xml" not in data:
        err = (proc.stderr or data or b"").decode("utf-8", "replace").strip()
        return err[:400] or "save backup failed"
    dest.write_bytes(data)
    return None


def restore_save(serial: str, src: Path) -> str | None:
    adb_see.adb(serial, "shell", "am", "force-stop", PACKAGE, check=False)
    time.sleep(0.4)
    proc = subprocess.run(
        [
            "adb", "-s", serial, "shell", "run-as", PACKAGE, "sh", "-c",
            "cat > shared_prefs/FlutterSharedPreferences.xml",
        ],
        input=src.read_bytes(),
        capture_output=True,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or b"").decode("utf-8", "replace").strip()
        return err[:400] or "restore failed"
    return None


def cold_start(serial: str) -> None:
    adb_see.adb(serial, "shell", "am", "force-stop", PACKAGE, check=False)
    time.sleep(0.5)
    adb_see.adb(serial, "shell", "am", "start", "-n", ACTIVITY, check=False)


def in_game(nodes: list[Node]) -> bool:
    """True only once the title and the save list are gone."""
    if not nodes:
        return False
    if any(
        find_label(nodes, phrase, exact=True) is not None
        for phrase in ("CONTINUE", "SAVE 1", "NEW GAME", "PLAY", "CHOOSE SAVE")
    ):
        return False
    return (
        find_label(nodes, "ENTER DUNGEON", exact=True) is not None
        or find_label(nodes, "GEAR", exact=True) is not None
        or "welcome back" in joined(nodes).lower()
    )


def boot_into_play(serial: str, folder: Path, new_game: bool) -> dict:
    result = {"note": "", "welcome": "", "nodes": [], "play_started": time.time()}
    cold_start(serial)
    nodes = wait_for(
        serial,
        folder,
        25,
        lambda found: any(
            find_label(found, phrase, exact=True) is not None
            for phrase in ("SKIP", "CONTINUE", "PLAY", "NEW GAME", "ENTER DUNGEON", "SAVE 1")
        ),
    )
    time.sleep(1.2)
    entered = False
    for _ in range(8):
        nodes = grab(serial, folder) or nodes
        skip = find_label(nodes, "SKIP", exact=True)
        continue_btn = find_label(nodes, "CONTINUE", exact=True)
        play_btn = find_label(nodes, "PLAY", exact=True)
        new_btn = find_label(nodes, "NEW GAME", exact=True) or find_label(
            nodes, "CUSTOMIZE", exact=True
        )
        if skip is not None and continue_btn is None and play_btn is None and new_btn is None:
            tap_node(serial, skip)
            continue
        if new_game and new_btn is not None:
            tap_node(serial, new_btn)
            nodes = wait_for(
                serial,
                folder,
                8,
                lambda found: find_label(found, "START", exact=True) is not None,
            )
            start = find_label(nodes, "START", exact=True)
            if start is not None:
                tap_node(serial, start)
            result["note"] = "Started a new game."
            entered = True
            break
        if not new_game and continue_btn is None and find_label(nodes, "SAVE 1", exact=True) is not None:
            slot = pick_save_slot(nodes, title_hint(nodes))
            if slot is None:
                result["note"] = "Save list was open but no save could be tapped."
                result["nodes"] = nodes
                return result
            print(f"tap {slot.label[:40]}")
            tap_node(serial, slot)
            nodes = wait_for(
                serial,
                folder,
                8,
                lambda found: in_game(found),
            )
            if not in_game(nodes):
                continue
            entered = True
            break
        if not new_game and continue_btn is not None:
            # The title ignores taps for about a second after it appears.
            time.sleep(1.2)
            nodes = grab(serial, folder) or nodes
            continue_btn = find_label(nodes, "CONTINUE", exact=True)
            if continue_btn is None:
                continue
            hint = title_hint(nodes)
            print("tap CONTINUE")
            tap_node(serial, continue_btn)
            nodes = wait_for(
                serial,
                folder,
                6,
                lambda found: find_label(found, "SAVE 1", exact=True) is not None
                or find_label(found, "ENTER DUNGEON", exact=True) is not None,
            )
            if find_label(nodes, "CONTINUE", exact=True) is not None and find_label(
                nodes, "SAVE 1", exact=True
            ) is None:
                continue
            if find_label(nodes, "SAVE 1", exact=True) is not None and find_label(
                nodes, "ENTER DUNGEON", exact=True
            ) is None:
                slot = pick_save_slot(nodes, hint)
                if slot is None:
                    result["note"] = "Save list was open but no save could be tapped."
                    result["nodes"] = nodes
                    return result
                print(f"tap {slot.label[:40]}")
                tap_node(serial, slot)
                nodes = wait_for(
                    serial,
                    folder,
                    8,
                    lambda found: in_game(found),
                )
            if not in_game(nodes):
                continue
            entered = True
            break
        if not new_game and play_btn is not None and continue_btn is None:
            tap_node(serial, play_btn)
            result["note"] = "No save yet, so this round started with PLAY."
            entered = True
            break
        if in_game(nodes):
            result["note"] = "Already in the game."
            entered = True
            break
        time.sleep(0.7)
    if not entered:
        result["note"] = "Could not find CONTINUE."
        result["nodes"] = grab(serial, folder)
        return result
    result["play_started"] = time.time()
    time.sleep(1.0)
    nodes = grab(serial, folder)
    if "welcome back" in joined(nodes).lower():
        result["welcome"] = joined(nodes)
    for _ in range(8):
        nodes = grab(serial, folder)
        text = joined(nodes)
        choice = None
        for phrase in ("SKIP ALL TIPS", "NICE", "GOT IT"):
            choice = find_label(nodes, phrase, exact=True)
            if choice is not None:
                break
        if choice is None and "what's new" in text.lower():
            choice = find_label(nodes, "CLOSE", exact=True)
        if choice is None:
            break
        tap_node(serial, choice)
    result["nodes"] = grab(serial, folder)
    return result

def spawn_analyze(folder: Path, snap_id: str) -> None:
    cmd = [sys.executable, str(Path(__file__).resolve()), "_analyze", str(folder), snap_id]
    flags = {}
    if os.name == "nt":
        flags["creationflags"] = 0x00000008 | 0x00000200
    else:
        flags["start_new_session"] = True
    subprocess.Popen(
        cmd,
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        **flags,
    )


def ensure_analyzed(folder: Path, wait: float = 8) -> None:
    deadline = time.time() + wait
    while time.time() < deadline:
        data = load_session(folder)
        if all(snap.get("analyzed") for snap in data.get("snaps", [])):
            return
        time.sleep(0.25)
    data = load_session(folder)
    for snap in data.get("snaps", []):
        if not snap.get("analyzed"):
            analyze_snap(folder, snap["id"])


def _log_hits(folder: Path) -> list[str]:
    path = folder / "logcat.txt"
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    game_pids = {pid for line in lines for pid in _FLUTTER_PID.findall(line)}
    hits = []
    for line in lines:
        if not _LOG_BAD.search(line):
            continue
        low = line.lower()
        game = "flutter" in low or "idleparty" in low or "idle_party" in low
        if not game and "skipped" in low:
            pid = _LOG_PID.search(line)
            game = pid is not None and pid.group(1) in game_pids
        if not game:
            continue
        hits.append(line.strip()[:180])
    return hits


def analyze_snap(folder: Path, snap_id: str) -> None:
    data = load_session(folder)
    snap = next((item for item in data["snaps"] if item["id"] == snap_id), None)
    if snap is None or snap.get("analyzed"):
        return
    tree_path = folder / snap["tree"]
    tree = json.loads(tree_path.read_text(encoding="utf-8")) if tree_path.exists() else []
    screen = snap.get("screen") or "hub"
    findings: list[dict] = []
    if not snap.get("dump_ok"):
        findings.append(
            {
                "rule": "dump_failed",
                "label": screen,
                "message": "The screen list could not be read. The picture was still saved.",
                "type": "kod",
                "sev": "forvirrar",
            }
        )
    else:
        nodes = [node_from_dict(item) for item in tree]
        for item in run_checks(
            nodes,
            screen=screen,
            jargon=bool(data.get("jargon")),
            state=data.get("state") or None,
        ):
            findings.append(_from_check(item))
        base_png, base_json = baseline_paths(screen, data.get("stage") or "mid")
        if base_json.exists():
            baseline = json.loads(base_json.read_text(encoding="utf-8"))
            for item in tree_diff(tree, baseline):
                findings.append(item)
        png = folder / snap["png"] if snap.get("png") else None
        if base_png.exists() and png is not None and png.exists():
            masks = _masks_for(screen, png, tree)
            diff_path = folder / f"{snap['id']}-diff.png"
            result = diff_images(png, base_png, diff_path, masks)
            if result["changed_frac"] >= PIXEL_FLAG:
                findings.append(
                    {
                        "rule": "pixels_changed",
                        "label": screen,
                        "type": "visuellt",
                        "sev": "forvirrar",
                        "message": (
                            f"Picture differs from the baseline "
                            f"({result['changed_frac']:.0%}). Diff: {diff_path.name}"
                        ),
                    }
                )
    log_lines = _log_hits(folder)
    cursor = int(data.get("log_cursor") or 0)
    for line in log_lines[cursor:cursor + 30]:
        sev = "kosmetiskt" if "Skipped" in line else "blockerar" if ("FATAL" in line or "ANR" in line) else "forvirrar"
        findings.append(
            {
                "rule": "log_error",
                "screen": "log",
                "label": line[:80],
                "type": "kod",
                "sev": sev,
                "message": line,
            }
        )
    log_end = min(len(log_lines), cursor + 30)

    def mutate(fresh: dict) -> None:
        target = next((item for item in fresh["snaps"] if item["id"] == snap_id), None)
        if target is None or target.get("analyzed"):
            return
        for item in findings:
            item.setdefault("screen", screen)
            item.setdefault("type", _TYPE.get(item["rule"], "ux"))
            item.setdefault("sev", _SEV.get(item["rule"], "forvirrar"))
            item["snap"] = snap_id
            add_finding(fresh, **item)
        target["analyzed"] = True
        fresh["log_cursor"] = max(int(fresh.get("log_cursor") or 0), log_end)

    update_session(folder, mutate)


def _from_check(item: CheckFinding) -> dict:
    return {
        "rule": item.rule,
        "label": item.label,
        "message": item.message,
        "count": item.count,
        "type": _TYPE.get(item.rule, "ux"),
        "sev": _SEV.get(item.rule, "forvirrar"),
    }


def _masks_for(screen: str, png: Path, tree: list[dict]) -> list[tuple[int, int, int, int]]:
    from PIL import Image

    with Image.open(png) as image:
        width, height = image.size
    screens = load_screens()
    masks = []
    for frac in screens.get("screens", {}).get(screen, {}).get("mask", []):
        masks.append(scale_rect(frac, width, height))
    sx = width / SCREEN_W
    sy = height / SCREEN_H
    for node in tree:
        if not any(ch.isdigit() for ch in node.get("label", "")):
            continue
        masks.append(
            (
                int(node["x1"] * sx),
                int(node["y1"] * sy),
                int(node["x2"] * sx),
                int(node["y2"] * sy),
            )
        )
    return masks


def baseline_paths(screen: str, stage: str) -> tuple[Path, Path]:
    stem = BASELINE / f"{screen}__{stage}"
    return stem.with_suffix(".png"), stem.with_suffix(".json")


def take_snap(folder: Path, requested: str | None, expect: str = "") -> dict:
    data = load_session(folder)
    serial = data["serial"]
    snap_index = int(data.get("next_snap") or 1)
    snap_id = f"s{snap_index:03d}"
    name = requested or ""
    png_name = f"{snap_id}.png"
    tree_name = f"{snap_id}.json"
    png_path = folder / png_name
    picture_ok = capture_png(serial, png_path)
    nodes = capture_tree(serial, folder / f"{snap_id}.xml")
    ip_text = flutter_log(serial)
    state = dict(data.get("state") or {})
    state.update(fold_ip_state(ip_text))
    nav = latest_nav(ip_text)
    screen = _screen_for(name, nav, bool(state.get("in_dungeon")), load_screens())
    covers = [screen]
    labels = nodes or []
    if screen == "hub" and has_any(labels, "ENTER DUNGEON"):
        covers.append("path")
    record = {
        "id": snap_id,
        "name": name or screen,
        "screen": screen,
        "covers": covers,
        "png": png_name if picture_ok else "",
        "tree": tree_name,
        "expect": expect,
        "dump_ok": nodes is not None,
        "analyzed": False,
        "at": time.time(),
    }
    (folder / tree_name).write_text(
        json.dumps([node_dict(node) for node in labels], indent=2),
        encoding="utf-8",
    )

    def mutate(fresh: dict) -> None:
        fresh["next_snap"] = snap_index + 1
        fresh["snaps"].append(record)
        if state:
            fresh["state"] = state

    update_session(folder, mutate)
    spawn_analyze(folder, snap_id)
    print(f"snap {snap_id} {screen} picture={'yes' if picture_ok else 'no'} tree={'yes' if nodes is not None else 'no'}")
    if expect:
        print(f"expect: {expect}")
    return record


def _screen_for(name: str, nav: str, in_dungeon: bool, screens: dict) -> str:
    known = set(screens.get("screens", {}))
    if name in known:
        return name
    if name.startswith("fight"):
        return "dungeon"
    if nav or in_dungeon:
        mapped = screen_from_nav(nav, in_dungeon)
        if mapped in known:
            return mapped
    return "hub"


def cmd_start(new_game: bool, scope: str, serial: str | None) -> int:
    serial = adb_see.resolve_serial(serial)
    if CURRENT.exists():
        try:
            old = load_session(current_dir())
            end_logcat(old.get("log_pid"))
        except SystemExit:
            pass
    folder = SHOTS / time.strftime("%Y%m%d-%H%M%S")
    folder.mkdir(parents=True, exist_ok=True)
    screens = load_screens()
    memory = load_memory()
    extra = look_extra(memory, screens)
    backup = folder / "save-backup.xml"
    backup_error = backup_save(serial, backup)
    if new_game and backup_error:
        raise SystemExit("Refusing a new game because the save backup failed:\n" + backup_error)
    before_text = flutter_log(serial)
    before = fold_ip_state(before_text)
    log_pid = begin_logcat(serial, folder)
    print("restarting the app to check the offline return")
    booted = boot_into_play(serial, folder, new_game)
    after_text = flutter_log(serial)
    after = fold_ip_state(after_text) or before
    stage = stage_of(after)
    welcome = booted.get("welcome") or ""
    notes = offline_notes(before, after, welcome)
    session = {
        "serial": serial,
        "scope": scope,
        "new_game": new_game,
        "started_ts": time.time(),
        "play_started": booted.get("play_started") or time.time(),
        "stage": stage,
        "jargon": wants_jargon(after, stage),
        "state": after,
        "state_before": before,
        "welcome": welcome,
        "note": booted.get("note") or "",
        "backup": backup.name if backup_error is None else "",
        "backup_error": backup_error or "",
        "look_extra": extra,
        "log_pid": log_pid,
        "commit": head_commit(),
        "next_id": 1,
        "next_snap": 1,
        "snaps": [],
        "findings": [],
        "fight_sheet": "",
    }
    save_session(folder, session)
    CURRENT.write_text(str(folder), encoding="utf-8")
    for item in notes:
        update_session(folder, lambda fresh, item=item: add_finding(fresh, **item))
    print(f"session {folder}")
    print(f"stage {stage} state {after or '(no [IP] state yet)'}")
    if backup_error:
        print("BACKUP FAILED: " + backup_error)
    else:
        print(f"save backed up to {backup.name}")
    if session["note"]:
        print(session["note"])
    if welcome:
        print("Welcome back was showing")
    elif not notes:
        print("No Welcome back")
    if extra:
        print("look extra: " + ", ".join(f"{item['screen']} ({item['why']})" for item in extra))
    if booted.get("note", "").startswith("Could not") or booted.get("note", "").startswith("Save list"):
        return 1
    take_snap(folder, None)
    return 0


def cmd_snap(name: str | None) -> int:
    take_snap(current_dir(), name)
    return 0


def cmd_tap(label: str, expect: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    if _REFUSE.search(label):
        print(f"refused: {label}")
        print("That would change or delete the save. Stop on the confirm step.")
        return 2
    if _WARN.search(label):
        print(f"WARNING: {label} can change the save. Open the screen, then back out.")
    nodes = grab(data["serial"], folder)
    node = find_label(nodes, label)
    if node is None:
        print(f"no button matching {label}")
        take_snap(folder, None, expect)
        update_session(
            folder,
            lambda fresh: add_finding(
                fresh,
                rule="tap_missed",
                screen=fresh["snaps"][-1]["screen"] if fresh["snaps"] else "",
                label=label,
                type="ux",
                sev="forvirrar",
                message=f"No button matched {label}",
                snap=fresh["snaps"][-1]["id"] if fresh["snaps"] else "",
            ),
        )
        return 2
    print(f"tap {node.label[:80]}")
    tap_node(data["serial"], node)
    take_snap(folder, None, expect)
    return 0


def cmd_back(expect: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    adb_see.adb(data["serial"], "shell", "input", "keyevent", "4", check=False)
    time.sleep(0.6)
    take_snap(folder, None, expect)
    return 0


def cmd_swipe(coords: list[str], expect: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    adb_see.adb(
        data["serial"], "shell", "input", "swipe", *coords, "280", check=False
    )
    time.sleep(0.6)
    take_snap(folder, None, expect)
    return 0


def cmd_fight(seconds: int) -> int:
    folder = current_dir()
    deadline = time.time() + max(1, seconds)
    index = 0
    while True:
        take_snap(folder, f"fight-{index}")
        index += 1
        remaining = deadline - time.time()
        if remaining <= 1:
            break
        time.sleep(min(FIGHT_EVERY, remaining))
    ensure_analyzed(folder, 4)
    data = load_session(folder)
    paths = []
    for snap in data["snaps"]:
        if str(snap.get("name", "")).startswith("fight-") and snap.get("png"):
            paths.append(folder / snap["png"])
    if paths:
        dest = folder / "fight-sheet.png"
        contact_sheet(paths[-6:], dest)
        update_session(folder, lambda fresh: fresh.__setitem__("fight_sheet", dest.name))
        print(dest)
    return 0


def _clock(session: dict, now: float | None = None) -> tuple[int, int]:
    now = time.time() if now is None else now
    started = float(session.get("play_started") or session.get("started_ts") or now)
    elapsed = max(0, int(now - started))
    return divmod(elapsed, 60)


def cmd_status() -> int:
    folder = current_dir()
    ensure_analyzed(folder, 3)
    data = load_session(folder)
    screens = load_screens()
    minutes, seconds = _clock(data)
    left = max(0, TARGET_SECONDS - (minutes * 60 + seconds))
    left_m, left_s = divmod(left, 60)
    missing = missing_coverage(data.get("stage") or "mid", seen_screens(data), screens)
    print(f"played {minutes}m {seconds:02d}s, about {left_m}m {left_s:02d}s left of 10")
    print("opened: " + (", ".join(sorted(seen_screens(data))) or "(none)"))
    print("not opened: " + (", ".join(missing) or "(none)"))
    print(f"findings {len(data.get('findings') or [])}")
    extra = data.get("look_extra") or []
    if extra:
        print("look extra: " + ", ".join(item["screen"] for item in extra))
    return 0


def cmd_note(text: str, kind: str, sev: str) -> int:
    folder = current_dir()

    def mutate(fresh: dict) -> None:
        snap = fresh["snaps"][-1]["id"] if fresh["snaps"] else ""
        screen = fresh["snaps"][-1]["screen"] if fresh["snaps"] else ""
        add_finding(
            fresh,
            kind="note",
            rule="note",
            screen=screen,
            label="",
            type=kind,
            sev=sev,
            message=text,
            snap=snap,
        )

    data = update_session(folder, mutate)
    print(data["findings"][-1]["id"])
    return 0


def cmd_ok(screen: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    memory = load_memory()
    upsert_ok(memory, screen, data.get("stage") or "mid", head_commit(), date.today().isoformat())
    write_memory(memory)
    print(f"ok {screen}")
    return 0


def cmd_good(screen: str, why: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    stage = data.get("stage") or "mid"
    snap = next(
        (item for item in reversed(data["snaps"]) if item.get("screen") == screen and item.get("png")),
        None,
    )
    if snap is None:
        raise SystemExit(f"No picture of {screen} in this round.")
    BASELINE.mkdir(parents=True, exist_ok=True)
    png, tree = baseline_paths(screen, stage)
    shutil.copyfile(folder / snap["png"], png)
    tree_src = folder / snap["tree"]
    if tree_src.exists():
        shutil.copyfile(tree_src, tree)
    memory = load_memory()
    rel = png.relative_to(ROOT).as_posix()
    kept = [
        item
        for item in memory["good"]
        if not (item.get("screen") == screen and item.get("stage") == stage)
    ]
    kept.append(
        {
            "date": date.today().isoformat(),
            "screen": screen,
            "stage": stage,
            "why": why,
            "image": rel,
        }
    )
    memory["good"] = kept
    for row in memory["ok"]:
        if row["screen"] == screen and row["stage"] == stage:
            row["streak"] = 0
            row["commit"] = head_commit()
            row["date"] = date.today().isoformat()
    write_memory(memory)
    print(f"good {screen} -> {rel}")
    return 0


def cmd_learn(pattern: str, rule: str) -> int:
    memory = load_memory()
    memory["learned"].append(
        {
            "date": date.today().isoformat(),
            "pattern": pattern,
            "rule": rule,
        }
    )
    write_memory(memory)
    print("learned")
    return 0


def cmd_report() -> int:
    folder = current_dir()
    ensure_analyzed(folder, 8)
    data = load_session(folder)
    end_logcat(data.get("log_pid"))
    text = render_report(data, load_screens(), time.time())
    dest = folder / "report.md"
    dest.write_text(text, encoding="utf-8")
    print(dest)
    print(text)
    return 0


def cmd_after(finding_id: str) -> int:
    folder = current_dir()
    data = load_session(folder)
    dest = folder / "after" / f"{finding_id}.png"
    if not capture_png(data["serial"], dest):
        raise SystemExit("Could not take the after picture.")

    def mutate(fresh: dict) -> None:
        for item in fresh["findings"]:
            if item["id"] == finding_id:
                item["after"] = str(dest)

    update_session(folder, mutate)
    print(dest)
    return 0


def cmd_restore() -> int:
    folder = current_dir()
    data = load_session(folder)
    src = folder / (data.get("backup") or "save-backup.xml")
    if not src.exists():
        raise SystemExit("This round has no save backup.")
    error = restore_save(data["serial"], src)
    if error:
        raise SystemExit(error)
    print(f"save restored from {src.name}")
    return 0


def main(argv: list[str] | None = None) -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)
    parser = argparse.ArgumentParser(description="Run one Idle Party playtest on the A56.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    start = sub.add_parser("start")
    start.add_argument("--new", action="store_true")
    start.add_argument("--scope", nargs="*", default=[])
    start.add_argument("--serial", default=None)

    snap = sub.add_parser("snap")
    snap.add_argument("name", nargs="?")

    tap = sub.add_parser("tap")
    tap.add_argument("label", nargs="+")
    tap.add_argument("--expect", default="")

    back = sub.add_parser("back")
    back.add_argument("--expect", default="")

    swipe = sub.add_parser("swipe")
    swipe.add_argument("coords", nargs=4)
    swipe.add_argument("--expect", default="")

    fight = sub.add_parser("fight")
    fight.add_argument("seconds", nargs="?", type=int, default=60)

    sub.add_parser("status")

    note = sub.add_parser("note")
    note.add_argument("text", nargs="+")
    note.add_argument("--type", required=True, choices=("kod", "ux", "visuellt"))
    note.add_argument("--sev", required=True, choices=("blockerar", "forvirrar", "kosmetiskt"))

    ok = sub.add_parser("ok")
    ok.add_argument("screen")

    good = sub.add_parser("good")
    good.add_argument("screen")
    good.add_argument("why", nargs="+")

    learn = sub.add_parser("learn")
    learn.add_argument("pattern", nargs="+")
    learn.add_argument("--rule", default="")

    sub.add_parser("report")

    after = sub.add_parser("after")
    after.add_argument("finding")

    sub.add_parser("restore")

    hidden = sub.add_parser("_analyze")
    hidden.add_argument("folder")
    hidden.add_argument("snap_id")

    args = parser.parse_args(argv)
    if args.cmd == "start":
        raise SystemExit(cmd_start(args.new, " ".join(args.scope), args.serial))
    if args.cmd == "snap":
        raise SystemExit(cmd_snap(args.name))
    if args.cmd == "tap":
        raise SystemExit(cmd_tap(" ".join(args.label), args.expect))
    if args.cmd == "back":
        raise SystemExit(cmd_back(args.expect))
    if args.cmd == "swipe":
        raise SystemExit(cmd_swipe(args.coords, args.expect))
    if args.cmd == "fight":
        raise SystemExit(cmd_fight(args.seconds))
    if args.cmd == "status":
        raise SystemExit(cmd_status())
    if args.cmd == "note":
        raise SystemExit(cmd_note(" ".join(args.text), args.type, args.sev))
    if args.cmd == "ok":
        raise SystemExit(cmd_ok(args.screen))
    if args.cmd == "good":
        raise SystemExit(cmd_good(args.screen, " ".join(args.why)))
    if args.cmd == "learn":
        raise SystemExit(cmd_learn(" ".join(args.pattern), args.rule))
    if args.cmd == "report":
        raise SystemExit(cmd_report())
    if args.cmd == "after":
        raise SystemExit(cmd_after(args.finding))
    if args.cmd == "restore":
        raise SystemExit(cmd_restore())
    if args.cmd == "_analyze":
        analyze_snap(Path(args.folder), args.snap_id)


if __name__ == "__main__":
    main()
