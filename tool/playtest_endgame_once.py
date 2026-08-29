"""Inject AL20/Lv100 save and walk hub + META KEY menus (360x780)."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
SAVE = ROOT / "tool" / "out" / "endgame_playtest_save.json"
URL = "http://localhost:8082/"


def buttons(page) -> list[str]:
    return page.locator("flt-semantics[role=button]").all_text_contents()


def bridge(page, label: str) -> bool:
    return bool(
        page.evaluate(
            """(label) => typeof window.__idlePartyClick === 'function'
              && window.__idlePartyClick(label)""",
            label,
        )
    )


def click_any(page, *labels: str, wait_ms: int = 700) -> str | None:
    for label in labels:
        if bridge(page, label):
            page.wait_for_timeout(wait_ms)
            return label
    for label in labels:
        loc = page.get_by_role("button", name=label)
        if loc.count() > 0:
            loc.first.click(force=True)
            page.wait_for_timeout(wait_ms)
            return label
    return None


def save_summary(page) -> dict | None:
    return page.evaluate(
        """() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const md = s.metaDepth || {};
      return {
        al: s.ascensionLevel,
        hm: s.hardmodeLevel,
        gold: s.gold,
        essence: s.essence,
        gauntlet: md.gauntletBestFloor,
        rift: md.riftBestTier,
        gr: md.grBestTier,
        heroes: (s.heroes || []).map(h => h.level),
        inDungeon: s.inDungeon,
      };
    }"""
    )


def dismiss(page) -> None:
    for _ in range(8):
        btns = buttons(page)
        if any("What's New" in b or "WHATS NEW" in b.upper() for b in btns):
            click_any(page, "GOT IT", "CLOSE", wait_ms=500)
            continue
        if "SKIP ALL TIPS" in btns:
            click_any(page, "SKIP ALL TIPS", wait_ms=400)
            continue
        if "GOT IT" in btns:
            click_any(page, "GOT IT", wait_ms=300)
            continue
        if "MAYBE LATER" in btns:
            click_any(page, "MAYBE LATER", wait_ms=400)
            continue
        break


def main() -> int:
    if not SAVE.is_file():
        print("missing save", SAVE, file=sys.stderr)
        return 1
    raw = SAVE.read_text(encoding="utf-8")
    notes: list[str] = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
        ).new_page()
        page.goto(URL, wait_until="domcontentloaded")
        page.wait_for_timeout(3500)
        page.evaluate(
            """(raw) => localStorage.setItem(
                  'flutter.idle_party_save_v2', JSON.stringify(raw))""",
            raw,
        )
        page.reload(wait_until="domcontentloaded")
        page.wait_for_timeout(4500)
        dismiss(page)

        # Boot intro / start menu
        click_any(page, "SKIP", wait_ms=600)
        click_any(page, "CONTINUE", "NEW GAME", wait_ms=1200)
        dismiss(page)
        page.wait_for_timeout(800)

        snap = save_summary(page)
        notes.append(f"save: {snap}")
        hub_btns = buttons(page)
        notes.append(f"hub buttons sample: {hub_btns[:18]}")

        # TODAY / primary CTA
        today = [b for b in hub_btns if "TODAY" in b.upper() or "ENTER" in b.upper() or "KEY" in b.upper() or "GAUNTLET" in b.upper() or "GREATER" in b.upper() or "CLAIM" in b.upper()]
        notes.append(f"hub chase CTAs: {today[:8]}")

        # META → KEY
        if click_any(page, "META", wait_ms=900):
            meta_btns = buttons(page)
            notes.append(f"meta tabs: {[b for b in meta_btns if 'KEY' in b or 'QUEST' in b or 'BEAST' in b or 'CODEX' in b][:10]}")
            click_any(page, "KEYSTONE", "KEY", wait_ms=700)
            key_btns = buttons(page)
            notes.append(f"key panel: {key_btns[:20]}")
            click_any(page, "CLOSE", wait_ms=600)

        dismiss(page)
        # Gauntlet enter if visible on hub
        gaunt = [b for b in buttons(page) if "GAUNTLET" in b.upper() or "SPIRE" in b.upper() or "GREATER" in b.upper() or "RIFT" in b.upper()]
        notes.append(f"endgame hub labels: {gaunt[:10]}")
        entered = click_any(
            page,
            "ENTER GAUNTLET",
            "GAUNTLET",
            "ENTER KEY +20",
            "ENTER KEY +21",
            "ENTER DUNGEON",
            wait_ms=1600,
        )
        if entered:
            notes.append(f"entered via: {entered}")
            page.evaluate("() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(10)")
            page.wait_for_timeout(4000)
            d_btns = buttons(page)
            notes.append(f"dungeon/endgame buttons: {d_btns[:16]}")
            click_any(page, "LEAVE", "RETURN TO HUB", "HUB", wait_ms=1200)
        else:
            notes.append("no gauntlet/key enter button found on hub")

        browser.close()

    for line in notes:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
