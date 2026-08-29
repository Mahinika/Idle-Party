"""Long exploratory playtest (360x780) — find bugs / jargon / UX friction.

New save → hub menus → several dungeon floors @10x → leave → more hub poking.
Writes notes + screenshots under tool/out/long_session/.
"""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "long_session"
URL = "http://localhost:8085/"

# Words a brand-new player might not understand in the first hour
JARGON = re.compile(
    r"\b(AL\d+|KEY\+?\d*|Gauntlet|Rift|Ascend|Blessing|Apex|God Hand|"
    r"FORGE|KEEP|Essence|\+\d+e\b|Mythic|Will of|KEYSTONE|REBORN|"
    r"WotLK|ilvl|iLvl|affix)\b",
    re.I,
)


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : ''"
    )
    text = str(raw or "").strip()
    if text:
        return [p.strip() for p in text.split(" | ") if p.strip()]
    return page.locator("flt-semantics[role=button]").all_text_contents()


def visible_text(page) -> str:
    try:
        return page.locator("flt-semantics").inner_text(timeout=2000)
    except Exception:
        return ""


def bridge(page, label: str, wait_ms: int = 800) -> bool:
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


def mouse_click(page, name: str, wait_ms: int = 800) -> bool:
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


def click_any(page, *names: str, wait_ms: int = 800) -> str | None:
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


def flag(findings: list[dict], severity: str, area: str, title: str, detail: str) -> None:
    findings.append(
        {
            "severity": severity,
            "area": area,
            "title": title,
            "detail": detail,
        }
    )
    print(f"[{severity}] {area}: {title} — {detail}".encode("ascii", "replace").decode("ascii"))


def scan_jargon(findings: list[dict], area: str, text: str, btns: list[str]) -> None:
    blob = text + "\n" + "\n".join(btns)
    hits = sorted(set(JARGON.findall(blob)))
    if hits:
        flag(
            findings,
            "medium",
            area,
            "Possible first-hour jargon",
            ", ".join(hits[:12]),
        )


def dismiss(page, notes: list[str], findings: list[dict], tag: str) -> None:
    for i in range(16):
        btns = buttons(page)
        txt = visible_text(page)
        if "SKIP ALL TIPS" in btns:
            shot(page, f"{tag}_tip_{i}")
            tip_btns = [b for b in btns if len(b) < 70][:18]
            log(notes, f"[{tag}] tip: {tip_btns}")
            scan_jargon(findings, f"tip/{tag}", txt, tip_btns)
            if i == 0 and "GOT IT" in btns:
                click_any(page, "GOT IT", wait_ms=600)
            else:
                click_any(page, "SKIP ALL TIPS", wait_ms=600)
            continue
        if any("What's New" in b or "WHATS NEW" in b.upper() for b in btns):
            shot(page, f"{tag}_whatsnew_{i}")
            click_any(page, "GOT IT", "CLOSE", wait_ms=500)
            continue
        if "MAYBE LATER" in btns:
            shot(page, f"{tag}_discord_{i}")
            # Discord should not sit on top of first tip
            if "SKIP ALL TIPS" in btns or "GOT IT" in btns:
                flag(
                    findings,
                    "high",
                    "hub",
                    "Discord over tips",
                    "MAYBE LATER visible while tip buttons still present",
                )
            click_any(page, "MAYBE LATER", wait_ms=500)
            continue
        if "GOT IT" in btns:
            shot(page, f"{tag}_gotit_{i}")
            log(notes, f"[{tag}] GOT IT: {[b for b in btns if len(b) < 60][:12]}")
            click_any(page, "GOT IT", wait_ms=500)
            continue
        break


def wait_bridge(page, timeout_ms: int = 90000) -> bool:
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        ok = page.evaluate(
            "() => typeof window.__idlePartyClick === 'function' "
            "&& typeof window.__idlePartyButtons === 'function'"
        )
        if ok:
            btns = buttons(page)
            if btns:
                return True
        page.wait_for_timeout(500)
    return False


def set_speed(page, n: int = 10) -> None:
    page.evaluate(
        "(s) => typeof window.__idlePartySetSpeed === 'function' "
        "&& window.__idlePartySetSpeed(s)",
        n,
    )


