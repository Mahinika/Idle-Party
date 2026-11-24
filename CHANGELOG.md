# Changelog (main merges)

Short human notes for each merge to `main`. In-game What's New stays
`lib/core/changelog.dart` (`ChangelogCatalog`).

Add one bullet under `[Unreleased]` in every PR that targets `main`. CI
checks that this file changed.

## [Unreleased]

- **Abilities-61:** every hero spec reaches 11 kit abilities (Protection stays 13; Blood and Guardian unchanged) — 61 new spells with v3-layered `SpellShapePaint` / `SpellVfxLayers` (summon silhouettes, pillars, domes, meteor scorch), in-context A56 fight renders + v3 comparison sheet under `docs/design/abilities-61/rendered/`, labeled traveling bolts, fallback mechanics where proposals needed new engine work, and regression tests for catalog counts, legacy coeffs, saves, and combat resolution.
- Play review: race picker says cosmetic-only (no stat bonuses), and music bed resyncs after ads or dead voice handles via `MusicPlaybackPlan`.
- Analytics: once-per-install onboarding steps (prefs, not the save), install cohort and ad-free / season pass user properties, and separate Play purchase fail vs cancel. No price or reward change.
- Apex audit (2026-11-24): boss clears save the default craft goal before CRAFT opens, “Use auto target” keeps meter progress when auto still names the same mat, duplicate vault copies show the highest rank in the sheet, plus regression coverage for goal/meter toasts, vault bag cap, bag-only upgrades, legacy duplicates, and boss material payoff lines.
- UI batch 2: BIG/LIST fight toggle, FULL stays after first TRAIN buy, plain speed chip, shortfall on forge buy faces, 640px rail icons, FULL cave ≥34% layout check, and reduce-motion for fight presentation only.
- UI batch 1: fight HUD clarity, contrast, and chrome baseline.
- SHOP and ads copy: 24h featured Ad-free → Delver's Kit, unlisted Cinder/season rows hidden until Play prices, season pass and CAMP/Welcome Back clarity, hub WATCH ticket removed (SCROLLS stays), quest reroll labeled AD, reinstall pouch analytics placement.
- Arena review: heal crits repeat for the same floor and clock without moving damage rolls, portrait stays locked, a cancelled Play update opens the listing, a failed slot migration retries, quest dates follow the game clock, clipboard import keeps this device's Play purchases, purchase ids are never forgotten, friend claims count in one write, and Android backup does not copy the local save.
- Audit fixes: away catch-up is saved if the app backgrounds again, dead pets stay down, Ascend keeps leave rewards, a failed WISP ad can be retried, DODGE and PARRY show like BLOCK, STA no longer revives the dead, a dying enemy does not swing, hub idle and the comeback chest use the offline time cap, Shield Block's extra reduction applies in melee, and a rejected save write is rolled back.
- Crashlytics: `RenderFlex` overflows (including wipe-retry rewarded offer) record as non-fatal; the wipe panel scrolls on short phones at text scale 1.45; `setDungeonTilesReady` and `clearToast` defer `notifyListeners` during build. CI goldens for target strip / top bar refreshed on Linux Flutter 3.47.9 (pixel drift, no UI code).
- QA 2026-11-21: wipe scrim covers fight tools, ability-name floaters stack, the tomorrow teaser stays on the town card, and small UI fixes (MENU, party chip, shop, vault CTA, speed tip).
- QA retest: each sheet keeps its own subtitle, loot and ability names share one lane, the equip toast clears the lantern, the hero tab keeps the level, the CC line stays in its chip, a failed audio load retries once, and layout plus audio failures are non-fatal in Crashlytics.
- A fight save stamps the away clock, and leaving the app writes the current gold and essence before the process can be killed.
- Docs refresh for 1.14.0: README ship line, town and theme notes, sweep ledger, and playtest memory after the stack merged to main.

## [1.14.0] — 2026-11-21

- Release 1.14.0: fight UI stack (role icons, roster slots, town, Copilot batches A–C). Includes the unreleased 1.13.18 dungeon crash, banner, resume, and large-text fixes.
