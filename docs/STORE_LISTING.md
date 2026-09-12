# Idle Party — store listing (research + copy)

**Updated:** 2026-09-11 · Target: Google Play (en-US) · Honesty first.  
Growth checklist / review templates: [`PLAY_GROWTH.md`](PLAY_GROWTH.md).

## Research: what makes people tap Install

Sources: Play Console Help (preview assets), ASO / CRO guides 2025–2026
(ASOMobile, AppDrift, InspiringApps), plus Idle Party prefs (phone-only,
fairness, cheap convenience SHOP).

| Rank | Asset | Why it moves installs |
|------|--------|------------------------|
| 1 | **Icon** | Seen in search before the page; must read at tiny size and look unlike neighbors. |
| 2 | **First 2–3 screenshots** | Visible in search carousels; most users never scroll further. Lead with the *promise*, not settings. |
| 3 | **Short description** (≤80 chars) | Under the title in search; one sentence of genre + hook. |
| 4 | **Feature graphic** | Top of the listing page (not always search). Atmosphere + readable title. |
| 5 | **Full description** | For people who already almost decided; keywords + honesty. |
| 6 | **Preview video** | Strong for games when available — see `docs/TRAILER.md` § Play preview. |

### Rules we follow for Idle Party

1. **Real UI only** — no fake chrome, no “#1 idle” badges, no borrowed art.
2. **Benefit order** — screenshots 1–2 = live first-minute combat (the crawl);
   then chase / grow / classes; later = World Path / AFK / Ascend. Not KEY as
   the search lead.
3. **Captions short** (≤ ~8 words) if used; never cover critical HUD.
4. **Phone portrait** 9:16, ≥1080 px wide (Play featuring bar).
5. **Copy matches ship** — 15 zones, 31 specs, KEYSTONE (not invented systems).
   Do **not** promise “no ads forever” — rewarded POWERUPS and a cheap SHOP
   catalog exist (`docs/SHOP_MONETIZATION.md`).
6. **English only on the store page** — default locale **en-US**. Do not add
   translated Play listings (sv-SE or otherwise). Screenshot captions stay English.
7. **Genre honesty** — Category stays **Rollspel / Role Playing** (one only).
   Play tags are a **fixed list**, max **5** — not free keywords.
   **Live Console tags (2026-09-11):** **Clicker-rollspel**, **Rollspel**
   (Swedish UI; no separate “Idle” / “Incremental” tags in the picker —
   Clicker-rollspel is the closest idle-RPG cluster). Removed dishonest
   Clicker-spel + Rogue-liknande. Keywords in short/full copy: idle RPG,
   AFK, party, dungeon, Ascend. Never puzzle / battle royale / sandbox UGC
   framing. Never Casual / Action / Arcade as category.

### Idle Party pitch (one line)

*Grow a fantasy party that keeps fighting while you are away — and always know what you are chasing today.*

---

## en-US copy (paste into Play Console)

### Short description (80 chars max)

```
Idle RPG: grow a fantasy party that fights AFK — always know today's chase.
```

(75 characters)

### Full description

```
Idle fantasy RPG for phones. Build a party that keeps fighting while you are away. Return to loot, progress, and one clear TODAY goal.

BUILD YOUR PARTY
• Choose classic fantasy roles: tanks, healers, melee fighters, ranged heroes, and spellcasters.
• Discover 10 classes and 31 distinct hero specs.
• Equip, merge, and craft gear to make the whole party stronger.
• Battle through 15 dungeon zones filled with room chests, enemies, and bosses.

IDLE PROGRESS, REAL COMBAT
• Watch your heroes move, fight, heal, and use their own abilities — the same combat when you AFK.
• Leave a dungeon whenever you want and continue when you are ready.
• TODAY puts your next useful goal on the main button: claim, equip, or enter.

KEEP GROWING
• Ascend to unlock more heroes and permanent upgrades.
• Reach level 100 to open challenging endgame modes: KEYSTONE, Infinity Gauntlet, Rifts, and Greater Rifts.
• Take on daily, weekly, and long-term quests.
• Optional Google Play Games adds cloud save and seasonal leaderboards.

FAIR PLAY
• Single-player — no Idle Party account required.
• Optional rewarded ads (hub POWERUPS) grant timed boosts and never interrupt a fight.
• Optional SHOP sells cheap convenience only (boosts, ad-free, small QoL) — not pay-to-win gear.
• Privacy policy covers optional Play Games, ads, and analytics.
• Designed for portrait phones.

Start your party and take one more floor.
```

### Release notes — Alpha / Production ship line (en-US)

Working ship: **1.12.156+186** (`pubspec.yaml`). Paste into Play **Release notes** (en-US) when uploading Production:

```
• Your party fights on its own. GEAR uses EQUIP; BAG keeps FILTERS on the sheet; compare leads with ATK / DEF / STA.
```

### Full description honesty (SHOP)

SHOP convenience (boosts / ad-free / QoL) is live in Console — the FAIR PLAY
line above is accurate. Do **not** imply whale packs, gacha, or BiS-for-cash.
POWERUPS ads remain the free path to the same boost power.

### Screenshot plan (Play phone carousel)

