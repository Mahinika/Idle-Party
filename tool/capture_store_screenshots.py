"""Capture Play Store phone screenshots into docs/store/screenshots/.

Requires Flutter web on http://localhost:8080/ with semantics + WebClickBridge.
Prefer bridge clicks over raw mouse (CanvasKit).
"""
from __future__ import annotations

from pathlib import Path

from playwright.sync_api import sync_playwright

OUT = Path("docs/store/screenshots")
OUT.mkdir(parents=True, exist_ok=True)
URL = "http://localhost:8080/"


def buttons(page):
    return page.locator("flt-semantics[role=button]").all_text_contents()


def bridge(page, label: str) -> bool:
    return bool(
        page.evaluate(
            "(l) => !!(window.__idlePartyClick && window.__idlePartyClick(l))",
            label,
        )
    )


def bridge_wait(page, label: str, pause_ms: int = 800) -> bool:
    ok = bridge(page, label)
    if ok:
        page.wait_for_timeout(pause_ms)
    return ok


def shot(page, name: str) -> Path:
    path = OUT / f"{name}.png"
    page.screenshot(path=str(path), full_page=False)
    print("wrote", path)
    return path


def dismiss_tips(page) -> None:
    bridge_wait(page, "SKIP ALL TIPS", 500)
    for _ in range(12):
        if not bridge_wait(page, "GOT IT", 280):
            break


with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(
        viewport={"width": 1080, "height": 1920},
        device_scale_factor=1,
    )
    page.goto(URL, wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(4000)
    page.wait_for_selector("flt-semantics[role=button]", timeout=30000)

    # Fresh save so title + first hub are clean.
    page.evaluate("() => localStorage.clear()")
    page.reload(wait_until="domcontentloaded")
    page.wait_for_timeout(5000)
    page.wait_for_selector("flt-semantics[role=button]", timeout=30000)
    shot(page, "01_title")

    assert bridge_wait(page, "NEW GAME", 1000)
    assert bridge_wait(page, "START", 1500)
    dismiss_tips(page)
    for _ in range(4):
        if "CLOSE" in buttons(page):
            bridge_wait(page, "CLOSE", 500)
        else:
            break

    assert "ENTER DUNGEON" in buttons(page), buttons(page)
    shot(page, "02_hub")

    more = next((b for b in buttons(page) if b.startswith("MORE")), None)
    if more and bridge_wait(page, more, 700):
        shot(page, "04_more")
        if bridge_wait(page, "GUIDES", 900):
            shot(page, "05_guides")
            bridge_wait(page, "CLOSE", 500)
        bridge_wait(page, "CLOSE", 500)

    assert bridge_wait(page, "ENTER DUNGEON", 2000)
    dismiss_tips(page)
    bridge_wait(page, "FARM dungeon mode", 500) or bridge_wait(page, "FARM", 500)
    page.wait_for_timeout(3000)
    shot(page, "03_dungeon")
    page.evaluate("() => window.__idlePartyTap && window.__idlePartyTap(540, 960)")
    page.wait_for_timeout(1200)
    shot(page, "06_god_hand")

    browser.close()
    print("done", sorted(p.name for p in OUT.glob("*.png")))
