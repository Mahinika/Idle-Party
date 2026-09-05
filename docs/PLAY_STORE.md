# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ GitHub Releases | Tag `v*` → APK/AAB via `build-apk.yml` |
| Play Console app | ✅ Exists | `com.idleparty.app` — listing + closed Alpha |
| Closed testing | ⏳ submit | Working ship **1.12.96+125** — Alpha AAB upload this pass (SHOP Coming later + POWER wipe tips + production polish backlog). Previous Alpha note **1.12.87 (116)** / live may lag until review. Alpha countries: all + rest of world. |
| Production | ⏳ access review | **Production-access application submitted 2026-09-04 ~16:54**. Track still locked until Google grants access. Upload production AAB **1.12.96+125** (or newer) after IARC ads + access. |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit). Workflow now writes keystore to `android/upload-keystore.jks` (matches `storeFile=../upload-keystore.jks`). **v1.12.52 GitHub AAB was debug-signed** — Play used a local upload rebuild; re-tag/rebuild after secrets path fix. |
| Privacy URL opens in browser | ✅ | Console: `docs/PRIVACY.md` on GitHub (`main` preferred after merge; still OK on feature branch until then). |
| Data safety form | ⏳ review | Updated 2026-08-21 for AdMob (device IDs collected+shared, advertising purpose) + Advertising ID declaration Yes. Submitted with Alpha **57**. |
| IARC / content rating | ⏳ ads | Questionnaire said **no ads** (2026-08-08). **Before production:** re-answer ads (hub POWERUPS). Agent cannot open content-ratings (Console redirects to app-list) — owner: Idle Party → **Policy → App content → Content ratings**. |
| Play Games Services | ✅ | Published. Saved Games on; App ID `986358854278`; 2026-08 boards wired; OAuth + Android credential + test user. Category Role Playing; icon + feature graphic from `app_icon`. Remaining: smoke on a Play-installed closed-test build near ship line. |
| Store listing copy (EN) | ✅ | Default locale **en-US only**. Short + full from `docs/STORE_LISTING.md` (Lv100 endgame + World Path level gates). |
| Screenshots + feature graphic | ✅ phone | **Phone screenshots attached** on main listing (2026-09-04 check: 8 phone slots, Save idle = already live). Composed set also in `tool/store_listing/out/` (6×1080×1920). Feature graphic + icon live. |

## Production gate (12 × 14)

Track closed testers who **install from Play** and stay opted in:

- [x] **12** unique testers enrolled on closed track
- [x] **14 consecutive days** with at least one tester active — production-access **application submitted 2026-09-04** (Google reviewing)
- [x] Owner played **1.12.87+** on A56 (owner OK 2026-09-04)
- [x] Phone screenshots attached on listing (verified 2026-09-04 — slots filled, Save idle)
- [ ] IARC ads questionnaire re-done if Console prompts after AdMob / before production AAB
- [ ] Production access granted by Google → upload production AAB **1.12.96+125** or newer
- [ ] Owner play OK on the production candidate build (A56 save) before upload
- [ ] After production live: AdMob store-link Idle Party

### Production AAB upload checklist (agent + owner)

1. Confirm IARC ads re-answered and production track unlocked.
2. `flutter build appbundle --release` with upload keystore (or tag `v*` after CI signing verified).
3. Upload via play-store-prep CORS recipe → Production track (not Alpha).
4. Release notes from `docs/STORE_LISTING.md` (COMING LATER / POWER wipe honesty).
5. Update this Operator status table (submitted vs live).
6. **Do not** upload until the owner played the build and said yes.

Agent skill: `.cursor/skills/play-store-prep/`. Update this table when a row changes.

Closed opt-in: `https://play.google.com/apps/testing/com.idleparty.app`

## Current decision (2026-08)

**Primary distribution: GitHub Releases (sideload).**  
Tag pushes `v*` publish signed APK + AAB via `.github/workflows/build-apk.yml`. Play
Console closed Alpha exists; **production is not live**. Day-to-day: prefer content/feel
over Play ops unless the owner asks about Play.

