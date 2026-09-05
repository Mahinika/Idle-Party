"""Continue naive play: hub POWER/PARTY/dungeon loop (360x780) on 1.12.75."""
from __future__ import annotations

import json
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "naive_continue"
URL = "http://localhost:8084/"


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : ''"
    )
    text = str(raw or "").strip()
    if text:
        return [p.strip() for p in text.split(" | ") if p.strip()]
    return page.locator("flt-semantics[role=button]").all_text_contents()


def bridge(page, label: str, wait_ms: int = 900) -> bool:
    ok = bool(
        page.evaluate(
            "(n) => typeof window.__idlePartyClick === 'function' "
            "&& !!window.__idlePartyClick(n)",
            label,
        )
    )
    if ok:
        page.wait_for_timeout(wait_ms)
    return ok


def mouse_click(page, name: str, wait_ms: int = 900) -> bool:
    if bridge(page, name, wait_ms):
        return True
    loc = page.get_by_role("button", name=name)
    if loc.count() == 0:
        return False
    box = loc.first.bounding_box()
    if not box:
        return False
    page.mouse.click(
        box["x"] + box["width"] / 2, box["y"] + box["height"] / 2, delay=40
    )
    page.wait_for_timeout(wait_ms)
    return True


def click_any(page, *names: str, wait_ms: int = 900) -> str | None:
    for n in names:
        if mouse_click(page, n, wait_ms):
            return n
    return None


def shot(page, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUT / f"{name}.png"), full_page=True)


def log(notes: list[str], msg: str) -> None:
    notes.append(msg)
    print(msg.encode("ascii", "replace").decode("ascii"))


def dismiss(page, notes: list[str], tag: str) -> None:
    for i in range(14):
        btns = buttons(page)
        if "SKIP ALL TIPS" in btns:
            shot(page, f"{tag}_tip_{i}")
            log(notes, f"[{tag}] tip: {[b for b in btns if len(b) < 55][:14]}")
            if i == 0 and "GOT IT" in btns:
                click_any(page, "GOT IT", wait_ms=600)
            else:
                click_any(page, "SKIP ALL TIPS", wait_ms=600)
            continue
        if any("What's New" in b for b in btns):
            click_any(page, "GOT IT", "CLOSE", wait_ms=500)
            continue
        if "MAYBE LATER" in btns:
            shot(page, f"{tag}_discord_{i}")
            log(notes, f"[{tag}] discord after tips? tip first_run seen")
            click_any(page, "MAYBE LATER", wait_ms=500)
            continue
        if "GOT IT" in btns:
            click_any(page, "GOT IT", wait_ms=500)
            continue
        break


def main() -> int:
    notes: list[str] = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        ).new_page()
        page.goto(URL, wait_until="domcontentloaded", timeout=120000)
        page.wait_for_timeout(2000)
        page.evaluate("() => localStorage.clear()")
        page.reload(wait_until="networkidle", timeout=120000)
        page.wait_for_selector("flt-semantics[role=button]", timeout=90000)
        page.wait_for_timeout(2500)

        click_any(page, "SKIP", wait_ms=700)
        shot(page, "01_title")
        log(notes, f"title: {buttons(page)[:8]}")

        click_any(page, "NEW GAME", wait_ms=1600)
        click_any(page, "OVERWRITE", wait_ms=700)
        # If picker appears
        for label in ("Warrior", "PROT", "Priest", "DISC", "Mage", "FIRE"):
            mouse_click(page, label, 400)
        click_any(page, "START", wait_ms=1600)
        click_any(page, "OVERWRITE", wait_ms=700)

        dismiss(page, notes, "hub")
        shot(page, "02_hub")
        hub = buttons(page)
        log(notes, f"hub: {hub}")

        # POWER first-hour shape
        if click_any(page, "POWER", wait_ms=1100):
            shot(page, "03_power")
            pbtns = buttons(page)
            log(notes, f"power tabs/buttons: {pbtns[:30]}")
            keepish = [b for b in pbtns if any(x in b.upper() for x in ("KEEP", "APEX", "PERMANENT", "CAMP", "SHOP"))]
            log(notes, f"power advanced chrome: {keepish}")
            # try buy BEST or ATK
            for b in pbtns:
                if "BEST" in b.upper() or b.upper().startswith("ATK"):
                    bridge(page, b, 800)
                    shot(page, "03b_after_buy")
                    log(notes, f"bought via: {b}")
                    break
            click_any(page, "Shop", "Buy supplies", wait_ms=800)
            shot(page, "03c_market")
            log(notes, f"market: {buttons(page)[:18]}")
            click_any(page, "CLOSE", wait_ms=600)

        dismiss(page, notes, "after_power")

        # Enter and play a while
        click_any(page, "ENTER DUNGEON", wait_ms=2000)
        dismiss(page, notes, "dung")
        page.evaluate(
            "() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(8)"
        )
        page.wait_for_timeout(5000)
        shot(page, "04_dungeon")
        log(notes, f"dungeon: {buttons(page)[:22]}")

        # Equip if badge
        if click_any(page, "PARTY", wait_ms=1000):
            shot(page, "05_party")
            log(notes, f"party: {buttons(page)[:20]}")
            for b in buttons(page):
                if "EQUIP" in b.upper() and "OPEN" not in b.upper():
                    bridge(page, b, 900)
                    shot(page, "05b_equip")
                    log(notes, f"equip clicked: {b}")
                    break
            click_any(page, "CLOSE", wait_ms=600)

        page.wait_for_timeout(12000)
        shot(page, "06_dungeon_later")
        log(notes, f"dungeon later: {buttons(page)[:22]}")

        # Try leave
        click_any(page, "LEAVE", wait_ms=900)
        shot(page, "07_leave")
        log(notes, f"leave dialog: {buttons(page)[:12]}")
        click_any(page, "STAY", wait_ms=700)

        # Floor clear path — wait more
        page.wait_for_timeout(20000)
        shot(page, "08_midfight")
        log(notes, f"midfight: {buttons(page)[:20]}")

        click_any(page, "LEAVE", wait_ms=900)
        click_any(page, "RETURN", wait_ms=1200)
        dismiss(page, notes, "back")
        page.wait_for_timeout(800)
        shot(page, "09_hub_back")
        hub2 = buttons(page)
        log(notes, f"hub back: {hub2}")

        jargon = []
        for b in hub2:
            u = b.upper()
            for w in (
                "ASCEND",
                "AL ",
                "FORGE",
                "KEEP",
                "APEX",
                "POWERUPS",
                "FARM",
                "KEY",
                "ESSENCE",
                "VAULT",
                "PROT",
                "DISC",
            ):
                if w in u:
                    jargon.append(b)
                    break
        log(notes, f"jargon on hub: {jargon}")

        browser.close()

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "notes.json").write_text(json.dumps(notes, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
