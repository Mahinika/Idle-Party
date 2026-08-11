# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ GitHub Releases | Tag `v*` → APK/AAB via `build-apk.yml` |
| Play Console app | ✅ Exists | `com.idleparty.app` — listing + closed Alpha |
| Closed testing | ⏳ Alpha | Historical AAB noted **14 / 1.9.3**; ship line **1.11.2** on GitHub |
| Production | ❌ | Needs **12 closed testers × 14 days** (background ops — recruit/remind; not a feature blocker); not live |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit) |
| Privacy URL opens in browser | ⏳ | Prep URL: repo `docs/PRIVACY.md` on main |
| Data safety form | ⏳ | Match PRIVACY: local save, no ads/accounts/analytics servers |
| IARC / content rating | ❌ | Mild fantasy combat; no chat / gambling / ads |
| Store listing copy (EN) | ⏳ | Idle Party short + full; no Flutter placeholders |
| Screenshots + feature graphic | ❌ | Hub + dungeon; icon `assets/custom/ui/app_icon.png` |

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
- [ ] Keep Alpha AAB roughly near GitHub ship line when you care about Play testers.
- [ ] Enable Play App Signing if prompted on new uploads.
- [ ] Add / retain closed testers toward **12 × 14 days** for production access.
- [ ] Smoke-test install → hub → short dungeon → leave → relaunch (save persists).

## Privacy / Data safety

- [ ] Privacy policy URL pointing at this repo’s  
  `https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md`  
  (or the equivalent branch/raw URL you publish).
- [ ] Data safety form: **no accounts**, **no ads**, **no analytics collection to Idle Party servers**, **local-only save**; clipboard export/import is optional and user-initiated (see [PRIVACY.md](PRIVACY.md)).

## Content rating / store listing notes

- [ ] Complete the content rating questionnaire (IARC). Expect a general / mild fantasy violence rating for an idle RPG with combat; no real-world gambling, no user-generated chat, no ads in the build described in PRIVACY.
- [ ] Short description / full description: use product name **Idle Party**; avoid placeholder Flutter text.
- [ ] Screenshots and feature graphic from current hub/dungeon UI; icon from `assets/custom/ui/app_icon.png` (or Play-exported adaptive icon).
- [ ] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*`.

## Production listing

- [ ] Promote internal → closed/open testing → production when ready.
- [ ] Or keep **sideload-only** (GitHub Releases) indefinitely — this is an explicit, valid ship path for Idle Party.

## CI reminder

Tag push `v*` runs the Android workflow: release APK + AAB (when the AAB path exists), attached to the GitHub Release when secrets allow signed builds.
