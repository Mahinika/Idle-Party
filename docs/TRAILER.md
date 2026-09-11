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

| Sec | Shot | On-screen (≤6 words) |
|-----|------|----------------------|
| 0–4 | Hub TODAY card (READY / clear goal) | Always know today's chase |
| 4–14 | A56 gameplay: party walks, fights, abilities | Your party keeps fighting |
| 14–19 | Welcome Back / AFK marketing card | Progress while you're away |
| 19–24 | A56 gameplay: switch heroes in GEAR | Build and equip your party |
| 24–30 | Title lockup + feature graphic feel | Idle Party |

Music: soft dungeon / parchment mood. No voice-over required. End on title —
no “Download now” hard sell if it fights the tone.

### Export

```powershell
# Needs ffmpeg on PATH (winget install --id Gyan.FFmpeg -e)
py -3 tool/store_listing/build_preview_video.py
# → tool/store_listing/preview/idle_party_preview_16x9.mp4  (~30s, Play/YouTube)
# → tool/store_listing/preview/idle_party_preview_9x16.mp4  (~30s, ads tests)
```

Music: owned `assets/custom/audio/music/hub.ogg`. A56 gameplay recordings:
`preview/gameplay_{hub,combat,gear}_raw.mp4`; if missing, the builder falls
back to tracked `tool/store_listing/marketing/` cards. Raw clips and preview
MP4s are gitignored — regenerate locally before Console upload.

Capture gameplay on A56 at 1080×2340 with `adb shell screenrecord`; use the
AL3 showcase save, **Zoom · Close**, and restore the emulator save afterward.
The 16:9 render puts the real phone capture beside the English promise; 9:16
keeps the whole phone UI visible.

- Play listing uses a **YouTube URL only** (not direct MP4). Live unlisted on
  **Cognifox Studio**: `https://www.youtube.com/watch?v=OMWXbgGBFMA`
  (relinked **2026-09-11**; old personal upload `fiZjJ9S9l4A` superseded).
- Rebuild from local 16:9 if the clip changes, then replace the YT upload and
  update the Console field. Keep 9:16 for ads tests (`docs/PLAY_GROWTH.md`).
- YT must stay public/unlisted, **ads off**, embeddable, not age-restricted.

### Do not

Puzzle / BR / Roblox framing. Class-spec jargon. Zone-count brag walls.
Engine / ads / GitHub mentions.
