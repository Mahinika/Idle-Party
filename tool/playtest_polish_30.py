"""~30 min AL20 exploratory polish playtest (360x780).

Injects max_unlock save, walks hub + KEY + GOLD + BAG + dungeon + wipe paths.
Writes notes + screenshots under tool/out/polish_30/.
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "polish_30"
SAVE = ROOT / "tool" / "out" / "max_unlock_save.json"
URL = "http://localhost:8085/"

# Wall-clock target for exploratory loop (seconds).
# Keep long enough to cover hub + several hunts; not a literal idle sit.
SESSION_SEC = 22 * 60


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : ''"
    )
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    text = str(raw or "").strip()
    if text:
        # Bridge may return "a | b" or a JSON-ish list string.
        if text.startswith("["):
            try:
                data = json.loads(text.replace("'", '"'))
                if isinstance(data, list):
                    return [str(x).strip() for x in data if str(x).strip()]
            except Exception:
                pass
        return [p.strip() for p in text.split(" | ") if p.strip()]
    return page.locator("flt-semantics[role=button]").all_text_contents()


def visible_text(page) -> str:
    try:
        return page.locator("flt-semantics").inner_text(timeout=2000)
    except Exception:
        return ""


def bridge(page, label: str, wait_ms: int = 700) -> bool:
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


def click_any(page, *names: str, wait_ms: int = 700) -> str | None:
    btns = buttons(page)
    for n in names:
        if n in btns and bridge(page, n, wait_ms):
            return n
        for b in btns:
            if n.lower() in b.lower() and bridge(page, b, wait_ms):
                return b
    return None


def shot(page, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUT / f"{name}.png"), full_page=True)


def note(notes: list[str], msg: str) -> None:
    notes.append(msg)
    print(msg)


def flag(findings: list[dict], severity: str, area: str, title: str, detail: str) -> None:
    findings.append(
        {"severity": severity, "area": area, "title": title, "detail": detail}
    )
    print(f"[{severity}] {area}: {title} — {detail}")


def wait_bridge(page, timeout_ms: int = 90000) -> bool:
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        ok = page.evaluate(
            "() => typeof window.__idlePartyClick === 'function' "
            "&& typeof window.__idlePartyButtons === 'function'"
        )
        if ok and buttons(page):
            return True
        page.wait_for_timeout(400)
    return False


def dismiss(page) -> None:
    for _ in range(14):
        btns = buttons(page)
        if "SKIP ALL TIPS" in btns:
            bridge(page, "SKIP ALL TIPS", 400)
            continue
        if any("what's new" in b.lower() for b in btns):
            click_any(page, "GOT IT", "CLOSE", wait_ms=400)
            continue
        if "MAYBE LATER" in btns:
            bridge(page, "MAYBE LATER", 400)
            continue
        if "GOT IT" in btns:
            bridge(page, "GOT IT", 300)
            continue
        if "SKIP" in btns:
            bridge(page, "SKIP", 500)
            continue
        break


def set_speed(page, n: int = 10) -> None:
    page.evaluate(
        "(s) => typeof window.__idlePartySetSpeed === 'function' "
        "&& window.__idlePartySetSpeed(s)",
        n,
    )


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
        inDungeon: s.inDungeon,
        dungeonId: s.dungeonId,
        floor: (s.currentRoom||{}).floorNumber,
        wiped: s.isPartyDefeated,
        keyActive: s.keystoneRunActive,
        keyLevel: s.keystoneRunLevel,
        keyTimer: s.keystoneTimerMs,
        wipeAdvice: s.wipeAdviceLine,
        bag: (s.gearStash||[]).length,
        vaultClaimed: md.dailyVaultClaimed,
        gauntlet: md.gauntletBestFloor,
        rift: md.riftBestTier,
        gr: md.grBestTier,
      };
    }"""
    )


def today_bits(page) -> dict:
    txt = visible_text(page)
    btns = buttons(page)
    return {
        "has_today": "TODAY" in txt.upper() or any("TODAY" in b.upper() for b in btns),
        "ready": "READY" in txt,
        "almost": "ALMOST" in txt,
        "boards": any("BOARDS" in b.upper() for b in btns),
        "enter_key": any("ENTER KEY" in b.upper() for b in btns),
        "enter_dungeon": any(
            b.upper() in ("ENTER DUNGEON", "ENTER") or "ENTER DUNGEON" in b.upper()
            for b in btns
        ),
        "gauntlet": any("GAUNTLET" in b.upper() for b in btns),
        "rift": any(b.upper() == "RIFT" or "GREATER RIFT" in b.upper() for b in btns),
        "ashen": any("ASHEN" in b.upper() for b in btns),
        "primary_candidates": [
            b
            for b in btns
            if any(
                k in b.upper()
                for k in (
                    "ENTER",
                    "KEY",
                    "GAUNTLET",
                    "RIFT",
                    "ASHEN",
                    "BOARDS",
                    "CLAIM",
                    "ASCEND",
                    "EQUIP",
                )
            )
        ][:12],
        "snippet": " | ".join(txt.splitlines()[:8])[:400],
    }


