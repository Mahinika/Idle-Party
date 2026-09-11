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
| 4–12 | Dungeon: party walks, fights, abilities | Your party keeps fighting |
| 12–18 | Leave / Welcome Back AFK summary (or AFK marketing card) | Progress while you're away |
| 18–24 | GEAR / party / Ascend beat (pick one) | Grow stronger. Ascend. |
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

Music: owned `assets/custom/audio/music/hub.ogg`. Stills: tracked
`tool/store_listing/marketing/` cards (TRAILER shot order). Preview MP4s are
gitignored — regenerate locally before Console upload.

- Landscape **YouTube** link Play accepts, or Console upload of the 16:9 file.
- Keep the vertical 9:16 cut for ads tests later (`docs/PLAY_GROWTH.md`).

### Do not

Puzzle / BR / Roblox framing. Class-spec jargon. Zone-count brag walls.
Engine / ads / GitHub mentions.
