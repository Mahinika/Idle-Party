# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ GitHub Releases | Tag `v*` → APK/AAB via `build-apk.yml` |
| Play Console app | ⏳ | Create when ready; id `com.idleparty.app` |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit) |
| Privacy URL opens in browser | ⏳ | Prep URL: repo `docs/PRIVACY.md` on main |
| Data safety form | ✅ draft | Answers in [`docs/store/LISTING.md`](store/LISTING.md) (paste into Console) |
| IARC / content rating | ✅ draft | Questionnaire answers in `docs/store/LISTING.md` — submit in Console |
| Store listing copy (EN) | ✅ draft | Short + full description in `docs/store/LISTING.md` |
| Screenshots + feature graphic | ✅ draft | `docs/store/screenshots/` + `feature_graphic.png` / `icon_512.png` |
| Internal testing track | ❌ | Upload AAB; smoke hub → dungeon → leave → relaunch |
| Production listing | ❌ | Optional; GitHub Releases remains valid forever |

Listing pack: [`docs/store/LISTING.md`](store/LISTING.md). Recapture phone shots: `py -3 tool/capture_store_screenshots.py` (Flutter web on `:8080`).

Agent skill: `.cursor/skills/play-store-prep/`. Update this table when a row changes.

## Current decision (2026-08)

**Primary distribution: GitHub Releases (sideload).**  
Tag pushes `v*` publish signed APK + AAB via `.github/workflows/build-apk.yml`. Play Console production listing is **optional / deferred** until privacy URL hosting, IARC, screenshots, and store listing copy are ready.

When you choose to publish on Play, complete the checklists below. Until then, treat this file as operator prep — not a blocker for GitHub releases.

## Signing

- [ ] Create an upload keystore (or use Play App Signing with an upload key).
- [ ] Copy `android/key.properties.example` → `android/key.properties` and fill in passwords / alias / `storeFile`.
- [ ] For CI: set secrets `KEYSTORE_BASE64` (base64 of the `.jks`) and `KEY_PROPERTIES` (full `key.properties` contents), same pattern as `.github/workflows/build-apk.yml`.
- [ ] Locally: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

## Play Console — internal track (optional)

- [ ] Create the app in Play Console with application id `com.idleparty.app`.
- [ ] Enable Play App Signing if prompted.
- [ ] Create an **Internal testing** release and upload the AAB (from CI tag `v*` artifacts/release assets, or a local build).
- [ ] Add testers (email list or Google Group) and share the opt-in link.
- [ ] Smoke-test install → hub → short dungeon → leave → relaunch (save persists).

## Privacy / Data safety

- [ ] Privacy policy URL pointing at this repo’s  
  `https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md`  
  (or the equivalent branch/raw URL you publish).
- [ ] Data safety form: **no accounts**, **no ads**, **no analytics collection to Idle Party servers**, **local-only save**; clipboard export/import is optional and user-initiated (see [PRIVACY.md](PRIVACY.md)).

## Content rating / store listing notes

- [x] Draft IARC answers + listing copy: [`docs/store/LISTING.md`](store/LISTING.md) (still submit/paste in Play Console).
- [x] Screenshots + feature graphic prepared under `docs/store/` (re-run `tool/capture_store_screenshots.py` after big UI changes).
- [ ] Complete the content rating questionnaire (IARC) **in Play Console** using the draft answers.
- [ ] Paste short / full description from LISTING.md; avoid placeholder Flutter text.
- [ ] Upload icon (`docs/store/icon_512.png` or `assets/custom/ui/app_icon.png`), feature graphic, and phone screenshots.
- [ ] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*`.

## Production listing

- [ ] Promote internal → closed/open testing → production when ready.
- [ ] Or keep **sideload-only** (GitHub Releases) indefinitely — this is an explicit, valid ship path for Idle Party.

## CI reminder

Tag push `v*` runs the Android workflow: release APK + AAB (when the AAB path exists), attached to the GitHub Release when secrets allow signed builds.