def boot_hub(page, raw: str) -> None:
    page.goto(URL, wait_until="domcontentloaded", timeout=120000)
    page.wait_for_timeout(1200)
    page.evaluate(
        """(raw) => localStorage.setItem(
              'flutter.idle_party_save_v2', JSON.stringify(raw))""",
        raw,
    )
    page.reload(wait_until="domcontentloaded")
    wait_bridge(page)
    page.wait_for_timeout(2000)
    click_any(page, "SKIP", "CONTINUE", wait_ms=900)
    click_any(page, "CONTINUE", wait_ms=1200)
    dismiss(page)
    page.wait_for_timeout(600)


def explore_hub(page, notes: list[str], findings: list[dict]) -> None:
    note(notes, "=== HUB ===")
    shot(page, "01_hub")
    bits = today_bits(page)
    note(notes, f"TODAY bits: {json.dumps(bits, ensure_ascii=True)}")
    if not bits["has_today"]:
        flag(findings, "high", "hub", "TODAY missing", bits["snippet"])
    # Soft rest / boards
    if "Done for today" in bits["snippet"] or bits["boards"]:
        if bits["enter_dungeon"] and not bits["boards"]:
            flag(
                findings,
                "high",
                "hub",
                "Done-for-today primary may still be ENTER",
                str(bits["primary_candidates"]),
            )
        else:
            note(notes, "OK: soft rest / BOARDS visible")
    # AL pill
    txt = visible_text(page)
    if "AL 20" in txt or "AL20" in txt:
        if "MAX" in txt and ("KEY" in txt or "Spire" in txt or "rest" in txt or "GR" in txt or "claim" in txt):
            note(notes, "OK: AL20 · MAX · hunt hint present")
        elif "MAX" in txt:
            flag(findings, "medium", "hub", "AL20 MAX without hunt hint", txt[:200])

    # Bottom bar tour
    for tab in ("GEAR", "GOLD", "SHOP", "ESSENCE", "MORE", "KEY"):
        hit = click_any(page, tab, wait_ms=900)
        note(notes, f"open {tab}: {hit}")
        shot(page, f"02_tab_{tab.lower()}")
        t = visible_text(page)
        b = buttons(page)
        if tab == "GEAR":
            # BAG / EQUIP path
            click_any(page, "BAG", wait_ms=700)
            shot(page, "02_bag")
            bb = buttons(page)
            equip_btns = [x for x in bb if "EQUIP" in x.upper()]
            note(notes, f"BAG equip buttons: {equip_btns}")
            if any(x.upper() == "AUTO EQUIP" for x in equip_btns) and any(
                x.upper().startswith("EQUIP ") for x in equip_btns
            ):
                flag(
                    findings,
                    "medium",
                    "bag",
                    "AUTO EQUIP and EQUIP N both visible",
                    str(equip_btns),
                )
            if "Scrap" in t or "Sell junk" in t or "LOADOUTS" in t:
                flag(findings, "high", "bag", "Dead chrome still visible", t[:240])
            click_any(page, "GEAR", wait_ms=500)
        if tab == "GOLD":
            click_any(page, "MARKET", "Market", "Shop", wait_ms=700)
            shot(page, "02_market")
            mt = visible_text(page)
            if "UPGRADE" in mt:
                note(notes, "OK: MARKET UPGRADE badge/text present")
            else:
                flag(
                    findings,
                    "low",
                    "market",
                    "No UPGRADE label on current listings",
                    mt[:200],
                )
            # POWER tracks
            if "ATK" in mt or "DEF" in mt or "STA" in mt or "POWER" in mt:
                note(notes, "OK: GOLD tracks / POWER language visible")
            click_any(page, "TRACKS", "Gold", wait_ms=500)
        if tab == "SHOP":
            if "Coming later" in t or "coming later" in t.lower():
                note(notes, "OK: SHOP Coming later honesty")
            else:
                flag(findings, "medium", "shop", "SHOP may look buyable", t[:200])
        if tab == "MORE":
            for sub in ("WHAT'S NEW", "WHATS NEW", "GUIDE", "QUESTS", "SETTINGS"):
                if click_any(page, sub, wait_ms=700):
                    shot(page, f"02_more_{sub.replace(' ', '_').replace(chr(39), '')[:20]}")
                    st = visible_text(page)
                    if "WHAT" in sub.upper() and "1.12.98" not in st and "1.12." in st:
                        flag(
                            findings,
                            "medium",
                            "whatsnew",
                            "Version on screen may not be 1.12.98",
                            st[:240],
                        )
                    if "GUIDE" in sub.upper() and "lifetime gold" in st.lower():
                        flag(
                            findings,
                            "high",
                            "guides",
                            "WORLD PATH still says lifetime gold",
                            st[:240],
                        )
            click_any(page, "CLOSE", "GOT IT", wait_ms=400)
        if tab == "KEY":
            note(notes, f"KEY buttons: {[x for x in b if len(x) < 40][:20]}")
            if "Affix" in t or "affix" in t.lower() or "Tyrannical" in t or "Fortified" in t:
                note(notes, "OK: KEY affix chrome present")
        # Close sheets
        click_any(page, "CLOSE", wait_ms=400)
        # tap hub empty / leave sheet by toggling same tab
        click_any(page, tab, wait_ms=400)

    dismiss(page)
    shot(page, "03_hub_after_menus")


