# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ Google Play | Store listing live; closed test for early builds |
| Play Console app | ✅ Exists | `com.idleparty.app` — listing + closed Alpha + production |
| Closed testing | ⏳ | Last Alpha upload **1.12.133 (163)** (2026-09-10). Production **187** was not mirrored to Alpha this round. |
| Production | ✅ live | Live store **1.12.171 (201)** as of Console **2026-09-17**. **1.12.172 (202)** uploaded + submitted for review **2026-09-17** (full rollout). |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit). Workflow now writes keystore to `android/upload-keystore.jks` (matches `storeFile=../upload-keystore.jks`). **v1.12.52 GitHub AAB was debug-signed** — Play used a local upload rebuild; re-tag/rebuild after secrets path fix. |
| Privacy URL opens in browser | ✅ | Console: `https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md` (fixed 2026-09-08; was wrongly on old `cursor/keystone-habit-b46b` branch). |
| Data safety form | ✅ review | Ads / Play Games / Advertising ID + **Firebase Analytics** (App interactions, Diagnostics, Device IDs) submitted **2026-09-10** — under Google review (`Ändringarna granskas`). Matches [PRIVACY.md](PRIVACY.md). |
| IARC / content rating | ⏳ review | New questionnaire submitted 2026-09-08: fantasy creature violence (often close-up, pixel, no blood), digital goods (SHOP) yes / no loot-boxes / no player trading, no fear/sex/gambling/language/drugs. Ads are **not** in this IARC form — covered by Ads declaration **Yes**. Ratings preview: ESRB 10+ fantasy violence, USK 12, PEGI 3 + IAP. |
| Play Games Services | ✅ | Published. Saved Games on; App ID `986358854278`; 2026-08 KEY/Gauntlet wired; 2026-09 Greater Rift `CgkIhuXGvNocEAIQAw` wired (Console Draft — publish via Games Publishing). OAuth + Android credential + test user. Category Role Playing; icon + feature graphic from `app_icon`. Remaining: smoke on a Play-installed closed-test build near ship line. |
| Store listing copy (EN) | ✅ live | Default locale **en-US**. Title **Idle Party: Idle RPG** + crawl-on-screen full desc live on the public listing **2026-09-17**. Extra locales gated. |
| Store contact email | ✅ | **cognifoxstudio@gmail.com** (Play Butiksinställningar; also in `docs/PRIVACY.md`). Login account may still be Robertjonsson90@gmail.com — that is Console login only, not public. |
| Screenshots + feature graphic | ⏳ attach | Live carousel still older 8. New pack in `out/` (party-centered 1–2); Console needs crop-before-add. Feature graphic unchanged. Preview rebuild uploaded YT `XfKog5CAiUs` but Play embed rejected — listing stays on `OMWXbgGBFMA`. |
| Preview video (YouTube) | ⏳ review | Live listing: `OMWXbgGBFMA`. Rebuilt combat-first MP4 uploaded Cognifox `XfKog5CAiUs` (unlisted) — Play rejected embed (ads/visibility). Keep ads off / not made-for-kids, then swap. |
| Ads declaration | ✅ fixed | Was **No ads** (wrong). Set to **Yes, contains ads** 2026-09-08 (hub POWERUPS / AdMob). In review with Alpha **135**. |
| Advertising ID | ✅ | Yes + advertising purpose; AD_ID in manifest. Cleared mistaken “disable AD_ID version errors” checkbox 2026-09-08. |

## Production gate (12 × 14)

Track closed testers who **install from Play** and stay opted in:

- [x] **12** unique testers enrolled on closed track
- [x] **14 consecutive days** with at least one tester active — production-access **application submitted 2026-09-04** (Google reviewing)
- [x] Owner played **1.12.87+** on A56 (owner OK 2026-09-04)
- [x] Phone screenshots attached on listing (verified 2026-09-04 — slots filled, Save idle)
- [x] IARC new questionnaire submitted 2026-09-08 (fantasy combat + digital goods; ads via Ads declaration)
- [x] Production access granted by Google (seen on dashboard 2026-09-09)
- [x] Signed Production candidate AAB built: **1.12.157+187** (`app-release.aab`)
- [x] Owner asked upload Production (2026-09-12)
- [x] Uploaded + submitted for review: Production **187 (1.12.157)** + listing copy + 8 phone shots (2026-09-12)
- [x] Google review / publish complete → store listing shows Updated (owner **2026-09-13**)
- [x] After production live: AdMob store-link Idle Party (**2026-09-09** — Play linked; AdMob app review 2–3 days)
- [x] Owner asked new Production AAB (**2026-09-14**)
- [x] Signed Production AAB **1.12.170+200** built + uploaded; submitted for review (full rollout). Console: Ändringarna granskas. AD_ID warning ignored for this version (permission is in the 200 AAB).
- [x] Owner asked new Production AAB (**2026-09-15**)
- [x] Signed Production AAB **1.12.171+201** built + uploaded; submitted for review (full rollout). Console: Ändringarna granskas. AD_ID “Lansera utan behörighet” (permission is in the 201 AAB).
- [x] Owner asked new Production AAB (**2026-09-17**)
- [x] Signed Production AAB **1.12.172+202** built + uploaded; submitted for review (full rollout). Console: *Ändringarna granskas* + Produktion **202 (1.12.172)**. AD_ID “Lansera utan behörighet” (permission is in the 202 AAB). Phone shots + preview URL still the live set (crop / Play-YT embed).

### Production upload paste (en-US release notes)

From `docs/STORE_LISTING.md` — use when Console asks for release notes:

```
• Your party fights on its own. Day-one menus stay GEAR and MORE until gold, the shop, and essence mean something. Shield, Healer, and Damage kits show their job in the fight.
• PATH is a continent map. PUSH floors pay a little essence. SHOP has forever SCROLLS and a redeem code. Party Lv100 still unlocks Craft Trial and the extra hunts.
```

Update release notes when shipping a build that includes Play Billing SHOP buys
(see `docs/SHOP_MONETIZATION.md`). **IAP SKUs (2026-09-10):** all five product
ids exist in Console and were **activated 2026-09-10** (1 purchase option each).
Smoke on a Play-installed build; restart the app so Billing refreshes.

### Production AAB upload checklist (agent + owner)

1. Confirm production track unlocked (IARC + ads declarations already submitted).
2. `flutter build appbundle --release` with upload keystore (or tag `v*` after CI signing verified).
3. Upload via play-store-prep CORS recipe → Production track (not Alpha).
4. Release notes from `docs/STORE_LISTING.md` (COMING LATER / POWER wipe honesty).
5. Update this Operator status table (submitted vs live).
6. **Do not** upload until the owner played the build and said yes.

Agent skill: `.cursor/skills/play-store-prep/`. Update this table when a row changes.

Closed opt-in: `https://play.google.com/apps/testing/com.idleparty.app`

## Current decision (2026-09-11)

**Primary distribution: Google Play.**  
Store: `https://play.google.com/store/apps/details?id=com.idleparty.app`
(production track live; keep Operator status honest above). Closed opt-in for early builds. Do **not**
point players at GitHub Releases (repo may be private). Day-to-day: owner
names work ([GROWTH_MANDATE.md](GROWTH_MANDATE.md)). D1 paste **2026-09-14**
(not readable). Play publish/smoke closed **2026-09-13**.
Ship path for players = Play AAB **only when the owner asks** (after they
play OK) — not public GitHub APK links. Agents never upload AAB unprompted.

