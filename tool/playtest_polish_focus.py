"""Focused AL20 polish playtest — hub + dungeon + notes (360x780)."""
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


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : null"
    )
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    if isinstance(raw, str) and raw.strip():
        return [p.strip() for p in raw.split(" | ") if p.strip()]
    return [t.strip() for t in page.locator("flt-semantics[role=button]").all_text_contents() if t.strip()]


def bridge(page, label: str, wait_ms: int = 600) -> bool:
    ok = bool(
        page.evaluate(
            "(n) => typeof window.__idlePartyClick === 'function' && !!window.__idlePartyClick(n)",
            label,
        )
    )
    if ok:
        page.wait_for_timeout(wait_ms)
    return ok


def click_any(page, *names: str, wait_ms: int = 600) -> str | None:
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


def visible(page) -> str:
    try:
        return page.locator("flt-semantics").inner_text(timeout=1500)
    except Exception:
        return ""


def dismiss(page) -> None:
    for _ in range(10):
        btns = buttons(page)
        if "SKIP ALL TIPS" in btns:
            bridge(page, "SKIP ALL TIPS", 350)
            continue
        if "MAYBE LATER" in btns:
            bridge(page, "MAYBE LATER", 350)
            continue
        if "GOT IT" in btns:
            bridge(page, "GOT IT", 300)
            continue
        if "SKIP" in btns:
            bridge(page, "SKIP", 400)
            continue
        break


def save_summary(page) -> dict:
    return page.evaluate(
        """() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return {};
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const md = s.metaDepth || {};
      return {
        al: s.ascensionLevel, hm: s.hardmodeLevel, gold: s.gold,
        inDungeon: s.inDungeon, wiped: s.isPartyDefeated,
        wipeAdvice: s.wipeAdviceLine, bag: (s.gearStash||[]).length,
        vaultClaimed: md.dailyVaultClaimed, gauntlet: md.gauntletBestFloor,
        keyActive: s.keystoneRunActive, keyLevel: s.keystoneRunLevel,
        floor: (s.currentRoom||{}).floorNumber, dungeonId: s.dungeonId,
      };
    }"""
    )


def flag(findings, sev, area, title, detail):
    findings.append({"severity": sev, "area": area, "title": title, "detail": detail})
    print(f"[{sev}] {area}: {title} — {detail[:180]}")


