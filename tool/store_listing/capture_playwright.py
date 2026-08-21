"""Capture Play Store raw phone shots via Playwright + showcase save."""
from __future__ import annotations

import json
from pathlib import Path

from playwright.sync_api import sync_playwright

RAW = Path(__file__).resolve().parent / "raw"
SAVE = Path(__file__).resolve().parent / "showcase_save.json"


def bridge(page, name: str, wait_ms: int = 900) -> bool:
    ok = page.evaluate(
        "(n) => typeof window.__idlePartyClick === 'function' "
        "? window.__idlePartyClick(n) : false",
        name,
    )
    print("bridge", name, ok)
    if ok:
        page.wait_for_timeout(wait_ms)
    return bool(ok)


def click_role(page, name: str, wait_ms: int = 900) -> bool:
    if bridge(page, name, wait_ms):
        return True
    loc = page.get_by_role("button", name=name)
    if loc.count() == 0:
        print("missing", name)
        return False
    box = loc.first.bounding_box()
    if not box:
        print("no box", name)
        return False
    page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2, delay=40)
    page.wait_for_timeout(wait_ms)
    print("clicked", name)
    return True


def shot(page, name: str) -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / name
    page.screenshot(path=str(path), type="png")
    print("wrote", path.name, path.stat().st_size)


def buttons(page) -> list:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : []"
    )
    # Avoid Windows console UnicodeEncodeError on ◂ etc.
    if isinstance(raw, list):
        return [str(x).encode("ascii", "replace").decode("ascii") for x in raw]
    return [str(raw).encode("ascii", "replace").decode("ascii")]


def tap_text(page, name: str, wait_ms: int = 700) -> bool:
    """Tab labels are often Text, not Semantics buttons."""
    loc = page.get_by_text(name, exact=True)
    n = loc.count()
    print("text", name, "count", n)
    if n == 0:
        return False
    try:
        loc.first.click(timeout=2000)
        page.wait_for_timeout(wait_ms)
        print("text-click", name)
        return True
    except Exception as e:
        print("text-click fail", name, e)
        return False


def main() -> None:
    raw = SAVE.read_text(encoding="utf-8")
    json.loads(raw)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()
        page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=90000)
        page.wait_for_timeout(2500)

        page.evaluate(
            """(raw) => {
              localStorage.setItem(
                'flutter.idle_party_save_v2',
                JSON.stringify(raw)
              );
            }""",
            raw,
        )
        page.reload(wait_until="domcontentloaded")
        page.wait_for_timeout(4500)
        page.wait_for_selector("flt-semantics[role=button]", timeout=30000)

        click_role(page, "SKIP", 700)
        click_role(page, "CONTINUE", 1400)
        click_role(page, "SKIP ALL TIPS", 600)
        click_role(page, "GOT IT", 400)
        page.wait_for_timeout(800)
        print("hub buttons", buttons(page))

        shot(page, "01_hub.png")
        shot(page, "05_zone.png")

        # GEAR paper-doll
        click_role(page, "PARTY", 900)
        click_role(page, "GEAR", 700)
        print("party buttons", buttons(page))
        shot(page, "03_gear.png")
        click_role(page, "CLOSE", 600)

        # POWER → INCOME (default) then FORGE → KEEP via tap coords
        # (Material TabBar labels are not WebClickBridge buttons).
        click_role(page, "POWER", 900)
        print("power buttons", buttons(page))
        shot(page, "06_power.png")  # INCOME rates

        click_role(page, "FORGE", 800)
        click_role(page, "KEEP", 800)
        print("forge buttons", buttons(page))
        shot(page, "04_meta.png")
        click_role(page, "CLOSE", 600)

        # Combat
        page.wait_for_timeout(500)
        print("pre-dungeon", buttons(page))
        if not click_role(page, "ENTER DUNGEON", 2000):
            click_role(page, "ENTER", 2000)
        page.evaluate(
            """() => {
              if (typeof window.__idlePartySetSpeed === 'function') {
                window.__idlePartySetSpeed(8);
              }
            }"""
        )
        page.wait_for_timeout(6500)
        print("dungeon buttons", buttons(page))
        shot(page, "02_combat.png")

        browser.close()
    print("done")


if __name__ == "__main__":
    main()
