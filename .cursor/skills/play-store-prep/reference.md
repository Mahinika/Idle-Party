# Play Store prep — reference (read on demand)

Read this file when uploading listing screenshots or a signed AAB via Cursor browser.

## Store screenshots (capture → compose → Console)

Copy + shot order live in [`docs/STORE_LISTING.md`](../../../docs/STORE_LISTING.md).
Helpers: `tool/store_listing/`.

### Recipe (Windows)

```powershell
# 1) Showcase save (AL3 / unlocked World Path — not empty day-one)
flutter test tool/store_listing/export_showcase_save_test.dart

# 2) Listing shots still use Flutter web on :8080 (Playwright).
#    Daily playtest is the A56 emulator — see a56-playtest.
# 3) Capture raw 1080×2340 phone shots
py -3 tool/store_listing/capture_playwright.py

# 4) Compose 1080×1920 with top caption band
py -3 tool/store_listing/compose_shots.py
# → tool/store_listing/out/01_01_hub.png … 06_06_power.png
```

### Lessons (do not re-learn)

1. **Showcase save, not AL0** — empty hub / LOCKED path / +0 forge looks dead in search.
2. **SharedPreferences web encodes strings** — inject with
   `localStorage.setItem('flutter.idle_party_save_v2', JSON.stringify(raw))`
   (plain JSON → CONTINUE stays disabled / “No save yet”).
3. **Prefer Playwright + `__idlePartyClick`** over widget-test `toImage` (Google Fonts)
   or Cursor CDP alone (harder file IO). Phone viewport **360×780 @ DPR 3**.
4. **Material `TabBar` needs bridge** — wrap labels with `MenuChrome.bridgedTab`
   (GEAR / GOLD / ESSENCE sub-tabs) or clicks never leave INCOME/BAG.
5. **Compose captions on top** (~210px), smart vertical crop bias — do not stamp a
   fat bottom bar over the hero of the UI. Captions ≤ ~8 English words.
6. **Play Console upload** — `DOM.setFileInputFiles` is denied. Serve `out/` with
   CORS (`py -3` on e.g. `127.0.0.1:9877`), then CDP `fetch` → `DataTransfer` into
   the phone-screenshots file input. Delete old phone shots first (aria
   “Ta bort Skärmbilder för mobiler”). Paste short+full from `STORE_LISTING.md`
   (no forever-free / no-ads promises). Submit listing → update `PLAY_STORE.md`.

### Upload listing assets (Cursor browser)

1. Serve: `cd tool/store_listing/out` → CORS HTTP on **9877**
2. Open `…/main-store-listing` for `com.idleparty.app`
3. Remove existing **Skärmbilder för mobiler**, then attach the six PNGs via fetch
4. Set short + full description from `STORE_LISTING.md`
5. Save → Publishing overview → submit for review
6. Kill the local HTTP server

## Upload signed AAB to closed Alpha (Cursor browser)

Owner asked → do this (ask before push/tag; Play upload is OK when they ask).

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
- Commit locally; ask before push.
- Testers keep the previous live Alpha until review publishes the new one.
