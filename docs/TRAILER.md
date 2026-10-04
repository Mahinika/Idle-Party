# Idle Party — player cinematic brief

Idle Party is a cozy-but-crunchy **idle RPG for phones**. A small fantasy party
crawls painted dungeons. They fight while you watch — or while you are away.

This file is the **player-facing story** for a short boot cinematic. It is not a
developer demo, not a source-repo promo, and not a feature tour.

## One line

Your party fights while you watch. Tap to help. Grow stronger. No other game
required.

## Scenes (keep this order)

1. **Cave mouth.** A small party waits at the cave mouth. They fight without you.
2. **The cave.** Send them into a dungeon. They clear rooms and pick up loot.
3. **Your job.** Tap the map to help. Grow the party. Beat the first boss.
4. **Enter.** The party walks into the torch-lit cave. Fade. No call to action.

## Look

Pixel art. Torch-lit cave. Dark charcoal stone, warm gold light, parchment
text. A handful of heroes — shield, healer, damage — standing together.
Owned Idle Party identity art, Kenney-like world tiles.

**Not:** photoreal fantasy stock, neon, sci-fi HUD, IDE, terminal,
source-hosting websites, app-store mockups, or live UI of another game.

## Voice

English. Present tense. Short sentences. Storyteller, not salesman.
Simple words. No MMO homework, no class-spec jargon, no zone-count brag.

## Do not say

Do not mention the engine, source control, ads, agent docs, or tests. Do not
list class counts, zone counts, or endgame modes. End with the cave, not a
call to action.

## End

The party enters the cave. Silence. The game begins.

---

## Play Store preview video (15–30 s)

Separate from the boot cinematic. This clip sits on the **Google Play listing**
(search carousel + store page). English on-screen text only. Owned Idle Party
art + real UI — no fake #1 badges, no other-game footage.

### Goal

In one glance: **idle fantasy RPG** · party fights · AFK progress · TODAY chase.

### Shot list (keep this order)

Play Help: real combat in the **first 10 seconds** (muted autoplay). Hub is
not the lead.

| Sec | Shot | On-screen (≤6 words) |
|-----|------|----------------------|
| 0–8 | Sandy crawl: party walks and fights | IDLE PARTY / Your party fights on its own |
| 8–14 | Same cave: pack drops, they walk on | (no extra line) |
| 14–20 | Leave, one second of TODAY, back in the cave | Leave. They keep going. |
| 20–24 | Title over the same cave | Idle Party |

One cave. Gauntlet, Greater Rift, and Hell's Gate stay in the long
description, not in the first 20 seconds. A new player does not see them
until the whole party is level 100.

Music: owned Sandy bed `assets/custom/audio/music/bed_warm.ogg` (synth from
`tool/audio_synth`). Do **not** use `hub.ogg` here — that file is the CC0
track “Heavenly Loop”, not owned, and a Content ID claim can force ads on.
No voice-over. The clip must still make sense muted. End on the title over
the cave — no “Download now”.

### Export

```powershell
# Needs ffmpeg on PATH (winget install --id Gyan.FFmpeg -e)
py -3 tool/store_listing/build_preview_video.py
# → tool/store_listing/preview/idle_party_preview_16x9.mp4  (reserve if Play refuses portrait)
# → tool/store_listing/preview/idle_party_preview_9x16.mp4  (24s, store page)
```

Music: owned `assets/custom/audio/music/bed_warm.ogg`. The portrait film is
one Sandy crawl, `preview/gameplay_crawl_raw.mp4`. The builder stops if that
clip or the music file is missing. Raw clips and preview MP4s are gitignored
— regenerate locally before Console upload.

Capture on A56 at 1080×2340 with `adb shell screenrecord` (~30 fps). Saves
come from `export_showcase_save_test.dart` (Zoom · Close). Record with
`py -3 tool/store_listing/capture_preview_beats.py`, then restore the
emulator save. Do not reuse the 2026-09-20 combat raw (~13 fps).
The 9:16 film fills the frame (no blurred border). 16:9 keeps its soft
background and is only the reserve if Play refuses a portrait embed.