**Growth:** paste listing from [`STORE_LISTING.md`](STORE_LISTING.md); owner
Play-smoke checklist + review templates in [`PLAY_GROWTH.md`](PLAY_GROWTH.md).
Category stays Role Playing. Tags (2026-09-11 Console): **Clicker-rollspel**,
**Rollspel** (no Idle/Incremental picker names in SV UI).

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
- [x] Data safety form (baseline 2026-08-16 / ads 2026-08-21): **optional Play Games** (User IDs / gameplay Other actions / Saved Games files); **AdMob** + Advertising ID; collected/shared answers as submitted; OAuth; delete account + data URLs → [PRIVACY.md](PRIVACY.md). Clipboard export/import is optional and user-initiated.
- [x] **Firebase Analytics (code live 2026-09-10):** Play Data safety updated **2026-09-10** — App interactions + Diagnostics + Device IDs (collected/shared, Analytics purpose, optional via UMP); Other actions kept (Play Games + gameplay). Submitted for review from Publishing overview. Matches [PRIVACY.md](PRIVACY.md).
- [x] **Rewarded ads (1.12.27):** AdMob live IDs in app. Data safety + Advertising ID declaration updated 2026-08-21 and submitted with Alpha **57**. Privacy copy in [PRIVACY.md](PRIVACY.md). Ads declaration **Yes** + IARC re-survey 2026-09-08.
- [x] **AdMob ↔ Firebase link (2026-09-10):** Idle Party AdMob app linked to Firebase project `idle-party-4a2e9`. User metrics in AdMob may take up to ~48h.

### Firebase Analytics setup (owner)

Phone product only (`com.idleparty.app`). Config file is in-repo:

`android/app/google-services.json` (project `idle-party-4a2e9`)

Soft events: Play funnel (`app_ready`, `first_enter` with seconds-to-combat,
`first_reward`, `first_boss`, `d1_return`; Firebase auto-collects `first_open`),
enter/leave dungeon, Ascend, party wipe. UMP consent gates collection
(SETTINGS → AD PRIVACY). Rebuild Android after pull.

**If you ever re-download the JSON:** Project settings → Your apps → Idle Party
→ **google-services.json** → save over `android/app/google-services.json`.

DebugView (optional): `adb shell setprop debug.firebase.analytics.app com.idleparty.app` then `flutter run` on a device/emulator.

### Rewarded ads / AdMob (how money actually arrives)

Hub **POWERUPS** is already in the game. Payouts go **AdMob → your bank**, not through Idle Party servers.

**Wired:** Idle Party is in AdMob with Play store listing linked (**2026-09-09**). App ID and rewarded unit **POWERUPS hour** live in `lib/core/ad_config.dart`. Release Android builds use them; debug `flutter run` still uses Google sample ads so you do not click your own ads. AdMob ↔ Firebase linked **2026-09-10**.

**AdMob check:**

| Item | Status |
|------|--------|
| Account | ✅ Approved (“Ditt konto är godkänt”) |
| GDPR message | ✅ 1 active (Europeiska förordningar) |
| App ID | ✅ `ca-app-pub-4980376195917009~4491640230` |
| Rewarded unit | ✅ **POWERUPS hour** `…/5225353586` (matches code) |
| Store link | ✅ Play linked **2026-09-09** (`com.idleparty.app`) |
| App approval | ✅ Klart / annonsvisning aktiverad (2026-09-10 AdMob Apps) |
| Firebase link | ✅ AdMob ↔ Firebase project `idle-party-4a2e9` (2026-09-10); user metrics may take up to 48h |
| app-ads.txt | ✅ Hosted at `https://mahinika.github.io/app-ads.txt`; Play Website set to `https://mahinika.github.io` |
| Payment profile | ⏳ AdMob may show a payment-problem banner until AdSense payout settings are fixed |
| Identity payout verify | Later — only when earnings hit Google’s threshold |

**Still later (AdMob checklist):**

1. Smoke POWERUPS on a Play-installed build; confirm Apps → Idle Party shows requests/impressions. Prefer a tester account; avoid click-farming your own live ads.
2. Fix AdMob / AdSense **payment profile** banner if still red.
3. Optional later: US-state privacy message (not required for EU-first ship).

**Code fix (2026-08-22):** rewarded show used to finish when the ad *opened*, dispose the ad, and skip the hour. It now waits until the ad is dismissed and only then grants POWERUPS. Duration: **1 ad = 3 hours** (stacks to 24h).

**Play Console (2026-08-21):**

