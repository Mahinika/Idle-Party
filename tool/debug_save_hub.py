"""Quick check: does modified AL20 save reach hub?"""
from __future__ import annotations

import json
from pathlib import Path

from playwright.sync_api import sync_playwright

from capture_dungeon_screenshots import (
    al20_save_raw,
    buttons,
    click_role,
    dismiss_to_hub,
    hub_ready,
    inject_save,
)

SAVE_PATH = Path(__file__).resolve().parent / "store_listing" / "showcase_save.json"


def main() -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
        ).new_page()
        page.goto("http://localhost:8080/", wait_until="domcontentloaded")
        page.wait_for_timeout(1500)

        for label, inject in (
            ("showcase", lambda: page.evaluate(
                """(raw) => localStorage.setItem(
                      'flutter.idle_party_save_v2', JSON.stringify(raw))""",
                SAVE_PATH.read_text(encoding="utf-8"),
            )),
            ("al20", inject_save),
        ):
            inject()
            page.reload(wait_until="domcontentloaded")
            try:
                dismiss_to_hub(page)
                print(label, "OK", hub_ready(page), buttons(page)[:3])
            except Exception as e:
                print(label, "FAIL", e)
        browser.close()


if __name__ == "__main__":
    main()
