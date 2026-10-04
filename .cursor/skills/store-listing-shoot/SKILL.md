---
name: store-listing-shoot
description: >-
  Shoots the Idle Party Google Play listing from the Samsung A56: eight phone
  screenshots, the Sandy preview video, the 512 icon, and the 1024x500 feature
  graphic. Use when the store page, screenshots, preview video, or feature
  graphic are stale, or when hero art or hub chrome changed and the Play shots
  would lie. Do not upload an AAB. Do not use Flutter web unless the emulator
  cannot run.
---

# Store listing shoot (Idle Party)

The pictures must show the build that is live on Play. Web captures are the
fallback, not the default.

## Shoot

1. `flutter test tool/store_listing/export_showcase_save_test.dart`
2. AVD `Samsung_A56` booted, `com.idleparty.app` on the version in
   `ChangelogCatalog.currentVersion`.
3. `py -3 tool/store_listing/capture_a56_shots.py`
   - Shots 1–3: `first_minute_save.json` (new-save Sandy).
   - Shots 4–8: `showcase_save.json` (AL3 hub).
   - Restores the emulator save when it finishes.
4. `py -3 tool/store_listing/compose_shots.py`
5. `py -3 tool/store_listing/make_listing_icon.py`
6. `py -3 tool/store_listing/make_feature_graphic.py`
7. `py -3 tool/store_listing/capture_preview_beats.py crawl`
8. `py -3 tool/store_listing/build_preview_video.py`

## What the page is

- Shots 1–3 and the first 20 seconds of the video are the Sandy crawl a new
  player sees. No Gauntlet, Greater Rift, Hell's Gate, or KEY in that lead.
- Captions stay in the top band, under 20% of the frame.
- Video music is owned `assets/custom/audio/music/bed_warm.ogg`. Never
  `hub.ogg` (that file is CC0 and can draw a Content ID claim).
- The builder exits if the crawl recording or the music file is missing.
  Do not ship a silent film or a still-card stand-in.
- Portrait 1080×1920 fills the frame. Keep the 16:9 file as the reserve if
  Play refuses the portrait embed.

## Upload

Follow `play-store-prep` reference for Console graphics. One PNG at a time.
Do not 9:16-crop the icon. Do not upload an AAB unless the owner asks that
turn.

YouTube (`@CognifoxStudio`) is the owner's login. Hand them
`tool/store_listing/preview/idle_party_preview_9x16.mp4`. Public, ads off,
embedding on. They confirm Studio shows no Content ID claim. Then put the
new URL in the Play preview field.

## After

Update the freshness row in `docs/PLAY_STORE.md` to this version and date.
`flutter test test/store_listing_plan_test.dart` must pass.
