# Idle Party — distribution & Play Store

Package id: **`com.idleparty.app`**

## Operator status (keep honest)

| Item | Status | Notes |
|------|--------|-------|
| Primary installs | ✅ GitHub Releases | Tag `v*` → APK/AAB via `build-apk.yml` |
| Play Console app | ✅ | `com.idleparty.app` created; AAB **14 (1.9.3)** on tracks |
| Local upload keystore | ✅ | `android/upload-keystore.jks` + `key.properties` (gitignored — **back up!**) |
| CI signing secrets | ⏳ | `KEYSTORE_BASE64` + `KEY_PROPERTIES` (never commit) |
| Privacy URL opens in browser | ✅ | Repo **public**; prefer raw: `https://raw.githubusercontent.com/Mahinika/Idle-Party/main/docs/PRIVACY.md` |
| Data safety form | ✅ | Match [`PRIVACY.md`](PRIVACY.md) / [`store/LISTING.md`](store/LISTING.md) in Console |
| Advertising ID declaration | ✅ | App does **not** use advertising ID (no ads) |
| IARC / content rating | ✅ | Submitted in Console (~PEGI 7 / fantasy violence) |
| Store listing (EN) | ✅ | Short + full description, icon, feature graphic, phone + tablet shots |
| Internal testing track | ⏳ | Release live; Play install can lag (“item not found”) for new testers |
| Closed testing track | ⏳ | **Alpha** + AAB 14; recruiting ≥12 testers for **14 days** → production access |
| Production listing | ❌ | After closed-test criteria + apply |

Listing pack: [`docs/store/LISTING.md`](store/LISTING.md). Recapture phone shots: `py -3 tool/capture_store_screenshots.py` (Flutter web on `:8080`).

Closed opt-in (web): `https://play.google.com/apps/testing/com.idleparty.app`

Agent skill: `.cursor/skills/play-store-prep/`. Update this table when a row changes.

## Current decision (2026-08)

**Primary distribution: GitHub Releases (sideload).**  
Tag pushes `v*` publish signed APK + AAB via `.github/workflows/build-apk.yml`.

**Play Console is in progress:** listing + closed Alpha are set up; production waits on **12 closed testers × 14 days**, then “apply for production access”. GitHub Releases remains a valid forever path.

## Signing

- [x] Create an upload keystore (`android/upload-keystore.jks`, alias `upload`).
- [x] Local `android/key.properties` (gitignored) with `storeFile=../upload-keystore.jks`.
- [ ] For CI: set secrets `KEYSTORE_BASE64` (base64 of the `.jks`) and `KEY_PROPERTIES` (full `key.properties` contents), same pattern as `.github/workflows/build-apk.yml`.
- [x] Locally: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

**Important:** back up the keystore + `key.properties` offline. Losing them blocks updates with the same upload key.

## Play Console — tracks

### Internal testing

- [x] App created with application id `com.idleparty.app`.
- [x] Play App Signing / upload key as prompted.
- [x] Internal release with AAB **14 (1.9.3)**.
- [x] Tester list + opt-in link shared.
- [ ] Smoke-test install → hub → short dungeon → leave → relaunch (save persists) once Play shows the listing.

### Closed testing (production gate)

- [x] **Stängt test - Alpha** channel with AAB **14** (add from library if version code already used).
- [x] Countries/regions set for testers’ locales.
- [ ] ≥12 testers opted in continuously for 14 days.
- [ ] Apply for production access when Console unlocks the button.

## Privacy / Data safety

- [x] Privacy policy URL (raw preferred while repo is public):  
  `https://raw.githubusercontent.com/Mahinika/Idle-Party/main/docs/PRIVACY.md`
- [x] Data safety: **no accounts**, **no ads**, **no analytics to Idle Party servers**, **local-only save**; clipboard export/import optional and user-initiated (see [PRIVACY.md](PRIVACY.md)).
- [x] Advertising ID: **not used**.

## Content rating / store listing

- [x] IARC questionnaire submitted in Play Console (draft answers remain in [`docs/store/LISTING.md`](store/LISTING.md)).
- [x] Short / full description pasted from LISTING.md.
- [x] Icon (`docs/store/icon_512.png`), feature graphic, phone + tablet screenshots uploaded.
- [ ] Keep release name / versionName in sync with `pubspec.yaml` and git tags `v*` on each new upload (bump `+versionCode` when Play already has that code).

## Production listing

- [ ] Meet closed-test criteria → apply for production → promote when approved.
- [ ] Or keep **sideload-only** (GitHub Releases) indefinitely — still a valid ship path.

## CI reminder

Tag push `v*` runs the Android workflow: release APK + AAB (when the AAB path exists), attached to the GitHub Release when secrets allow signed builds.
