from playwright.sync_api import sync_playwright
import json

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)
    page.wait_for_selector("flt-semantics[role=button]", timeout=15000)

    skip = page.get_by_role("button", name="SKIP")
    if skip.count() > 0:
        box = skip.first.bounding_box()
        if box:
            page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2, delay=40)
            page.wait_for_timeout(800)

    # Check if CONTINUE is disabled via aria
    for name in ["CONTINUE", "NEW GAME"]:
        loc = page.get_by_role("button", name=name)
        handle = loc.element_handle()
        info = handle.evaluate("""el => ({
          ariaDisabled: el.getAttribute('aria-disabled'),
          disabled: el.getAttribute('disabled'),
          tabindex: el.getAttribute('tabindex'),
          pe: getComputedStyle(el).pointerEvents,
          html: el.outerHTML.slice(0,250)
        })""")
        print(name, info)

    # Click NEW GAME with real mouse
    box = page.get_by_role("button", name="NEW GAME").bounding_box()
    x = box["x"] + box["width"] / 2
    y = box["y"] + box["height"] / 2
    print("click NEW GAME", x, y)
    page.mouse.click(x, y, delay=50)
    page.wait_for_timeout(2500)
    after = page.locator("flt-semantics[role=button]").all_text_contents()
    print("AFTER NEW GAME", after)
    page.screenshot(path="tool/out/playwright_newgame.png")
    browser.close()
print("done")
