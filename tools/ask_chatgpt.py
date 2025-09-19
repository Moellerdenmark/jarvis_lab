import sys, json, time
from pathlib import Path
from argparse import ArgumentParser
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

parser = ArgumentParser()
parser.add_argument("--prompt", help="Tekst der skal sendes til ChatGPT")
parser.add_argument("--read", action="store_true", help="Læs sidste assistant-svar")
parser.add_argument("--timeout", type=int, default=25_000)
args = parser.parse_args()

ROOT = Path(r"C:\Users\gubbi\jarvis_core")
PROFILE = ROOT / "tools" / "pw_profile"  # persistent login
PROFILE.mkdir(parents=True, exist_ok=True)

def last_assistant_text(page):
    # Dæk flere varianter af siden
    sels = [
        "[data-message-author-role='assistant']",
        "[data-testid='assistant-response']",
        ".markdown.prose",
        ".prose",
        "article"
    ]
    # Saml tekst og returnér sidste non-empty
    texts = []
    for sel in sels:
        for el in page.query_selector_all(sel):
            t = (el.inner_text() or "").strip()
            if t:
                texts.append(t)
    return texts[-1] if texts else ""

with sync_playwright() as p:
    # persistent context => login bevares i PROFILE
    ctx = p.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE),
        headless=False,
        args=["--disable-dev-shm-usage"]
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.set_default_timeout(args.timeout)

    # Åbn ChatGPT
    page.goto("https://chatgpt.com/", wait_until="domcontentloaded")

    # Hvis der ikke er inputfelt, er du nok ikke logget ind -> vent på login
    def find_input():
        el = page.query_selector("textarea, [contenteditable='true']")
        return el

    if not find_input():
        # Giv brugeren mulighed for at logge ind manuelt
        try:
            page.wait_for_selector("textarea, [contenteditable='true']", timeout=args.timeout)
        except PWTimeout:
            print("[LOGIN] Log ind i vinduet og kør kommandoen igen.", flush=True)
            sys.exit(2)

    if args.prompt:
        # Skriv og send
        inp = find_input()
        if inp and inp.get_attribute("contenteditable") == "true":
            inp.click()
            page.keyboard.press("Control+A")
            page.keyboard.type(args.prompt)
            page.keyboard.press("Enter")
        elif inp:
            inp.click()
            inp.fill(args.prompt)
            # klik send-knappen hvis den findes, ellers Enter
            btn = page.query_selector("[data-testid='send-button'], button[aria-label*='Send' i], form button[type='submit']")
            if btn:
                btn.click()
            else:
                page.keyboard.press("Enter")
        else:
            print("[ERR] Ingen inputfelt fundet.", flush=True)
            sys.exit(3)

        # Vent på, at et nyt svar dukker op (spinner -> svar)
        # Lidt robust polling:
        start = time.time()
        last = ""
        while time.time() - start < (args.timeout/1000.0 + 10):
            time.sleep(0.8)
            t = last_assistant_text(page)
            if t and t != last:
                last = t
                # ofte kommer svaret lagvis; vi fortsætter lidt endnu
            # stop hvis der ikke har ændret sig i 2 sek
            if last and time.time() - start > 3:
                # heuristik: hvis der ikke er ændring i ~1.6s, antag færdig
                t2 = last_assistant_text(page)
                time.sleep(0.8)
                t3 = last_assistant_text(page)
                if t3 == t2:
                    break
        print(last, flush=True)
        ctx.close()
        sys.exit(0)

    if args.read:
        print(last_assistant_text(page), flush=True)
        ctx.close()
        sys.exit(0)

    # Hvis ingen flags, skriv hjælpetekst
    print("Brug: --prompt 'tekst' eller --read", flush=True)
    ctx.close()