def explore_menu(page, notes: list[dict] | list[str], findings: list[dict], pillar: str) -> None:
    shot(page, f"menu_{pillar.lower()}_open")
    btns = buttons(page)
    txt = visible_text(page)
    log(notes, f"[{pillar}] buttons: {[b for b in btns if len(b) < 55][:30]}")
    scan_jargon(findings, f"menu/{pillar}", txt, btns)

    # Duplicate labels (e.g. Gold upgrades GOLD)
    lower = [b.lower() for b in btns]
    for b in btns:
        parts = b.split()
        if len(parts) >= 2 and parts[-1].upper() == parts[-1] and parts[-1].lower() in b.lower()[:-len(parts[-1])]:
            # crude: ends with uppercase token that already appears earlier
            last = parts[-1]
            if last.isupper() and last.lower() in " ".join(parts[:-1]).lower():
                flag(
                    findings,
                    "low",
                    f"menu/{pillar}",
                    "Duplicate scope tag on tab",
                    b,
                )

    # Tap a few inner tabs if present
    for tab in (
        "Gold upgrades",
        "Buy supplies",
        "BAG",
        "GEAR",
        "ROSTER",
        "GUIDE",
        "SETTINGS",
        "QUESTS",
        "CODEX",
        "WHAT'S NEW",
        "WHATS NEW",
        "BASICS",
        "PARTY",
        "WORLD PATH",
    ):
        if any(tab.lower() == b.lower() or tab.lower() in b.lower() for b in btns):
            # exact match preferred
            exact = next((b for b in btns if b.upper() == tab.upper()), None)
            if exact and mouse_click(page, exact, 700):
                shot(page, f"menu_{pillar.lower()}_{exact.replace(' ', '_')[:24]}")
                scan_jargon(
                    findings,
                    f"menu/{pillar}/{exact}",
                    visible_text(page),
                    buttons(page),
                )
                break

    click_any(page, "CLOSE", "BACK", "DONE", wait_ms=500)
    # If still open, tap pillar again to toggle
    if pillar in buttons(page) and "ENTER DUNGEON" not in buttons(page):
        mouse_click(page, pillar, 600)


