from playwright.sync_api import sync_playwright
import json, os, time

OUT = "tool/out/playtest_al0_v3"
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
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)

    # Continue existing save if present, else new game
    btns = buttons(page)
    if "CONTINUE" in btns:
        dis = page.get_by_role("button", name="CONTINUE").evaluate("el => el.getAttribute('aria-disabled')")
        if dis != "true":
            click_btn(page, "CONTINUE")
        else:
            click_btn(page, "NEW GAME"); page.wait_for_timeout(800); click_btn(page, "START")
    else:
        click_btn(page, "NEW GAME"); page.wait_for_timeout(800); click_btn(page, "START")
    page.wait_for_timeout(1500)
    click_if(page, "SKIP ALL TIPS")
    while click_if(page, "GOT IT"):
        page.wait_for_timeout(200)

    s0 = save_summary(page)
    print("start", safe(s0))

    # If in dungeon, power up then push; else enter
    if s0 and s0.get("inDungeon"):
        power_up(page)
        click_if(page, "RETRY FLOOR")
        click_if(page, "PUSH dungeon mode")
    else:
        click_if(page, "ENTER DUNGEON"); page.wait_for_timeout(1200)
        while click_if(page, "SKIP ALL TIPS", "GOT IT"):
            page.wait_for_timeout(200)
        click_if(page, "FARM dungeon mode")
        for i in range(18):
            page.wait_for_timeout(5000)
            s = save_summary(page)
            print("farm", i, safe(s))
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
    browser.close()
