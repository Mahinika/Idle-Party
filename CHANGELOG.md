# Changelog (main merges)

Short human notes for each merge to `main`. In-game What's New stays
`lib/core/changelog.dart` (`ChangelogCatalog`).

Add one bullet under `[Unreleased]` in every PR that targets `main`. CI
checks that this file changed.

## [Unreleased]

- Play review: race picker says cosmetic-only (no stat bonuses), and music bed resyncs after ads or dead voice handles via `MusicPlaybackPlan`.
- Crashlytics: `RenderFlex` overflows (including wipe-retry rewarded offer) record as non-fatal; the wipe panel scrolls on short phones at text scale 1.45; `setDungeonTilesReady` and `clearToast` defer `notifyListeners` during build. CI goldens for target strip / top bar refreshed on Linux Flutter 3.47.9 (pixel drift, no UI code).
- QA 2026-11-21: wipe scrim covers fight tools, ability-name floaters stack, the tomorrow teaser stays on the town card, and small UI fixes (MENU, party chip, shop, vault CTA, speed tip).
- QA retest: each sheet keeps its own subtitle, loot and ability names share one lane, the equip toast clears the lantern, the hero tab keeps the level, the CC line stays in its chip, a failed audio load retries once, and layout plus audio failures are non-fatal in Crashlytics.
- A fight save stamps the away clock, and leaving the app writes the current gold and essence before the process can be killed.
- Docs refresh for 1.14.0: README ship line, town and theme notes, sweep ledger, and playtest memory after the stack merged to main.

## [1.14.0] — 2026-11-21

- Release 1.14.0: fight UI stack (role icons, roster slots, town, Copilot batches A–C). Includes the unreleased 1.13.18 dungeon crash, banner, resume, and large-text fixes.
