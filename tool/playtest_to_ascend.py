from playwright.sync_api import sync_playwright
import json, os, time

OUT = "tool/out/playtest_al0_long"
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

def save_summary(page):
    return page.evaluate("""() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      const room = s.currentRoom || {};
      return {
        al: s.ascensionLevel,
        inDungeon: s.inDungeon,
        gold: s.gold,
        essence: s.essence,
        bosses: s.bossVictories,
        bag: (s.gearStash||[]).length,
        roomType: room.type,
        roomName: room.name,
        dungeonMode: s.dungeonMode,
        heroes: (s.heroes||[]).map(h => ({id:h.id||h.classId, lv:h.level, hp:h.hp, max:h.maxHp}))
      };
    }""")

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)

    # Fresh run
    click_btn(page, "NEW GAME")
    page.wait_for_timeout(1000)
    click_btn(page, "START")
    page.wait_for_timeout(1500)
    if "SKIP ALL TIPS" in buttons(page):
        click_btn(page, "SKIP ALL TIPS")
        page.wait_for_timeout(500)
    else:
        while "GOT IT" in buttons(page):
            click_btn(page, "GOT IT")
            page.wait_for_timeout(300)

    page.screenshot(path=f"{OUT}/hub.png")
    click_btn(page, "ENTER DUNGEON")
    page.wait_for_timeout(2000)
    while "GOT IT" in buttons(page) or "SKIP ALL TIPS" in buttons(page):
        if "SKIP ALL TIPS" in buttons(page):
            click_btn(page, "SKIP ALL TIPS")
        else:
            click_btn(page, "GOT IT")
        page.wait_for_timeout(300)

    # Ensure PUSH
    try:
        click_btn(page, "PUSH dungeon mode")
    except Exception:
        pass

    t0 = time.time()
    last_bosses = 0
    ascended = False
    for i in range(90):  # up to ~7.5 min @ 5s
        page.wait_for_timeout(5000)
        s = save_summary(page)
        btns = buttons(page)
        entry = {"i": i, "t": int(time.time()-t0), "save": s, "hasAscend": any("ASCEND" in b.upper() for b in btns), "btnSample": [safe(b) for b in btns[:12]]}
        log.append(entry)
        print(safe(entry))
        if i % 6 == 0:
            page.screenshot(path=f"{OUT}/t{entry['t']:04d}.png")
        if s and s.get("bosses", 0) > last_bosses:
            last_bosses = s["bosses"]
            page.screenshot(path=f"{OUT}/boss_{last_bosses}.png")
            print("BOSS", last_bosses)
        # leave dungeon tips / hub after wipe or clear
        if s and not s.get("inDungeon"):
            page.screenshot(path=f"{OUT}/hub_return.png")
            # open MORE and look for ASCEND
            if any(b == "MORE" for b in btns):
                try:
                    click_btn(page, "MORE")
                    page.wait_for_timeout(800)
                except Exception:
                    pass
            btns = buttons(page)
            page.screenshot(path=f"{OUT}/hub_menus.png")
            ascend = next((b for b in btns if "ASCEND" in b.upper()), None)
            if ascend:
                print("ASCEND AVAILABLE", safe(ascend))
                page.screenshot(path=f"{OUT}/ascend_ready.png")
                # stop before ascending so we report first
                ascended = True
                break
            # re-enter if need more bosses
            if s.get("bosses", 0) < 1 and any(b == "ENTER DUNGEON" for b in btns):
                click_btn(page, "ENTER DUNGEON")
                page.wait_for_timeout(1500)
                try:
                    click_btn(page, "PUSH dungeon mode")
                except Exception:
                    pass
        # God Hand occasionally
        if i % 8 == 3:
            try:
                # tap map center for GH
                page.mouse.click(415, 420)
            except Exception:
                pass

    with open(f"{OUT}/log.json", "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)
    print("FINAL ascended_ready", ascended, "bosses", last_bosses)
    browser.close()
