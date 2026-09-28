"""Read the Samsung A56 emulator as a UI tree plus [IP] logs.

    py -3 tool/adb_see.py                  # labels, bounds, recent [IP]
    py -3 tool/adb_see.py see GEAR           # only rows whose label contains GEAR
    py -3 tool/adb_see.py log                # [IP] lines only
    py -3 tool/adb_see.py tap CONTINUE       # tap by label, then print the new tree
    py -3 tool/adb_see.py swipe 540 1800 540 900
    py -3 tool/adb_see.py text hello
    py -3 tool/adb_see.py key back
    py -3 tool/adb_see.py shot playshots/now.png

Screenshots are opt-in. Bounds come from the dump, so the emulator window
stays free of the layout-debug overlay.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DUMP_LOCAL = ROOT / "tool" / "out" / "ui.xml"
REMOTE_DUMP = "/sdcard/idle_party_ui.xml"
DEFAULT_SERIAL = "emulator-5554"

_NODE = re.compile(r"<node\b([^>]*)/?>")
_ATTR = re.compile(r'([\w:-]+)="([^"]*)"')
_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")

KEYS = {
    "back": "4",
    "home": "3",
    "enter": "66",
    "del": "67",
    "menu": "82",
}


@dataclass
class Node:
    label: str
    clickable: bool
    scrollable: bool
    kind: str
    x1: int
    y1: int
    x2: int
    y2: int

    @property
    def cx(self) -> int:
        return (self.x1 + self.x2) // 2

    @property
    def cy(self) -> int:
        return (self.y1 + self.y2) // 2

    @property
    def area(self) -> int:
        return max(0, self.x2 - self.x1) * max(0, self.y2 - self.y1)


def unescape(raw: str) -> str:
    return (
        raw.replace("&amp;", "&")
        .replace("&quot;", '"')
        .replace("&apos;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&#10;", "\n")
    )


def parse_nodes(xml: str) -> list[Node]:
    found: list[Node] = []
    for match in _NODE.finditer(xml):
        attrs = {k: unescape(v) for k, v in _ATTR.findall(match.group(1))}
        bounds = _BOUNDS.search(attrs.get("bounds", ""))
        if not bounds:
            continue
        desc = attrs.get("content-desc", "").strip()
        text = attrs.get("text", "").strip()
        if desc and text and text not in desc:
            label = f"{desc} | {text}"
        else:
            label = desc or text
        label = " ".join(label.split())
        if not label:
            continue
        x1, y1, x2, y2 = (int(n) for n in bounds.groups())
        kind = attrs.get("class", "").rsplit(".", 1)[-1] or "View"
        found.append(
            Node(
                label=label,
                clickable=attrs.get("clickable") == "true",
                scrollable=attrs.get("scrollable") == "true",
                kind=kind,
                x1=x1,
                y1=y1,
                x2=x2,
                y2=y2,
            )
        )
    return _dedupe(found)


def _dedupe(nodes: list[Node]) -> list[Node]:
    """Keep the clickable (or smaller) node when the same label sits on the same spot."""
    best: dict[tuple[str, int, int], Node] = {}
    for node in nodes:
        key = (node.label.casefold(), node.cx // 12, node.cy // 12)
        prev = best.get(key)
        if prev is None:
            best[key] = node
            continue
        if node.clickable and not prev.clickable:
            best[key] = node
        elif node.clickable == prev.clickable and node.area < prev.area:
            best[key] = node
    ordered = list(best.values())
    ordered.sort(key=lambda n: (n.y1, n.x1, n.area))
    return ordered


def format_nodes(nodes: list[Node], needle: str = "", limit: int = 80) -> str:
    needle_l = needle.casefold()
    rows = [n for n in nodes if needle_l in n.label.casefold()] if needle_l else nodes
    lines: list[str] = []
    shown = rows[:limit]
    for node in shown:
        mark = "CLICK" if node.clickable else "    "
        scroll = " scroll" if node.scrollable else ""
        lines.append(
            f"{mark}  {node.label[:140]}  @{node.cx},{node.cy}"
            f"  [{node.x1},{node.y1}][{node.x2},{node.y2}]  {node.kind}{scroll}"
        )
    if len(rows) > limit:
        lines.append(f"… {len(rows) - limit} more (pass a filter word)")
    if not lines:
        lines.append("(no labeled nodes)")
    return "\n".join(lines)


def adb(serial: str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = ["adb", "-s", serial, *args]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode != 0:
        err = (result.stderr or result.stdout or "").strip()
        raise SystemExit(f"adb failed: {' '.join(cmd)}\n{err}")
    return result


def resolve_serial(explicit: str | None) -> str:
    if explicit:
        return explicit
    listed = subprocess.run(
        ["adb", "devices"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    serials = []
    for line in (listed.stdout or "").splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            serials.append(parts[0])
    if DEFAULT_SERIAL in serials:
        return DEFAULT_SERIAL
    if len(serials) == 1:
        return serials[0]
    if not serials:
        raise SystemExit("No adb device. Launch Samsung_A56 first.")
    raise SystemExit(
        "Several devices. Pass --serial. Online: " + ", ".join(serials)
    )


def dump_xml(serial: str) -> str:
    DUMP_LOCAL.parent.mkdir(parents=True, exist_ok=True)
    adb(serial, "shell", "uiautomator", "dump", REMOTE_DUMP, check=False)
    pulled = adb(serial, "pull", REMOTE_DUMP, str(DUMP_LOCAL), check=False)
    if not DUMP_LOCAL.exists() or DUMP_LOCAL.stat().st_size == 0:
        err = (pulled.stderr or pulled.stdout or "").strip()
        raise SystemExit(f"UI dump failed.\n{err}")
    return DUMP_LOCAL.read_text(encoding="utf-8", errors="replace")


def ip_log(serial: str, lines: int) -> str:
    raw = adb(serial, "logcat", "-d", "-t", "2500", check=False)
    hits = [ln for ln in (raw.stdout or "").splitlines() if "[IP]" in ln]
    tail = hits[-lines:]
    if not tail:
        return "(no [IP] lines — debug build only)"
    return "\n".join(tail)


def pick(nodes: list[Node], words: list[str]) -> Node:
    need = [w.casefold() for w in words if w.strip()]
    if not need:
        raise SystemExit("tap needs a label, for example: tap CONTINUE")
    hits = [n for n in nodes if all(w in n.label.casefold() for w in need)]
    if not hits:
        print(format_nodes(nodes))
        raise SystemExit("No node matched: " + " ".join(words))
    hits.sort(key=lambda n: (not n.clickable, n.area, n.y1))
    return hits[0]


def do_see(serial: str, needle: str, log_lines: int) -> None:
    xml = dump_xml(serial)
    print(format_nodes(parse_nodes(xml), needle))
    print("\n--- [IP] ---")
    print(ip_log(serial, log_lines))


def do_tap(serial: str, words: list[str], log_lines: int) -> None:
    node = pick(parse_nodes(dump_xml(serial)), words)
    print(f"tap {node.label[:80]} @{node.cx},{node.cy}")
    adb(serial, "shell", "input", "tap", str(node.cx), str(node.cy))
    time.sleep(0.8)
    do_see(serial, "", log_lines)


def do_swipe(serial: str, coords: list[str], log_lines: int) -> None:
    if len(coords) < 4:
        raise SystemExit("swipe needs x1 y1 x2 y2")
    x1, y1, x2, y2 = coords[:4]
    duration = coords[4] if len(coords) > 4 else "280"
    adb(serial, "shell", "input", "swipe", x1, y1, x2, y2, duration)
    time.sleep(0.8)
    do_see(serial, "", log_lines)


def do_text(serial: str, words: list[str], log_lines: int) -> None:
    raw = " ".join(words)
    # adb input text treats %s as space.
    encoded = (
        raw.replace("%", "%25")
        .replace(" ", "%s")
        .replace("&", "\\&")
        .replace("(", "\\(")
        .replace(")", "\\)")
    )
    adb(serial, "shell", "input", "text", encoded)
    time.sleep(0.4)
    do_see(serial, "", log_lines)


def do_key(serial: str, name: str, log_lines: int) -> None:
    code = KEYS.get(name.casefold())
    if code is None:
        raise SystemExit("key must be one of: " + ", ".join(KEYS))
    adb(serial, "shell", "input", "keyevent", code)
    time.sleep(0.6)
    do_see(serial, "", log_lines)


def do_shot(serial: str, path: str) -> None:
    dest = Path(path)
    if not dest.is_absolute():
        dest = ROOT / dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/idle_party_screen.png"
    adb(serial, "shell", "screencap", "-p", remote)
    adb(serial, "pull", remote, str(dest))
    print(dest)


def self_test() -> None:
    xml = """
    <hierarchy>
      <node text="" content-desc="CONTINUE" class="android.widget.Button"
            clickable="true" bounds="[72,1559][1008,1711]" />
      <node text="" content-desc="CONTINUE" class="android.view.View"
            clickable="false" bounds="[72,1559][1008,1711]" />
      <node text="" content-desc="Your party&#10;fights" class="android.view.View"
            clickable="false" bounds="[201,516][879,573]" />
    </hierarchy>
    """
    nodes = parse_nodes(xml)
    assert len(nodes) == 2, nodes
    button = pick(nodes, ["continue"])
    assert button.clickable and button.cx == 540 and button.cy == 1635, button
    assert any("fights" in n.label and "\n" not in n.label for n in nodes)
    print("adb_see self-test ok")


def main(argv: list[str] | None = None) -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="See the Idle Party emulator via adb.")
    parser.add_argument("--serial", default=None)
    parser.add_argument("--lines", type=int, default=25, help="[IP] log lines")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument(
        "cmd",
        nargs="?",
        default="see",
        choices=("see", "log", "tap", "swipe", "text", "key", "shot"),
    )
    parser.add_argument("rest", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.self_test:
        self_test()
        return
    serial = resolve_serial(args.serial)
    rest = args.rest
    if args.cmd == "see":
        do_see(serial, " ".join(rest), args.lines)
    elif args.cmd == "log":
        print(ip_log(serial, args.lines))
    elif args.cmd == "tap":
        do_tap(serial, rest, args.lines)
    elif args.cmd == "swipe":
        do_swipe(serial, rest, args.lines)
    elif args.cmd == "text":
        do_text(serial, rest, args.lines)
    elif args.cmd == "key":
        if not rest:
            raise SystemExit("key needs back, home, enter, or del")
        do_key(serial, rest[0], args.lines)
    elif args.cmd == "shot":
        if not rest:
            raise SystemExit("shot needs a file path")
        do_shot(serial, rest[0])


if __name__ == "__main__":
    main()
