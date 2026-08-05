from playwright.sync_api import sync_playwright
import json, os, time

OUT = "tool/out/playtest_al0_newgame"
os.makedirs(OUT, exist_ok=True)

def safe(s):
    return str(s).encode("ascii", "replace").decode("ascii")

def buttons(page):
    return page.locator("flt-semantics[role=button]").all_text_contents()

def click_btn(page, name):
    # exact=True avoids AUTO matching AUTO MERGE
    loc = page.get_by_role("button", name=name, exact=True)
    box = loc.bounding_box()
    if not box:
        raise RuntimeError("no box "+name)
    if loc.evaluate("el => el.getAttribute('aria-disabled')") == "true":
        raise RuntimeError("disabled "+name)
    page.mouse.click(box["x"]+box["width"]/2, box["y"]+box["height"]/2, delay=40)
    page.wait_for_timeout(450)

def click_if(page, *names):
    btns = buttons(page)
    for n in names:
        if n in btns:
            click_btn(page, n); return n
        # Prefer exact label; only then substring (longest match)
        matches = [b for b in btns if n.lower() in b.lower()]
        if not matches:
            continue
        m = next((b for b in matches if b == n), None) or min(matches, key=len)
        click_btn(page, m); return m
    return None

def save_summary(page):
    return page.evaluate("""() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const eq = s.equipment || {};
      let eqCount = 0;
      for (const h of (s.heroes||[])) {
        const e = h.equipment || h.gear || {};
        eqCount += Object.keys(e).length;
      }
      // also party equipment map
      if (s.equippedByHero) eqCount += Object.keys(s.equippedByHero).length;
      return {
        al: s.ascensionLevel, inDungeon: s.inDungeon, gold: s.gold, essence: s.essence,
        bosses: s.bossVictories, bag: (s.gearStash||[]).length,
        roomType: (s.currentRoom||{}).type, dungeonMode: s.dungeonMode,
        heroes: (s.heroes||[]).map(h => ({id:h.id||h.classId, lv:h.level})),
        eqSlots: Object.keys(s.equipment||{}).length
      };
    }""")

def power_up(page):
    """BAG AUTO + FORGE train a few times."""
    try:
        if click_if(page, "BAG"):
            page.wait_for_timeout(700)
            page.screenshot(path=f"{OUT}/bag.png")
            for _ in range(3):
                if not click_if(page, "AUTO"):
                    break
                page.wait_for_timeout(400)
            # Do NOT SELL JUNK here — it was stripping power before first boss.
            page.wait_for_timeout(200)
            page.mouse.click(415, 40); page.wait_for_timeout(400)
        if click_if(page, "MORE"):
            page.wait_for_timeout(500)
            if click_if(page, "FORGE"):
                page.wait_for_timeout(700)
                page.screenshot(path=f"{OUT}/forge.png")
                for _ in range(8):
                    if not (click_if(page, "TRAIN") or click_if(page, "UPGRADE")):
                        btns = buttons(page)
                        hit = next((b for b in btns if any(k in b.upper() for k in ["ATK","DEF","VIT","TRAIN","BUY"])), None)
                        if not hit: break
                        try: click_btn(page, hit)
                        except Exception: break
                    page.wait_for_timeout(350)
                page.mouse.click(415, 40); page.wait_for_timeout(400)
            else:
                page.mouse.click(415, 40); page.wait_for_timeout(300)
    except Exception as e:
        print("power_up err", safe(e))
        page.mouse.click(415, 40)
        page.wait_for_timeout(300)