def dungeon_loop(page, notes: list[str], findings: list[dict], floors: int = 4) -> None:
    set_speed(page, 10)
    for f in range(floors):
        tag = f"dungeon_f{f}"
        t0 = time.time()
        cleared = False
        while time.time() - t0 < 90:
            btns = buttons(page)
            txt = visible_text(page)
            if f == 0 and time.time() - t0 < 3:
                shot(page, f"{tag}_start")
                scan_jargon(findings, "dungeon/start", txt, btns)
                # Fist label check
                fistish = [b for b in btns if "fight" in b.lower() or "god hand" in b.lower()]
                log(notes, f"[{tag}] fist-ish: {fistish[:6]}")
                if any("God Hand" in b for b in fistish) and not any(
                    "Tap the fight" in b for b in fistish
                ):
                    flag(
                        findings,
                        "high",
                        "dungeon",
                        "Fist still says God Hand",
                        str(fistish[:4]),
                    )

            # Tips / wipe / door overlays
            if "SKIP ALL TIPS" in btns or "GOT IT" in btns:
                dismiss(page, notes, findings, tag)
                continue
            if any(x in btns for x in ("LEAVE TO HUB", "LEAVE", "STAY", "GO BACK")):
                # leave confirm mid-run — don't leave yet unless stuck
                pass

            # Prefer PUSH once, else FARM
            if f == 0:
                click_any(page, "PUSH", "CLIMB PUSH", "FARM", "LOOP FARM", wait_ms=400)

            # God Hand / Tap the fight when ready
            ready = next(
                (
                    b
                    for b in btns
                    if "Tap the fight" in b
                    or b == "God Hand ready"
                    or (b.startswith("God Hand") and "cooling" not in b.lower())
                ),
                None,
            )
            if ready:
                mouse_click(page, ready, 200)

            # Flask if low
            flask = next((b for b in btns if "flask" in b.lower() or "heal" in b.lower()), None)
            if flask and "empty" not in flask.lower():
                # occasional use
                if int(time.time()) % 7 == 0:
                    mouse_click(page, flask, 200)

            # Floor advance signals
            if any(
                x in " ".join(btns).lower()
                for x in ("next floor", "stairs", "continue", "enter next")
            ):
                click_any(
                    page,
                    "NEXT FLOOR",
                    "CONTINUE",
                    "ENTER",
                    "GO",
                    wait_ms=600,
                )

            # Hub return = left dungeon
            if "ENTER DUNGEON" in btns:
                flag(
                    findings,
                    "medium",
                    "dungeon",
                    "Kicked to hub mid-loop",
                    f"during floor pass {f}",
                )
                return

            # Wipe panel
            if any("wipe" in b.lower() for b in btns) or "TOO WEAK" in " ".join(btns).upper():
                shot(page, f"{tag}_wipe")
                log(notes, f"[{tag}] wipe-ish: {[b for b in btns if len(b) < 50][:16]}")
                scan_jargon(findings, "dungeon/wipe", txt, btns)
                # Prefer POWER redirect over jargon FORGE
                if any("FORGE" in b and "POWER" not in b for b in btns):
                    flag(
                        findings,
                        "medium",
                        "dungeon/wipe",
                        "Wipe advice still says FORGE",
                        str([b for b in btns if "FORGE" in b][:4]),
                    )
                click_any(page, "GOT IT", "CLOSE", "RETRY", "CONTINUE", wait_ms=600)

            # Detect floor clear by looking for hub leave availability and time spent
            # Heuristic: after enough time, try LEAVE to check progress once
            page.wait_for_timeout(800)

            # If we see "Floor N" climb in text, note progress
            m = re.search(r"Floor\s+(\d+)", txt, re.I)
            if m and int(m.group(1)) > f + 1:
                cleared = True
                log(notes, f"[{tag}] advanced to floor {m.group(1)}")
                break

        if not cleared:
            log(notes, f"[{tag}] timeout or slow clear after {int(time.time()-t0)}s")
            shot(page, f"{tag}_timeout")

    # Leave dungeon
    set_speed(page, 1)
    shot(page, "dungeon_before_leave")
    if click_any(page, "LEAVE", wait_ms=700):
        shot(page, "dungeon_leave_dialog")
        leave_btns = buttons(page)
        leave_txt = visible_text(page)
        log(notes, f"[leave] {leave_btns[:20]}")
        scan_jargon(findings, "dungeon/leave", leave_txt, leave_btns)
        if any("sanctuary" in b.lower() for b in leave_btns) or "sanctuary" in leave_txt.lower():
            flag(
                findings,
                "low",
                "dungeon/leave",
                "Leave dialog uses sanctuary jargon",
                leave_txt[:120],
            )
        click_any(
            page,
            "LEAVE TO HUB",
            "YES",
            "LEAVE",
            "CONFIRM",
            wait_ms=900,
        )
        # confirm overwrite style
        click_any(page, "LEAVE TO HUB", "YES", "LEAVE", wait_ms=600)