def main() -> int:
    raw = SAVE.read_text(encoding="utf-8")
    notes: list[str] = []
    findings: list[dict] = []
    t0 = time.time()

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
        page.evaluate(
            "(raw) => localStorage.setItem('flutter.idle_party_save_v2', JSON.stringify(raw))",
            raw,
        )
        page.reload(wait_until="domcontentloaded")
        for _ in range(60):
            if buttons(page):
                break
            page.wait_for_timeout(500)
        page.wait_for_timeout(2000)
        click_any(page, "SKIP", "CONTINUE", wait_ms=900)
        click_any(page, "CONTINUE", wait_ms=1200)
        dismiss(page)
        notes.append(f"boot save: {save_summary(page)}")
        shot(page, "w_hub")

        btns = buttons(page)
        txt = visible(page)
        notes.append(f"hub buttons ({len(btns)}): {btns[:40]}")
        notes.append(f"hub text head: {txt[:500]}")
        if not any("TODAY" in b.upper() for b in btns) and "TODAY" not in txt.upper():
            # semantics may omit TODAY label — check chase CTAs
            chase = [b for b in btns if any(k in b.upper() for k in ("ENTER KEY", "GAUNTLET", "BOARDS", "CLAIM", "RIFT", "ASHEN", "DONE"))]
            if not chase:
                flag(findings, "high", "hub", "No TODAY/chase CTA found", str(btns[:25]))
            else:
                notes.append(f"chase CTAs without TODAY word: {chase}")
        else:
            notes.append("OK: TODAY present")

        # Menus
        for tab in ("GEAR", "GOLD", "SHOP", "ESSENCE", "MORE", "KEY"):
            hit = click_any(page, tab, wait_ms=800)
            notes.append(f"tab {tab} -> {hit}")
            shot(page, f"w_{tab.lower()}")
            t = visible(page)
            b = buttons(page)
            if tab == "GEAR":
                click_any(page, "BAG", wait_ms=600)
                bb = buttons(page)
                notes.append(f"BAG btns: {[x for x in bb if 'EQUIP' in x.upper() or 'SCRAP' in x.upper() or 'SELL' in x.upper()]}")
                if any("Scrap" == x or "Sell junk" in x for x in bb):
                    flag(findings, "high", "bag", "Dead chrome visible", str(bb[:20]))
                if any(x.startswith("EQUIP ") for x in bb):
                    notes.append("OK: EQUIP N on BAG")
            if tab == "GOLD":
                click_any(page, "MARKET", wait_ms=600)
                mt = visible(page) + " " + " ".join(buttons(page))
                if "UPGRADE" in mt.upper():
                    notes.append("OK: UPGRADE on market")
                else:
                    flag(findings, "low", "market", "No UPGRADE string visible", mt[:160])
            if tab == "SHOP":
                blob = t + " " + " ".join(b)
                if "coming later" in blob.lower():
                    notes.append("OK: SHOP Coming later")
                else:
                    flag(findings, "medium", "shop", "SHOP honesty unclear", blob[:160])
            if tab == "MORE":
                if click_any(page, "WHAT'S NEW", "WHATS NEW", wait_ms=700):
                    wn = visible(page)
                    notes.append(f"whatsnew: {wn[:300]}")
                    if "1.12.98" not in wn:
                        flag(findings, "medium", "whatsnew", "1.12.98 not in What's New body", wn[:200])
                    click_any(page, "GOT IT", "CLOSE", wait_ms=400)
                if click_any(page, "GUIDE", wait_ms=700):
                    g = visible(page)
                    if "lifetime gold" in g.lower():
                        flag(findings, "high", "guides", "lifetime gold unlock copy", g[:200])
                    click_any(page, "CLOSE", wait_ms=400)
            if tab == "KEY":
                notes.append(f"KEY btns: {[x for x in b if len(x) < 42][:25]}")
            click_any(page, "CLOSE", wait_ms=350)
            click_any(page, tab, wait_ms=350)  # toggle close
            dismiss(page)

        # Enter endgame hunt
        entered = False
        for label in ("KEY · BOARDS", "GAUNTLET", "GREATER RIFT", "RIFT", "ASHEN CROWN", "ENTER KEY +20", "ENTER KEY", "ENTER DUNGEON"):
            if click_any(page, label, wait_ms=900):
                click_any(page, "ENTER", "CONFIRM", "YES", wait_ms=700)
                dismiss(page)
                if save_summary(page).get("inDungeon"):
                    notes.append(f"entered via {label}")
                    entered = True
                    break
        shot(page, "w_dungeon" if entered else "w_no_enter")
        if entered:
            page.evaluate(
                "(s) => typeof window.__idlePartySetSpeed === 'function' && window.__idlePartySetSpeed(s)",
                10,
            )
            # poke God Hand / leave
            for _ in range(40):
                s = save_summary(page)
                if s.get("wiped"):
                    notes.append(f"wipe advice={s.get('wipeAdvice')}")
                    shot(page, "w_wipe")
                    if s.get("wipeAdvice") and "FORGE" in s["wipeAdvice"] and "POWER" not in s["wipeAdvice"]:
                        flag(findings, "high", "wipe", "FORGE wording", s["wipeAdvice"])
                    if s.get("wipeAdvice") and "POWER" in s["wipeAdvice"]:
                        notes.append("OK: POWER wipe tip")
                    break
                click_any(page, "God Hand ready", "Tap the fight", wait_ms=200)
                page.wait_for_timeout(700)
            if click_any(page, "LEAVE", wait_ms=600):
                lt = visible(page)
                notes.append(f"LEAVE copy: {lt[:240]}")
                shot(page, "w_leave")
                if "Floor is clear" in lt or "stairs ready" in lt or "fight progress is lost" in lt or "FARM loop" in lt or "KEY run ends" in lt:
                    notes.append("OK: LEAVE dialog has specific copy")
                click_any(page, "RETURN", "STAY", wait_ms=700)
                click_any(page, "RETURN", wait_ms=700)
        else:
            flag(findings, "high", "hub", "Could not enter dungeon from AL20 save", str(btns[:30]))

        shot(page, "w_end")
        notes.append(f"final: {save_summary(page)}")
        notes.append(f"elapsed_sec={round(time.time()-t0,1)}")
        browser.close()

    OUT.mkdir(parents=True, exist_ok=True)
    report = {"findings": findings, "notes": notes, "elapsed_sec": round(time.time() - t0, 1)}
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    md = [f"# Polish playtest {report['elapsed_sec']}s", "", f"Findings: {len(findings)}", ""]
    for f in findings:
        md.append(f"- **{f['severity'].upper()}** · {f['area']} · {f['title']}: {f['detail']}")
    md += ["", "## Log"] + [f"- {n}" for n in notes]
    (OUT / "NOTES.md").write_text("\n".join(md), encoding="utf-8")
    print(f"DONE findings={len(findings)} -> {OUT / 'NOTES.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
