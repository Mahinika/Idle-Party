"""Play Idle Party web to AL3 with 10x combat speed; log hub/dungeon observations."""
from __future__ import annotations

import json
import os
import time
from playwright.sync_api import sync_playwright

OUT = "tool/out/playtest_al3"
os.makedirs(OUT, exist_ok=True)
log: list[dict] = []


def safe(s: object) -> str:
    return str(s).encode("ascii", "replace").decode("ascii")


def buttons(page) -> list[str]:
    return page.locator("flt-semantics[role=button]").all_text_contents()


def click_btn(page, name: str, wait_ms: int = 500) -> None:
    loc = page.get_by_role("button", name=name, exact=True)
    if loc.count() == 0:
        loc = page.get_by_role("button", name=name)
    box = loc.first.bounding_box()
    if not box:
        raise RuntimeError("no box " + name)
    if loc.first.evaluate("el => el.getAttribute('aria-disabled')") == "true":
        raise RuntimeError("disabled " + name)
    page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2, delay=40)
    page.wait_for_timeout(wait_ms)


def try_click(page, name: str, wait_ms: int = 400) -> bool:
    try:
        click_btn(page, name, wait_ms=wait_ms)
        return True
    except Exception:
        return False


def bridge_click(page, label: str) -> bool:
    return bool(
        page.evaluate(
            """(label) => {
              if (typeof window.__idlePartyClick !== 'function') return false;
              return !!window.__idlePartyClick(label);
            }""",
            label,
        )
    )


def save_summary(page):
    return page.evaluate(
        """() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const room = s.currentRoom || {};
      const md = s.metaDepth || {};
      return {
        al: s.ascensionLevel,
        inDungeon: s.inDungeon,
        gold: s.gold,
        essence: s.essence,
        bosses: s.bossVictories,
        bag: (s.gearStash || []).length,
        floor: room.floorNumber,
        roomType: room.type,
        dungeonId: s.dungeonId,
        dungeonMode: s.dungeonMode,
        lifetimeGold: s.lifetimeGoldEarned,
        highestCleared: s.highestDungeonCleared,
        weeklyModifier: md.weeklyModifier,
        dailyVaultClears: md.dailyVaultClears,
        dailyVaultClaimed: md.dailyVaultClaimed,
        titles: (md.titles || []).slice(0, 8),
        heroes: (s.heroes || []).map(h => ({
          id: h.id || h.classId || h.specId,
          lv: h.level,
          hp: h.hp,
          max: h.maxHp
        }))
      };
    }"""
    )


def dismiss_tips(page) -> None:
    for _ in range(12):
        btns = buttons(page)
        if "SKIP ALL TIPS" in btns and bridge_click(page, "SKIP ALL TIPS"):
            page.wait_for_timeout(400)
            continue
        if "GOT IT" in btns and bridge_click(page, "GOT IT"):
            page.wait_for_timeout(300)
            continue
        break


def ensure_hub(page) -> None:
    dismiss_tips(page)
    btns = buttons(page)
    if any("LEAVE" in b.upper() for b in btns) or any("RETURN" in b.upper() for b in btns):
        for label in btns:
            if "LEAVE" in label.upper() or "RETURN TO HUB" in label.upper() or label.upper() == "HUB":
                bridge_click(page, label)
                page.wait_for_timeout(800)
                break
    dismiss_tips(page)


def has_hub_menu_label(btns: list[str], label: str) -> bool:
    """True when MORE sheet (not Guides) exposes [label]."""
    for b in btns:
        if b.startswith("Guide"):
            continue
        if b == label or b.startswith(f"{label} ") or b.startswith(f"{label}\n") or b.startswith(f"{label} ("):
            return True
    return False


