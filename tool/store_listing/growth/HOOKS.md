# Idle Party — Shorts / TikTok / Reels hook library

**Updated:** 2026-09-17. English on-screen. Real A56 footage only — no AI combat, no fake UI.
Play link in **bio + first comment**, not as a GitHub Release. Cross-post the same master.

**Capture:** Samsung A56, 1080×2340, `adb shell screenrecord`, Zoom · Close.
Sandy new-save for “first minute” hooks. Showcase / later zones for spectacle.
Restore the emulator save afterward. Trim with `build_shorts_feed.py` or a 7–15s cut.

**Hard rules**

- Frame 0 = **live combat** (party walking or swinging). Not hub, not logo.
- Game name **Idle Party** on screen by **3s**.
- On-screen hook ≤ **6 words**.
- No AI voice, no stock, no “#1 idle”.
- End card text CTA only (`Idle Party · Google Play`). No official Play badge PNG.

**Caption block (every clip)**

```
Idle Party — idle RPG. Your fantasy party keeps fighting while you AFK.

Android (Google Play):
https://play.google.com/store/apps/details?id=com.idleparty.app
```

Hashtags (rotate, never stuff): `#idleRPG` `#AFK` `#androidgames` `#indiegames` `#pixelart`

Pick **5 of 20** per batch. Kill a format if 1s retention stays under ~30% after 10 posts.

| # | First-second on-screen | Footage | 7–15s beat | Why it might hold |
|---|------------------------|---------|------------|-------------------|
| 01 | They fight without you | Sandy new-save: party walks into first pack, auto-swings | Name card 1–3s → walk → one ability → freeze on crawl | Listing promise, first minute |
| 02 | Same fight while away | Combat continue, cut to Welcome Back / AFK card, back to same floor | Combat → AFK card 2s → combat | Idle hook without a menu lead |
| 03 | Healer saves the tank | Shield + healer: tank dips, heal lands, pack dies | Cold open on low HP bar → heal VFX → win | Role fantasy in one glance |
| 04 | Tap the cave to help | God Hand / tap steer AOE on a clump | Idle walk → tap smack → pack drops | Interactive idle, not a cookie clicker |
| 05 | One job on the hub | Hub TODAY READY, then **smash cut** to ENTER combat (combat still frame 0 via reverse: start in cave, flash hub 1s, back) | Cave fight → 1s TODAY → cave | Chase without leading on menus |
| 06 | Loot walks to you | Floor clear, gold/gear vacuum, walk to stairs | Last kill → vacuum → stairs | Satisfying idle loop |
| 07 | Merge makes the party | GEAR merge: two items → one stronger, smash cut to dungeon swing | Merge UI 3s max → bigger hit in cave | Progress you can see |
| 08 | Fifteen caves, one crawl | Fast cuts Sandy → Hell → Crystal (owned showcase combat) | 1s each zone, name once | Spectacle; not KEY chrome |
| 09 | Shield, healer, damage | Starter three specs walking as a blob, each kit fires | Role labels 1 word each | Party identity |
| 10 | Boss has a tell | Any shipped boss wind-up then party burst | Wind-up freeze → explode | “This is a fight,” not a number go up |
| 11 | Leave. Progress keeps | LEAVE mid-floor → hub crumb → re-enter same crawl | Combat → leave → combat | Honest AFK, not fake offline |
| 12 | Pixel party, real rooms | Wide shot of oval/L chamber, party pathing around props | No text except name | SpatialCombat is the listing hook |
| 13 | Equip. Walk back in | BAG equip a drop, character doll updates, dungeon again | Doll 2s → crawl | Paper-doll proof |
| 14 | Ascend. Party stays | Short Ascend confirm toast then starter cave with same heroes | “Party stays” 4 words → Sandy crawl | Prestige without whale framing |
| 15 | No gacha. Just the cave | Combat only; end card: fair SHOP / optional scrolls | Fight → one honesty line | Incremental crowd filter |
| 16 | Crit. Pack drops | Big crit number + pack wipe | First frame is the crit | Dopamine 1s |
| 17 | Corridor gate opens | Chamber clear → gate → next pack wakes | “Next room” energy | Floor blueprint, not a single arena |
| 18 | Flask mid-wipe | Party low, flask, turn | Near-death → recover | Stakes |
| 19 | World path, then ENTER | 1s continent map, then **immediately** Sandy combat (combat still first frame if you start the file on the cave and insert map at 4s) | Cave → map flash → cave | PATH without a dead hub lead |
| 20 | Comment asked the name | Combat loop, huge **IDLE PARTY** at 2s, Play in comment | Branded search seed | For clips that already got views |

## Per-clip caption variants (01–05 ready to paste)

**01**
```
They keep swinging when you look away. Idle Party — Android idle RPG.

Play: https://play.google.com/store/apps/details?id=com.idleparty.app
```

**02**
```
AFK is the same dungeon crawl. Not a different sim.

Idle Party on Google Play.
```

**03**
```
Shield holds. Healer lands. The pack drops. Party idle RPG.

Idle Party — Android.
```

**04**
```
They fight on their own. Tap the cave when you want to help.

Idle Party.
```

**05**
```
One chase. Then back into the room.

Idle Party — idle RPG on Google Play.
```

## Batch recipe (owner ~1 evening)

1. Record 3× 60s combat (Sandy new-save, one later zone, one boss).
2. Cut 7 clips from the table (mix 01, 03, 04, 06, 09, 10, 16).
3. Hardcode **Idle Party** text by 3s.
4. Upload TikTok + Shorts + Reels same day. Pin Play comment.

Do **not** upload the 30s Play listing trailer as a FYP Short (`build_preview_video.py`).
