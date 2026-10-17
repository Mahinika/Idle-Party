# Play Store prep — reference (read on demand)

## Play API (this is the upload)

Service account `play-console@idle-party-505709.iam.gserviceaccount.com`.
Key stays **outside git**: `~/.config/idle-party/play-console.json`
(`%USERPROFILE%\.config\idle-party\play-console.json` on Windows). Do not
mint another key. Do not print `private_key`.

Use `py -3`. Sign a JWT (PyJWT) for both scopes

- `https://www.googleapis.com/auth/androidpublisher`
- `https://www.googleapis.com/auth/playdeveloperreporting`

Exchange it at the key's `token_uri`. Call as Bearer. On Windows, start the
script with `sys.stdout.reconfigure(encoding="utf-8")` or a Korean or
Japanese title crashes the console and can hide a later error.

Package `com.idleparty.app`. Base host
`https://androidpublisher.googleapis.com`.

`CAN_MANAGE_PUBLIC_APKS` is granted. **Never commit an edit or upload an AAB
unless the owner asks that turn.**

### Reads (always delete the edit)

```text
POST /androidpublisher/v3/applications/com.idleparty.app/edits
body {}
→ { "id": "<editId>" }

GET  .../edits/{id}/tracks/production
GET  .../edits/{id}/listings
GET  .../edits/{id}/listings/{lang}/phoneScreenshots
GET  .../edits/{id}/listings/{lang}/sevenInchScreenshots
GET  .../edits/{id}/listings/{lang}/tenInchScreenshots
GET  .../edits/{id}/listings/{lang}/icon
GET  .../edits/{id}/listings/{lang}/featureGraphic

DELETE .../edits/{id}
```

Also without an edit:

- `GET /androidpublisher/v3/applications/com.idleparty.app/reviews` — about the last week
- `GET .../applications/com.idleparty.app/tracks/production/releases` (also `alpha`, `internal`)
- `GET .../applications/com.idleparty.app/oneTimeProducts` — shop products
- Crash/ANR: `POST .../playdeveloperreporting/v1beta1/apps/com.idleparty.app/crashRateMetricSet:query` (same shape for `anrRateMetricSet`). `endTime` must be on or before freshness

Reply: `POST .../reviews/{reviewId}:reply` with `replyText`. English, like a
person, only the review they named. List the review again and read the
developer comment before saying it posted.

Not this API: device acquisitions, first opens, rating average, D1. Do not
invent those numbers. `purchases/voidedpurchases` has returned 401 — do not
invent revenue from it.

### One release edit

Do the whole release in one edit. Commit only when every step below returned
2xx. On any failure, `DELETE` the edit and stop.

1. `POST /androidpublisher/v3/applications/com.idleparty.app/edits` with `{}`.
2. Images, then listing text, then the AAB, then the track.
3. `POST .../edits/{id}:commit`.

Image types: `phoneScreenshots`, `sevenInchScreenshots`,
`tenInchScreenshots`, `icon`, `featureGraphic`.

Delete every image of one type (tablet wipe, or before replacing phone shots):

```text
DELETE /androidpublisher/v3/applications/com.idleparty.app/edits/{id}/listings/{lang}/{imageType}
```

Upload one PNG (phone shots **in order** `01` … `08`, then icon, then feature graphic):

```text
POST /upload/androidpublisher/v3/applications/com.idleparty.app/edits/{id}/listings/{lang}/{imageType}?uploadType=media
Content-Type: image/png
body: raw PNG bytes
```

Local files:

| Play type | File |
|-----------|------|
| `phoneScreenshots` | `tool/store_listing/out/01_01_combat_a.png` … `08_08_ascend.png` |
| `icon` | `tool/store_listing/out/play_icon_512.png` |
| `featureGraphic` | `tool/store_listing/marketing/01_feature_graphic_1024x500.png` |

Phone order is the upload order after `deleteall`. Do not 9:16-crop the icon.
Check every locale. Images on `en-US` are what other locales inherit when
their own lists are empty. Delete `sevenInchScreenshots` and
`tenInchScreenshots` wherever the list is not empty.

Listing text (`PUT`, replaces the listing — send the video back or it clears):

```text
PUT /androidpublisher/v3/applications/com.idleparty.app/edits/{id}/listings/{lang}
{
  "language": "en-US",
  "title": "Idle Party: Idle RPG",
  "shortDescription": "<from docs/STORE_LISTING.md, ≤80>",
  "fullDescription": "<from docs/STORE_LISTING.md>",
  "video": "https://www.youtube.com/watch?v=cyBlN3HCR48"
}
```

English is `docs/STORE_LISTING.md`. Other locales are
`tool/store_listing/growth/LOCALES.md`. Update a locale when its text still
names a system the game no longer uses (Gauntlet, not Infinity Gauntlet).
Leave a locale alone when it already matches.

Signed AAB:

```text
POST /upload/androidpublisher/v3/applications/com.idleparty.app/edits/{id}/bundles?uploadType=media
Content-Type: application/octet-stream
body: build/app/outputs/bundle/release/app-release.aab
→ { "versionCode": 227 }
```

Production track. Read it first. Send **one** `completed` release. A second
`completed` release is rejected. `tracks.update` replaces the track object.