def explore_hub_menus(page) -> dict:
    notes: dict[str, object] = {"menus": []}
    ensure_hub(page)
    bridge_click(page, "MORE")
    page.wait_for_timeout(700)
    more_btns = [safe(b) for b in buttons(page)]
    notes["moreButtons"] = more_btns
    notes["moreTitleOk"] = any(b == "MORE" or b.startswith("MORE") for b in more_btns) and "HUB" not in more_btns[:3]
    page.screenshot(path=f"{OUT}/more.png")

    for label in ["GUIDES", "CONTRACTS", "FORGE", "PARTY", "BAG", "SANCTUARY", "MARKET", "ACHIEVEMENTS", "CODEX"]:
        if not has_hub_menu_label(buttons(page), label):
            # reopen MORE if closed
            if any(b == "MORE" or b.startswith("MORE") for b in buttons(page)):
                bridge_click(page, "MORE")
                page.wait_for_timeout(500)
        if has_hub_menu_label(buttons(page), label):
            ok = bridge_click(page, label) or try_click(page, label)
            page.wait_for_timeout(700)
            page.screenshot(path=f"{OUT}/menu_{label.lower().replace(' ', '_')}.png")
            notes["menus"].append({"label": label, "opened": ok, "buttons": [safe(b) for b in buttons(page)[:20]]})
            # Close overlay / sheet before next MORE item (avoids Guide · FOO hits).
            for close in ["CLOSE", "BACK", "DONE", "GOT IT", "NICE", "HUB"]:
                if any(close == b or b.startswith(close) for b in buttons(page)):
                    bridge_click(page, close) or try_click(page, close)
                    page.wait_for_timeout(400)
            # Re-open MORE sheet from hub for the next label.
            if "MORE" in buttons(page) or any(b.startswith("MORE") for b in buttons(page)):
                pass
            elif "ENTER DUNGEON" in buttons(page):
                bridge_click(page, "MORE")
                page.wait_for_timeout(500)
            if "CLOSE" in buttons(page) and label != "GUIDES":
                # Still in an overlay — leave hub meta shell.
                bridge_click(page, "CLOSE")
                page.wait_for_timeout(400)
                if "MORE" in buttons(page) or any(b.startswith("MORE") for b in buttons(page)):
                    bridge_click(page, "MORE")
                    page.wait_for_timeout(500)
    if "CLOSE" in buttons(page):
        bridge_click(page, "CLOSE")
        page.wait_for_timeout(400)
    notes["hubAfterMenus"] = [safe(b) for b in buttons(page)[:25]]
    notes["save"] = save_summary(page)
    return notes


