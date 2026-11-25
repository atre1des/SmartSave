"""Run against the loopback web build and Firebase emulators. Uses only disposable data."""
import json
import os
import re
import time
import uuid
from pathlib import Path
from urllib.request import Request, urlopen

from playwright.sync_api import expect, sync_playwright

APP = "http://127.0.0.1:8613"
AUTH = "http://127.0.0.1:8610"
PROJECT = "demo-smartsave-web"
SDK = os.environ.get("SMARTSAVE_FIREBASE_SDK_MIRROR")
SCREENSHOTS = os.environ.get("SMARTSAVE_TEST_SCREENSHOTS")
PASSWORD = "disposable-emulator-password"


def verify(email):
    with urlopen(f"{AUTH}/emulator/v1/projects/{PROJECT}/oobCodes", timeout=10) as response:
        entries = json.load(response)["oobCodes"]
    code = [row["oobCode"] for row in entries if row.get("email") == email][-1]
    request = Request(
        f"{AUTH}/identitytoolkit.googleapis.com/v1/accounts:update?key=emulator-only",
        data=json.dumps({"oobCode": code}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=10) as response:
        assert response.status == 200


def button(page, name):
    return page.get_by_role("button", name=name, exact=True)


def heading(page, name):
    return page.get_by_role("heading", name=name, exact=True)


def prepare(context):
    if SDK:
        def mirror(route):
            filename = route.request.url.rsplit("/", 1)[-1]
            path = Path(SDK) / filename
            if not path.is_file():
                route.abort()
                return
            route.fulfill(path=str(path), content_type="text/javascript",
                          headers={"Access-Control-Allow-Origin": APP})
        context.route("https://www.gstatic.com/firebasejs/11.9.1/*", mirror)


def fill(page, field, value):
    page.bring_to_front()
    field.click()
    page.keyboard.press("Control+A")
    page.keyboard.insert_text(value)
    expect(field).to_have_value(value)


def sign_in(page, email, register=False):
    page.goto(APP)
    expect(heading(page, "Sign in")).to_be_visible(timeout=25000)
    if register:
        button(page, "Sign up").click()
        expect(heading(page, "Sign up")).to_be_visible()
    fill(page, page.get_by_role("textbox", name="Email", exact=True), email)
    fill(page, page.get_by_role("textbox", name="Password", exact=True), PASSWORD)
    button(page, "Sign up" if register else "Sign in").click()
    if register:
        expect(heading(page, "Verify your email")).to_be_visible(timeout=15000)
        button(page, "Resend verification email").click()
        page.wait_for_timeout(700)
        verify(email)
        button(page, "I've verified my email").click()
    expect(heading(page, "Your finances")).to_be_visible(timeout=25000)


def save(page):
    button(page, "Save").click()
    expect(button(page, "Save")).to_have_count(0, timeout=16000)


def amount(page):
    return page.get_by_role("textbox", name=re.compile("Amount"))


def record(page, name):
    return page.get_by_role("button", name=re.compile(name))


def snapshot_contains(page, text, timeout=10000):
    deadline = time.monotonic() + timeout / 1000
    while time.monotonic() < deadline:
        current = page.locator("body").aria_snapshot()
        if text in current:
            return current
        page.wait_for_timeout(50)
    raise AssertionError(f"{text!r} missing from accessibility tree: {current}")


def capture(page, name):
    if SCREENSHOTS:
        folder = Path(SCREENSHOTS)
        folder.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(folder / name), animations="disabled")


