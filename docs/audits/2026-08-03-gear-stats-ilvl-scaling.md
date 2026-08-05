# Wow-lite equipment — implementation audit — 2026-08-03

Audit of the shipped Wow-lite + set work against the plan. Sources: `equipment_factory.dart`, `loot.dart`, `gear_set.dart`, `hero.dart`, `game_logic.dart`, `game_state.dart`, `spatial_combat.dart`, `item_affixes.json`, `test/equipment_wow_lite_test.dart`.

## Verdict

**Audit findings fixed.** Core Wow-lite systems + P0/P1 remediation. `flutter analyze lib` clean; full test suite green.

| Plan item | Status | Notes |
|-----------|--------|-------|
| Soulbound primaries → meta | Done | Str/Agi→AP or Int+SP/2; armor; Sta×10 |
| Spatial multi-drop | Partial | Spawns all *returned* drops; `rollLoot.take(3)` truncates first |
| Dungeon/AL scaling | Done* | Budget = zoneMult `1+zone×0.28` × AL `1+AL×0.05`; ilvl +zone×4 +AL×2 |
| Slot budget | Done | MH 1.0 / 2H 1.15 / mid 0.75 / OH·jewelry·wrist 0.55 / ranged 0.50 |
| Real affixes | Done | 15–25% budget; IDs persist; role-filtered pools |
| powerScore + auto-sell ilvl | Done | `powerScore` includes ilvl; UI = item level cap |
| Dungeon sets 2/4 | Done | rare+ head/shoulder/chest/legs; 2/4 bonuses; equip-score; merge keeps `setId` |
| dungeonId + tests | Done | Wired through roll/spatial/offline; wow-lite test file |

\* Preferred zoneMult path (impact analysis), not draft `floor+dung×4+AL×2` for budget.

## Findings

### Fixed (post-audit)

- **`rollLoot.take(3)`** → `_finalizeLootDrops`: always keeps gear/sigil/relic/vial; soft-cap 5 for filler only.
- **Merge affix names** rebuilt from `affixPrefixId`/`affixSuffixId`.
- **Set UI**: `setLabel` in `statsLine` + N/4 progress in bag/character sheet.
- **Gold**: `statPowerScore + ilvl×2` (no triple-count).
- **Armor pts** reserved from primary budget before distributing primaries.
- **Dual scores** documented on `powerScore` (junk/gold) vs `roleEquipScore` (BiS).

### Remaining (low)

- Dual scoring still intentional split (documented).
- AL loot mult 0.05 vs enemy 0.08 — mild by design.

## Suggested fix order

~~1. Prioritize gear/sigil in `rollLoot`~~ done  
~~2. Merge affix names~~ done  
~~3. Set display~~ done  
~~4. Gold / armor accounting~~ done  

## Covered & working

- Soulbound meta from primaries
- Zone-scaled loot vs sandy (crystal stronger)
- Slot mults (chest > wrist)
- Affix JSON load + persist
- Set 2pc/4pc combat aggregators + equip preference
- `powerScore` + circular ilvl fallback fixed via `statPowerScore`
- Save round-trip for new fields
- Boss Sigil retained under stacked drops
- Merge preserves set + affix names