def explore_dungeon(page, notes: list[str], findings: list[dict], tag: str) -> None:
    note(notes, f"=== DUNGEON ({tag}) ===")
    set_speed(page, 10)
    dismiss(page)
    shot(page, f"10_{tag}_enter")
    btns = buttons(page)
    txt = visible_text(page)
    note(notes, f"dungeon buttons: {[b for b in btns if len(b) < 45][:25]}")
    # God Hand / KEY timer presence
    if any("God Hand" in b or "Tap the fight" in b for b in btns):
        note(notes, "OK: God Hand semantics present")
    else:
        flag(findings, "medium", "dungeon", "God Hand label missing", str(btns[:15]))
    if "KEY +" in txt or "KEY +" in " ".join(btns):
        # timer chip is pixel text — may not be in semantics
        note(notes, "OK: KEY level mentioned in dungeon chrome")
    # FARM/PUSH
    if "FARM" in btns or "PUSH" in btns:
        note(notes, "OK: FARM/PUSH chips present")
    # Party kit
    party = [b for b in btns if any(x in b.upper() for x in ("PROT", "DISC", "FIRE", "COM", "BM", "L1"))]
    note(notes, f"party-ish buttons: {party[:10]}")

    # Fight for a while
    deadline = time.time() + 90
    last_floor = None
    while time.time() < deadline:
        s = save_summary(page) or {}
        if s.get("wiped"):
            note(notes, f"WIPED advice={s.get('wipeAdvice')}")
            shot(page, f"11_{tag}_wipe")
            advice = s.get("wipeAdvice") or ""
            if advice:
                if "FORGE" in advice and "POWER" not in advice:
                    flag(findings, "high", "wipe", "Wipe tip still says FORGE", advice)
                if "POWER" in advice:
                    note(notes, "OK: wipe tip uses POWER")
                # OPEN POWER / OPEN BAG CTA
                wb = buttons(page)
                if any("OPEN POWER" in b or "OPEN BAG" in b or "OPEN GOLD" in b for b in wb):
                    note(notes, f"OK: wipe CTA { [b for b in wb if 'OPEN' in b] }")
            else:
                flag(findings, "medium", "wipe", "Wipe with empty advice", str(s))
            click_any(page, "RETRY", "Retry", wait_ms=800)
            break
        floor = s.get("floor")
        if floor != last_floor and floor is not None:
            note(notes, f"floor {floor} gold={s.get('gold')} bag={s.get('bag')}")
            last_floor = floor
            shot(page, f"12_{tag}_f{floor}")
        # clear banner / stairs
        if "stairs" in visible_text(page).lower() or "CLEAR" in visible_text(page):
            shot(page, f"13_{tag}_clear")
            note(notes, "clear/stairs state seen")
        # occasional God Hand
        click_any(page, "God Hand ready", "Tap the fight — steer your party smash", wait_ms=200)
        page.wait_for_timeout(800)

    # Leave dialog copy
    if click_any(page, "LEAVE", wait_ms=600):
        shot(page, f"14_{tag}_leave_dialog")
        lt = visible_text(page)
        note(notes, f"LEAVE dialog: {lt[:280]}")
        if "fight progress is lost" in lt and "clear" in lt.lower():
            pass
        if "Floor is clear" in lt or "already clear" in lt or "stairs ready" in lt:
            note(notes, "OK: LEAVE knows floor is clear")
        click_any(page, "STAY", "RETURN", wait_ms=600)
        # if still in dialog, stay
        click_any(page, "STAY", wait_ms=400)
        if save_summary(page).get("inDungeon"):
            # force leave
            click_any(page, "LEAVE", wait_ms=500)
            click_any(page, "RETURN", wait_ms=800)
    dismiss(page)
    shot(page, f"15_{tag}_back")


