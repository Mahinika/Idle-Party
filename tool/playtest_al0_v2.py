from playwright.sync_api import sync_playwright
import json, os, time

OUT = "tool/out/playtest_al0_v2"
os.makedirs(OUT, exist_ok=True)
log = []

def safe(s):
    return str(s).encode("ascii", "replace").decode("ascii")

def buttons(page):
    return page.locator("flt-semantics[role=button]").all_text_contents()

def click_btn(page, name):
    loc = page.get_by_role("button", name=name)
    box = loc.bounding_box()
    if not box:
        raise RuntimeError("no box "+name)
    if loc.evaluate("el => el.getAttribute('aria-disabled')") == "true":
        raise RuntimeError("disabled "+name)
    page.mouse.click(box["x"]+box["width"]/2, box["y"]+box["height"]/2, delay=40)
    page.wait_for_timeout(500)

def click_if(page, *names):
    btns = buttons(page)
    for n in names:
        if n in btns:
            click_btn(page, n)
            return n
        match = next((b for b in btns if n.lower() in b.lower()), None)
        if match:
            click_btn(page, match)
            return match
    return None

def save_summary(page):
    return page.evaluate("""() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const room = s.currentRoom || {};
      return {
        al: s.ascensionLevel, inDungeon: s.inDungeon, gold: s.gold, essence: s.essence,
        bosses: s.bossVictories, bag: (s.gearStash||[]).length,
        roomType: room.type, dungeonMode: s.dungeonMode,
        heroes: (s.heroes||[]).map(h => ({id:h.id||h.classId, lv:h.level}))
      };
    }""")

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)

    click_btn(page, "NEW GAME"); page.wait_for_timeout(1000)
    click_btn(page, "START"); page.wait_for_timeout(1500)
    click_if(page, "SKIP ALL TIPS")
    while click_if(page, "GOT IT"):
        page.wait_for_timeout(200)

    # Short farm first for gold/levels
    click_btn(page, "ENTER DUNGEON"); page.wait_for_timeout(1500)
    while click_if(page, "SKIP ALL TIPS", "GOT IT"):
        page.wait_for_timeout(200)
    click_if(page, "FARM dungeon mode")
    page.screenshot(path=f"{OUT}/farm_start.png")
    t0 = time.time()
    for i in range(24):  # ~2 min farm
        page.wait_for_timeout(5000)
        s = save_summary(page)
        print("farm", i, safe(s))
        if click_if(page, "RETRY FLOOR"):
            print("retried during farm")
            page.wait_for_timeout(1000)
        if s and s.get("gold", 0) >= 40 and s.get("heroes",[{}])[0].get("lv",1) >= 2:
            break

    # Equip from bag if possible
    if click_if(page, "BAG"):
        page.wait_for_timeout(800)
        page.screenshot(path=f"{OUT}/bag.png")
        # spam a few equip-ish buttons
        for _ in range(8):
            btns = buttons(page)
            equip = next((b for b in btns if "EQUIP" in b.upper() or "WEAR" in b.upper() or "AUTO" in b.upper()), None)
            if equip:
                try:
                    click_btn(page, equip)
                    page.wait_for_timeout(400)
                except Exception:
                    break
            else:
                break
        click_if(page, "CLOSE", "BACK", "DONE")
        page.mouse.click(415, 50); page.wait_for_timeout(300)

    # Switch to PUSH
    click_if(page, "PUSH dungeon mode")
    page.screenshot(path=f"{OUT}/push.png")

    last_bosses = 0
    ready = False
    for i in range(120):  # up to 10 min
        page.wait_for_timeout(5000)
        s = save_summary(page)
        btns = buttons(page)
        entry = {"i": i, "t": int(time.time()-t0), "save": s, "btns": [safe(b) for b in btns[:10]]}
        log.append(entry)
        print(safe(entry))
        if i % 6 == 0:
            page.screenshot(path=f"{OUT}/t{entry['t']:04d}.png")

        # Handle wipe
        if click_if(page, "RETRY FLOOR"):
            print("RETRY")
            page.wait_for_timeout(800)
            click_if(page, "PUSH dungeon mode")
            continue
        if "RETURN TO HUB" in btns:
            click_btn(page, "RETURN TO HUB")
            page.wait_for_timeout(1200)
            page.screenshot(path=f"{OUT}/hub_after_wipe.png")
            # spend / reenter
            if click_if(page, "MORE"):
                page.wait_for_timeout(600)
                page.screenshot(path=f"{OUT}/more.png")
                if any("ASCEND" in b.upper() for b in buttons(page)):
                    ready = True
                    page.screenshot(path=f"{OUT}/ascend_ready.png")
                    print("ASCEND READY")
                    break
                click_if(page, "CLOSE", "BACK")
                page.mouse.click(415, 40)
            if s and s.get("bosses", 0) >= 1:
                ready = True
                print("boss done, hub")
                page.screenshot(path=f"{OUT}/boss_done_hub.png")
                break
            if click_if(page, "ENTER DUNGEON"):
                page.wait_for_timeout(1200)
                click_if(page, "PUSH dungeon mode")
            continue

        if s and s.get("bosses", 0) > last_bosses:
            last_bosses = s["bosses"]
            page.screenshot(path=f"{OUT}/boss_{last_bosses}.png")
            print("BOSS", last_bosses)

        if s and not s.get("inDungeon"):
            page.screenshot(path=f"{OUT}/hub.png")
            if click_if(page, "MORE"):
                page.wait_for_timeout(600)
                if any("ASCEND" in b.upper() for b in buttons(page)):
                    ready = True
                    page.screenshot(path=f"{OUT}/ascend_ready.png")
                    print("ASCEND READY")
                    break
            if s.get("bosses", 0) >= 1:
                ready = True
                break
            click_if(page, "ENTER DUNGEON")
            page.wait_for_timeout(1000)
            click_if(page, "PUSH dungeon mode")

        if i % 10 == 4:
            page.mouse.click(415, 420)  # God Hand tap

        # critical flask
        if any("critical" in b.lower() for b in btns):
            click_if(page, "Use healing flask", "FLASK")

    with open(f"{OUT}/log.json","w",encoding="utf-8") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)
    print("FINAL ready", ready, "bosses", last_bosses, "save", safe(save_summary(page)))
    browser.close()
