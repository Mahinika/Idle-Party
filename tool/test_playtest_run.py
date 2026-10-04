"""Pure playtest runner checks. No emulator."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from adb_see import Node
from playtest_run import (
    _log_hits,
    add_finding,
    extra_screens,
    fold_ip_state,
    missing_coverage,
    offline_notes,
    parse_semantics,
    pick_save_slot,
    png_bytes,
    render_memory,
    render_report,
    screen_from_nav,
    stage_of,
    title_hint,
    tree_diff,
    upsert_ok,
    EMPTY_MEMORY,
)


def node(label, x1, y1, x2, y2, clickable=True) -> Node:
    return Node(label, clickable, False, "View", x1, y1, x2, y2)


def test_fold_ip_state_applies_continue_then_delta_then_enter():
    text = """
I/flutter: [IP] continue · AL0 · hub · gold 100 · e 5 · chase Fight · bag 2 · meanLv 4
I/flutter: [IP] state · gold 100→130 · e 5→9
I/flutter: [IP] enter · sandy F1 · KEY +0
"""
    state = fold_ip_state(text)
    assert state["gold"] == 130
    assert state["essence"] == 9
    assert state["al"] == 0
    assert state["mean_lv"] == 4
    assert state["in_dungeon"] is True


def test_stage_and_nav():
    assert stage_of({"al": 0, "mean_lv": 4}) == "early"
    assert stage_of({"al": 3, "mean_lv": 40}) == "mid"
    assert stage_of({"al": 0, "mean_lv": 100}) == "endgame"
    assert screen_from_nav("GEAR/bag", False) == "bag"
    assert screen_from_nav("closed", True) == "dungeon"
    assert screen_from_nav("closed", False) == "hub"


def test_save_slot_prefers_the_named_party_and_skips_empty():
    title = [node("Bram · Sandy Caverns", 40, 1500, 1000, 1560, clickable=False)]
    assert title_hint(title) == "Bram"
    picker = [
        node("SAVE 1", 40, 200, 700, 320),
        node("Empty", 40, 250, 400, 300, clickable=False),
        node("SAVE 2", 40, 400, 700, 520),
        node("Bram", 40, 450, 400, 500, clickable=False),
        node("ERASE 2", 760, 400, 1000, 520),
    ]
    assert pick_save_slot(picker, "Bram").label == "SAVE 2"
    assert pick_save_slot(picker, "").label == "SAVE 2"
    live = [
        node("SAVE 1 The Party Hollow Grove · Lv 20 · AL 3", 40, 200, 800, 360),
        node("ERASE 1", 820, 200, 1040, 360),
        node("SAVE 2 Empty", 40, 400, 800, 520),
    ]
    assert pick_save_slot(live, "The Party").label.startswith("SAVE 1")


def test_offline_mismatch_and_quiet_when_the_number_matches():
    before = {"gold": 100, "essence": 5}
    after = {"gold": 180, "essence": 5}
    welcome = "Welcome back!\nYour party earned 50 gold while you were away."
    notes = offline_notes(before, after, welcome)
    assert notes and notes[0]["rule"] == "offline_mismatch"
    honest = "Welcome back!\nYour party earned 80 gold while you were away."
    assert offline_notes(before, after, honest) == []
    assert offline_notes(before, after, "hub") == []


def test_tree_diff_missing_moved_and_primary():
    baseline = [
        {"label": "GEAR", "clickable": True, "x1": 0, "y1": 100, "x2": 200, "y2": 240},
        {"label": "ENTER DUNGEON", "clickable": True, "x1": 80, "y1": 1900, "x2": 1000, "y2": 2100},
    ]
    current = [
        {"label": "GEAR", "clickable": True, "x1": 400, "y1": 100, "x2": 600, "y2": 240},
        {"label": "SHOP", "clickable": True, "x1": 80, "y1": 1900, "x2": 1000, "y2": 2100},
    ]
    rules = {item["rule"] for item in tree_diff(current, baseline)}
    assert "tree_missing" in rules
    assert "tree_moved" in rules
    assert "primary_changed" in rules


def test_look_extra_and_coverage():
    screens = {
        "coverage": {"early": ["hub", "gear"]},
        "screens": {"gear": {"files": ["lib/visual/"]}},
    }
    ok_rows = [
        {"screen": "gear", "stage": "early", "commit": "abc", "streak": 3},
    ]
    extra = extra_screens(ok_rows, screens, ["lib/visual/helm.png"])
    assert extra[0]["screen"] == "gear"
    assert "stale" in extra[0]["why"]
    assert "code changed" in extra[0]["why"]
    assert missing_coverage("early", {"hub"}, screens) == ["gear"]


def test_findings_collapse_and_report_warns_when_short():
    session = {"next_id": 1, "findings": [], "snaps": [], "stage": "early", "play_started": 1000}
    add_finding(session, rule="touch_small", screen="gear", label="SELL", message="small")
    add_finding(session, rule="touch_small", screen="gear", label="SELL", message="small")
    assert session["findings"][0]["count"] == 2
    text = render_report(session, {"coverage": {"early": ["hub"]}}, now=1010)
    assert "WARNING: round was under 8 minutes." in text
    assert "Not opened: hub" in text


def test_memory_roundtrip_shape():
    data = {"good": [], "learned": [], "ok": []}
    text = render_memory(data)
    assert "## Bra" in text and "_None yet._" in text
    upsert_ok(data, "hub", "early", "abc1234", "2026-10-04")
    upsert_ok(data, "hub", "early", "abc1234", "2026-10-04")
    assert data["ok"][0]["streak"] == 2
    assert render_memory(EMPTY_MEMORY) == render_memory({"good": [], "learned": [], "ok": []})


def test_parse_semantics_scales_logical_pixels_and_drops_the_inner_copy():
    text = """
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 └─SemanticsNode#1
   │ Rect.fromLTRB(0.0, 0.0, 360.0, 780.0) scaled by 3.0x
   ├─SemanticsNode#2
   │ │ Rect.fromLTRB(12.0, 700.0, 80.0, 760.0)
   │ │ actions: tap
   │ │ flags: isButton
   │ │ label: "GEAR"
   │ └─SemanticsNode#3
   │     Rect.fromLTRB(0.0, 0.0, 28.0, 30.0)
   │     actions: tap
   │     label: "GEAR"
   └─SemanticsNode#4
     │ Rect.fromLTRB(0.0, 0.0, 100.0, 40.0) with transform
     │ [[1.0,0.0,0.0,12.0];
     │ [0.0,1.0,0.0,400.0];
     │ [0.0,0.0,1.0,0.0]; [0.0,0.0,0.0,1.0]]
     │ actions: tap
     │ label: "CLAIM QUESTS"
