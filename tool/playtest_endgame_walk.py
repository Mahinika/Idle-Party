"""Walk AL20 endgame: hub chase, META KEY, Gauntlet/KEY enter (360x780)."""
from __future__ import annotations

import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))
from capture_dungeon_screenshots import boot_to_hub, click_role  # noqa: E402

SAVE = ROOT / "tool" / "out" / "endgame_playtest_save.json"
OUT = ROOT / "tool" / "out" / "endgame_playtest"
URL = "http://localhost:8082/"


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : ''"
    )
    text = str(raw or "").strip()
    if not text:
        return page.locator("flt-semantics[role=button]").all_text_contents()
    return [p.strip() for p in text.split(" | ") if p.strip()]


def find_button(page, *needles: str) -> str | None:
    low = [n.lower() for n in needles]
    for b in buttons(page):
        bl = b.lower()
        if all(n in bl for n in low):
            return b
    return None


def dismiss(page) -> None:
    for _ in range(12):
        btns = buttons(page)
        if not btns:
            page.wait_for_timeout(400)
            continue
        if any("what's new" in b.lower() for b in btns):
            click_role(page, "GOT IT", 500)
            continue
        if "SKIP ALL TIPS" in btns:
            click_role(page, "SKIP ALL TIPS", 400)
            continue
        if "GOT IT" in btns:
            click_role(page, "GOT IT", 300)
            continue
        if "MAYBE LATER" in btns:
            click_role(page, "MAYBE LATER", 400)
            continue
        break


def save_summary(page) -> dict:
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
        zone: s.dungeonId,
        inDungeon: s.inDungeon,
        inGauntlet: s.inGauntlet,
        vaultClaimed: md.dailyVaultClaimed,
        vaultClears: md.dailyVaultClears,
      };
    }"""
    )


def screenshot(page, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUT / f"{name}.png"), full_page=True)


def click_found(page, label: str | None, wait_ms: int = 900) -> bool:
    if not label:
        return False
    return click_role(page, label, wait_ms)


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
            has_touch=True,
        ).new_page()
        page.goto(URL, wait_until="domcontentloaded", timeout=90000)
        page.wait_for_timeout(1500)
        page.evaluate(
            """(raw) => localStorage.setItem(
                  'flutter.idle_party_save_v2', JSON.stringify(raw))""",
            raw,
        )
        page.reload(wait_until="domcontentloaded")
        boot_to_hub(page)
        dismiss(page)
        page.wait_for_timeout(800)

        notes.append(f"save: {save_summary(page)}")
        btns = buttons(page)
        notes.append(f"hub buttons ({len(btns)}): {btns[:35]}")

        chase = [
            b
            for b in btns
            if any(
                x in b.upper()
                for x in (
                    "TODAY",
                    "ENTER",
                    "KEY",
                    "GAUNTLET",
                    "GREATER",
                    "RIFT",
                    "CLAIM",
                    "VAULT",
                    "DAILY",
                    "WILL",
                    "ASCEND",
                    "SPIRE",
                )
            )
        ]
        notes.append(f"chase CTAs: {chase}")
        screenshot(page, "01_hub")

        # META → KEYSTONE
        if click_role(page, "META", 900):
            meta = buttons(page)
            notes.append(f"meta tabs: {meta[:25]}")
            key_tab = find_button(page, "key") or "KEYSTONE"
            click_found(page, key_tab, 900)
            key_panel = buttons(page)
            notes.append(f"key panel: {key_panel[:30]}")
            screenshot(page, "02_meta_key")
            # Try rift / greater labels in KEY tab
            for needle in ("RIFT", "GREATER", "GAUNTLET", "VIEW"):
                hit = find_button(page, needle)
                if hit:
                    notes.append(f"key has: {hit}")
            click_role(page, "CLOSE", 600)
            dismiss(page)

        # POWER / FORGE
        if click_role(page, "POWER", 900):
            notes.append(f"power tabs: {buttons(page)[:20]}")
            screenshot(page, "03_power")
            click_role(page, "CLOSE", 600)

        # Gauntlet via META → VIEW GAUNTLET
        if click_role(page, "META", 900):
            if click_role(page, "VIEW GAUNTLET", 900):
                gaunt_btns = buttons(page)
                notes.append(f"gauntlet sheet: {gaunt_btns[:18]}")
                enter = find_button(page, "enter") or find_button(page, "gauntlet")
                if enter and enter != "VIEW GAUNTLET":
                    click_found(page, enter, 1400)
                page.evaluate(
                    "() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(8)"
                )
                page.wait_for_timeout(4500)
                notes.append(f"gauntlet run: {buttons(page)[:20]}")
                screenshot(page, "04_gauntlet")
                click_role(page, "LEAVE", 1200) or click_role(page, "HUB", 1200)
                dismiss(page)

        # KEY +20 dungeon (or generic enter)
        key_enter = find_button(page, "enter key") or find_button(page, "key +")
        if key_enter:
            notes.append(f"key enter: {key_enter}")
            click_found(page, key_enter, 1600)
        else:
            click_found(page, find_button(page, "enter dungeon"), 1600)
        page.evaluate(
            "() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(8)"
        )
        page.wait_for_timeout(5000)
        run_btns = buttons(page)
        notes.append(f"dungeon run: {run_btns[:25]}")
        notes.append(f"in dungeon save: {save_summary(page)}")
        screenshot(page, "05_dungeon")
        click_role(page, "LEAVE", 1400) or click_role(page, "HUB", 1400)

        browser.close()

    for line in notes:
        safe = line.encode("ascii", "replace").decode("ascii")
        print(safe)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