with sync_playwright() as p:
    # Visible Chrome so you can watch the playtest on your desktop.
    browser = p.chromium.launch(
        headless=False,
        slow_mo=80,
        args=["--start-maximized"],
    )
    page = browser.new_page(viewport={"width": 900, "height": 1000})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(2000)
    # Always fresh run: wipe save then hard reload.
    page.evaluate("""() => {
      for (const k of Object.keys(localStorage)) {
        if (k.includes('idle_party') || k.includes('flutter')) localStorage.removeItem(k);
      }
    }""")
    page.reload(wait_until="domcontentloaded")
    page.wait_for_timeout(4000)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)
    # Title input unlock is ~900ms after mount.
    page.wait_for_timeout(1200)

    print("title buttons", safe(buttons(page)))
    click_btn(page, "NEW GAME")
    page.wait_for_timeout(1200)
    print("picker", safe(buttons(page)))
    click_btn(page, "START")
    page.wait_for_timeout(2000)
    if click_if(page, "SKIP ALL TIPS"):
        page.wait_for_timeout(500)
    while click_if(page, "GOT IT"):
        page.wait_for_timeout(300)

    s0 = save_summary(page)
    print("start", safe(s0), safe(buttons(page)[:12]))

    # Always start from hub → farm then push (never resume mid-dungeon).
    if not click_if(page, "ENTER DUNGEON"):
        raise RuntimeError("ENTER DUNGEON missing: " + safe(buttons(page)))
    page.wait_for_timeout(2000)
    for _ in range(10):
        if click_if(page, "SKIP ALL TIPS", "GOT IT"):
            page.wait_for_timeout(400)
        else:
            break
    # Confirm we entered
    for attempt in range(5):
        s = save_summary(page)
        print("enter check", attempt, safe(s), safe(buttons(page)[:10]))
        if s and s.get("inDungeon"):
            break
        click_if(page, "ENTER DUNGEON")
        page.wait_for_timeout(1500)
    else:
        raise RuntimeError("failed to enter dungeon")

    click_if(page, "FARM dungeon mode")
    page.screenshot(path=f"{OUT}/farm_start.png")
    for i in range(18):
        page.wait_for_timeout(5000)
        s = save_summary(page)
        print("farm", i, safe(s), safe(buttons(page)[:8]))
        if not (s and s.get("inDungeon")):
            print("left dungeon during farm — re-enter")
            click_if(page, "ENTER DUNGEON")
            page.wait_for_timeout(1200)
            click_if(page, "FARM dungeon mode")
        click_if(page, "RETRY FLOOR")
        if s and s.get("gold",0) >= 80 and s["heroes"][0]["lv"] >= 4:
            break
    power_up(page)
    click_if(page, "PUSH dungeon mode")

    t0 = time.time()
    last_bosses = 0
    ready = False
    for i in range(150):
        page.wait_for_timeout(5000)
        s = save_summary(page)
        print(i, int(time.time()-t0), safe(s), safe(buttons(page)[:8]))
        if i % 5 == 0:
            page.screenshot(path=f"{OUT}/t{int(time.time()-t0):04d}.png")

        if s and s.get("roomType") == "RoomType.boss":
            # spam God Hand during boss
            for _ in range(4):
                page.mouse.click(415, 400)
                page.wait_for_timeout(200)

        if click_if(page, "RETRY FLOOR"):
            print("RETRY -> power up")
            page.wait_for_timeout(600)
            power_up(page)
            click_if(page, "PUSH dungeon mode")
            continue

        if "RETURN TO HUB" in buttons(page):
            click_btn(page, "RETURN TO HUB"); page.wait_for_timeout(1000)
            power_up(page)
            if any("ASCEND" in b.upper() for b in buttons(page)) or (s and s.get("bosses",0)>=1):
                # check MORE for ascend
                click_if(page, "MORE"); page.wait_for_timeout(500)
                page.screenshot(path=f"{OUT}/ascend_check.png")
                if any("ASCEND" in b.upper() for b in buttons(page)) or (s and s.get("bosses",0)>=1):
                    ready = True
                    print("ASCEND/BOSS DONE")
                    page.screenshot(path=f"{OUT}/ascend_ready.png")
                    break
            click_if(page, "ENTER DUNGEON"); page.wait_for_timeout(1000)
            click_if(page, "PUSH dungeon mode")
            continue

        if s and s.get("bosses",0) > last_bosses:
            last_bosses = s["bosses"]
            page.screenshot(path=f"{OUT}/boss_{last_bosses}.png")
            print("BOSS KILL", last_bosses)
            ready = True
            # leave to hub for ascend report
            if click_if(page, "RETURN TO HUB") or click_if(page, "MORE"):
                pass
            break

        if s and not s.get("inDungeon"):
            click_if(page, "MORE"); page.wait_for_timeout(400)
            if any("ASCEND" in b.upper() for b in buttons(page)):
                ready = True
                page.screenshot(path=f"{OUT}/ascend_ready.png")
                print("ASCEND READY")
                break
            if s.get("bosses",0) >= 1:
                ready = True; break
            power_up(page)
            click_if(page, "ENTER DUNGEON"); page.wait_for_timeout(800)
            click_if(page, "PUSH dungeon mode")

        if any("critical" in b.lower() for b in buttons(page)):
            click_if(page, "Use healing flask", "FLASK")

        if i % 12 == 6:
            power_up(page)

    print("FINAL", ready, last_bosses, safe(save_summary(page)))
    page.screenshot(path=f"{OUT}/final.png")
    # Keep window open briefly so you can see the end state.
    page.wait_for_timeout(8000)
    browser.close()
