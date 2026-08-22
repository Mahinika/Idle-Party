"""Capture one in-dungeon screenshot per zone (360x780 phone)."""
from __future__ import annotations

import json
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "dungeon_review"
SAVE_PATH = ROOT / "tool" / "store_listing" / "showcase_save.json"
URL = "http://localhost:8080/"

ZONES = (
    "sandy",
    "goblin",
    "king",
    "underworld",
    "dead",
    "hell",
    "crystal",
    "tide",
    "ember",
    "grove",
    "storm",
    "rime",
    "fen",
    "brass",
    "veil",
)

# World Path semantics labels when all zones cleared (AL20-ish save).
ZONE_PICK = {
    "sandy": "Sandy Caverns, CLEAR",
    "goblin": "Goblin's Hideout, CLEAR",
    "king": "King's Fort, CLEAR",
    "underworld": "Underworld, CLEAR",
    "dead": "City of Dead, CLEAR",
    "hell": "Hell's Gate, CLEAR",
    "crystal": "Crystal Spire, CLEAR",
    "tide": "Sunken Tidehold, CLEAR",
    "ember": "Ashen Vault, CLEAR",
    "grove": "Hollow Grove, CLEAR",
    "storm": "Stormwake Hollow, CLEAR",
    "rime": "Rimeglass Rift, CLEAR",
    "fen": "Blightfen Mire, CLEAR",
    "brass": "Brassvault Deep, CLEAR",
    "veil": "Mothveil Hollow, CLEAR",
}


def bridge(page, name: str, wait_ms: int = 700) -> bool:
    ok = page.evaluate(
        "(n) => typeof window.__idlePartyClick === 'function' "
        "? window.__idlePartyClick(n) : false",
        name,
    )
    if ok:
        page.wait_for_timeout(wait_ms)
    return bool(ok)


def click_role(page, name: str, wait_ms: int = 700) -> bool:
    if bridge(page, name, wait_ms):
        return True
    loc = page.get_by_role("button", name=name)
    if loc.count() == 0:
        return False
    box = loc.first.bounding_box()
    if not box:
        return False
    page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
    page.wait_for_timeout(wait_ms)
    return True


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : []"
    )
    return [str(x) for x in (raw or [])]


def boot_to_hub(page) -> None:
    page.wait_for_selector("flt-semantics[role=button]", timeout=60000)
    page.wait_for_timeout(4500)
    click_role(page, "SKIP", 700)
    click_role(page, "CONTINUE", 1400)
    click_role(page, "SKIP ALL TIPS", 600)
    click_role(page, "GOT IT", 400)
    page.wait_for_timeout(800)


def al20_save_raw() -> str:
    base = json.loads(SAVE_PATH.read_text(encoding="utf-8"))
    base["ascensionLevel"] = 20
    base["highestDungeonCleared"] = 14
    base["lifetimeGoldEarned"] = 9_999_999_999
    base["inDungeon"] = False
    base["inGauntlet"] = False
    base["bossVictories"] = max(base.get("bossVictories", 0), 15)
    base["dungeonId"] = "veil"
    md = dict(base.get("metaDepth") or {})
    md["pendingHeroReveals"] = []
    base["metaDepth"] = md
    base["seenTips"] = list(
        {
            *(base.get("seenTips") or []),
            "first_run",
            "lore_descent",
            "farm_push",
            "godhand",
            "bag",
            "sanctuary",
            "market",
            "forge",
            "pets",
            "contracts",
            "ascend",
            "post_ascend",
            "hardmode",
            "weekly",
            "apex",
            "gauntlet",
            "prestige",
        }
    )
    return json.dumps(base)


def inject_save(page) -> None:
    raw = al20_save_raw()
    page.evaluate(
        """(raw) => localStorage.setItem(
              'flutter.idle_party_save_v2',
              JSON.stringify(raw)
            )""",
        raw,
    )


def select_zone(page, zone_id: str) -> None:
    label = ZONE_PICK[zone_id]
    if not click_role(page, label, 900):
        # Selected node reads "HERE, selected" — try partial via bridge scan.
        for b in buttons(page):
            if zone_id in b.lower() or ZONE_PICK[zone_id].split(",")[0] in b:
                if click_role(page, b, 900):
                    return
        raise RuntimeError(f"could not pick {zone_id}: {label}")


def enter_dungeon(page) -> None:
    for label in ("ENTER DUNGEON", "ENTER", "ENTER KEY +20"):
        if click_role(page, label, 1600):
            break
    else:
        # TODAY "Meet …" blocks ENTER — ack via PARTY then retry.
        if click_role(page, "PARTY", 900):
            click_role(page, "CLOSE", 700)
        for label in ("ENTER DUNGEON", "ENTER", "ENTER KEY +20"):
            if click_role(page, label, 1600):
                break
        else:
            raise RuntimeError(f"no enter button: {buttons(page)[:10]}")
    page.evaluate(
        "() => window.__idlePartySetSpeed && window.__idlePartySetSpeed(6)"
    )
    page.wait_for_timeout(5500)
    if not any("FARM dungeon mode" in b for b in buttons(page)):
        raise RuntimeError(f"not in dungeon: {buttons(page)[:10]}")


def leave_dungeon(page) -> None:
    click_role(page, "HUB", 1400)
    page.wait_for_timeout(800)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()
        page.goto(URL, wait_until="domcontentloaded", timeout=90000)
        page.wait_for_timeout(1500)
        inject_save(page)
        page.reload(wait_until="domcontentloaded")
        boot_to_hub(page)

        for i, zone_id in enumerate(ZONES):
            print(f"capture {zone_id}…")
            select_zone(page, zone_id)
            enter_dungeon(page)
            out = OUT / f"{zone_id}.png"
            page.screenshot(path=str(out), type="png")
            print("  ->", out.name, out.stat().st_size)
            if i < len(ZONES) - 1:
                leave_dungeon(page)
        browser.close()
    print("done", OUT)


if __name__ == "__main__":
    main()
