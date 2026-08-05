from playwright.sync_api import sync_playwright
import json, os, re

OUT = "tool/out/playtest_al0"
os.makedirs(OUT, exist_ok=True)
notes = []

def safe(s):
    return s.encode("ascii", "replace").decode("ascii")

def shot(page, name):
    path = f"{OUT}/{name}.png"
    page.screenshot(path=path, full_page=False)
    notes.append(f"shot:{name}")
    return path

def buttons(page):
    return page.locator("flt-semantics[role=button]").all_text_contents()

def click_btn(page, name, timeout=8000):
    loc = page.get_by_role("button", name=name)
    loc.wait_for(state="visible", timeout=timeout)
    box = loc.bounding_box()
    if not box:
        raise RuntimeError(f"no box for {name}")
    disabled = loc.evaluate("el => el.getAttribute('aria-disabled')")
    if disabled == "true":
        raise RuntimeError(f"{name} is disabled")
    x = box["x"] + box["width"] / 2
    y = box["y"] + box["height"] / 2
    page.mouse.click(x, y, delay=40)
    page.wait_for_timeout(700)
    notes.append(f"click:{safe(name)}")

def click_contains(page, substr):
    btns = buttons(page)
    match = next((b for b in btns if substr.lower() in b.lower()), None)
    if not match:
        return False
    click_btn(page, match)
    return True

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=20000)
    shot(page, "01_title")
    print(safe(str(buttons(page))))

    click_btn(page, "NEW GAME")
    page.wait_for_timeout(1200)
    shot(page, "02_party_picker")

    # try add a 4th DPS if available - optional
    click_btn(page, "START")
    page.wait_for_timeout(2000)
    shot(page, "03_after_start")
    print("after start", safe(str(buttons(page))))

    for _ in range(15):
        btns = buttons(page)
        if "SKIP ALL TIPS" in btns:
            click_btn(page, "SKIP ALL TIPS")
            page.wait_for_timeout(500)
            break
        if "GOT IT" in btns:
            click_btn(page, "GOT IT")
            page.wait_for_timeout(400)
        else:
            break

    shot(page, "04_hub")
    print("hub", safe(str(buttons(page))))

    # Settings
    if click_contains(page, "Settings"):
        page.wait_for_timeout(800)
        shot(page, "05_settings")
        print("settings", safe(str(buttons(page))))
        click_contains(page, "BACK") or click_contains(page, "CLOSE")
        page.wait_for_timeout(500)

    # MORE hub chrome
    if click_contains(page, "MORE"):
        page.wait_for_timeout(800)
        shot(page, "06_more")
        print("more", safe(str(buttons(page))))

    # Try open known hub destinations if listed
    for label in ["SANCTUARY", "MARKET", "FORGE", "BEAST", "GUIDES", "ASCEND"]:
        if click_contains(page, label):
            page.wait_for_timeout(900)
            shot(page, f"07_{label.lower()}")
            print(label, safe(str(buttons(page))[:300]))
            # leave overlay
            for back in ["BACK", "CLOSE", "DONE", "LEAVE", "HUB"]:
                if click_contains(page, back):
                    break
            page.wait_for_timeout(400)
            # if still in overlay, click outside-ish top
            page.mouse.click(415, 40)
            page.wait_for_timeout(300)

    shot(page, "08_hub_before_dungeon")
    if "ENTER DUNGEON" in buttons(page):
        click_btn(page, "ENTER DUNGEON")
        page.wait_for_timeout(2500)
        for _ in range(8):
            if "GOT IT" in buttons(page):
                click_btn(page, "GOT IT")
                page.wait_for_timeout(400)
            elif "SKIP ALL TIPS" in buttons(page):
                click_btn(page, "SKIP ALL TIPS")
                page.wait_for_timeout(400)
            else:
                break
        shot(page, "09_dungeon")
        print("dungeon", safe(str(buttons(page))))

        # Watch combat for a bit — idle game plays itself
        for i in range(12):
            page.wait_for_timeout(5000)
            shot(page, f"10_combat_{i:02d}")
            print(f"t+{(i+1)*5}s", safe(str(buttons(page))[:200]))
            # read save-ish from localStorage if present
            try:
                summary = page.evaluate("""() => {
                  const raw = localStorage.getItem('flutter.idle_party_save_v2');
                  if (!raw) return null;
                  let s = JSON.parse(raw);
                  if (typeof s === 'string') s = JSON.parse(s);
                  return {
                    al: s.ascensionLevel,
                    floor: s.currentFloor ?? s.floor,
                    inDungeon: s.inDungeon,
                    gold: s.gold,
                    bosses: s.bossVictories,
                    heroes: (s.heroes||[]).map(h => (h.classId||'') + ' L' + (h.level||'?'))
                  };
                }""")
                print("save", summary)
                notes.append({"t": (i+1)*5, "save": summary})
            except Exception as e:
                notes.append(f"save err {e}")
    else:
        notes.append("missing ENTER DUNGEON")
        shot(page, "09_no_enter")

    with open(f"{OUT}/notes.json", "w", encoding="utf-8") as f:
        json.dump(notes, f, indent=2, ensure_ascii=False)
    browser.close()
print("done")