- Play listing uses a **YouTube URL only** (not direct MP4). Live unlisted on
  **Cognifox Studio** (`@CognifoxStudio`):
  `https://www.youtube.com/watch?v=UHLG28lHmPs`
  (relinked **2026-09-11**; old personal upload `fiZjJ9S9l4A` superseded).
  **2026-09-26:** local montage is Sandy crawl, Gauntlet, Greater Rift,
  Hell's Gate, a short AFK card, then the title (~28s, ~30 fps). Rebuild
  locally, then replace YT when ads/visibility pass Play. Do not reuse the
  ~13 fps `gameplay_combat_raw.mp4`.
- **Feed Short** (public combat ad, Cognifox Studio **2026-09-12**):
  `https://www.youtube.com/shorts/l9jWy29YwJM`
  Related video in Studio → unlisted Play preview `UHLG28lHmPs`.
- **Listing 9:16 Short** (older Play-trailer crop, still public):
  `https://www.youtube.com/shorts/wdnrXCYLtZE`
  (The 2026-09-11 upload `0zKNQKg6kaQ` is 16:9, so YouTube treats it as a
  regular video — keep or unlist separately.)
- Channel art helper:
  `py -3 tool/store_listing/build_youtube_channel_art.py`
  → `tool/store_listing/youtube/channel_avatar_800.png` +
  `channel_banner_2560x1440.jpg` (gitignored; upload in Studio → Anpassning).
- Rebuild from local 16:9 if the clip changes, then replace the YT upload and
  update the Console field. Keep 9:16 for Shorts / ads tests
  (`docs/PLAY_GROWTH.md`).
- Play listing YT: public/unlisted, **ads off**, embeddable, not age-restricted.
  Shorts stay **public** for reach.

### Do not

Puzzle / BR / Roblox framing. Class-spec jargon. Zone-count brag walls.
Engine / ads / GitHub mentions.

---

## Feed Short (combat first — not the Play trailer)

Separate clip for the **Shorts feed**. Do **not** reuse
`build_preview_video.py` or the Play shot list (hub → AFK card → logo). That
listing 9:16 file puts the phone in a blur frame; a feed Short wants
**full-bleed combat after a short hook card**.

Mobile-game ads (10–15s) usually go **hook → mechanic → product + CTA**.
This feed Short follows that: a short moving 03 hook card, three brisk zone
cuts with one benefit each, then a moving 07 AFK card with a Play Store
end card. On-screen English. Text CTA only (no official Play badge PNG).
Do not put a store CTA on the Play listing trailer.

| | Play preview | Feed Short |
|--|--------------|------------|
| Builder | `build_preview_video.py` | `build_shorts_feed.py` |
| First frame | Live combat (party centered) | Hook: *Your party fights even while you're away* |
| Picture | 16:9 listing + 9:16 phone-in-frame | intro + three zones + outro, 1080×1920 |
| On-screen | Chase / AFK / lockup beats | away hook → build / push / return → *Download free* |
| Music | owned `bed_warm.ogg` | owned `dungeon.mp3` |

```powershell
# A56: three showcase combat saves (hell / crystal / mothveil), Zoom · Close
# py -3 tool/store_listing/capture_shorts_shots.py
# → preview/gameplay_shorts_{hell,crystal,veil}_raw.mp4  (gitignored)
# Restore the emulator save afterward.

py -3 tool/store_listing/build_shorts_feed.py
# → tool/store_listing/preview/idle_party_shorts_feed.mp4  (~13s, gitignored)
# Shot trims live in gitignored preview/shorts_feed.json.
```

Feed hook library (20 first-second combat clips, A56):
[`tool/store_listing/growth/HOOKS.md`](../tool/store_listing/growth/HOOKS.md).
Cut a 7-clip FYP batch (not the 13s listing-style feed ad):

```powershell
py -3 tool/store_listing/capture_hook_clips.py
py -3 tool/store_listing/build_hook_clips.py
# → tool/store_listing/preview/hooks/01_they_fight.mp4 … 16_crit_pack.mp4
```

Recipe: [`tool/store_listing/growth/hooks_batch.json`](../tool/store_listing/growth/hooks_batch.json).

Live public Short: `https://www.youtube.com/shorts/l9jWy29YwJM`.
Related video in Studio → Play listing preview `UHLG28lHmPs`.
