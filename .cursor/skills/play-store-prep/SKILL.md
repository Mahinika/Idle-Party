---
name: play-store-prep
description: >-
  Idle Party Play Console readiness (signing, privacy URL, screenshots, IARC,
  listing copy) and AAB upload to closed Alpha. Use when preparing Google Play,
  store listing, release ops, uploading AAB, itch.io listing, or when the owner
  says "lägg upp på Play" / Play Store / itch. Do not upload an APK to itch or
  point players at GitHub Releases (product lock).
---

# Play Store prep (Idle Party)

**Fact today:** **Google Play is the primary install path** (production live).
Do not link players to GitHub Releases (repo may be private). Closed Alpha
remains for early builds. Source of truth:
[`docs/PLAY_STORE.md`](../../../docs/PLAY_STORE.md).

## When to run this skill

- **Growth mandate** listing pack (screenshots 1–2 = new-save first-minute combat)
- Owner mentions Play, store listing, privacy, IARC, screenshots, AAB upload
- Owner mentions itch.io listing / community post (PAGE.md — no APK)
- Before tagging a release meant for Play closed testing
- Agent notices store blockers while doing release polish

**Ask before push/tag.** Play upload is OK when the owner asks.

## Operator status (update `docs/PLAY_STORE.md`)

Keep the **Operator status** table in `PLAY_STORE.md` honest (✅ / ⏳ / ❌).
Never invent a public privacy host or Play listing URL.

| Blocker | Ready when… |
|---------|-------------|
| Signing secrets | `KEYSTORE_BASE64` + `KEY_PROPERTIES` work for CI tag builds |
| Privacy URL | URL opens in a normal browser (raw/GitHub blob OK for prep) |
| Data safety | Form matches [PRIVACY.md](../../../docs/PRIVACY.md): local save, optional Play Games, optional rewarded ads |
| IARC / rating | Questionnaire done; mild fantasy combat expectations |
| Listing copy | Idle Party short + full description (English), no Flutter placeholders |
| Screenshots | Shots 1–2 = new-save Sandy combat + 512 icon from owned `app_icon`; later carousel as in STORE_LISTING.md |
| Closed Alpha | App `com.idleparty.app`, AAB on Alpha track, testers can install |

## Checklist

```
Play prep:
- [ ] 1. Operator status table honest in PLAY_STORE.md
- [ ] 2. pubspec versionName ↔ MetaSystems.currentVersion
- [ ] 3. Privacy + data safety match PRIVACY.md
- [ ] 4. Listing copy from STORE_LISTING.md
- [ ] 5. Screenshots current (hub-smoke / screenshotting-changelog)
- [ ] 6. Signed AAB built (owner asked)
- [ ] 7. Upload via reference.md recipe when ready
```

## itch.io (discovery only)

Play stays the install path. itch is a public page + Play button — **no APK**.
Copy, live URLs, and image-upload gotchas:
[`tool/store_listing/itch/PAGE.md`](../../../tool/store_listing/itch/PAGE.md).
Read **[reference.md](reference.md)** § itch.io when attaching cover/screenshots.

## Upload recipes (read on demand)

For screenshot capture, CORS listing upload, AAB attach, and itch images via
Cursor browser, read **[reference.md](reference.md)** when you reach that step.

## Agent do / don't

**Do**

- Point at missing rows in the status table; offer the next concrete ops step
- Keep versionName / `MetaSystems.currentVersion` / tag `v*` in sync
- Use the AAB upload recipe in `reference.md` when the owner asks to put a build on Play

**Don't**

- Pretend Play production is live when status says otherwise
- Commit keystores, `key.properties`, or base64 secrets
  (includes `tool/store_listing/itch/upload/`)
- Rely on `python` on this Windows box — use `py -3`
- Waste turns on `DOM.setFileInputFiles` (blocked)
- Reuse Play Console localhost-CORS against itch.io (HTTPS page — mixed content)
- Upload an APK to itch or point players at GitHub Releases
- Block cozy-game features waiting on store chrome

## Related

- Privacy copy: `docs/PRIVACY.md`
- Tag → APK/AAB: `.github/workflows/build-apk.yml`
- Hub chrome before screenshots: `hub-smoke` / `screenshotting-changelog`
- Browser phone metrics: `browser-playtest`
- itch.io page + community post: `tool/store_listing/itch/PAGE.md`
