---
name: add-ability
description: >-
  Wires Idle Party hero abilities end-to-end (AbilityId, ClassAbilityDef,
  legacy tickers vs AbilityEffectRunner, HUD, VFX, tests). Use when adding
  or fixing a kit ability, spell, passive, taunt, or when an ability shows
  in HUD but never fires.
---

# Add ability (Idle Party)

## Pipeline

```
HeroSpecDef → ClassAbilityDef → SpatialCombat.step
  → AbilityEffectRunner (non-legacy) OR _tick*Abilities (legacy)
  → HUD: ClassKits.hudAbilitiesAtSpec
  → Offline: same SpatialCombat.step (no fork)
```

## Source of truth

| Layer | Path |
|-------|------|
| Specs | `lib/models/hero_spec.dart` |
| Kits | `lib/models/class_ability.dart` |
| Effects | `lib/spatial/ability_effects.dart` (`part of` spatial_combat) |
| Combat | `lib/spatial/spatial_combat.dart` |
| HUD | `lib/ui/is2_shell.dart` |
| Offline | `GameLogic.simulateSpatialOffline` |
| Guides (copy only) | `lib/core/game_guides.dart` |

**Legacy specs** (`ClassKits.isLegacySpec`): `protection`, `discipline`, `fire`, `combat` — need hand-written ticker branches. All other specs use `_tickSpecKit` / effect kinds.

## Checklist

```
Add ability:
- [ ] 1. AbilityId enum (camelCase) in class_ability.dart
- [ ] 2. ClassAbilityDef in ClassKits.all with exact specId
- [ ] 3. Legacy? implement _tick*Abilities branch — else effect/passive path
- [ ] 4. Passive? case in _applyPassive (non-legacy)
- [ ] 5. Optional VFX: boltStyleForAbility / _boltStyleForAbilityId
- [ ] 6. Optional HUD buff glow: _abilityBuffActive in is2_shell
- [ ] 7. Tests (existence / cast / passive)
- [ ] 8. flutter analyze + targeted flutter test
```

### ClassAbilityDef essentials

- `specId:` required — `forSpec` never falls back
- `effect` + `tier` + `coeff` + `cooldown` + `resourceCost` + `unlockLevel`
- `showInHud: false` for passives; `requiresShield` when needed
- Resource is always `SpatialActor.rage` (0–100); labels from `SpecResource`

### Effect kinds

`passive`, `damage`, `aoe`, `heal`, `absorb`, `selfBuff`, `root`, `grantResource`, `emergencyDefend`, `emergencyHeal`, `taunt`

`selfBuff` uses **name heuristics** (haste/shield substrings) — extend `_selfBuff` if a new buff type is needed.

## Pitfalls

| Symptom | Cause |
|---------|--------|
| In catalog, never fires | Legacy without ticker; `passive` never cast; wrong/missing `specId` |
| Wrong class | Bad `specId` |
| Never selected | Bad tier / execute gate / pack-size AoE / cost vs regen |
| requiresShield starved | No off-hand shield |
| Offline “broken” | Same step path — don’t fork ability logic |
| Passive no mul | Missing `_applyPassive` case |

## Tests

| File | Use |
|------|-----|
| `test/class_kits_combat_test.dart` | Live casts via build+step |
| `test/kit_passives_test.dart` | Non-legacy passives |
| `test/warrior_abilities_test.dart` | Kit existence / unlock |
| `test/starter_gear_test.dart` | Every spec has `forSpec` rows |
| `test/spell_vfx_test.dart` | Bolt styles |

**Cast recipe:** `SpatialCombat.build` → place near enemies → fill `rage` → zero `abilityCd[id.name]` → `step` loop → assert HP/CD/timers.
