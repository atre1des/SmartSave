"""Measure and capture the authenticated browser controls using the local emulators."""
import uuid
import os

from playwright.sync_api import expect, sync_playwright

from browser_test import (
    APP, amount, button, capture, fill, heading, prepare, record, save, sign_in,
    snapshot_contains,
)


def compact(control, upper=360):
    expect(control).to_be_visible()
    bounds = control.bounding_box()
    assert 44 <= bounds["width"] <= upper, bounds
    assert bounds["height"] >= 40, bounds
    return bounds


def viewport(page, width, height=1000):
    page.set_viewport_size({"width": width, "height": height})
    page.wait_for_timeout(180)
    assert page.evaluate("document.documentElement.scrollWidth == window.innerWidth")


def run(browser):
    context = browser.new_context(viewport={"width": 1440, "height": 1000},
                                  color_scheme="light")
    prepare(context)
    page = context.new_page()
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(APP)
    expect(heading(page, "Sign in")).to_be_visible(timeout=25000)
    auth = button(page, "Sign in")
    print("Desktop sign-in", compact(auth, 170))
    capture(page, "desktop-authentication.png")
    viewport(page, 390, 844)
    assert auth.bounding_box()["width"] >= 310
    viewport(page, 1440)

    email = f"buttons-{uuid.uuid4().hex[:10]}@example.test"
    sign_in(page, email, register=True)
    add = button(page, "Add transaction")
    print("Desktop add transaction", compact(add, 220))
    capture(page, "after-home-empty.png")
    compact(button(page, "Ask SmartSave"), 220)
    compact(button(page, "Investment Intelligence"), 300)
    add.focus()
    expect(add).to_be_focused()
    add.press("Enter")
    expect(button(page, "Save")).to_be_visible()
    compact(button(page, "Save"), 130)
    compact(button(page, "Cancel"), 130)
    assert button(page, "Save").bounding_box()["x"] > 720
    assert button(page, "Cancel").bounding_box()["x"] < button(page, "Save").bounding_box()["x"]
    capture(page, "desktop-financial-edit.png")
    fill(page, page.get_by_role("textbox", name="Merchant"), "Orchard Market")
    fill(page, amount(page), "1300")
    save(page)
    snapshot_contains(page, "Orchard Market")

    record(page, "Orchard Market").click()
    button(page, "Delete").click()
    snapshot_contains(page, "Delete transaction")
    compact(button(page, "Delete").last, 130)
    capture(page, "desktop-confirmation.png")
    button(page, "Cancel").last.click()
    button(page, "Cancel").click()
    capture(page, "desktop-home-light.png")
    page.emulate_media(color_scheme="dark")
    page.wait_for_timeout(250)
    compact(add, 220)
    capture(page, "desktop-home-dark.png")
    page.emulate_media(color_scheme="light")

    button(page, "Invest").click()
    expect(heading(page, "Investment Intelligence")).to_be_visible()
    compact(button(page, "Ask SmartSave"), 220)
    capture(page, "desktop-invest-light.png")
    button(page, "AI").click()
    expect(heading(page, "Conversation History")).to_be_visible()
    compact(button(page, "New Chat"), 160)
    capture(page, "desktop-ai-chat.png")

    button(page, "My Account").click()
    compact(button(page, "Sync financial records"), 290)
    compact(button(page, "Export local data"), 240)
    for label, heading_text, sync in [
        ("Русский", "Язык", "Синхронизировать финансовые записи"),
        ("Қазақша", "Тіл", "Қаржы жазбаларын синхрондау"),
    ]:
        page.get_by_role("checkbox", name=label, exact=True).click()
        expect(heading(page, heading_text)).to_be_visible(timeout=15000)
        compact(button(page, sync))
    page.get_by_role("checkbox", name="English", exact=True).click()
    expect(heading(page, "Language")).to_be_visible(timeout=15000)

    for width in (1024, 768, 390):
        viewport(page, width, 844)
        button(page, "Home").click()
        expect(heading(page, "Your finances")).to_be_visible()
        # Scroll the Flutter viewport to the action before measuring its hit box.
        page.mouse.move(width / 2, 540)
        for _ in range(5):
            bounds = add.bounding_box()
            if bounds and 120 < bounds["y"] < 730 and bounds["height"] >= 40:
                break
            page.mouse.wheel(0, -230 if bounds and bounds["y"] < 120 else 230)
            page.wait_for_timeout(150)
        expect(add).to_be_visible()
        if width == 1024:
            compact(add, 220)
        else:
            assert add.bounding_box()["width"] >= width * .75
        add.click()
        expect(button(page, "Save")).to_be_visible()
        button(page, "Cancel").click()
        assert not errors, errors
        print(f"{width}px: layout, navigation and editor passed")
    print("PASS EN/KK/RU, light/dark, desktop keyboard activation and compact auth")
    context.close()


if __name__ == "__main__":
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=os.environ.get("SMARTSAVE_BROWSER_BINARY"),
        )
        run(browser)
        browser.close()
