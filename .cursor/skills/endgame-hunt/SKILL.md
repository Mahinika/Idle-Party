---
name: endgame-hunt
description: >-
  Deepens or fixes the Idle Party endgame hunts: KEY (keystone), Gauntlet,
  Farm Rift, Ranked GR, and Ashen Crown, plus the hub ENDGAME map. Use when
  the owner says "mer endgame", "endgame känns tunt", KEY, Gauntlet, Rift,
  GR, or Ashen, or when a hunt's rules, payout, unlock, or hub panel change.
  Do not use for a new zone (new-dungeon), enemy AI or packs inside the
  fight (spatial-combat-change), kit DPS trim (grinding-until-pass), or the
  monthly Craft Trial (it is not an ENDGAME hunt).
---

# Endgame hunts (Idle Party)

Endgame unlocks when the **active party is all Lv100**, not at AL20 alone.
There is no KEY tab before that. Each hunt module below is rules and payout
only. SpatialCombat stays the fight sim.

## Where each hunt lives

| Hunt | Venue | Rules | Hub / UI | Tests |
|------|--------|-------|----------|-------|
| KEY | Hub KEY | `lib/core/keystone.dart` | `lib/ui/meta/keystone_sheet.dart` | `test/keystone_test.dart` |
| Gauntlet | Crystal Spire, boss every 5 floors | `lib/core/gauntlet_pact.dart`, `lib/core/gauntlet_anomaly.dart` | `lib/ui/meta/gauntlet_hub_panel.dart` | `test/gauntlet_anomaly_test.dart` |
| Farm Rift | Stormwake Hollow, no fail timer | `lib/core/rift.dart`, `lib/core/rift_pacing.dart`, `lib/core/rift_progress.dart` | `lib/ui/meta/rift_hub_panel.dart`, `lib/ui/meta/rift_tier_picker.dart`, `lib/ui/shell/rift_progress_hud.dart` | `test/rift_test.dart`, `test/rift_pacing_test.dart`, `test/rift_progress_test.dart`, `test/rift_tier_picker_test.dart`, `test/rift_progress_hud_test.dart` |
| Ranked GR | Mothveil Hollow, timed, local season PB | `lib/core/greater_rift.dart` | `lib/ui/meta/greater_rift_hub_panel.dart` | `test/greater_rift_test.dart` |
| Ashen Crown | Weekly ticket, rotates shipped caves | `lib/core/ashen_crown.dart` | `lib/ui/meta/ashen_crown_hub_panel.dart` | |
| Hub map | Not dungeon 16 | `lib/core/hub_endgame_act.dart`, `lib/core/game_logic_endgame.dart` | `lib/ui/hub/hub_endgame_map.dart` | `test/endgame_systems_test.dart` |

## Before you add depth

Name the player problem first (Open notes in `docs/PLAY_NOTES.md`, or
`10-what-to-build`). Deepen one hunt per batch. TODAY must stay honest
(`lib/core/chase_contract.dart`, `docs/CHASE_CONTRACT.md`).

## Gotchas

- Hub → hunt enter must start the floor: `GameDirector._rebuildSpatial()` + `_startSpatialLoop()`, or the view stays on **Loading floor…**. Ashen hit this in 1.12.152 (see `spatial-combat-change`).
- A PUSH clear pays +1 essence, a PUSH boss +2. FARM pays that mint 0. Gauntlet pays its own floor essence, doubled under GREED, and does not use the PUSH mint (`AGENTS.md`).
- The hub ENDGAME map is not dungeon #16 and not a row under the 15-zone path. Hunts reuse existing caves.
- Ashen save fields still use `worldBoss*` JSON keys. Keep them for old saves (`save-migrate`).
- Craft Trial stays MORE → CRAFT.
- Player words: a Gauntlet stretch is a run, KEY is the daily, a sitting is a session (`.cursor/rules/play-words.mdc`).

## Done when

- `flutter analyze lib test --no-fatal-infos` is clean and the hunt's tests above plus `flutter test test/ship_smoke_test.dart` are green.
- TODAY and the hub panel say what the hunt now does (English).
- A changed hunt was played once on an endgame save on the A56 running this batch.
- Version bumped: `flutter test test/changelog_sync_test.dart` is green.