## Signing

- [ ] Create an upload keystore (or use Play App Signing with an upload key).
- [ ] Copy `android/key.properties.example` → `android/key.properties` and fill in passwords / alias / `storeFile`.
- [ ] For CI: set secrets `KEYSTORE_BASE64` (base64 of the `.jks`) and `KEY_PROPERTIES` (full `key.properties` contents), same pattern as `.github/workflows/build-apk.yml`.
- [ ] Locally: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

## Play Console — closed / internal (ops)

- [x] App exists in Play Console (`com.idleparty.app`) with listing + closed Alpha.
- [x] Keep Alpha AAB roughly near GitHub ship line when you care about Play testers. **1.12.83 (112)** submitted 2026-08-29 (review). Previous live may still be **1.12.78 (107)** until Google publishes.
- [ ] Enable Play App Signing if prompted on new uploads.
- [ ] Add / retain closed testers toward **12 × 14 days** for production access.
- [ ] Smoke-test install → hub → short dungeon → leave → relaunch (save persists).

## Privacy / Data safety

- [x] Privacy policy URL in Play Console (2026-08-16):  
  Prefer `https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md`  
  after this branch merges (branch blob still works until then).
- [x] Data safety form (2026-08-16): **optional Play Games** (User IDs / gameplay Other actions / Saved Games files); collected not shared; encrypted in transit; OAuth; delete account + data URLs point at [PRIVACY.md](PRIVACY.md). **No Idle Party analytics servers**; clipboard export/import is optional and user-initiated.
- [x] **Rewarded ads (1.12.27):** AdMob live IDs in app. Data safety + Advertising ID declaration updated 2026-08-21 and submitted with Alpha **57**. Privacy copy in [PRIVACY.md](PRIVACY.md). IARC ads questions still ⏳ if Console prompts.

### Rewarded ads / AdMob (how money actually arrives)

Hub **POWERUPS** is already in the game. Payouts go **AdMob → your bank**, not through Idle Party servers.

**Wired (2026-08-21):** Idle Party is in AdMob (not store-linked yet). App ID and rewarded unit **POWERUPS hour** live in `lib/core/ad_config.dart`. Release Android builds use them; debug `flutter run` still uses Google sample ads so you do not click your own ads.

**AdMob check (2026-08-22):**

| Item | Status |
|------|--------|
| Account | ✅ Approved (“Ditt konto är godkänt”) |
| GDPR message | ✅ 1 active (Europeiska förordningar) |
| App ID | ✅ `ca-app-pub-4980376195917009~4491640230` |
| Rewarded unit | ✅ **POWERUPS hour** `…/5225353586` (matches code) |
| Store link | ❌ empty — home setup **3/4**; needs Play store listing |
| App approval | ⏳ **Requires review** until store-linked + Google reviews |
| app-ads.txt | ✅ Hosted at `https://mahinika.github.io/app-ads.txt`; Play Website set to `https://mahinika.github.io` (2026-08-22). AdMob crawl may take up to 24h |
| Revenue today | ~0.54 SEK estimated (ads can fill a little even while in review) |
| Identity payout verify | Later — only when earnings hit Google’s threshold |

**Still later (AdMob checklist):**

1. **Store-link** Idle Party in AdMob → App settings → Add store listing when Play is public (closed Alpha **cannot** link). That is the last setup step and what clears **Requires review**.
2. After link + review: smoke POWERUPS on a Play-installed build; confirm Apps → Idle Party shows requests/impressions. Prefer a tester account; avoid click-farming your own live ads.
3. **app-ads.txt (2026-08-22):** file is live at `https://mahinika.github.io/app-ads.txt` (repo `Mahinika/Mahinika.github.io`). Play store contact **Website** must be `https://mahinika.github.io` (not the GitHub repo URL — AdMob crawls the domain root). Wait up to 24h for AdMob crawl; then open AdMob → Apps → Idle Party → app-ads.txt and refresh status.
4. IARC ads questions if Console asks after review.
5. Optional later: US-state privacy message (not required for EU-first ship).