with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 390, "height": 844})  # phone-ish
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=30000)

    # Fresh run
    bridge_click(page, "NEW GAME")
    page.wait_for_timeout(1000)
    bridge_click(page, "START")
    page.wait_for_timeout(1000)
    if "OVERWRITE" in buttons(page):
        bridge_click(page, "OVERWRITE")
        page.wait_for_timeout(1200)
    dismiss_tips(page)
    page.screenshot(path=f"{OUT}/hub_start.png")

    # Speed up combat
    speed = page.evaluate(
        """() => {
          if (typeof window.__idlePartySetSpeed === 'function') return window.__idlePartySetSpeed(10);
          return null;
        }"""
    )
    log.append({"event": "speed", "value": speed})

    hub_notes = explore_hub_menus(page)
    with open(f"{OUT}/hub_explore.json", "w", encoding="utf-8") as f:
        json.dump(hub_notes, f, indent=2)
    print("HUB_EXPLORE", safe(hub_notes.get("menus")))

    # Enter dungeon PUSH
    ensure_hub(page)
    bridge_click(page, "ENTER DUNGEON")
    page.wait_for_timeout(1500)
    dismiss_tips(page)
    bridge_click(page, "PUSH dungeon mode") or try_click(page, "PUSH dungeon mode")
    page.wait_for_timeout(500)

    t0 = time.time()
    last_al = 0
    last_bosses = 0
    max_loops = 240  # ~20 min @ 5s
    for i in range(max_loops):
        page.wait_for_timeout(5000)
        s = save_summary(page)
        btns = buttons(page)
        entry = {
            "i": i,
            "t": int(time.time() - t0),
            "save": s,
            "hasAscend": any("ASCEND" in b.upper() for b in btns),
            "btnSample": [safe(b) for b in btns[:16]],
        }
        log.append(entry)
        print(safe(entry))

        if i % 8 == 0:
            page.screenshot(path=f"{OUT}/t{entry['t']:04d}.png")

        if s and s.get("bosses", 0) > last_bosses:
            last_bosses = s["bosses"]
            page.screenshot(path=f"{OUT}/boss_al{s.get('al')}_b{last_bosses}.png")
            print("BOSS", last_bosses, "AL", s.get("al"))

        # Wipe / clear overlays
        dismiss_tips(page)
        if any("RETRY" in b.upper() for b in btns):
            for b in btns:
                if "RETRY" in b.upper():
                    bridge_click(page, b)
                    page.wait_for_timeout(1200)
                    dismiss_tips(page)
                    bridge_click(page, "PUSH dungeon mode") or try_click(page, "PUSH dungeon mode")
                    break
            continue
        if any("RETURN TO HUB" in b.upper() for b in btns):
            bridge_click(page, "RETURN TO HUB")
            page.wait_for_timeout(1000)
            continue

        # Claim vault / jobs if on hub
        if s and not s.get("inDungeon"):
            for claim in ["CLAIM VAULT", "CLAIM JOBS", "CLAIM (1)", "CLAIM (2)", "CLAIM (3)"]:
                if any(claim in b for b in btns):
                    bridge_click(page, claim)
                    page.wait_for_timeout(600)

            # Ascend when ready
            ascend_labels = [b for b in btns if "ASCEND" in b.upper()]
            if ascend_labels:
                page.screenshot(path=f"{OUT}/ascend_ready_al{s.get('al')}.png")
                label = ascend_labels[0]
                bridge_click(page, label) or try_click(page, label)
                page.wait_for_timeout(800)
                # confirm dialog
                for conf in ["ASCEND", "CONFIRM", "YES", "DO IT"]:
                    if conf in buttons(page) or any(conf == b for b in buttons(page)):
                        bridge_click(page, conf)
                        page.wait_for_timeout(1000)
                dismiss_tips(page)
                s2 = save_summary(page)
                if s2 and (s2.get("al") or 0) > last_al:
                    last_al = s2["al"]
                    last_bosses = 0
                    page.screenshot(path=f"{OUT}/ascended_al{last_al}.png")
                    print("ASCENDED TO", last_al, flush=True)
                    if last_al >= 3:
                        break
                # spend a bit of gold/essence if forge available — skip for speed
                if "ENTER DUNGEON" in buttons(page):
                    bridge_click(page, "ENTER DUNGEON")
                    page.wait_for_timeout(1200)
                    dismiss_tips(page)
                    bridge_click(page, "PUSH dungeon mode") or try_click(page, "PUSH dungeon mode")
            elif "ENTER DUNGEON" in buttons(page):
                bridge_click(page, "ENTER DUNGEON")
                page.wait_for_timeout(1200)
                dismiss_tips(page)
                bridge_click(page, "PUSH dungeon mode") or try_click(page, "PUSH dungeon mode")

        # God Hand / flask occasional
        if any("God Hand ready" in b for b in btns):
            bridge_click(page, "God Hand ready")
        if any("Use healing flask" in b for b in btns):
            if i % 8 == 0:
                bridge_click(page, "Use healing flask")

        if s and (s.get("al") or 0) >= 3:
            break

    final = save_summary(page)
    page.screenshot(path=f"{OUT}/final.png")
    with open(f"{OUT}/log.json", "w", encoding="utf-8") as f:
        json.dump({"final": final, "log": log}, f, indent=2)
    print("FINAL", safe(final))
    browser.close()
