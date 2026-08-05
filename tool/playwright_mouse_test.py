from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 830, "height": 925})
    page.goto("http://localhost:8080/", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3500)  # past 900ms input unlock + enter anim
    page.wait_for_selector("flt-semantics[role=button]", timeout=15000)
    box = page.get_by_role("button", name="CONTINUE").bounding_box()
    print("box", box)
    x = box["x"] + box["width"] / 2
    y = box["y"] + box["height"] / 2
    # Real CDP mouse path
    page.mouse.move(x, y)
    page.mouse.down()
    page.mouse.up()
    page.wait_for_timeout(2000)
    after = page.locator("flt-semantics[role=button]").all_text_contents()
    print("AFTER mouse", after)
    page.screenshot(path="tool/out/playwright_mouse.png")

    # If still stuck, try double approach on glass/canvas via JS coords + mouse
    if "CONTINUE" in after:
        print("retry with longer press")
        page.mouse.click(x, y, delay=80)
        page.wait_for_timeout(2000)
        after2 = page.locator("flt-semantics[role=button]").all_text_contents()
        print("AFTER2", after2)
        page.screenshot(path="tool/out/playwright_mouse2.png")
    browser.close()
print("done")
