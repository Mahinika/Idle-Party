---
name: play-store-prep
description: >-
  Idle Party Play Console / store readiness checklist (signing, privacy URL,
  screenshots, IARC, listing copy). Use when preparing Google Play, store
  listing, release ops, or when owner asks about Play Store / distribution.
---

# Play Store prep (Idle Party)

**Fact today:** GitHub Releases (APK/AAB on tag `v*`) is the live install path.
Play Console is the **goal** — prepare listing pieces, don’t claim the listing
already ships installs. Source of truth: [`docs/PLAY_STORE.md`](../../../docs/PLAY_STORE.md).

## When to run this skill

- Owner mentions Play, store listing, privacy, IARC, screenshots, AAB upload
- Before tagging a release meant for Play internal testing
- Agent notices store blockers while doing release polish

## Operator status (update `docs/PLAY_STORE.md`)

Keep the **Operator status** table in `PLAY_STORE.md` honest (✅ / ⏳ / ❌).
Never invent a public privacy host or Play listing URL.

| Blocker | Ready when… |
|---------|-------------|
| Signing secrets | `KEYSTORE_BASE64` + `KEY_PROPERTIES` work for CI tag builds |
| Privacy URL | URL opens in a normal browser (raw/GitHub blob OK for prep) |
| Data safety | Form matches [PRIVACY.md](../../../docs/PRIVACY.md): local save, no ads/accounts |
| IARC / rating | Questionnaire done; mild fantasy combat expectations |
| Listing copy | Idle Party short + full description (English), no Flutter placeholders |
| Screenshots | 4–6 current hub/dungeon shots + feature graphic; icon from custom app icon |
| Internal track | App created as `com.idleparty.app`, AAB uploaded, testers can install |

## Agent do / don’t

**Do**

- Point at missing rows in the status table; offer the next concrete ops step
- Keep versionName / `MetaSystems.currentVersion` / tag `v*` in sync
- Prefer GitHub Release when Play pieces are still ❌ — still a valid ship

**Don’t**

- Pretend Play is live when status says otherwise
- Commit keystores, `key.properties`, or base64 secrets
- Block cozy-game features waiting on store chrome

## Related

- Privacy copy: `docs/PRIVACY.md`
- Listing pack (copy, IARC, data safety, screenshot index): `docs/store/LISTING.md`
- Recapture screenshots: `py -3 tool/capture_store_screenshots.py` (web on `:8080`)
- Tag → APK/AAB: `.github/workflows/build-apk.yml`
- Hub chrome before screenshots: `hub-smoke` / `screenshotting-changelog`
