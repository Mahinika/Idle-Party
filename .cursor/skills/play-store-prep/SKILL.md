---
name: play-store-prep
description: >-
  Idle Party Play Console readiness (signing, privacy URL, screenshots, IARC,
  listing copy), review replies, and Play API reads. Use when preparing Google
  Play, store listing, release ops, uploading AAB, answering reviews, reading
  Play stats the API can see, itch.io listing, or when the owner says "lägg upp
  på Play" / "play console" / "recensioner" / "statistik" / Play Store / itch.
  Do not upload an AAB unless the owner asks that turn. Do not upload an APK to
  itch or point players at GitHub Releases (product lock).
---

# Play Store prep (Idle Party)

**Fact today:** Google Play is the install path (`com.idleparty.app`).
Do not link players to GitHub Releases. Source of truth:
[`docs/PLAY_STORE.md`](../../../docs/PLAY_STORE.md).

The only upload path is the **Play Android Publisher API**
(`~/.config/idle-party/play-console.json`). One edit holds the images, the
store text, the AAB, and the production track. Nothing is live until
`edits.commit`. Read **[reference.md](reference.md)** for the recipe. The
browser path is a fallback only when that key cannot call the API.

## When to run this skill

- Owner mentions Play, the store listing, privacy, IARC, screenshots, or an AAB
- Owner mentions Play stats, reviews, or "play console" (read the API first)
- Owner mentions itch.io (page only — no APK)
- A release is meant for Play production

Push or tag when the batch needs it. **Play AAB upload only when the owner asks that turn.**

## Before an upload

1. Read `tracks/production`. That is the build players have. If a local version
   between that build and this one was never sent, fold those patch notes into
   What's New. What's New is `en-US` and at most 500 characters.
2. Open every composed shot in `tool/store_listing/out/` and the feature
   graphic in `tool/store_listing/marketing/`. Shot 8 must be the ASCEND?
   dialog. The feature graphic must show the whole starter party and the pack.
   Then `flutter test test/store_listing_plan_test.dart` and
   `flutter test test/changelog_sync_test.dart`.
3. List images on every listing locale. `sevenInchScreenshots` and
   `tenInchScreenshots` must be empty. Delete them in this same edit if any
   remain. Phone shots are the pictures Play should use.
4. One atomic edit, and only because the owner asked in this turn:
   `POST /edits` → images, listings, bundle, `tracks/production` →
   `POST /edits/{id}:commit`. If a step fails, `DELETE` the edit. Do not
   commit a half edit.

## Operator status (update `docs/PLAY_STORE.md`)

Keep the Operator status table honest. A track that says `completed` is the
live build. A commit that just happened is submitted, not live, until a later
read of `tracks/production` says `completed` for that version. Never invent
Console numbers.

| Blocker | Ready when… |
|---------|-------------|
| Signing secrets | Local `android/key.properties` + upload keystore for this build. CI secrets stay out of git |
| Privacy URL | URL opens in a normal browser |
| Data safety | Form matches [PRIVACY.md](../../../docs/PRIVACY.md) |
| IARC / rating | Questionnaire done |
| Listing copy | [`docs/STORE_LISTING.md`](../../../docs/STORE_LISTING.md) matches the game |
| Screenshots | Shots 1–2 are new-save Sandy combat. No tablet shots left on the listing |
| Production | App `com.idleparty.app`, AAB on `production`, owner asked this turn |

## Checklist

```
Play prep:
- [ ] 1. tracks/production read (fold unsent versions into What's New)
- [ ] 2. pubspec versionName ↔ ChangelogCatalog.currentVersion
- [ ] 3. Every out/ shot and the feature graphic checked by eye
- [ ] 4. store_listing_plan_test and changelog_sync_test green
- [ ] 5. sevenInchScreenshots and tenInchScreenshots empty
- [ ] 6. Signed AAB built
- [ ] 7. One edit committed (owner asked this turn)
- [ ] 8. PLAY_STORE.md says submitted, not live, until the track says completed
```

## itch.io (discovery only)

Play stays the install path. itch is a public page + Play button — **no APK**.
Copy and image gotchas: [`tool/store_listing/itch/PAGE.md`](../../../tool/store_listing/itch/PAGE.md).
Read **[reference.md](reference.md)** § itch.io when attaching cover or screenshots.

## Play API reads

Reviews, the live version, store text, shop products, and crash/ANR come from
the same key. Reply only to the review the owner names. Never commit an edit
or upload an AAB unless they ask that turn.

## Agent do / don't

**Do**

- Trust `tracks/production` over an old sentence in `docs/PLAY_STORE.md`
- Send phone shots in order `01` … `08` after `deleteall` on that image type
- Send the existing YouTube URL back when updating a listing, or the video field clears

**Don't**

- Commit keystores, `key.properties`, or the service-account JSON
- Use `python` on this Windows box — use `py -3`
- 9:16-crop the 512 icon
- Leave old tablet shots up
- Point players at GitHub Releases or upload an APK to itch
- Commit the edit before images, text, and the bundle are all staged

## Related

- Privacy copy: `docs/PRIVACY.md`
- Phone shots: `store-listing-shoot`
- itch.io page: `tool/store_listing/itch/PAGE.md`

## Done when

- `docs/PLAY_STORE.md` matches the last `tracks/production` read.
- `pubspec.yaml` versionName equals `ChangelogCatalog.currentVersion`.
- No AAB was uploaded unless the owner asked in this turn.
