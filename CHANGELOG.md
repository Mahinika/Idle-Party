# Changelog (main merges)

Short human notes for each merge to `main`. In-game What's New stays
`lib/core/changelog.dart` (`ChangelogCatalog`).

Add one bullet under `[Unreleased]` in every PR that targets `main`. CI
checks that this file changed.

## [Unreleased]

- IP-048–222: Crashlytics non-fatals on save/friend/boot catches, release `debugPrint` gated behind `kDebugMode`, post-frame measure guards on fight chrome/docks, deferred install-referrer read, shop restore idempotency test.
- Fixlist batch 2: d7/d14/d30 funnel events, boss_clear and daily_run_complete analytics, Crashlytics non-fatals on IO catches, dungeon.mp3 and town preview assets out of APK, text-scale persist on drag end, analyzer infos, and fixlist status doc.
- IP-383 / IP-402: LEAVE explains bag merge gold spend and hunt consolation essence (+Ne) in toast copy.
- Fixlist batch 3: CrashReport on save/swap/friend paths, kDebugMode-gated release logs, post-frame perf guards, full 95-item status doc.
- Fixlist UI batch 4 (IP-337–381): `TextOverflow.ellipsis` on remaining capped `Text` widgets in shell/hub HUD; mechanical fixlist status in `docs/fixlist-ui-751c-status.md`.
- Fixlist UI batch 3 (IP-026–030): a11y on race/spec picks, rift tier stepper, offline banner, sheet scrim; party HUD and coach lines allow two lines at 1.45; MARKET chip ellipsis; Apex material rows min touch; offline welcome still opens at 5 min away (not 2 min).
- Fixlist UI (IP-022–228): SLOW chip hint, SCROLLS rail rename, MERGE copy, ASCEND ghost, vault claimed tap, quest reroll (ad) label, party chip text scale, shop blurbs, Apex CRAFT a11y, Cinders on ESSENCE bar, title CHOOSE PARTY, starter pouch label.
- Fixlist UI copy: town QUESTS sign, TRAIN/MENU/MARKET player strings, hub→town via NavCopy, lantern and bag empty hints, Discord defer after offline return, relic discover line.
- Apex rank follows Ascend: max rank stays 3 through AL4, then one more rank every 5 Ascend levels up to 7 at AL20. Ranks 4–7 keep the +0.08 power step and cost more materials than rank 3. Each Ascend rebakes Apex item level to the new AL at the same rank. CRAFT shows the current max rank and when the next rank unlocks.
- Pre-Sunday UI polish: fight HUD drops in-cave hunt lines and CLAIM over the floor, F# CLEAR clears on the next floor, loot names spawn above the party, tomorrow vault copy names shelf not wallet gold, shorter SHOP header and Play wait text, two-line hero/gear names, 360×640 @1.45 layout on home and wallet.
- Copy polish (#136): shorter title tagline, one NEW PARTY start button, town FORGE · CRAFT naming, OPEN TRAIN on welcome back, plain ESSENCE and CRAFT lines, INN lock text matches roster size, Patch Notes no longer auto-covers the town square, and a clearer cave-cleared boss toast when no next zone opens.
- **Hero range / positioning:** Option A′ ranges + melee arc v2 (per-spec arc radius/step, tank stand, lone-melee rank fallback, combat arc / swarm rank); see `docs/RANGE_POSITIONING_AUDIT.md`.
- Sim nightly: tighten AoE×12 combat-share regression (parse median band, 4 trials); documents #116 spatial shift and #130 re-center (no kit coeffs in this PR).
- **Feral melee paint:** hide travel weapon bolts from non-ranged casters; compact caster announce puff instead of full disc; Maim impact stays on target.
- **Melee signature VFX:** Execute, Kidney Shot, Revealing Strike, and Maim use distinct showcase/fight overlays (vertical cleave, low jab + daze, cross-slash expose mark, triple rake shreds); skip shared disc/motion for those four; regression test + before/after sheet under `docs/design/abilities-61/rendered/`.



- **Abilities-61 VFX (pass 2):** per-ability showcase signatures, motion phases (charge/smear/impact), 6-frame anim strips under `docs/design/abilities-61/rendered/anim/`, ffmpeg GIF script, and centered in-fight staging.
- **Abilities-61 VFX (pass 2c):** drop generic weapon slash arc for bespoke melee signatures (showcase + fight); pixel regression on lower-left worm; anim assets are strips/GIFs only (no per-frame PNG dirs).
- **Abilities-61 VFX (pass 2b):** remove contact-sheet horizontal motion smear and default weapon bolt capsule; in-fight weapon projectiles without custom labels render as a dot, not a worm.
- **Abilities-61:** every hero spec reaches 11 kit abilities (Protection stays 13; Blood and Guardian unchanged) — 61 new spells with v3-layered `SpellShapePaint` / `SpellVfxLayers` (summon silhouettes, pillars, domes, meteor scorch), in-context A56 fight renders + v3 comparison sheet under `docs/design/abilities-61/rendered/`, labeled traveling bolts, fallback mechanics where proposals needed new engine work, and regression tests for catalog counts, legacy coeffs, saves, and combat resolution.
- Town square: calm lawn tufts only (no tiled flower dots), no ambient critters; shrubs and meadow clumps, buildings, and hero-scale folk stay. Town lawn QA cobbles and folk shading.

- A save from a newer build stays on the device and in the cloud, with "Update the app to load this save". The consent form is no longer cut off by the 10s UMP update timer, and consent plus Remote Config sync after it closes. A rewarded ad older than 55 minutes reloads, a second tap while an ad is open does not grant again, uncaught async errors are non-fatal in Crashlytics, and the changelog check diffs from the merge-base.

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