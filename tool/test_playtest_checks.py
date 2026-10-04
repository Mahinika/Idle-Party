"""Checks for /playtest. No emulator."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from adb_see import Node
from playtest_checks import human_number, numbers_close, run_checks


def node(label, x1, y1, x2, y2, clickable=True) -> Node:
    return Node(label, clickable, False, "View", x1, y1, x2, y2)


def rules(found) -> set[str]:
    return {item.rule for item in found}


def test_small_tap_target_is_flagged():
    found = run_checks([node("SELL", 0, 0, 100, 80)])
    assert "touch_small" in rules(found)


def test_large_tap_target_is_quiet():
    found = run_checks([node("ENTER DUNGEON", 80, 1800, 1000, 2000)])
    assert "touch_small" not in rules(found)


def test_offscreen_node_is_flagged():
    found = run_checks([node("CUT OFF", 900, 100, 1300, 300)])
    assert "offscreen" in rules(found)


def test_partial_overlap_is_flagged_and_nesting_is_not():
    overlap = run_checks(
        [
            node("FIGHT", 0, 0, 200, 200),
            node("BAG", 40, 40, 240, 240),
        ]
    )
    assert "overlap" in rules(overlap)
    nested = run_checks(
        [
            node("FIGHT", 0, 0, 400, 400),
            node("BAG", 50, 50, 150, 150),
        ]
    )
    assert "overlap" not in rules(nested)


def test_duplicate_buttons():
    found = run_checks(
        [
            node("CONTINUE", 0, 0, 400, 200),
            node("CONTINUE", 0, 500, 400, 700),
        ]
    )
    dupes = [item for item in found if item.rule == "duplicate"]
    assert len(dupes) == 1
    assert dupes[0].count == 2


def test_jargon_only_for_a_new_save():
    nodes = [node("Enter the Gauntlet", 0, 0, 400, 200)]
    assert "jargon" in rules(run_checks(nodes, jargon=True))
    assert "jargon" not in rules(run_checks(nodes, jargon=False))


def test_dead_end_and_way_out():
    empty = run_checks([], screen="gear")
    assert "dead_end" in rules(empty)
    trapped = run_checks([node("MYSTERY", 0, 0, 400, 200)], screen="gear")
    assert "dead_end" in rules(trapped)
    closed = run_checks([node("CLOSE", 0, 0, 400, 200)], screen="gear")
    assert "dead_end" not in rules(closed)
    hub = run_checks([node("ENTER DUNGEON", 0, 0, 400, 200)], screen="hub")
    assert "dead_end" not in rules(hub)


def test_state_mismatch_and_compact_gold():
    wrong = run_checks(
        [node("gold 250", 0, 0, 400, 200)],
        state={"gold": 100},
    )
    assert "state_mismatch" in rules(wrong)
    compact = run_checks(
        [node("12.4k gold", 0, 0, 400, 200)],
        state={"gold": 12400},
    )
    assert "state_mismatch" not in rules(compact)
    shared = run_checks(
        [node("Gold 88.1k, Essence 2,873", 0, 0, 400, 200)],
        state={"gold": 88100, "essence": 2873},
    )
    assert "state_mismatch" not in rules(shared)
    level = run_checks(
        [node("AL 3", 0, 0, 400, 200)],
        state={"al": 0},
    )
    assert any("AL3" in item.message for item in level)


def test_human_number():
    assert human_number("1,234 gold") == 1234
    assert human_number("12.4k") == 12400
    assert numbers_close(12000, 12400)
    assert not numbers_close(100, 250)


def _run_all() -> None:
    failed = 0
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        try:
            test()
        except Exception as error:
            failed += 1
            print(f"FAIL {test.__name__}: {error}")
        else:
            print(f"ok {test.__name__}")
    raise SystemExit(failed)


if __name__ == "__main__":
    _run_all()
