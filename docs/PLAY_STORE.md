# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ GitHub Releases | Tag `v*` → APK/AAB via `build-apk.yml` |
| Play Console app | ✅ Exists | `com.idleparty.app` — listing + closed Alpha |
| Closed testing | ⏳ review | **1.12.27 (57)** submitted to closed Alpha 2026-08-21 (POWERUPS ads + Play update notice + shield fix). Testers still on **1.12.25 (55)** until Google publishes. Production still ❌. |
| Production | ❌ | Needs **12 closed testers × 14 days** (background ops — recruit/remind; not a feature blocker); not live |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit) |
| Privacy URL opens in browser | ✅ | Console: `docs/PRIVACY.md` on GitHub (`main` preferred after merge; still OK on feature branch until then). |
| Data safety form | ⏳ review | Updated 2026-08-21 for AdMob (device IDs collected+shared, advertising purpose) + Advertising ID declaration Yes. Submitted with Alpha **57**. |
| IARC / content rating | ⏳ ads | Questionnaire said **no ads** (2026-08-08). Re-answer ads questions if Console asks after this review. |
| Play Games Services | ✅ | Published. Saved Games on; App ID `986358854278`; 2026-08 boards wired; OAuth + Android credential + test user. Category Role Playing; icon + feature graphic from `app_icon`. Remaining: smoke on a Play-installed closed-test build near ship line. |
| Store listing copy (EN) | ✅ live | Default locale **en-US only** (no extra listing languages). Honesty copy from `docs/STORE_LISTING.md`. Verified 2026-08-20. |
| Screenshots + feature graphic | ⏳ review | **9 phone + feature graphic** submitted 2026-08-21 (promo cards in `tool/store_listing/marketing/`, 1080×1920 + 1024×500). Icon unchanged. Tablet shots still older (phone-first). |

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
- [x] Keep Alpha AAB roughly near GitHub ship line when you care about Play testers. **1.12.27 (57)** submitted 2026-08-21 (review). Previous live for testers: **1.12.25 (55)**.
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

**AdMob done (2026-08-21):** GDPR message **Idle Party GDPR** published (Consent / Do not consent / Manage options). Privacy URL is this repo’s `docs/PRIVACY.md`. SETTINGS **AD PRIVACY** withdraws consent. Payment profile is complete. Account verification is in progress (~24h, sometimes up to 2 weeks). Store-link waits until Play is public (closed Alpha cannot be linked).

**Still later:**

1. Wait for AdMob **account verification**, then a live-ads Android build so the app can leave **Requires review**.
2. Optional: **app-ads.txt** on the Play developer website (`pub-4980376195917009`) once ads are live.
3. Wait for Play review of Alpha **57**; then smoke POWERUPS on a Play-installed build (do not click your own ads on a personal release device if you can avoid it).
4. IARC ads questions if Console asks after review.

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
- [x] Short + full description (en-US only — no extra listing locales) live 2026-08-20 from `docs/STORE_LISTING.md`.
- [x] Phone screenshots + feature graphic refreshed 2026-08-21 (`tool/store_listing/marketing/`, 8×1080×1920 promo cards + 1024×500 banner). Submitted for review with listing graphics. Icon still from owned `app_icon` (refresh 2026-08-16). Tablet shots unchanged.
- [ ] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*`.

## Production listing

- [ ] Promote internal → closed/open testing → production when ready.
- [ ] Or keep **sideload-only** (GitHub Releases) indefinitely — this is an explicit, valid ship path for Idle Party.

## CI reminder

Tag push `v*` runs the Android workflow: release APK + AAB (when the AAB path exists), attached to the GitHub Release when secrets allow signed builds.

## Agent: upload AAB from Cursor

Closed Alpha upload recipe (CORS + `py -3` + fetch into file input — **not**
`DOM.setFileInputFiles`) lives in `.cursor/skills/play-store-prep/SKILL.md`
under **Upload signed AAB to closed Alpha**. Update the Operator status table
after each submit.
