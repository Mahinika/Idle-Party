"""Naive new-player clarity playtest (360x780) — mouse + bridge."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "naive_clarity"
URL = "http://localhost:8083/"


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
    page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2, delay=40)
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
    for i in range(12):
        btns = buttons(page)
        if any("What's New" in b for b in btns) or any(
            "WHATS NEW" in b.upper() for b in btns
        ):
            shot(page, f"{tag}_whatsnew_{i}")
            log(notes, f"[{tag}] Whats New visible")
            click_any(page, "GOT IT", "CLOSE", wait_ms=500)
            continue
        if "SKIP ALL TIPS" in btns:
            shot(page, f"{tag}_tip_{i}")
            tippy = [b for b in btns if len(b) < 60][:16]
            log(notes, f"[{tag}] tip buttons: {tippy}")
            # Read first tip via GOT IT once, then skip rest
            if i == 0 and "GOT IT" in btns:
                click_any(page, "GOT IT", wait_ms=600)
            else:
                click_any(page, "SKIP ALL TIPS", wait_ms=600)
            continue
        if "GOT IT" in btns:
            shot(page, f"{tag}_gotit_{i}")
            log(notes, f"[{tag}] GOT IT modal: {btns[:12]}")
            click_any(page, "GOT IT", wait_ms=500)
            continue
        if "MAYBE LATER" in btns:
            shot(page, f"{tag}_discord_{i}")
            log(notes, f"[{tag}] Discord/invite overlay")
            click_any(page, "MAYBE LATER", wait_ms=500)
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

        shot(page, "01_boot")
        log(notes, f"boot: {buttons(page)[:12]}")
        click_any(page, "SKIP", wait_ms=800)
        page.wait_for_timeout(500)
        shot(page, "02_title")
        log(notes, f"title: {buttons(page)[:12]}")

        click_any(page, "NEW GAME", wait_ms=1500)
        click_any(page, "OVERWRITE", "START OVER", wait_ms=800)
        page.wait_for_timeout(600)
        shot(page, "03_picker")
        log(notes, f"picker: {buttons(page)[:25]}")

        # Naive: tap whatever looks like roles
        for label in (
            "Warrior",
            "PROT",
            "Protection",
            "Shield",
            "Priest",
            "DISC",
            "Discipline",
            "Healer",
            "Mage",
            "FIRE",
            "Fire",
            "Damage",
        ):
            mouse_click(page, label, 450)

        shot(page, "04_picker_filled")
        log(notes, f"picker filled: {buttons(page)[:20]}")
        click_any(page, "START", wait_ms=1800)
        click_any(page, "OVERWRITE", wait_ms=800)

        dismiss(page, notes, "after_start")
        page.wait_for_timeout(700)
        shot(page, "06_hub")
        hub = buttons(page)
        log(notes, f"hub ({len(hub)}): {hub}")

        # TODAY
        today = next((b for b in hub if "TODAY" in b.upper()), None)
        if today:
            bridge(page, today, 800)
            shot(page, "07_today")
            log(notes, f"today: {buttons(page)[:20]}")
            click_any(page, "CLOSE", "GOT IT", wait_ms=500)
            dismiss(page, notes, "after_today")

        # POWER peek — what would confuse a newbie
        if click_any(page, "POWER", wait_ms=1000):
            shot(page, "08_power")
            log(notes, f"power: {buttons(page)[:25]}")
            # open first gold-looking tab if any
            for t in ("GOLD", "FORGE", "Gold upgrades", "Buy supplies", "MARKET", "CAMP"):
                if mouse_click(page, t, 700):
                    shot(page, f"08b_power_{t.replace(' ', '_')}")
                    log(notes, f"power tab {t}: {buttons(page)[:18]}")
                    break
            click_any(page, "CLOSE", wait_ms=600)

        if click_any(page, "META", wait_ms=1000):
            shot(page, "09_meta")
            log(notes, f"meta: {buttons(page)[:22]}")
            click_any(page, "CLOSE", wait_ms=600)

        if click_any(page, "PARTY", wait_ms=1000):
            shot(page, "10_party")
            log(notes, f"party: {buttons(page)[:22]}")
            click_any(page, "CLOSE", wait_ms=600)

        # POWERUPS if visible
        if click_any(page, "POWERUPS", wait_ms=900):
            shot(page, "11_powerups")
            log(notes, f"powerups: {buttons(page)[:15]}")
            click_any(page, "CLOSE", "MAYBE LATER", "GOT IT", wait_ms=600)

        entered = click_any(page, "ENTER DUNGEON", "ENTER", wait_ms=2000)
        log(notes, f"enter: {entered}")
        dismiss(page, notes, "dungeon_enter")
        page.evaluate(
            "() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(6)"
        )
        page.wait_for_timeout(4000)
        shot(page, "12_dungeon")
        log(notes, f"dungeon: {buttons(page)[:28]}")

        page.wait_for_timeout(10000)
        shot(page, "13_dungeon_mid")
        log(notes, f"dungeon mid: {buttons(page)[:22]}")

        # Try God Hand / flask / leave
        for label in buttons(page):
            if "God Hand" in label or "Tap the fight" in label:
                bridge(page, label, 600)
                shot(page, "13b_godhand")
                log(notes, f"tapped godhand-ish: {label}")
                break

        click_any(page, "LEAVE", "HUB", wait_ms=1400)
        dismiss(page, notes, "back")
        page.wait_for_timeout(800)
        shot(page, "14_hub_return")
        hub2 = buttons(page)
        log(notes, f"return hub: {hub2}")

        jargon_words = (
            "AL ",
            "AL•",
            "ESSENCE",
            "KEY",
            "ASCEND",
            "PROT",
            "DISC",
            "FIRE",
            "BAL",
            "Z-N",
            "DPS",
            "FORGE",
            "APEX",
            "GAUNTLET",
            "POWERUPS",
            "VAULT",
            "iLvl",
            "STA",
            "ATK",
            "DEF",
            "MOVE",
            "HASTE",
            "CRIT",
            "FARM",
            "PUSH",
            "LOOP",
            "CLIMB",
        )
        jargon = []
        for b in hub2 + buttons(page):
            u = b.upper()
            for w in jargon_words:
                if w.upper() in u:
                    jargon.append(b)
                    break
        log(notes, f"jargon still visible: {sorted(set(jargon))[:25]}")

        browser.close()

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "notes.json").write_text(json.dumps(notes, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