def try_enter(page, notes: list[str], *labels: str) -> bool:
    hit = click_any(page, *labels, wait_ms=1000)
    note(notes, f"enter attempt {labels} -> {hit}")
    if hit is None:
        return False
    # confirm dialogs
    for _ in range(4):
        if click_any(page, "ENTER", "CONFIRM", "YES", "START", wait_ms=700):
            continue
        break
    dismiss(page)
    page.wait_for_timeout(800)
    return bool(save_summary(page).get("inDungeon"))


def main() -> int:
    if not SAVE.is_file():
        print("missing", SAVE)
        return 1
    raw = SAVE.read_text(encoding="utf-8")
    notes: list[str] = []
    findings: list[dict] = []
    t0 = time.time()

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()
        boot_hub(page, raw)
        note(notes, f"save after boot: {save_summary(page)}")
        explore_hub(page, notes, findings)

        # Primary chase enter
        bits = today_bits(page)
        entered = False
        for label in bits["primary_candidates"] + [
            "ENTER KEY +20",
            "ENTER KEY +1",
            "ENTER KEY",
            "GAUNTLET",
            "GREATER RIFT",
            "RIFT",
            "ASHEN CROWN",
            "ENTER DUNGEON",
        ]:
            if try_enter(page, notes, label):
                entered = True
                explore_dungeon(page, notes, findings, "chase")
                break

        if not entered:
            flag(findings, "high", "hub", "Could not enter any chase/dungeon", str(bits))
            # fallback zone enter
            if try_enter(page, notes, "ENTER DUNGEON"):
                explore_dungeon(page, notes, findings, "fallback")

        # KEY dial path
        dismiss(page)
        if click_any(page, "KEY", wait_ms=800):
            shot(page, "20_key_sheet")
            # try set dial / enter key
            click_any(page, "+", "＋", wait_ms=300)
            if try_enter(page, notes, "ENTER KEY", "RUN KEY", "START KEY"):
                explore_dungeon(page, notes, findings, "key")
            click_any(page, "CLOSE", "KEY", wait_ms=400)

        # Gauntlet / Rift from KEY or hub
        for hunt in ("GAUNTLET", "GREATER RIFT", "RIFT", "ASHEN CROWN", "PRACTICE"):
            dismiss(page)
            if time.time() - t0 > SESSION_SEC:
                break
            if try_enter(page, notes, hunt):
                explore_dungeon(page, notes, findings, hunt.lower().replace(" ", "_")[:12])

        # Offline welcome: can't easily fake offline in web without director API —
        # check Up next contract via save inject of offline summary is out of scope.
        # Spend remaining time poking GEAR/GOLD again and a short farm.
        while time.time() - t0 < SESSION_SEC:
            dismiss(page)
            if not save_summary(page).get("inDungeon"):
                if try_enter(page, notes, "ENTER DUNGEON", "ENTER KEY"):
                    explore_dungeon(page, notes, findings, "loop")
                else:
                    click_any(page, "GEAR", "GOLD", "MORE", wait_ms=600)
                    click_any(page, "CLOSE", wait_ms=400)
                    page.wait_for_timeout(1500)
            else:
                page.wait_for_timeout(2000)
                if time.time() - t0 > SESSION_SEC - 30:
                    click_any(page, "LEAVE", wait_ms=400)
                    click_any(page, "RETURN", wait_ms=600)

        shot(page, "99_end")
        note(notes, f"final save: {save_summary(page)}")
        browser.close()

    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "elapsed_sec": round(time.time() - t0, 1),
        "findings": findings,
        "notes": notes,
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    lines = [
        f"# Polish playtest — {report['elapsed_sec']}s",
        "",
        f"Findings: {len(findings)}",
        "",
    ]
    for f in findings:
        lines.append(f"- **{f['severity'].upper()}** · {f['area']} · {f['title']}: {f['detail']}")
    lines.append("")
    lines.append("## Log")
    lines.extend(f"- {n}" for n in notes)
    (OUT / "NOTES.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT / 'NOTES.md'} findings={len(findings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