```text
PUT /androidpublisher/v3/applications/com.idleparty.app/edits/{id}/tracks/production
{
  "track": "production",
  "releases": [{
    "name": "1.13.1",
    "status": "completed",
    "versionCodes": ["227"],
    "releaseNotes": [{ "language": "en-US", "text": "<What's New, ≤500>" }]
  }]
}
```

What's New covers this version **and** any version that was built but never
sent. Players jump from the live track to this one.

Commit:

```text
POST /androidpublisher/v3/applications/com.idleparty.app/edits/{id}:commit
```

After commit, `docs/PLAY_STORE.md` says **submitted**. Call it live only
after a later read shows that versionCode `completed`.

### Reusable script

Pipe this shape to `py -3 -`. Fill `LANGS`, the file list, the listing
bodies, and the release notes from the docs. Do not commit until `ready`
is true.

```python
import json, sys, time, urllib.parse, urllib.request, urllib.error
from pathlib import Path
import jwt

sys.stdout.reconfigure(encoding="utf-8")
PKG = "com.idleparty.app"
HOST = "https://androidpublisher.googleapis.com"
KEY = json.loads(Path.home().joinpath(".config/idle-party/play-console.json").read_text(encoding="utf-8"))
now = int(time.time())
token = jwt.encode(
    {"iss": KEY["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
     "aud": KEY["token_uri"], "iat": now, "exp": now + 3600},
    KEY["private_key"], algorithm="RS256")
req = urllib.request.Request(KEY["token_uri"], data=urllib.parse.urlencode({
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": token}
).encode(), method="POST")
access = json.load(urllib.request.urlopen(req))["access_token"]

def call(method, path, body=None, content_type="application/json", upload=False):
    url = ("https://androidpublisher.googleapis.com/upload" if upload else HOST) + path
    data = body if isinstance(body, bytes) else (None if body is None else json.dumps(body).encode())
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", f"Bearer {access}")
    if data is not None:
        r.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(r) as res:
            raw = res.read()
            return res.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} {e.code} {e.read()[:500]!r}")

edit = call("POST", f"/androidpublisher/v3/applications/{PKG}/edits", {})[1]["id"]
base = f"/androidpublisher/v3/applications/{PKG}/edits/{edit}"
try:
    # deleteall tablet + old phone shots, then upload PNGs in order
    # call("DELETE", f"{base}/listings/en-US/sevenInchScreenshots")
    # call("POST", f"{base}/listings/en-US/phoneScreenshots?uploadType=media",
    #      png_bytes, "image/png", upload=True)
    # call("PUT", f"{base}/listings/en-US", listing)
    # call("POST", f"{base}/bundles?uploadType=media", aab_bytes,
    #      "application/octet-stream", upload=True)
    # call("PUT", f"{base}/tracks/production", track)
    # call("POST", f"{base}:commit")
    raise SystemExit("fill the steps, then commit")
except BaseException:
    call("DELETE", base)
    raise
```

The comments are the steps. A real run deletes the edit in `finally` only
when it did **not** commit. A committed edit must not be deleted.

## Browser fallback (only if the key cannot call the API)

Do not use this when the service account works. `DOM.setFileInputFiles` is
denied. One PNG at a time. Do not 9:16-crop a 1:1 icon.

```powershell
py -3 tool/store_listing/serve_upload_cors.py
```

That serves `tool/store_listing/` with CORS on port **9888**. Fetch each PNG
in the locked Console tab into a `DataTransfer` on the phone-screenshot
input. For an AAB, the same idea on port **8765** against
`input[accept=".aab"]`. Kill the server when the attach finishes. Production
is the track, not closed Alpha.

## Store screenshots (capture)

Copy and shot order: [`docs/STORE_LISTING.md`](../../../docs/STORE_LISTING.md).
Shoot with the `store-listing-shoot` skill
(`tool/store_listing/capture_a56_shots.py`), then

```powershell
py -3 tool/store_listing/compose_shots.py
py -3 tool/store_listing/make_listing_icon.py
py -3 tool/store_listing/make_feature_graphic.py
```

Look at all eight files in `tool/store_listing/out/` and
`tool/store_listing/marketing/01_feature_graphic_1024x500.png` before upload.
Shot 8 is the ASCEND? dialog. The feature graphic shows the whole party.

Shots 1–2 are the Sandy first minute, not KEY and not a menu card.

## itch.io images (HTTPS — localhost CORS will not work)

Play Console is not itch. Do not copy the localhost recipe there.

Full copy: [`tool/store_listing/itch/PAGE.md`](../../../tool/store_listing/itch/PAGE.md).

**Dead (do not retry)**

1. CDP `DOM.setFileInputFiles` — denied.
2. Local `py -3` CORS on `127.0.0.1` — mixed content against itch HTTPS.
3. Pasting a huge `.b64` through the tool — corrupts the payload.

**Working hop (cover + screenshots)**

1. Patch `HTMLInputElement.prototype.click` so the picker does not open.
2. Host a complete `.b64` on an HTTPS origin with CORS (last time: a secret gist). Fetch it in the locked itch tab.
3. `atob` → `File` → `DataTransfer` → `input.files` + `change`.
4. Delete the gist immediately. Never commit `tool/store_listing/itch/upload/`.

**Community post:** studio email must be verified. reCAPTCHA is owner-only.
