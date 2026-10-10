---
name: save-migrate
description: >-
  Adds or migrates Idle Party GameState fields safely (toJson/fromJson
  defaults, Ascend keep/reset, SharedPreferences). Use when adding
  persistent state, meta, Ascend behavior, save load, export/import, or when
  the owner says save / ascend / lost progress / "sparningen försvann".
  Do not use for hub or menu text that saves nothing new (hub-smoke).
---

# Save / migrate (Idle Party)

## Paths

| Role | Path |
|------|------|
| State + serialize | `lib/core/game_state.dart` |
| Load / Ascend / v1 migrate | `lib/core/game_logic.dart` (`stateFromJson`, `ascend`) |
| Prefs I/O | `lib/core/game_storage.dart` (`SharedPreferencesGameStorage`) |
| Meta bundle | `lib/models/meta_depth.dart` |

**Prefs:** five slots `idle_party_save_slot_0` … `_4`; the active one is `idle_party_active_slot`. Autosave writes the active slot and mirrors it to `idle_party_save_v2` for older builds. The first run copies an old `idle_party_save_v2` / `idle_party_save_v1` into slot 0 (SAVE 1).  
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
- [ ] 6. Ascend: **prestige wipe** of gold / forge / drops / floors; keep
      meta (essence, relics, Apex, levels, zones). Set `freshPrestige` on wipe.
- [ ] 7. New Game: seed in createInitialState only if needed
- [ ] 8. Round-trip + legacy-missing tests
- [ ] 9. Mutate only via GameLogic + director (so persist runs)
```

Use `_jsonInt` / `as num?` for ints (web JSON). Bump `'version'` only for docs unless the shape breaks.

**Gotchas:** `GameState` must not import `GameLogic` — duplicate per-level CAMP/forge constants on the getter if needed. KEEP shop caps live in `PrestigeShopCatalog.atCap` — do not re-list them in `GameDirector`. Equipping in tests: `copyWith(heroRoster: …)`, not `heroes:` (roster is source of truth).

## Ascend (trust `GameLogic.ascend`)

**Prestige:** raise AL, stack Blessing, unlock kits, pay essence, **reset the
run bag** (gold, forge ATK/DEF/STA/MOVE/HASTE/CRIT/MASTERY, worn/stash drops, market,
loadouts, `highestFloorCleared`, starter gear). Apex vault + worn Apex stay.
CAMP / sanctuary levels **keep** (prestige-compress is a separate CAMP action).

**Keeps:** hero levels/XP/roster, `highestDungeonCleared`, essence, relics,
pets, sanctuary, metaDepth (plus `freshPrestige: true`), Apex, legacy heirloom
if present, God Hand, settings, achievements/codex, challenge toggles, KEY dial.

**Clears:** bossVictories, wipe streak/advice, active dungeon / KEY / rift /
GR run via leave-dungeon; mission board rebuilt for new AL.

**AL20 Reborn** (`GameLogic.rebornAtCap`): same bag wipe, no +AL / +Blessing,
essence + 1 constellation point. Optional; not a TODAY chase.

## Tests

```bash
flutter test test/save_load_test.dart test/meta_systems_test.dart test/meta_depth_test.dart
```

Use `GameDirector.preview()` for in-memory tests.

## Done when

- `flutter analyze lib test --no-fatal-infos` is clean and the tests above are green.
- An old save without the new field loads (legacy-missing test) and the field survives or resets on Ascend as intended.
