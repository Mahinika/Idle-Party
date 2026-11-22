# Changelog (main merges)

Short human notes for each merge to `main`. In-game What's New stays
`lib/core/changelog.dart` (`ChangelogCatalog`).

Add one bullet under `[Unreleased]` in every PR that targets `main`. CI
checks that this file changed.

## [Unreleased]

- Arena review: heal crits repeat for the same floor and clock without moving damage rolls, portrait stays locked, a cancelled Play update opens the listing, a failed slot migration retries, quest dates follow the game clock, clipboard import keeps this device's Play purchases, purchase ids are never forgotten, friend claims count in one write, and Android backup does not copy the local save.
- Audit fixes: away catch-up is saved if the app backgrounds again, dead pets stay down, Ascend keeps leave rewards, a failed WISP ad can be retried, DODGE and PARRY show like BLOCK, STA no longer revives the dead, a dying enemy does not swing, hub idle and the comeback chest use the offline time cap, Shield Block's extra reduction applies in melee, and a rejected save write is rolled back.
- QA 2026-11-21: wipe scrim covers fight tools, ability-name floaters stack, the tomorrow teaser stays on the town card, and small UI fixes (MENU, party chip, shop, vault CTA, speed tip).
- QA retest: each sheet keeps its own subtitle, loot and ability names share one lane, the equip toast clears the lantern, the hero tab keeps the level, the CC line stays in its chip, a failed audio load retries once, and layout plus audio failures are non-fatal in Crashlytics.
- A fight save stamps the away clock, and leaving the app writes the current gold and essence before the process can be killed.
- Docs refresh for 1.14.0: README ship line, town and theme notes, sweep ledger, and playtest memory after the stack merged to main.

## [1.14.0] — 2026-11-21

- Release 1.14.0: fight UI stack (role icons, roster slots, town, Copilot batches A–C). Includes the unreleased 1.13.18 dungeon crash, banner, resume, and large-text fixes.
