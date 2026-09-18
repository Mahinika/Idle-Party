# Idle Party — store listing (research + copy)

**Updated:** 2026-09-18 · Target: Google Play (en-US) · Honesty first.  
Growth checklist / review templates: [`PLAY_GROWTH.md`](PLAY_GROWTH.md).  
0 kr discovery pack: [`tool/store_listing/growth/`](../tool/store_listing/growth/).  
Play charts + idle/RPG listing peers: [`tool/store_listing/growth/PLAY_LISTING_PEERS.md`](../tool/store_listing/growth/PLAY_LISTING_PEERS.md).

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
   Do **not** promise “no ads forever” — rewarded SCROLLS and a cheap SHOP
   catalog exist (`docs/SHOP_MONETIZATION.md`).
6. **English only on the live store page** — default locale **en-US**.
   Screenshot captions stay English. Extra Play **metadata** locales live in
   [`tool/store_listing/growth/LOCALES.md`](../tool/store_listing/growth/LOCALES.md)
   and stay **gated** until the owner says paste (in-game UI stays English).
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

### App name / title (30 chars max)

Play indexes this hardest. Genre is honest (idle RPG). No “free”, “#1”, emoji.

```
Idle Party: Idle RPG
```

(20 characters)

### Short description (80 chars max)

**Paste this** (live line, 75 characters — keep until listing experiments have traffic):

```
Idle RPG: grow a fantasy party that fights AFK — always know today's chase.
```

Later A/B only (do not paste until Console experiments can finish):

```
Idle RPG: a fantasy party dungeon crawl that fights AFK.
Idle RPG: fantasy party dungeon crawl. Fights AFK on your phone.
Offline idle RPG: your party keeps the dungeon crawl going AFK.
```

### Full description

Match the itch.io page (`tool/store_listing/itch/PAGE.md`) so search and
community say the same game. Play still hides KEY in the first hour in-app;
full description may name endgame after party level 100.

```
Idle fantasy RPG for phones. Watch a party crawl dungeons on screen — they keep fighting while you are away. Return to loot, progress, and one clear TODAY goal.

Idle Party is a portrait idle RPG and dungeon crawl. The camera stays on your heroes as they move, fight, heal, and use their own abilities — the same combat when you AFK or play offline. Free to play, single-player, no Idle Party account. Combat is on screen in about a minute.

BUILD YOUR PARTY
• Choose classic fantasy roles: Shield, Healer, and Damage to start, then tanks, healers, melee fighters, ranged heroes, and spellcasters.
• Discover 10 classes and 31 distinct hero specs.
• Equip, merge, and craft gear to make the whole party stronger.
• Battle through 15 dungeon zones filled with room chests, enemies, and bosses.

IDLE PROGRESS, REAL COMBAT
• Watch the party fight on its own. Tap the fight to help. Leave a dungeon whenever you want and continue when you are ready — the cave crawl is the same fight AFK.
• TODAY puts your next useful goal on the main button: claim, equip, or enter.
• Day-one menus stay small until gold, the shop, and essence mean something.

KEEP GROWING
• Ascend to unlock more heroes and permanent upgrades. Your party stays; the run bag resets.
• Reach level 100 to open challenging endgame modes: KEYSTONE, Infinity Gauntlet, Rifts, and Greater Rifts.
• Take on daily, weekly, and long-term quests.
• Optional Google Play Games adds cloud save and seasonal leaderboards.

FAIR PLAY
• Single-player — no Idle Party account required.
• Optional rewarded ads (hub SCROLLS) grant timed scrolls and never interrupt a fight.
• Optional SHOP sells cheap convenience only (forever SCROLLS, ad-free, small QoL) — not pay-to-win gear.
• Privacy policy covers optional Play Games, ads, and analytics.
• Designed for portrait phones.

Start your party and take one more floor.

Cognifox Studio · cognifoxstudio@gmail.com
Privacy: https://github.com/Mahinika/Idle-Party/blob/main/docs/PRIVACY.md
```

### Release notes — Alpha / Production ship line (en-US)

Working ship: **1.12.172+202** (`pubspec.yaml`). Pasted as Play Production release notes with **202** submitted **2026-09-17**:

```
• Your party fights on its own. Day-one menus stay GEAR and MORE until gold, the shop, and essence mean something. Shield, Healer, and Damage kits show their job in the fight.
• The dungeon camera stays on your party. PATH is a continent map. PUSH floors pay a little essence. SHOP has forever SCROLLS and a redeem code. Party Lv100 still unlocks Craft Trial and the extra hunts.
```

### Full description honesty (SHOP)

SHOP convenience (boosts / ad-free / QoL) is live in Console — the FAIR PLAY
line above is accurate. Do **not** imply whale packs, gacha, or BiS-for-cash.
SCROLLS ads remain the free path to the same boost power.

### Screenshot plan (Play phone carousel)

Lead with the **live first minute of combat** (search carousel). Promo cards
live in `tool/store_listing/marketing/`; first-minute captures in
`tool/store_listing/out/`. All English, 1080×1920. Play max is **8** phone
shots. High-res icon: `out/play_icon_512.png` (owned `app_icon`).

| # | Source | Caption |
|---|--------|---------|
| Icon | `out/play_icon_512.png` | Owned cave-party mark (same as launcher) |
| Feature | `marketing/01_feature_graphic_1024x500.png` | IDLE PARTY · Party fights AFK. |
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
2. `flutter build web --release` and serve `build/web` on `:8080`
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
2. Release web on `:8080` (`flutter build web`) + `py -3 tool/store_listing/capture_first_minute.py`
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
| Flutter `web-server` never installs `__idlePartyButtons` | Serve a **release** `flutter build web` on :8080; `web-server` waits for a debug Chrome and Playwright times out |

Full agent recipe: `.cursor/skills/play-store-prep/SKILL.md` § Store screenshots.

## Console paste box (owner — no AAB)

Paste from this file. Do **not** upload an AAB in this listing batch.
Locales in `growth/LOCALES.md` stay gated until you say paste.

| Console field | Paste / file |
|---------------|----------------|
| App name | `Idle Party: Idle RPG` (confirm live is not bare “Idle Party”) |
| Short description | The 75-char line above |
| Full description | The full block above (crawl-on-screen opening) |
| Category | Role Playing / Rollspel only |
| Tags (max 5) | Keep **Clicker-rollspel** + **Rollspel**. Do not add Clicker-spel or Rogue-liknande |
| Phone screenshots 1–8 | `tool/store_listing/out/` + `marketing/` per table (shots 1–2 recaptured with party-centered camera) |
| Icon 512 | `out/play_icon_512.png` |
| Feature graphic | `marketing/01_feature_graphic_1024x500.png` |
| Preview video | After you upload the rebuilt MP4: keep ads off, unlisted OK. Until then `https://www.youtube.com/watch?v=OMWXbgGBFMA`. New files: `preview/idle_party_preview_16x9.mp4` + `_9x16.mp4` |
| Store listing experiment | Deferred until listing traffic is large enough |

Rebuild preview: `py -3 tool/store_listing/build_preview_video.py` (combat in first 10 s).

## Play Console status (2026-09-18)

- **Listing copy live:** app name **Idle Party: Idle RPG** + crawl-on-screen
  full desc on the public store. Extra locales gated in
  `tool/store_listing/growth/LOCALES.md`.
- **Production AAB:** **1.12.172+202** submitted **2026-09-17** (full rollout).
- **Phone carousel swap submitted 2026-09-18:** new 8 play-ready shots
  (`tool/store_listing/out/play_ready/` → Console `01_play_combat_a` …
  `08_play_ascend`). Order: combat a/b → TODAY chase → GEAR → party → zone →
  AFK → Ascend. Console: *Ändringarna granskas* (snabbkontroller then review).
- Listing preview URL: keep `https://www.youtube.com/watch?v=OMWXbgGBFMA`.
  Rebuilt MP4 (combat first 10 s) on Cognifox unlisted:
  `https://www.youtube.com/watch?v=XfKog5CAiUs` — Play rejected embed
  (ads/visibility); fix channel kids/ads, then swap later. Files:
  `preview/idle_party_preview_16x9.mp4` (+ 9:16).
- Icon `play_icon_512.png`. Developer: **Cognifox Studio**.
- Growth ops: [`PLAY_GROWTH.md`](PLAY_GROWTH.md). Feed Short:
  `https://www.youtube.com/shorts/l9jWy29YwJM`. Older 9:16 Short:
  `https://www.youtube.com/shorts/wdnrXCYLtZE`.
- Closed Alpha remains for early builds. Do not advertise GitHub Releases to players.