- Data safety + Advertising ID declaration submitted with Alpha **57**.
- Do not ship sample IDs as “live” ads on production.

Closed testers watching a few ads will not pay rent. Real money needs many players (Play production or a large sideload audience).

### Play Games setup (leaderboards + cloud)

1. Play Console → Play Games Services → link `com.idleparty.app`.
2. Enable player login + **Saved Games**.
3. Each calendar month create KEY + Gauntlet (+ Greater Rift) leaderboards and paste Android IDs into [`lib/core/play_leaderboard_ids.dart`](../lib/core/play_leaderboard_ids.dart).
4. Put the numeric Games **App ID** in [`android/app/src/main/res/values/games-ids.xml`](../android/app/src/main/res/values/games-ids.xml).
5. OAuth consent screen + Android credential (package `com.idleparty.app` + signing SHA-1) so device sign-in works.
6. Test on a **Play-installed** build (internal/closed). GitHub sideload may soft-fail sign-in.

**Done for 2026-08:** Saved Games on; App ID `986358854278`; boards `Timed KEY 2026-08` (`CgkIhuXGvNocEAIQAA`) and `Gauntlet 2026-08` (`CgkIhuXGvNocEAIQAQ`); OAuth consent (external Testing) + scopes `games` / `games_lite` / `drive.appdata`; Android credential attached (Play App Signing SHA-1, package `com.idleparty.app`); owner Google account added as OAuth test user; Games **category** Role Playing; **icon** 512 + **feature graphic** 1024×500 from owned `app_icon`; **Description saved + Games project published**. Smoke on a Play-installed closed-test build near ship line. Sideload debug SHA-1 needs a second Android client if you test unsigned APKs. Leave Cloud OAuth consent in **Testing** (do not click Cloud “Publish app”).

**2026-09 Greater Rift:** Android ID `CgkIhuXGvNocEAIQAw` (`Greater Rift 2026-09`) wired in `play_leaderboard_ids.dart`. Created as Console **Draft** — same ID after publish. Publish the board via Play Games Services → Publishing (same path as KEY/Gauntlet) so store players see it; testers can use the draft.

Suggested Description (en-US):

> Grow a party of classic fantasy heroes, farm dungeons while you are away, and chase KEYSTONE, Gauntlet, and Ascend. Optional Play Games leaderboards and cloud save.

## Content rating / store listing notes

- [x] Content rating questionnaire (IARC): original 2026-08-08; **re-survey submitted 2026-09-08** — fantasy creature violence (often close-up, pixel, no blood), SHOP digital goods, no loot-boxes/trading/chat. Ads via Ads declaration (not in new IARC form). Preview: ESRB 10+ / USK 12 / PEGI 3 + IAP.
- [x] Short + full description (en-US only — no extra listing locales) from `docs/STORE_LISTING.md` (refresh listing when ship copy changes).
- [x] Phone screenshots + feature graphic: **8 phone shots submitted 2026-09-12** (1–2 combat; carousel matches itch). Icon owned `play_icon_512.png`. Tablet shots unchanged.
- [x] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*` — **`v1.12.83`** tagged + pushed 2026-08-29 (CI `build-apk.yml`); Play Alpha **112** submitted 2026-08-29.

## Production listing

- [ ] Promote internal → closed/open testing → production when ready.
- [x] **Google Play is primary** (production live 2026-09-09). Do not advertise GitHub Releases to players.

## CI reminder (optional signed artifacts)

Tag push `v*` may still run `.github/workflows/build-apk.yml` for signed APK +
AAB when secrets are set — useful for Play upload / private backups. That is
**not** the player install path. Do not advertise GitHub Releases in Discord,
README, or store-facing copy. Daily work stays on `main`.

## Agent: upload AAB from Cursor

Closed Alpha upload recipe (CORS + `py -3` + fetch into file input — **not**
`DOM.setFileInputFiles`) lives in `.cursor/skills/play-store-prep/SKILL.md`
under **Upload signed AAB to closed Alpha**. Update the Operator status table
after each submit.
