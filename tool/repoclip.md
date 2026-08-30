# RepoClip operator checklist

Not product copy. The player cinematic brief is [`docs/TRAILER.md`](../docs/TRAILER.md).
Ignore this file when writing narration.

Paste into [repoclip.io](https://repoclip.io/) after `docs/TRAILER.md` and the
README look-and-feel block are on GitHub `main`.

Repo URL: `https://github.com/Mahinika/Idle-Party`

Custom instructions: copy [`docs/REPOCLIP_PROMPT.txt`](../docs/REPOCLIP_PROMPT.txt)
(must stay ≤500 characters).

## Dashboard settings (in-game boot)

- Mode: **Video Short** (~25s, 5 clips). Not Image for the ship file. Not Video Long.
- Aspect: **9:16**
- Visual style: **vibrant** (never tech or realistic)
- Background music: on
- Voice (in the prompt): fable or onyx
- Plan for ship: **Pro** — 1080p, Kling 3.0 Pro, no watermark, commercial license

Do not ship a Free/Starter watermarked 720p file in the APK.

## Cheap loop

1. Free **Image** generate first — judge script + art direction, not motion.
2. If it talks about GitHub / Flutter / feature lists, tweak `TRAILER.md` or the
   prompt and regenerate Image.
3. When the stills feel like Idle Party, Pro **Video Short** 9:16 Kling.
4. Optional later: a second 16:9 run for YouTube / README (not for the boot).

## QA — reject and regenerate if any fail

- No GitHub, Flutter, Dart, CI, ads, or “star this repo”
- No feature list (KEYSTONE, 15 zones, 31 specs, Gauntlet, Ascend)
- Story is cave mouth → dungeon loot → tap the map → first boss
- Pixel / torch / charcoal-gold — not photoreal stock fantasy
- English, short sentences
- Ends in the cave; no download / subscribe CTA
- No RepoClip watermark; 9:16 with no letterbox bars

## After a pass

Save the MP4 as `assets/video/boot_intro.mp4`, add that path under
`flutter.assets` in `pubspec.yaml`, and set `CustomAssets.introVideoBundled`
to `true`. The boot screen plays it on first cold start (skippable, respects
mute) and falls back to the painted 3-beat intro if the file is missing or
decode fails.

This cinematic is not a Google Play preview (Play wants real gameplay).