Lead with the **live first minute of combat** (search carousel). Promo cards
live in `tool/store_listing/marketing/`; first-minute captures in
`tool/store_listing/out/`. All English, 1080×1920. Play max is **8** phone
shots. High-res icon: `out/play_icon_512.png` (owned `app_icon`).

| # | Source | Caption |
|---|--------|---------|
| Icon | `out/play_icon_512.png` | Owned cave-party mark (same as launcher) |
| Feature | `marketing/01_feature_graphic_1024x500.png` | IDLE PARTY · Grow a party. Farm AFK. |
| 1 | `out/01_01_combat_a.png` | Your party fights on its own |
| 2 | `out/02_02_combat_b.png` | Same fight while you are away |
| 3 | `marketing/02_todays_chase_1080x1920.png` | Always know today's chase |
| 4 | `out/03_03_gear.png` | Build and equip your party |
| 5 | `marketing/05_build_party_1080x1920.png` | 10 classes. 31 specs. |
| 6 | `out/05_05_zone.png` | Explore the World Path |
| 7 | `marketing/07_afk_progress_1080x1920.png` | Progress while you're away |
| 8 | `marketing/09_ascend_1080x1920.png` | Ascend. Keep your power. |

Shots **1–2** are a **new-save** Sandy floor (starter Shield / Healer / Damage),
not KEY / Gauntlet / AL20 chrome. Capture:

1. `flutter test tool/store_listing/export_showcase_save_test.dart`
2. Flutter web on `:8080`
3. `py -3 tool/store_listing/capture_first_minute.py`
4. `py -3 tool/store_listing/compose_shots.py`
5. `py -3 tool/store_listing/make_listing_icon.py`

Console paste of those files is a **separate** owner box.

### Feature graphic note

Current Play feature graphic is `01_feature_graphic_1024x500.png` (party + title).
Listing **icon** is owned `app_icon` resized to 512 (`make_listing_icon.py`).

## How we capture screenshots (lessons)

Do **not** use an empty hub as shot 1. Growth mandate: shots **1–2** are
**new-save first-minute combat** (`capture_first_minute.py`). The AL3 showcase
save is still for later carousel slots (gear / world path), not the search
lead.

Pipeline:

1. `flutter test tool/store_listing/export_showcase_save_test.dart` →
   `first_minute_save.json` (+ `showcase_save.json` for later slots)
2. Flutter web on `:8080` + `py -3 tool/store_listing/capture_first_minute.py`
3. `py -3 tool/store_listing/compose_shots.py` + `make_listing_icon.py` → `out/`

Hard-won rules:

| Pitfall | Fix |
|---------|-----|
| CONTINUE disabled after inject | Web SharedPreferences JSON-encodes strings → `JSON.stringify(raw)` into `flutter.idle_party_save_v2` |
| Injected save overwritten / Welcome Back | `add_init_script` before Flutter boots; bump `lastUpdated` so AFK cannot eat the first minute |
| Tabs (FORGE / KEEP / GEAR) ignore clicks | `MenuChrome.bridgedTab` + `__idlePartyClick` (CanvasKit TabBar is not DOM) |
| Widget-test screenshots look blank | Prefer Playwright; Google Fonts + `toImage` fights you |
| AL0 empty **hub** / all LOCKED / forge +0 | Do not use as shot 1. Shot 1–2 = in-dungeon Sandy. Showcase AL3 is for later slots |
| Fat caption covering HUD | Top caption band in `compose_shots.py`, crop bias per shot |
| Play Console file picker blocked | CORS-serve `out/`, CDP `fetch` + `DataTransfer` (same idea as AAB) |

Full agent recipe: `.cursor/skills/play-store-prep/SKILL.md` § Store screenshots.

## Play Console status (2026-09-12)

- Short + full description: en-US only (this file) — **idle RPG ASO pasted + submitted for review 2026-09-11**.
- Phone screenshots **1–2** (live first-minute Sandy combat) **submitted for
  review 2026-09-12** (`Ändringarna granskas`). Play listing currently has
  those two phone slots only (minimum 2). Listing **icon** swapped to
  `play_icon_512.png` (1∶1 512) and **submitted 2026-09-12** (row **Ändra
  appikon**). Carousel 3–8 not attached this submit. Preview video still
  `https://www.youtube.com/watch?v=OMWXbgGBFMA`.
- Developer name: **Cognifox Studio**.
- Growth ops (reviews / video / ads): see [`PLAY_GROWTH.md`](PLAY_GROWTH.md).
- Preview video: `py -3 tool/store_listing/build_preview_video.py` →
  `tool/store_listing/preview/idle_party_preview_16x9.mp4` (+ 9x16). Built
  **2026-09-11** with real A56 hub/combat/GEAR gameplay. Live Play link
  (unlisted, **Cognifox Studio**): `https://www.youtube.com/watch?v=OMWXbgGBFMA`.
  Feed Short (public combat ad): `https://www.youtube.com/shorts/l9jWy29YwJM`
  — uploaded **2026-09-12** (related video → Play preview).
  Older listing 9:16 Short: `https://www.youtube.com/shorts/wdnrXCYLtZE`.
- Closed Alpha remains for early builds. Do not advertise GitHub Releases to players.
