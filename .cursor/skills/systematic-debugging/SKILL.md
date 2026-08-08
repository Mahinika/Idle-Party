---
name: systematic-debugging
description: >-
  Methodical Idle Party debugging — reproduce, isolate (SpatialCombat vs UI vs
  save), hypothesize, verify with GameDirector.preview / flutter test / playtest.
---

# Systematic debugging (Idle Party)

Don't randomly edit combat. Evidence first.

## 1. Reproduce

- Exact steps (hub vs in-dungeon vs AFK catch-up vs Gauntlet)
- Expected vs actual
- Note AL, dungeonId, Farm/Push, hardmode, save age

## 2. Isolate layer

| Symptom | Likely layer | First look |
|---------|--------------|------------|
| Wrong damage / AI / clear | **SpatialCombat** | `lib/spatial/spatial_combat.dart`, `ability_effects.dart` |
| Ability in HUD never fires | Kit wiring | `add-ability` skill |
| Gold/loot/essence wrong | GameLogic | `game_logic.dart`, drop rolls |
| Lost on Ascend / load | Save migrate | `save-migrate`, `meta_depth` / `game_state` |
| Button / tip / overlay | UI | `hub_screen`, `is2_shell`, `first_session_tips` |
| Offline ≠ live | AFK path | `simulateSpatialOffline` must use SpatialCombat.step |

Binary search: comment/disable half of a ticker or gate path only when safe; prefer logging + tests.

## 3. Hypothesize

Specific: “Drain Life uses heal-only effect so DPS share ignores it,” not “warlock is broken.”

## 4. Verify

- Unit: `GameDirector.preview()` + focused `flutter test`
- Combat: share-fast / gate for DPS; spatial tests for movement/clear
- UI: `verifying-in-browser` / `hub-smoke`
- “It worked before”: `git bisect` with a tiny reproduce test

## 5. Fix

Minimal root-cause fix + regression test when practical. Re-run the reproduce path.

## Idle Party rules

- **SpatialCombat is combat authority** — don't “fix” live by editing a dead legacy ticker
- Immutable state via `copyWith` in GameLogic
- No Riverpod — ChangeNotifier paths
- 15 minutes stuck → re-isolate; document tried hypotheses
