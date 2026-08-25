---
name: save-migrate
description: >-
  Adds or migrates Idle Party GameState fields safely (toJson/fromJson
  defaults, Ascend keep/reset, SharedPreferences). Use when adding
  persistent state, meta, Ascend behavior, save load, or export/import.
---

# Save / migrate (Idle Party)

## Paths

| Role | Path |
|------|------|
| State + serialize | `lib/core/game_state.dart` |
| Load / Ascend / v1 migrate | `lib/core/game_logic.dart` (`stateFromJson`, `ascend`) |
| Prefs I/O | `lib/core/game_director.dart` (`SharedPreferencesGameStorage`) |
| Meta bundle | `lib/models/meta_depth.dart` |

**Prefs:** write `idle_party_save_v2`; read v2 else legacy `idle_party_save_v1`.  
**Load:** always `GameLogic.stateFromJson` (not raw `GameState.fromJson`).  
**Save version:** written as `4`; migration is **field presence / defaults**, not a version switch.

## Checklist: new persistent field

```
New field:
- [ ] 1. Field + default on GameState
- [ ] 2. copyWith (clear-flag if nullable wipe)
- [ ] 3. toJson key
- [ ] 4. fromJson safe default if missing
- [ ] 5. Nested? MetaDepthState / model fromJson defaults
- [ ] 6. Ascend: usually **keep** (Ascend is claim-only). Only clear if the field is run-state (active KEY timer, etc.)
- [ ] 7. New Game: seed in createInitialState only if needed
- [ ] 8. Round-trip + legacy-missing tests
- [ ] 9. Mutate only via GameLogic + director (so persist runs)
```

Use `_jsonInt` / `as num?` for ints (web JSON). Bump `'version'` only for docs unless the shape breaks.

## Ascend (trust `GameLogic.ascend`)

**Claim:** raise AL, stack Blessing, unlock kits, pay essence. **No soft-reset.**

**Keeps:** wallet gold, forge ATK/DEF/STA/move/haste/crit, gear/stash, floors,
loadouts, market listings, essence, relics, hero levels/XP/roster gear, pets,
sanctuary, metaDepth, Apex, legacy heirloom if present, God Hand, settings,
achievements/codex, challenge toggles, KEY dial.

**Clears:** bossVictories (toward next AL), wipe streak/advice, active dungeon /
KEY / rift / GR run via leave-dungeon; mission board rebuilt for new AL.

## Tests

- `test/save_load_test.dart`
- `test/meta_systems_test.dart` (legacy saves without meta fields)
- `test/meta_depth_test.dart`

Use `GameDirector.preview()` for in-memory tests.
