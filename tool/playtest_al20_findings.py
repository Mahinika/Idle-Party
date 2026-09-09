"""AL20 hub screenshot pass via Playwright (360x780) — findings only."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "out" / "polish_30"
SAVE = ROOT / "tool" / "out" / "max_unlock_save.json"
URL = "http://localhost:8085/"
OUT.mkdir(parents=True, exist_ok=True)


def buttons(page) -> list[str]:
    raw = page.evaluate(
        "() => typeof window.__idlePartyButtons === 'function' "
        "? window.__idlePartyButtons() : ''"
    )
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    text = str(raw or "").strip()
    if text.startswith("["):
        try:
            data = json.loads(text.replace("'", '"'))
            if isinstance(data, list):
                return [str(x).strip() for x in data if str(x).strip()]
        except Exception:
            pass
    if text:
        return [p.strip() for p in text.split(" | ") if p.strip()]
    return []


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


def click_any(page, *names: str, wait_ms: int = 800) -> str | None:
    btns = buttons(page)
    for n in names:
        for b in btns:
            if n.lower() in b.lower() and bridge(page, b, wait_ms):
                return b
    return None


def shot(page, name: str) -> None:
    page.screenshot(path=str(OUT / f"al20_{name}.png"), full_page=False)


def main() -> int:
    raw = SAVE.read_text(encoding="utf-8")
    findings: list[str] = []
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
        page.wait_for_timeout(1200)
        page.evaluate(
            "(raw) => localStorage.setItem('flutter.idle_party_save_v2', JSON.stringify(raw))",
            raw,
        )
        page.reload(wait_until="domcontentloaded")
        for _ in range(50):
            if buttons(page):
                break
            page.wait_for_timeout(400)
        page.wait_for_timeout(1500)
        click_any(page, "SKIP", "CONTINUE", wait_ms=900)
        click_any(page, "CONTINUE", wait_ms=1200)
        for _ in range(6):
            if click_any(page, "SKIP ALL TIPS", "GOT IT", "MAYBE LATER", wait_ms=600):
                continue
            break
        page.wait_for_timeout(800)
        btns = buttons(page)
        notes.append("hub btns: " + str(btns[:45]))
        shot(page, "hub")

        low = " | ".join(btns).lower()
        if "join discord" in low or "maybe later" in low:
            findings.append(
                "P0 AL20 hub: Discord JOIN/MAYBE LATER still primary chrome beside chase"
            )
        if "today" not in low and not any(
            k in low for k in ("enter key", "gauntlet", "claim", "boards", "open bag")
        ):
            findings.append("P1 AL20: no obvious chase CTA in button list")
        if "open bag" in low and "enter key" not in low and "gauntlet" not in low:
            findings.append("P1 AL20: OPEN BAG chase but no KEY/Gauntlet CTA in buttons")
        if "enter dungeon" in low and "enter key" not in low:
            findings.append(
                "P1 AL20: ENTER DUNGEON present without ENTER KEY — endgame hunt unclear?"
            )

        # KEY sheet
        if click_any(page, "KEY", wait_ms=1000) or click_any(page, "KEY DIAL", wait_ms=1000):
            shot(page, "key")
            kb = buttons(page)
            notes.append("KEY btns: " + str(kb[:40]))
            kl = " | ".join(kb).lower()
            if "key · run" in kl and "spire" in kl and "rift" in kl:
                notes.append("OK KEY has run modes")
            if "today" not in kl and "hunt" not in kl:
                findings.append("P2 KEY sheet: no TODAY/hunt highlight word in buttons")
            click_any(page, "CLOSE", wait_ms=600)

        # GEAR BAG
        if click_any(page, "GEAR", wait_ms=900):
            click_any(page, "BAG", wait_ms=700)
            shot(page, "bag")
            bb = buttons(page)
            notes.append("BAG: " + str([b for b in bb if any(x in b.upper() for x in ("EQUIP", "SCRAP", "SELL", "AUTO"))]))
            if any("SCRAP" in b.upper() or "SELL JUNK" in b.upper() for b in bb):
                findings.append("P0 BAG: dead Scrap/Sell junk still visible")
            click_any(page, "CLOSE", wait_ms=600)

        # SHOP
        if click_any(page, "SHOP", wait_ms=900):
            shot(page, "shop")
            sb = " | ".join(buttons(page)).lower()
            notes.append("SHOP: " + sb[:300])
            if "coming later" not in sb and "billing" not in sb and "soon" not in sb:
                findings.append("P1 SHOP: missing Coming later / billing-soon honesty in buttons")
            click_any(page, "CLOSE", wait_ms=600)

        # Enter KEY or dungeon
        entered = False
        for needle in ("ENTER KEY", "GAUNTLET", "ENTER DUNGEON"):
            if click_any(page, needle, wait_ms=1000):
                click_any(page, "ENTER", "CONFIRM", "YES", wait_ms=800)
                page.wait_for_timeout(1500)
                shot(page, "dungeon")
                db = buttons(page)
                notes.append(f"after {needle}: " + str(db[:25]))
                if any("LEAVE" in b.upper() or "GOD HAND" in b.upper() or "FARM" in b.upper() for b in db):
                    entered = True
                    findings.append(f"NOTE entered via {needle}")
                    break
                # dismiss stuck confirm
                click_any(page, "CANCEL", "STAY", "CLOSE", wait_ms=500)

        if not entered:
            findings.append("P1 AL20: could not enter KEY/dungeon from hub CTAs")

        # Fight briefly if entered
        if entered:
            for i in range(15):
                click_any(page, "GOD HAND", wait_ms=200)
                page.wait_for_timeout(1400)
                b = " | ".join(buttons(page)).lower()
                if i in (0, 7, 14):
                    shot(page, f"fight_{i}")
                if "hold" in b or "clear" in b or "go stairs" in b:
                    findings.append("NOTE clear/HOLD seen on AL20 run")
                    shot(page, "clear")
                    click_any(page, "HOLD", wait_ms=1000)
                    shot(page, "after_hold")
                    break
                if "wiped" in b or "retry" in b:
                    findings.append("NOTE wipe on AL20 — check tip language")
                    shot(page, "wipe")
                    break

        browser.close()

    report = OUT / "AL20_FINDINGS.md"
    report.write_text(
        "# AL20 hub findings\n\n"
        + "\n".join(f"- {f}" for f in findings)
        + "\n\n## Notes\n"
        + "\n".join(f"- {n}" for n in notes),
        encoding="utf-8",
    )
    print(f"wrote {report}")
    for f in findings:
        print("FIND:", f)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