"""
    nodes = parse_semantics(text)
    gear = [node for node in nodes if node.label == "GEAR"]
    assert len(gear) == 1
    assert gear[0].clickable
    assert (gear[0].x1, gear[0].y1, gear[0].x2, gear[0].y2) == (36, 2100, 240, 2280)
    claim = next(node for node in nodes if node.label == "CLAIM QUESTS")
    assert (claim.x1, claim.y1) == (36, 1200)


def test_log_hits_keep_the_game_and_skip_the_phone():
    import tempfile

    with tempfile.TemporaryDirectory() as raw:
        folder = Path(raw)
        (folder / "logcat.txt").write_text(
            "\n".join(
                [
                    "E/Bluetooth(  706): Exception in radio",
                    "I/flutter ( 9193): Exception: save failed",
                    "I/Choreographer( 9193): Skipped 40 frames!",
                    "I/Choreographer(   12): Skipped 40 frames!",
                ]
            ),
            encoding="utf-8",
        )
        hits = _log_hits(folder)
    blob = "\n".join(hits)
    assert "save failed" in blob
    assert "9193" in blob and "Skipped 40" in blob
    assert "Bluetooth" not in blob
    assert "(   12)" not in blob


def test_png_bytes_keeps_a_healthy_signature_and_repairs_a_doubled_one():
    healthy = b"\x89PNG\r\n\x1a\nrest"
    assert png_bytes(healthy) == healthy
    broken = b"\x89PNG\r\r\n\x1a\r\nrest"
    assert png_bytes(broken).startswith(b"\x89PNG\r\n\x1a\n")


if __name__ == "__main__":
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