def run(browser):
    context = browser.new_context(viewport={"width": 1440, "height": 1000})
    prepare(context)
    page = context.new_page()
    uid = uuid.uuid4().hex[:10]
    email = f"web-{uid}@example.test"
    other = f"other-{uid}@example.test"
    sign_in(page, email, register=True)
    assert "Fictional preview" not in page.locator("body").aria_snapshot()
    print("PASS Auth emulator registration and verification")

    button(page, "Add transaction").click()
    fill(page, page.get_by_role("textbox", name=re.compile("Merchant")), "Disposable groceries")
    fill(page, amount(page), "1200")
    button(page, "Save").dblclick()
    expect(button(page, "Save")).to_have_count(0, timeout=16000)
    expect(record(page, "Disposable groceries")).to_have_count(1)
    snapshot_contains(page, "Disposable groceries")

    button(page, "New goal").click()
    fill(page, page.get_by_role("textbox", name="Goal name", exact=True), "Disposable goal")
    fill(page, page.get_by_role("textbox", name="Target", exact=False), "10000")
    save(page)
    button(page, "Add money").click()
    fill(page, amount(page), "1500")
    save(page)
    snapshot_contains(page, "1 500")
    button(page, "Edit budget").click()
    fill(page, amount(page), "2000")
    save(page)
    snapshot_contains(page, "2 000")
    print("PASS transaction, goal, contribution and budget saves")

    sibling = context.new_page()
    sign_in(sibling, email)
    record(page, "Disposable groceries").click()
    record(sibling, "Disposable groceries").click()
    fill(page, amount(page), "1300")
    save(page)
    fill(sibling, amount(sibling), "1600")
    button(sibling, "Save").click()
    snapshot_contains(sibling, "Some records need review")
    button(sibling, "Cancel").click()
    sibling.close()
    print("PASS stale edit rejected across two browser tabs")

    page.reload()
    expect(heading(page, "Your finances")).to_be_visible(timeout=20000)
    snapshot_contains(page, "1 300")
    button(page, "Add transaction").click()
    fill(page, page.get_by_role("textbox", name="Merchant"), "Offline attempt")
    fill(page, amount(page), "777")
    context.set_offline(True)
    button(page, "Save").click()
    expect(button(page, "Save")).to_be_enabled(timeout=10000)
    button(page, "Cancel").click()
    context.set_offline(False)
    page.reload()
    expect(heading(page, "Your finances")).to_be_visible(timeout=20000)
    assert "Offline attempt" not in page.locator("body").aria_snapshot()
    print("PASS duplicate click protection and offline write exclusion")
    capture(page, "authenticated-home.png")
    page.emulate_media(color_scheme="dark")
    page.wait_for_timeout(250)
    capture(page, "authenticated-home-dark.png")
    page.emulate_media(color_scheme="light")

    button(page, "My Account").click()
    button(page, "Export local data").click()
    snapshot_contains(page, "Local data export")
    button(page, "Close").click()
    page.get_by_role("checkbox", name="Русский", exact=True).click()
    expect(heading(page, "Язык")).to_be_visible(timeout=15000)
    page.reload()
    expect(heading(page, "Ваши финансы")).to_be_visible(timeout=20000)
    button(page, "Мой аккаунт").click()
    page.get_by_role("checkbox", name="English", exact=True).click()
    expect(heading(page, "Language")).to_be_visible(timeout=15000)
    print("PASS server-backed export and persisted per-account locale")
    scale = context.new_cdp_session(page)
    scale.send("Emulation.setPageScaleFactor", {"pageScaleFactor": 1.25})
    assert page.evaluate("visualViewport.scale") > 1
    scale.send("Emulation.setPageScaleFactor", {"pageScaleFactor": 1})
    scale.detach()

    button(page, "AI").click()
    snapshot_contains(page, "SmartSave Assistant")
    field = page.get_by_role("textbox", name="Ask about your SmartSave data")
    field.click()
    page.keyboard.insert_text("Қазақша сұрақ")
    page.keyboard.press("Shift+Enter")
    page.keyboard.insert_text("Вторая строка")
    expect(field).to_have_value("Қазақша сұрақ\nВторая строка")
    page.keyboard.press("Enter")
    first = snapshot_contains(page, "Қазақша: бірінші бөлік")
    assert "Русский: вторая часть" not in first
    snapshot_contains(page, "Русский: вторая часть")
    page.wait_for_timeout(2500)
    capture(page, "authenticated-chat.png")
    page.reload()
    expect(heading(page, "Your finances")).to_be_visible(timeout=20000)
    button(page, "AI").click()
    record(page, "Қазақша сұрақ").click()
    snapshot_contains(page, "Русский: вторая часть")
    for prompt, notice in [("fixture-401", "verify your sign-in"), ("fixture-429", "7s")]:
        fill(page, field, prompt)
        button(page, "Send question").click()
        snapshot_contains(page, notice)
    print("PASS browser incremental SSE, keyboard multiline, history reload, HTTP 401 and 429")

    if os.environ.get("SMARTSAVE_TEST_REPLAY_PROBE"):
        page.goto(f"{APP}/probe/")
        page.locator("flt-semantics-placeholder").evaluate("(element) => element.click()")
        snapshot_contains(page, "PASS transaction and contribution replay", timeout=25000)
        print("PASS direct repository replays kept one transaction and one contribution")
        page.goto(APP)
        expect(heading(page, "Your finances")).to_be_visible(timeout=20000)
    page.set_viewport_size({"width": 390, "height": 844})
    expect(button(page, "My Account")).to_be_visible()
    button(page, "My Account").click()
    page.set_viewport_size({"width": 1440, "height": 1000})
    button(page, "Sign out").click()
    expect(heading(page, "Sign in")).to_be_visible()
    fill(page, page.get_by_role("textbox", name="Email", exact=True), email)
    button(page, "Forgot password?").click()
    snapshot_contains(page, "Password reset email sent")
    sign_in(page, other, register=True)
    assert "Disposable groceries" not in page.locator("body").aria_snapshot()
    button(page, "AI").click()
    assert "Қазақша сұрақ" not in page.locator("body").aria_snapshot()
    print("PASS sign-out and account switching isolation")
    context.close()


if __name__ == "__main__":
    with sync_playwright() as playwright:
        browser_name = os.environ.get("SMARTSAVE_TEST_BROWSER", "chromium")
        executable = os.environ.get("SMARTSAVE_BROWSER_BINARY")
        browser = getattr(playwright, browser_name).launch(executable_path=executable)
        run(browser)
        browser.close()
