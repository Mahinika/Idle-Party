"""Screen checks for /playtest. No emulator: pass a UI tree and a state dict.

Rule ids stay stable so a finding can point at one, and so a learned pattern
can become a rule without renaming old notes.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from adb_see import Node

SCREEN_W = 1080
SCREEN_H = 2340
PX_PER_DP = 3
# GameTheme.minTouch is 44. A 48 dp bar would flag every real button.
MIN_TOUCH_PX = 44 * PX_PER_DP
OFFSCREEN_SLACK_PX = 8
OVERLAP_MIN = 0.40
OVERLAP_CONTAINED = 0.90

# Words a brand-new player may not know. Moved from playtest_long_session.py.
JARGON = re.compile(
    r"\b(AL\d+|KEY\+?\d*|Gauntlet|Rift|Ascend|Blessing|Apex|God Hand|"
    r"FORGE|KEEP|Essence|\+\d+e\b|Mythic|Will of|KEYSTONE|REBORN|"
    r"WotLK|ilvl|iLvl|affix)\b",
    re.I,
)

_WAY_OUT = re.compile(
    r"\b(close|back|leave|done|got it|cancel|gear|gold|shop|essence|more|key)\b",
    re.I,
)
_OPEN_SCREENS = {"hub", "path", "dungeon", "title", "boot", "fight"}
_HUMAN_NUMBER = re.compile(
    r"(\d{1,3}(?:[,\s]\d{3})+|\d+(?:\.\d+)?)\s*([kmb])?",
    re.I,
)
_GOLD = re.compile(r"\bgold\b", re.I)
_ESSENCE = re.compile(r"\bessence\b", re.I)
_AL = re.compile(r"\bAL\s*(\d+)\b", re.I)


@dataclass
class CheckFinding:
    rule: str
    message: str
    label: str = ""
    count: int = 1
    extra: dict = field(default_factory=dict)


def human_number(text: str) -> int | None:
    """First compact number in text. 12.4k -> 12400. 1,234 -> 1234."""
    match = _HUMAN_NUMBER.search(text.replace("\u00a0", " "))
    if not match:
        return None
    return _scaled(match)


def number_beside(text: str, word: re.Pattern[str]) -> int | None:
    """The number next to a word, not the first number in a shared label.

    "Gold 88.1k, Essence 2,873" must not report the gold as the essence.
    """
    cleaned = text.replace("\u00a0", " ")
    match = word.search(cleaned)
    if not match:
        return None
    after = _HUMAN_NUMBER.search(cleaned[match.end() :])
    if after is not None and after.start() <= 8:
        return _scaled(after)
    nearest = None
    for item in _HUMAN_NUMBER.finditer(cleaned[: match.start()]):
        if match.start() - item.end() <= 8:
            nearest = item
    if nearest is None:
        return None
    return _scaled(nearest)


def _scaled(match: re.Match[str]) -> int | None:
    raw = match.group(1).replace(",", "").replace(" ", "")
    try:
        value = float(raw)
    except ValueError:
        return None
    suffix = (match.group(2) or "").lower()
    scale = {"": 1, "k": 1_000, "m": 1_000_000, "b": 1_000_000_000}[suffix]
    return int(round(value * scale))


def numbers_close(shown: int, actual: int) -> bool:
    if shown == actual:
        return True
    gap = abs(shown - actual)
    if gap <= 2:
        return True
    base = max(abs(actual), 1)
    return gap / base <= 0.05


def run_checks(
    nodes: list[Node],
    *,
    screen: str = "",
    jargon: bool = False,
    state: dict | None = None,
) -> list[CheckFinding]:
    found: list[CheckFinding] = []
    found.extend(_touch(nodes))
    found.extend(_clipped_by_nav(nodes))
    found.extend(_offscreen(nodes))
    found.extend(_overlap(nodes))
    found.extend(_duplicates(nodes))
    if jargon:
        found.extend(_jargon(nodes))
    found.extend(_dead_end(nodes, screen))
    if state:
        found.extend(_state_mismatch(nodes, state))
    return _squash(found)


def _squash(found: list[CheckFinding]) -> list[CheckFinding]:
    merged: list[CheckFinding] = []
    for item in found:
        for prev in merged:
            if prev.rule == item.rule and prev.label == item.label and prev.message == item.message:
                prev.count += item.count
                break
        else:
            merged.append(item)
    return merged


def _touch(nodes: list[Node]) -> list[CheckFinding]:
    out: list[CheckFinding] = []
    screen_area = SCREEN_W * SCREEN_H
    for node in nodes:
        if not node.clickable:
            continue
        if node.area > screen_area * 0.5:
            continue
        width = node.x2 - node.x1
        height = node.y2 - node.y1
        if width >= MIN_TOUCH_PX and height >= MIN_TOUCH_PX:
            continue
        out.append(
            CheckFinding(
                rule="touch_small",
                label=node.label,
                message=(
                    f"Tap target {width}×{height}px is under {MIN_TOUCH_PX}px "
                    f"({MIN_TOUCH_PX // PX_PER_DP} dp) on a side"
                ),
            )
        )
    return out


_NAV_LABELS = {"gear", "gold", "shop", "essence", "more", "leave", "key"}


def _clipped_by_nav(nodes: list[Node]) -> list[CheckFinding]:
    """A short action sitting on the bottom bar was sliced, not a small button."""
    nav_tops = [
        node.y1
        for node in nodes
        if node.clickable and node.label.strip().casefold() in _NAV_LABELS
    ]
    if not nav_tops:
        return []
    nav_top = min(nav_tops)
    out: list[CheckFinding] = []
    for node in nodes:
        if not node.clickable:
            continue
        if node.label.strip().casefold() in _NAV_LABELS:
            continue
        height = node.y2 - node.y1
        if height >= MIN_TOUCH_PX:
            continue
        if node.y2 < nav_top - 48 or node.y1 >= nav_top:
            continue
        out.append(
            CheckFinding(
                rule="clipped_by_nav",
                label=node.label,
                message=(
                    f"{node.label} is cut against the bottom bar "
                    f"({height}px tall, bar starts at {nav_top})"
                ),
            )
        )
    return out


def _offscreen(nodes: list[Node]) -> list[CheckFinding]:
    out: list[CheckFinding] = []
    slack = OFFSCREEN_SLACK_PX
    for node in nodes:
        if (
            node.x1 >= -slack
            and node.y1 >= -slack
            and node.x2 <= SCREEN_W + slack
            and node.y2 <= SCREEN_H + slack
        ):
            continue
        out.append(
            CheckFinding(
                rule="offscreen",
                label=node.label,
                message=(
                    f"Sits outside the phone "
                    f"[{node.x1},{node.y1}][{node.x2},{node.y2}]"
                ),
            )
        )
    return out


def _overlap(nodes: list[Node]) -> list[CheckFinding]:
    clickable = [n for n in nodes if n.clickable and n.area > 0]
    out: list[CheckFinding] = []
    for i, a in enumerate(clickable):
        for b in clickable[i + 1 :]:
            if a.label.casefold() == b.label.casefold():
                continue
            ix1 = max(a.x1, b.x1)
            iy1 = max(a.y1, b.y1)
            ix2 = min(a.x2, b.x2)
            iy2 = min(a.y2, b.y2)
            if ix2 <= ix1 or iy2 <= iy1:
                continue
            shared = (ix2 - ix1) * (iy2 - iy1)
            smaller = min(a.area, b.area)
            ratio = shared / smaller
            if ratio < OVERLAP_MIN or ratio >= OVERLAP_CONTAINED:
                continue
            pair = " + ".join(sorted((a.label, b.label), key=str.casefold))
            out.append(
                CheckFinding(
                    rule="overlap",
                    label=pair,
                    message="Two buttons overlap, so a tap can hit the wrong one",
                )
            )
    return out


def _duplicates(nodes: list[Node]) -> list[CheckFinding]:
    groups: dict[str, list[Node]] = {}
    for node in nodes:
        if not node.clickable:
            continue
        groups.setdefault(node.label.casefold(), []).append(node)
    out: list[CheckFinding] = []
    for label, group in groups.items():
        if len(group) < 2:
            continue
        out.append(
            CheckFinding(
                rule="duplicate",
                label=group[0].label,
                count=len(group),
                message=f"The same button appears {len(group)} times",
            )
        )
    return out


def _jargon(nodes: list[Node]) -> list[CheckFinding]:
    out: list[CheckFinding] = []
    seen: set[str] = set()
    for node in nodes:
        for hit in JARGON.findall(node.label):
            key = hit.casefold()
            if key in seen:
                continue
            seen.add(key)
            out.append(
                CheckFinding(
                    rule="jargon",
                    label=hit,
                    message=f"A new player may not know “{hit}”",
                )
            )
    return out


def _dead_end(nodes: list[Node], screen: str) -> list[CheckFinding]:
    clickable = [n for n in nodes if n.clickable]
    if not clickable:
        return [
            CheckFinding(
                rule="dead_end",
                message="No button on this screen",
            )
        ]
    if screen in _OPEN_SCREENS:
        return []
    if any(_WAY_OUT.search(n.label) for n in clickable):
        return []
    return [
        CheckFinding(
            rule="dead_end",
            message="Buttons are here, but none of them lead back",
        )
    ]


def _state_mismatch(nodes: list[Node], state: dict) -> list[CheckFinding]:
    out: list[CheckFinding] = []
    gold = state.get("gold")
    essence = state.get("essence")
    al = state.get("al")
    if gold is not None:
        out.extend(_word_number(nodes, _GOLD, int(gold), "gold"))
    if essence is not None:
        out.extend(_word_number(nodes, _ESSENCE, int(essence), "essence"))
    if al is not None:
        for node in nodes:
            match = _AL.search(node.label)
            if not match:
                continue
            shown = int(match.group(1))
            if shown != int(al):
                out.append(
                    CheckFinding(
                        rule="state_mismatch",
                        label=node.label,
                        message=f"Screen says AL{shown} but the save is AL{int(al)}",
                    )
                )
            break
    return out


def _word_number(
    nodes: list[Node],
    word: re.Pattern[str],
    actual: int,
    name: str,
) -> list[CheckFinding]:
    for node in nodes:
        if not word.search(node.label):
            continue
        shown = number_beside(node.label, word)
        if shown is None:
            continue
        if numbers_close(shown, actual):
            return []
        return [
            CheckFinding(
                rule="state_mismatch",
                label=node.label,
                message=f"Screen says {name} {shown} but the save has {actual}",
            )
        ]
    return []
