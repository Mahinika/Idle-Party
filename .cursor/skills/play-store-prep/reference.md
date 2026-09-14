# Play Store prep — reference (read on demand)

Read this file when uploading listing screenshots or a signed AAB via Cursor browser.

## Store screenshots (capture → compose → Console)

Copy + shot order live in [`docs/STORE_LISTING.md`](../../../docs/STORE_LISTING.md).
Helpers: `tool/store_listing/`.

### Recipe (Windows)

```powershell
# 1) First-minute combat save (Sandy F1) + optional AL3 showcase
flutter test tool/store_listing/export_showcase_save_test.dart

# 2) Listing shots still use Flutter web on :8080 (Playwright).
#    Daily playtest is the A56 emulator — see a56-playtest.
# 3) Capture raw 1080×2340 first-minute combat
py -3 tool/store_listing/capture_first_minute.py

# 4) Compose 1080×1920 with top caption band + 512 icon
py -3 tool/store_listing/compose_shots.py
py -3 tool/store_listing/make_listing_icon.py
# → tool/store_listing/out/01_01_combat_a.png, 02_02_combat_b.png, play_icon_512.png
```

### Lessons (do not re-learn)

1. **Shots 1–2 = live first-minute combat** — Sandy floor, starter party. Not
   KEY, not empty hub, not a branded menu card.
2. **Showcase save (AL3)** — later carousel slots (gear / path). Empty hub /
   LOCKED path / +0 forge looks dead in search if used as shot 1.
3. **SharedPreferences web encodes strings** — inject with
   `localStorage.setItem('flutter.idle_party_save_v2', JSON.stringify(raw))`
   (plain JSON → CONTINUE stays disabled / “No save yet”).
   First-minute combat: `add_init_script` *before* boot so autosave cannot
   overwrite; bump `lastUpdated` or Welcome Back eats the first frame.
4. **Prefer Playwright + `__idlePartyClick`** over widget-test `toImage` (Google Fonts)
   or Cursor CDP alone (harder file IO). Phone viewport **360×780 @ DPR 3**.
5. **Material `TabBar` needs bridge** — wrap labels with `MenuChrome.bridgedTab`
   (GEAR / GOLD / ESSENCE sub-tabs) or clicks never leave INCOME/BAG.
6. **Compose captions on top** (~210px), smart vertical crop bias — do not stamp a
   fat bottom bar over the hero of the UI. Captions ≤ ~8 English words.
7. **Play Console upload** — `DOM.setFileInputFiles` is denied. Serve
   `tool/store_listing/` with `py -3 tool/store_listing/serve_upload_cors.py`
   on **9888** (9877 is often poisoned on this box), then CDP `fetch` →
   `DataTransfer` into the phone-screenshots file input. Delete old phone
   shots first. Attach **one PNG at a time** (library recency/dedupe scrambles
   dump-all). If the library says “Behöver beskäras”: Beskär → **9:16 stående**
   (not the default 16:9) → Spara som kopia → **Lägg till**. Appikon **1/1**:
   attach the new 512 from the library, then remove the old icon (never save
   empty). Do not 9:16-crop a 1∶1 icon. Paste short+full from
   `STORE_LISTING.md`. Submit listing → update `PLAY_STORE.md`.

### Upload listing assets (Cursor browser)

1. Serve: `py -3 tool/store_listing/serve_upload_cors.py` → CORS HTTP on **9888**
2. Open `…/main-store-listing` for `com.idleparty.app`
3. Remove existing **Skärmbilder för mobiler**, then attach PNGs **one-by-one** via fetch (combat 01 then 02 first)
4. Set short + full description from `STORE_LISTING.md`
5. Save → Publishing overview → submit for review
6. Kill the local HTTP server

## Upload signed AAB to closed Alpha (Cursor browser)

Owner asked for Play upload → do this (never upload AAB unprompted).

### 1. Build

```bash
# Confirm pubspec versionName+buildNumber matches MetaSystems.currentVersion
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Needs local `android/key.properties` + upload keystore (never commit).

### 2. Serve the AAB with CORS (Windows)

`DOM.setFileInputFiles` is **denied** in Cursor browser CDP — do not retry it.
`python` may be missing from PATH; use **`py -3`**:

```powershell
cd build/app/outputs/bundle/release
py -3 -c @"
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os
os.chdir(os.getcwd())
class CORS(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()
ThreadingHTTPServer(('127.0.0.1', 8765), CORS).serve_forever()
"@
```

Smoke: `curl.exe -I http://127.0.0.1:8765/app-release.aab` → 200 + CORS headers.

### 3. Play Console path

Developer Cognifox / app Idle Party (`com.idleparty.app`):

1. `…/app/…/closed-testing` → **Stängt test - Alpha** → **Hantera kanal**  
   (track id seen: `4700435970090074338`)
2. **Skapa ny version** → prepare page with `input[accept=".aab"]`
3. In the locked Console tab, CDP `Runtime.evaluate`:

```js
(async () => {
  const r = await fetch('http://127.0.0.1:8765/app-release.aab');
  const blob = await r.blob();
  const file = new File([blob], 'app-release.aab', {type: 'application/octet-stream'});
  const input = document.querySelector('input[accept=".aab"]');
  const dt = new DataTransfer();
  dt.items.add(file);
  input.files = dt.files;
  input.dispatchEvent(new Event('change', {bubbles: true}));
  return {count: input.files.length, size: file.size};
})()
```

4. Wait until progress finishes (~90 MB). Version name auto-fills from the bundle.
5. Fill **Viktig information** (`<en-US>…</en-US>`), **Nästa** → review → **Spara**.
6. Dialog → **Öppna översikten** → Publiceringsöversikt → **Skicka in 1 ändring för granskning** → confirm.
7. Page should show **Ändringarna granskas** + Alpha row with the new versionCode. Pre-checks may take ~10–14 min; then Google review.
8. **Kill the `py -3` server** when attach succeeds (do not leave port 8765 open).

### 4. After submit

- Update `docs/PLAY_STORE.md` Operator status (submitted vs live).
- Commit locally; push when the batch needs it.
- Testers keep the previous live Alpha until review publishes the new one.

## itch.io images (HTTPS — localhost CORS will not work)

Play Console is often HTTP-same-origin enough for `127.0.0.1` fetch. **itch.io
is HTTPS.** Do not copy the AAB/listing localhost recipe there.

Full copy + live URLs: [`tool/store_listing/itch/PAGE.md`](../../../tool/store_listing/itch/PAGE.md).

**Dead (do not retry)**

1. CDP `DOM.setFileInputFiles` — denied.
2. Local `py -3` CORS on `127.0.0.1` — mixed content / CORS against itch HTTPS.
3. `browser_fill` or pasting huge `.b64` through the tool — corrupts the payload.

**Working hop (cover + screenshots)**

1. Patch `HTMLInputElement.prototype.click` so **Upload Cover Image** / **Add
   screenshots** do not open the native picker.
2. Host a **complete** `.b64` text file on an HTTPS origin with CORS (last time:
   secret GitHub gist). Fetch it in the locked itch tab.
3. `atob` → `Uint8Array` → `File` → `DataTransfer` → `input.files` + `change`.
4. Delete the gist immediately (`gh gist delete <id> --yes`). Do not recreate
   unless uploading more images. Never commit `tool/store_listing/itch/upload/`.

**Community post** (`Release Announcements`): studio email must be verified;
reCAPTCHA is owner-only (agent cannot tick it). Board needs the itch page URL,
a short summary, and an embedded image or YouTube trailer.
