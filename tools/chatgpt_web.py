import argparse, os, sys, time, datetime
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", required=True)
    p.add_argument("--prompt", default="")
    p.add_argument("--login-only", action="store_true")
    p.add_argument("--headless", action="store_true")
    p.add_argument("--timeout", type=int, default=180)
    args = p.parse_args()

    out_chat = Path(args.root) / "out" / "chatgpt"
    out_chat.mkdir(parents=True, exist_ok=True)
    profile_dir = Path(args.root) / "out" / "browser" / "chatgpt_profile"
    profile_dir.mkdir(parents=True, exist_ok=True)

    # Lazy import + install tip
    try:
        from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout
    except Exception as e:
        print(f"[ERR] Playwright mangler: {e}", file=sys.stderr)
        sys.exit(2)

    def ts():
        return datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")

    with sync_playwright() as pw:
        # Persistent profil → login huskes
        browser = pw.chromium.launch_persistent_context(
            user_data_dir=str(profile_dir),
            headless=args.headless,
            args=[]
        )
        page = browser.new_page()
        page.set_default_timeout(args.timeout * 1000)

        page.goto("https://chatgpt.com/")
        # Hvis login-only: giv tid til at logge ind manuelt
        if args.login_only:
            print("[INFO] Login-vindue åbent. Log ind i den viste browser. Luk ikke scriptet.", file=sys.stderr)
            # Vent på at hovedchatten er klar (textarea el.lign.)
            try:
                # en af disse findes typisk når man er på chat-siden
                page.wait_for_selector("textarea, div[role='textbox']", timeout=args.timeout*1000)
            except PWTimeout:
                pass
            # Behold browseren åben lidt
            time.sleep(3)
            print("[INFO] Login-setup færdig.", file=sys.stderr)
            return

        # Hvis der er prompt: send den og læs svar
        prompt = (args.prompt or "").strip()
        if not prompt:
            print("", end="")
            return

        # Tæl eksisterende assistent-svar (for at vente på et nyt)
        def count_assistant():
            return len(page.query_selector_all("div[data-message-author-role='assistant']"))

        before = count_assistant()

        # Find inputfelt og send
        # Prøv textarea først
        box = page.query_selector("textarea")
        if box:
            box.click()
            box.fill(prompt)
            box.press("Enter")
        else:
            # fallback: contenteditable
            box2 = page.query_selector("div[role='textbox']")
            if not box2:
                raise RuntimeError("Kunne ikke finde inputfelt på chatgpt.com")
            box2.click()
            page.keyboard.type(prompt)
            page.keyboard.press("Enter")

        # Vent på et nyt assistent-svar
        page.wait_for_function(
            "(before) => document.querySelectorAll(\"div[data-message-author-role='assistant']\").length > before",
            arg=before, timeout=args.timeout*1000
        )

        nodes = page.query_selector_all("div[data-message-author-role='assistant']")
        reply = nodes[-1].inner_text().strip() if nodes else ""

        # Gem til filer
        last_path = out_chat / "last_reply.txt"
        chat_path = out_chat / f"chat_{ts()}.txt"
        with open(last_path, "w", encoding="utf-8") as f:
            f.write(reply)
        with open(chat_path, "w", encoding="utf-8") as f:
            f.write(f"You:\n{prompt}\n\nAssistant:\n{reply}\n")

        print(reply, end="")

        # hold konteksten åben lidt så cookies flushes
        time.sleep(1)
        browser.close()

if __name__ == "__main__":
    main()
