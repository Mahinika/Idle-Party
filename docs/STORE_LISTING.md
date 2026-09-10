# Idle Party — store listing (research + copy)

**Updated:** 2026-08-22 · Target: Google Play (en-US) · Honesty first.

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
| 6 | **Preview video** | Strong for games when available; optional for Alpha. |

### Rules we follow for Idle Party

1. **Real UI only** — no fake chrome, no “#1 idle” badges, no borrowed art.
2. **Benefit order** — screenshot 1 = chase / hub fantasy; 2 = combat feel; 3 = grow stronger; later = KEY / Ascend / keep gear.
3. **Captions short** (≤ ~8 words) if used; never cover critical HUD.
4. **Phone portrait** 9:16, ≥1080 px wide (Play featuring bar).
5. **Copy matches ship** — 15 zones, 31 specs, KEYSTONE (not invented systems).
   Do **not** promise “no ads forever” — rewarded POWERUPS and a cheap SHOP
   catalog exist; billing may land later (`docs/SHOP_MONETIZATION.md`).
6. **English only on the store page** — default locale **en-US**. Do not add
   translated Play listings (sv-SE or otherwise). Screenshot captions stay English.

### Idle Party pitch (one line)

*Grow a fantasy party that keeps fighting while you are away — and always know what you are chasing today.*

---

## en-US copy (paste into Play Console)

### Short description (80 chars max)

```
Build a fantasy party, fight while away, and return to real progress.
```

(69 characters)

### Full description

```
Build a fantasy party that keeps fighting while you are away. Return to loot, progress, and one clear goal for what to do next.

BUILD YOUR PARTY
• Choose classic fantasy roles: tanks, healers, melee fighters, ranged heroes, and spellcasters.
• Discover 10 classes and 31 distinct hero specs.
• Equip, merge, and craft gear to make the whole party stronger.
• Battle through 15 dungeon zones filled with room chests, enemies, and bosses.

IDLE PROGRESS, REAL COMBAT
• Watch your heroes move, fight, heal, and use their own abilities.
• Come back to AFK progress powered by the same dungeon combat.
• Leave a dungeon whenever you want and continue when you are ready.
• TODAY puts your next useful goal directly on the main button.

KEEP GROWING
• Ascend to unlock more heroes and permanent upgrades.
• Reach level 100 to open challenging endgame modes: KEYSTONE, Infinity Gauntlet, Rifts, and Greater Rifts.
• Take on daily, weekly, and long-term quests.
• Optional Google Play Games adds cloud save and seasonal leaderboards.

FAIR PLAY
• Single-player — no Idle Party account required.
• Optional rewarded ads grant timed boosts and never interrupt a fight.
• Designed for portrait phones.

Start your party and take one more floor.
```

### Release notes — Alpha / Production ship line (en-US)

Working ship: **1.12.117+146** (`pubspec.yaml`). Paste into Play **Release notes** (en-US) when uploading Production:

```
• TODAY now puts your next useful goal directly on the main button.
• QUESTS now includes Daily, Bounty, Side, Weekly, and long-term goals.
• Explore 15 World Path zones with smoother AFK dungeon progress.
```

### Full description honesty (SHOP)

Full description may mention optional cheap SHOP convenience (boosts / ad-free) once
Play Console products are active. Do **not** imply whale packs, gacha, or BiS-for-cash.
POWERUPS ads remain the free path to the same boost power.

### Screenshot plan (Play phone carousel, 2026-09-10)

Lead with the promise, then prove it with real in-game UI. Promo cards live in
`tool/store_listing/marketing/`; current UI captures live in
`tool/store_listing/out/`. All are English, 1080×1920. Play max is **8** phone
shots.

| # | Source | Caption |
|---|--------|---------|
| Feature | `marketing/01_feature_graphic_1024x500.png` | IDLE PARTY · Grow a party. Farm AFK. |
| 1 | `marketing/02_todays_chase_1080x1920.png` | Always know today's chase |
| 2 | `out/02_02_combat.png` | Your party keeps fighting |
| 3 | `out/03_03_gear.png` | Build and equip your party |
| 4 | `marketing/05_build_party_1080x1920.png` | 10 classes. 31 specs. |
| 5 | `out/05_05_zone.png` | Explore the World Path |
| 6 | `marketing/07_afk_progress_1080x1920.png` | Progress while you're away |
| 7 | `marketing/08_keystone_1080x1920.png` | KEYSTONE. Beat the clock. |
| 8 | `marketing/09_ascend_1080x1920.png` | Ascend. Keep your power. |

The three UI shots are current game captures with a small caption band. The
other five are branded explainers using owned Idle Party art.

### Feature graphic note

Current Play feature graphic is `01_feature_graphic_1024x500.png` (party + title). Icon stays owned `app_icon`.

## How we capture screenshots (lessons)

Do **not** start from a blank day-one save. Pipeline:

1. `flutter test tool/store_listing/export_showcase_save_test.dart` → `showcase_save.json`
2. Flutter web on `:8080` + `py -3 tool/store_listing/capture_playwright.py`
3. `py -3 tool/store_listing/compose_shots.py` → `out/` (1080×1920, caption on **top**)

Hard-won rules:

| Pitfall | Fix |
|---------|-----|
| CONTINUE disabled after inject | Web SharedPreferences JSON-encodes strings → `JSON.stringify(raw)` into `flutter.idle_party_save_v2` |
| Tabs (FORGE / KEEP / GEAR) ignore clicks | `MenuChrome.bridgedTab` + `__idlePartyClick` (CanvasKit TabBar is not DOM) |
| Widget-test screenshots look blank | Prefer Playwright; Google Fonts + `toImage` fights you |
| AL0 / all LOCKED / forge +0 | Use showcase save (AL3+, clears on World Path, real rates) |
| Fat caption covering HUD | Top caption band in `compose_shots.py`, crop bias per shot |
| Play Console file picker blocked | CORS-serve `out/`, CDP `fetch` + `DataTransfer` (same idea as AAB) |

Full agent recipe: `.cursor/skills/play-store-prep/SKILL.md` § Store screenshots.

## Play Console status (2026-09-10)

- Short + full description: en-US only (this file). Clearer pitch + feature sections.
- Phone screenshots (8): mixed branded cards + real combat/gear/zone UI from
  `tool/store_listing/upload/`.
- Developer name: **Cognifox Studio** (was Stuido) pending Google approval.
- **Listing changes submitted for review** 2026-09-10 (short + full + phone shots).
- **Production live until publish:** **1.12.110 (139)**; Production **1.12.117 (146)** also in review.
- Closed Alpha remains for early builds. Do not advertise GitHub Releases to players.
