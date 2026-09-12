"""Capture listing shots 1–2 from a new-save first minute of combat.

Requires Flutter web on :8080 and first_minute_save.json
(from export_showcase_save_test.dart).
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

_DIR = Path(__file__).resolve().parent
if str(_DIR) not in sys.path:
    sys.path.insert(0, str(_DIR))

from capture_playwright import buttons, click_role, dismiss_optional_overlays, shot

SAVE = Path(__file__).resolve().parent / "first_minute_save.json"


def save_payload() -> str:
    data = json.loads(SAVE.read_text(encoding="utf-8"))
    # Slightly in the future so boot cannot open Welcome Back / AFK catch-up
    # before the first listing frame.
    data["lastUpdated"] = (datetime.now(timezone.utc) + timedelta(minutes=10)).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z"
    )
    return json.dumps(data, separators=(",", ":"))


def main() -> None:
    raw = save_payload()
    json.loads(raw)
    # SharedPreferences on web JSON-encodes strings. Install *before* Flutter
    # boots so the running game cannot autosave over the inject.
    init = (
        "localStorage.setItem('flutter.idle_party_save_v2', JSON.stringify("
        + json.dumps(raw)
        + "));"
    )

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()
        page.add_init_script(init)
        page.goto(
            "http://localhost:8080/",
            wait_until="domcontentloaded",
            timeout=90000,
        )
        page.wait_for_timeout(4500)
        page.wait_for_selector("flt-semantics[role=button]", timeout=30000)

        click_role(page, "SKIP", 700)
        click_role(page, "CONTINUE", 1800)
        dismiss_optional_overlays(page)
        for label in ("NICE", "NOT NOW", "GOT IT", "SKIP ALL TIPS"):
            click_role(page, label, 400)
        print("after continue", buttons(page))
        labels = buttons(page)
        if any("ENTER DUNGEON" in b or b == "ENTER" for b in labels):
            click_role(page, "ENTER DUNGEON", 2000) or click_role(
                page, "ENTER", 2000
            )

        page.evaluate(
            """() => {
              if (typeof window.__idlePartySetSpeed === 'function') {
                window.__idlePartySetSpeed(3);
              }
            }"""
        )
        page.wait_for_timeout(2200)
        print("combat a", buttons(page))
        shot(page, "01_combat_a.png")

        page.wait_for_timeout(5000)
        for label in ("God Hand ready", "GOD HAND"):
            click_role(page, label, 600)
        page.wait_for_timeout(900)
        print("combat b", buttons(page))
        shot(page, "02_combat_b.png")

        browser.close()
    print("done")


if __name__ == "__main__":
    main()
