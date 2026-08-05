from playwright.sync_api import sync_playwright
import json, os, time

OUT = "tool/out/playtest_demo"
os.makedirs(OUT, exist_ok=True)

def buttons(page):
    return page.locator("flt-semantics[role=button]").all_text_contents()

def click_btn(page, name):
    loc = page.get_by_role("button", name=name)
    box = loc.bounding_box()
    if not box:
        raise RuntimeError("no box " + name)
    page.mouse.click(box["x"]+box["width"]/2, box["y"]+box["height"]/2, delay=40)
    page.wait_for_timeout(500)

def click_if(page, *names):
    btns = buttons(page)
    for n in names:
        if n in btns:
            click_btn(page, n); return n
        m = next((b for b in btns if n.lower() in b.lower()), None)
        if m:
            click_btn(page, m); return m
    return None

def save_summary(page):
    return page.evaluate("""() => {
      const raw = localStorage.getItem('flutter.idle_party_save_v2');
      if (!raw) return null;
      let s = JSON.parse(raw);
      if (typeof s === 'string') s = JSON.parse(s);
      return {
        al: s.ascensionLevel, inDungeon: s.inDungeon, gold: s.gold,
        bosses: s.bossVictories, bag: (s.gearStash||[]).length,
        dungeonMode: s.dungeonMode,
        heroes: (s.heroes||[]).map(h => ({id:h.id||h.classId, lv:h.level}))
      };
    }""")

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)
    page.screenshot(path=f"{OUT}/01_title.png")
    print("title", buttons(page))

    # Prefer continue if enabled, else new game
    cont = page.get_by_role("button", name="CONTINUE")
    disabled = cont.evaluate("el => el.getAttribute('aria-disabled')")
    if disabled == "true" or "CONTINUE" not in buttons(page):
        click_btn(page, "NEW GAME")
        page.wait_for_timeout(1000)
        page.screenshot(path=f"{OUT}/02_picker.png")
        print("picker", buttons(page)[:10])
        click_btn(page, "START")
    else:
        click_btn(page, "CONTINUE")
    page.wait_for_timeout(1500)
    click_if(page, "SKIP ALL TIPS")
    while click_if(page, "GOT IT"):
        page.wait_for_timeout(250)
    page.screenshot(path=f"{OUT}/03_hub.png")
    print("hub", save_summary(page), buttons(page)[:12])

    if click_if(page, "ENTER DUNGEON"):
        page.wait_for_timeout(1500)
        click_if(page, "SKIP ALL TIPS")
        while click_if(page, "GOT IT"):
            page.wait_for_timeout(200)
        click_if(page, "FARM dungeon mode")
        page.screenshot(path=f"{OUT}/04_dungeon.png")
        print("dungeon enter", save_summary(page), buttons(page)[:12])

        for i in range(8):
            page.wait_for_timeout(4000)
            # God Hand tap map center
            if i % 2 == 1:
                page.mouse.click(415, 400)
            s = save_summary(page)
            btns = buttons(page)
            print(f"t{i}", s, btns[:8])
            page.screenshot(path=f"{OUT}/05_combat_{i}.png")
            if click_if(page, "RETRY FLOOR", "RETURN TO HUB"):
                break
            if s and not s.get("inDungeon"):
                break

    page.screenshot(path=f"{OUT}/06_final.png")
    print("FINAL", save_summary(page))
    browser.close()