**Code fix (2026-08-22):** rewarded show used to finish when the ad *opened*, dispose the ad, and skip the hour. It now waits until the ad is dismissed and only then grants POWERUPS. Duration: **1 ad = 3 hours** (stacks to 24h).

**Play Console (2026-08-21):**

- Data safety + Advertising ID declaration submitted with Alpha **57**.
- Do not ship sample IDs as “live” ads on production.

Closed testers watching a few ads will not pay rent. Real money needs many players (Play production or a large sideload audience).

### Play Games setup (leaderboards + cloud)

1. Play Console → Play Games Services → link `com.idleparty.app`.
2. Enable player login + **Saved Games**.
3. Each calendar month create two leaderboards (e.g. `Timed KEY · 2026-08`, `Gauntlet · 2026-08`) and paste Android IDs into [`lib/core/play_leaderboard_ids.dart`](../lib/core/play_leaderboard_ids.dart).
4. Put the numeric Games **App ID** in [`android/app/src/main/res/values/games-ids.xml`](../android/app/src/main/res/values/games-ids.xml).
5. OAuth consent screen + Android credential (package `com.idleparty.app` + signing SHA-1) so device sign-in works.
6. Test on a **Play-installed** build (internal/closed). GitHub sideload may soft-fail sign-in.

**Done for 2026-08:** Saved Games on; App ID `986358854278`; boards `Timed KEY 2026-08` (`CgkIhuXGvNocEAIQAA`) and `Gauntlet 2026-08` (`CgkIhuXGvNocEAIQAQ`); OAuth consent (external Testing) + scopes `games` / `games_lite` / `drive.appdata`; Android credential attached (Play App Signing SHA-1, package `com.idleparty.app`); owner Google account added as OAuth test user; Games **category** Role Playing; **icon** 512 + **feature graphic** 1024×500 from owned `app_icon`; **Description saved + Games project published**. Smoke on a Play-installed closed-test build near ship line. Sideload debug SHA-1 needs a second Android client if you test unsigned APKs. Leave Cloud OAuth consent in **Testing** (do not click Cloud “Publish app”).

Suggested Description (en-US):

> Grow a party of classic fantasy heroes, farm dungeons while you are away, and chase KEYSTONE, Gauntlet, and Ascend. Optional Play Games leaderboards and cloud save.

## Content rating / store listing notes

- [x] Content rating questionnaire (IARC) completed 2026-08-08 — mild fantasy combat; PEGI 12 / ESRB Everyone 10+ / IARC 7+ (no chat / gambling). **Re-answer the ads questions** before shipping POWERUPS ads to Play.
- [x] Short + full description (en-US only — no extra listing locales) from `docs/STORE_LISTING.md` (refresh listing when ship copy changes).
- [x] Phone screenshots + feature graphic refreshed 2026-08-21 (`tool/store_listing/marketing/`, 8×1080×1920 promo cards + 1024×500 banner). Submitted for review with listing graphics. Icon still from owned `app_icon` (refresh 2026-08-16). Tablet shots unchanged.
- [x] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*` — **`v1.12.83`** tagged + pushed 2026-08-29 (CI `build-apk.yml`); Play Alpha **112** submitted 2026-08-29.

## Production listing

- [ ] Promote internal → closed/open testing → production when ready.
- [ ] Or keep **sideload-only** (GitHub Releases) indefinitely — this is an explicit, valid ship path for Idle Party.

## CI reminder (GitHub Releases)

Tag push `v*` runs `.github/workflows/build-apk.yml`: release APK + AAB attached to the GitHub Release when `KEYSTORE_BASE64` + `KEY_PROPERTIES` secrets are set. Daily work stays on `main`; only cut `v*` when you want a public sideload build. Do not open a `release/*` branch for chores.

## Agent: upload AAB from Cursor

Closed Alpha upload recipe (CORS + `py -3` + fetch into file input — **not**
`DOM.setFileInputFiles`) lives in `.cursor/skills/play-store-prep/SKILL.md`
under **Upload signed AAB to closed Alpha**. Update the Operator status table
after each submit.