def main() -> int:
    notes: list[str] = []
    findings: list[dict] = []
    OUT.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_context(
            viewport={"width": 360, "height": 780},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        ).new_page()
        page.goto(URL, wait_until="domcontentloaded", timeout=120000)
        page.wait_for_timeout(1500)
        page.evaluate("() => localStorage.clear()")
        page.reload(wait_until="networkidle", timeout=120000)
        if not wait_bridge(page):
            log(notes, "FAIL: bridge never ready")
            (OUT / "notes.json").write_text(
                json.dumps({"notes": notes, "findings": findings}, indent=2),
                encoding="utf-8",
            )
            return 1
        page.wait_for_timeout(2000)

        # Version probe via What's New later; note boot
        shot(page, "01_boot")
        log(notes, f"boot: {buttons(page)[:14]}")
        click_any(page, "SKIP", wait_ms=900)
        page.wait_for_timeout(600)
        shot(page, "02_title")
        title_btns = buttons(page)
        log(notes, f"title: {title_btns[:14]}")
        if "CONTINUE" in title_btns and "NEW GAME" in title_btns:
            # Fresh localStorage should disable CONTINUE — if enabled, note it
            pass

        click_any(page, "NEW GAME", wait_ms=1400)
        click_any(page, "OVERWRITE", "START OVER", wait_ms=700)
        page.wait_for_timeout(900)
        shot(page, "03_after_newgame")
        ng_btns = buttons(page)
        log(notes, f"after NEW GAME: {ng_btns[:30]}")

        # Spec picker (may be skipped if flow already landed in hub)
        if "ENTER DUNGEON" not in ng_btns and "SKIP ALL TIPS" not in ng_btns:
            scan_jargon(findings, "picker", visible_text(page), ng_btns)
            for label in (
                "Shield",
                "Healer",
                "Damage",
                "Warrior",
                "Protection",
                "PROT",
                "Priest",
                "Discipline",
                "DISC",
                "Mage",
                "Fire",
                "FIRE",
            ):
                mouse_click(page, label, 400)
            shot(page, "04_picker_filled")
            if not click_any(page, "START", "BEGIN", "LET'S GO", wait_ms=1200):
                flag(
                    findings,
                    "high",
                    "picker",
                    "Could not start new game",
                    str(ng_btns[:20]),
                )
                browser.close()
                (OUT / "notes.json").write_text(
                    json.dumps({"notes": notes, "findings": findings}, indent=2),
                    encoding="utf-8",
                )
                return 1
            page.wait_for_timeout(1000)
        else:
            log(notes, "picker skipped — already in hub/tips after NEW GAME")

        dismiss(page, notes, findings, "hub_boot")
        shot(page, "05_hub")
        hub_btns = buttons(page)
        hub_txt = visible_text(page)
        log(notes, f"hub: {hub_btns[:28]}")
        scan_jargon(findings, "hub", hub_txt, hub_btns)

        # TODAY expectations
        if "CLAIM VAULT" in hub_btns or "CLAIM QUESTS" in hub_btns:
            flag(
                findings,
                "high",
                "hub/TODAY",
                "Claim CTA before first boss",
                str([b for b in hub_btns if "CLAIM" in b]),
            )
        if any("Ascend" in b for b in hub_btns) and "Boss" not in hub_txt:
            # may be ok if not TODAY
            pass
        if "POWERUPS" in hub_btns:
            flag(
                findings,
                "high",
                "hub",
                "POWERUPS visible first hour",
                "should hide until first boss",
            )

        # Explore hub pillars
        for pillar in ("PARTY", "POWER", "META"):
            if pillar in buttons(page) or any(pillar in b for b in buttons(page)):
                label = next((b for b in buttons(page) if b.startswith(pillar)), pillar)
                if mouse_click(page, label, 900):
                    explore_menu(page, notes, findings, pillar)
                    dismiss(page, notes, findings, f"after_{pillar}")
                    # ensure back on hub
                    if "ENTER DUNGEON" not in buttons(page):
                        click_any(page, "CLOSE", "BACK", wait_ms=500)
                        if "ENTER DUNGEON" not in buttons(page):
                            click_any(page, label, wait_ms=500)

        shot(page, "06_hub_after_menus")
        hub2 = buttons(page)
        log(notes, f"hub after menus: {hub2[:24]}")

        # World map / other areas
        for label in ("Other areas", "Other areas ▸", "WORLD", "MAP"):
            if any(label.lower() in b.lower() for b in buttons(page)):
                exact = next((b for b in buttons(page) if label.lower() in b.lower()), None)
                if exact and mouse_click(page, exact, 800):
                    shot(page, "07_other_areas")
                    scan_jargon(
                        findings,
                        "hub/map",
                        visible_text(page),
                        buttons(page),
                    )
                    click_any(page, "CLOSE", "BACK", "DONE", wait_ms=500)
                    break

        # Enter dungeon
        if not click_any(page, "ENTER DUNGEON", wait_ms=1200):
            flag(findings, "high", "hub", "ENTER DUNGEON missing", str(hub2[:20]))
        else:
            dismiss(page, notes, findings, "enter_dungeon")
            dungeon_loop(page, notes, findings, floors=5)

        page.wait_for_timeout(800)
        dismiss(page, notes, findings, "back_hub")
        shot(page, "08_hub_return")
        back_btns = buttons(page)
        back_txt = visible_text(page)
        log(notes, f"hub return: {back_btns[:28]}")
        scan_jargon(findings, "hub/return", back_txt, back_btns)

        # After some floors, vault may be ready — should still NOT claim before boss
        if "CLAIM VAULT" in back_btns:
            flag(
                findings,
                "high",
                "hub/TODAY",
                "CLAIM VAULT after floors without boss",
                "firstHourQuiet should suppress until boss",
            )

        # Second dungeon short pass
        if "ENTER DUNGEON" in back_btns:
            click_any(page, "ENTER DUNGEON", wait_ms=1000)
            dismiss(page, notes, findings, "reenter")
            set_speed(page, 10)
            page.wait_for_timeout(8000)
            shot(page, "09_second_run")
            scan_jargon(
                findings,
                "dungeon/reenter",
                visible_text(page),
                buttons(page),
            )
            # Open POWER from dungeon
            if click_any(page, "POWER", wait_ms=900):
                shot(page, "10_dungeon_power")
                pbtns = buttons(page)
                log(notes, f"dungeon POWER: {[b for b in pbtns if len(b) < 50][:24]}")
                if any(b in pbtns for b in ("KEEP", "APEX")):
                    flag(
                        findings,
                        "medium",
                        "dungeon/POWER",
                        "KEEP/APEX visible in first hour",
                        str([b for b in pbtns if b in ("KEEP", "APEX")]),
                    )
                # buy something if gold
                for buy in pbtns:
                    if buy.startswith("Buy ") or buy.startswith("+") or "ATK" in buy:
                        mouse_click(page, buy, 500)
                        break
                click_any(page, "CLOSE", "BACK", wait_ms=500)

            # Open PARTY from dungeon — bag/gear
            if click_any(page, "PARTY", wait_ms=900):
                shot(page, "11_dungeon_party")
                party_btns = buttons(page)
                log(notes, f"dungeon PARTY: {[b for b in party_btns if len(b) < 50][:24]}")
                if any(b.upper() in ("SCRAP", "SELL JUNK", "LOADOUTS", "SELL") for b in party_btns):
                    dead = [
                        b
                        for b in party_btns
                        if b.upper() in ("SCRAP", "SELL JUNK", "LOADOUTS", "SELL")
                    ]
                    flag(
                        findings,
                        "medium",
                        "PARTY",
                        "Dead chrome still visible",
                        str(dead),
                    )
                click_any(page, "CLOSE", "BACK", wait_ms=500)

            click_any(page, "LEAVE", wait_ms=600)
            click_any(page, "LEAVE TO HUB", "YES", "LEAVE", wait_ms=800)

        page.wait_for_timeout(600)
        dismiss(page, notes, findings, "final")
        shot(page, "12_final_hub")
        final_btns = buttons(page)
        final_txt = visible_text(page)
        log(notes, f"final hub: {final_btns[:30]}")
        scan_jargon(findings, "hub/final", final_txt, final_btns)

        # META → What's New version check
        meta = next((b for b in final_btns if b.startswith("META")), None)
        if meta and mouse_click(page, meta, 900):
            click_any(page, "GUIDE", wait_ms=600)
            click_any(page, "WHAT'S NEW", "WHATS NEW", "What's New", wait_ms=700)
            shot(page, "13_whats_new")
            wn = visible_text(page)
            log(notes, f"whats new snippet: {wn[:240]}")
            if "1.12.77" not in wn and "1.12.7" not in wn:
                flag(
                    findings,
                    "low",
                    "meta",
                    "What's New may not show 1.12.77",
                    wn[:160],
                )
            click_any(page, "GOT IT", "CLOSE", "BACK", wait_ms=500)
            click_any(page, "CLOSE", "BACK", wait_ms=400)

        browser.close()

    # de-dupe findings by title+area
    seen = set()
    uniq = []
    for fnd in findings:
        key = (fnd["area"], fnd["title"], fnd["detail"][:80])
        if key in seen:
            continue
        seen.add(key)
        uniq.append(fnd)

    payload = {
        "notes": notes,
        "findings": uniq,
        "counts": {
            "high": sum(1 for f in uniq if f["severity"] == "high"),
            "medium": sum(1 for f in uniq if f["severity"] == "medium"),
            "low": sum(1 for f in uniq if f["severity"] == "low"),
        },
    }
    (OUT / "notes.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    log(notes, f"DONE findings high={payload['counts']['high']} med={payload['counts']['medium']} low={payload['counts']['low']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
