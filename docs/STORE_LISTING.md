# Idle Party — store listing (research + copy)

**Updated:** 2026-08-20 · Target: Google Play (en-US) · Honesty first.

## Research: what makes people tap Install

Sources: Play Console Help (preview assets), ASO / CRO guides 2025–2026
(ASOMobile, AppDrift, InspiringApps), plus Idle Party prefs (phone-only,
fairness, no IAP).

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
   Do **not** promise “no ads / no paid store forever” — monetization may come later.

### Idle Party pitch (one line)

*Grow a fantasy party that keeps fighting while you are away — and always know what you are chasing today.*

---

## en-US copy (paste into Play Console)

### Short description (80 chars max)

```
Grow a party, farm dungeons AFK, chase KEYSTONE and Ascend.
```

(59 characters)

### Full description

```
Idle Party is a single-player idle RPG for phones: grow a fantasy party, clear painted dungeons, and come back to real progress.

WHAT YOU DO
• Build a party of classic kits (tanks, healers, DPS) — 10 classes and 31 specs.
• Enter the World Path: 15 zones from Sandy Caverns through Mothveil Hollow.
• Fight on multi-chamber floors with loot, room chests, and bosses. Companions follow and hit.
• Leave the dungeon when you want — AFK catch-up keeps the party moving.
• Hub TODAY shows one clear chase (READY / ALMOST) so you always know the next beat.

LONG-TERM GOALS
• KEYSTONE: set a key, beat the boss under par, climb vault rewards.
• Ascend: reset the run, keep essence / Apex / pets / meta upgrades, unlock more kits.
• Infinity Gauntlet (Ascend Level 10+): endless Crystal Spire climb.
• Apex forge: craft forever gear that survives Ascend. MERGE two bag pieces into one stronger item.

FAIR PLAY
• Single-player — no idle-party account required.
• Optional Google Play Games for seasonal boards and cloud save (you can stay offline).
• Built for portrait phones.

Install, start a party, and take one more floor.
```

### Screenshot caption plan (optional overlays)

| # | Scene | Caption |
|---|--------|---------|
| 1 | Hub + World Path / TODAY | Always know today’s chase |
| 2 | Dungeon combat (party vs pack) | Your party keeps fighting |
| 3 | GEAR / bag / upgrade | Grow stronger every floor |
| 4 | POWER → FORGE → KEEP | Keep power when you Ascend |
| 5 | Hub World Path (15 zones) | 15 zones · World Path |
| 6 | POWER → INCOME | See your gold per minute |

### Feature graphic note

Keep 1024×500 from owned `app_icon` / brand art. Refresh only if title treatment looks dated; do not paste competitor screenshots.

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

## Play Console status (2026-08-20)

- Short description unchanged. Full description submitted with companions + MERGE (this file).
- Six phone screenshots from earlier the same day (`tool/store_listing/out/`) — not recaptured for 1.12.25.
- Closed Alpha AAB **55 (1.12.25)** + listing copy submitted 2026-08-20 (“Ändringarna granskas”). Testers keep **1.12.21** until Google publishes.
- Feature graphic + icon still from owned `app_icon`.
