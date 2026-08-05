from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3000)
    # ensureSemantics should already expose buttons
    page.wait_for_selector("flt-semantics[role=button]", timeout=15000)
    buttons = page.locator("flt-semantics[role=button]").all_text_contents()
    print("BUTTONS", buttons)
    cont = page.get_by_role("button", name="CONTINUE")
    print("continue count", cont.count())
    cont.click(force=True, timeout=5000)
    page.wait_for_timeout(2000)
    after = page.locator("flt-semantics[role=button]").all_text_contents()
    print("AFTER", after)
    page.screenshot(path="tool/out/playwright_after_continue.png")
    browser.close()
print("done")
