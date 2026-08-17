---
name: add-ability
description: >-
  Wires Idle Party hero abilities end-to-end (AbilityId, ClassAbilityDef,
  AbilityEffectRunner, HUD, VFX, tests). Use when adding or fixing a kit
  ability, spell, passive, taunt, or when an ability shows in HUD but never fires.
---

# Add ability (Idle Party)

## Pipeline

```
HeroSpecDef → ClassAbilityDef → SpatialCombat.step
  → AbilityEffectRunner (all 31 specs)
  → HUD: ClassKits.hudAbilitiesAtSpec
  → Offline: same SpatialCombat.step (no fork)
```

Every spec uses the same picker. Rare casts are named helpers in
`lib/spatial/kit_migrated_casts.dart` (`KitNamedCasts`), pointed at from
`ClassAbilityDef.customId` — not a second combat engine.

## Source of truth

| Layer | Path |
|-------|------|
| Specs | `lib/models/hero_spec.dart` |
| Kits | `lib/models/class_ability.dart` |
| Effects | `lib/spatial/ability_effects.dart` (`part of` spatial_combat) |
| Named casts | `lib/spatial/kit_migrated_casts.dart` (`part of` spatial_combat) |
| Combat | `lib/spatial/spatial_combat.dart` |
| HUD | `lib/ui/shell/dungeon_party_hud.dart` |
| Offline | `GameLogic.simulateSpatialOffline` |
| Guides (copy only) | `lib/core/game_guides.dart` |

## Checklist

```
Add ability:
- [ ] 1. AbilityId enum (camelCase) in class_ability.dart
- [ ] 2. ClassAbilityDef in ClassKits.all with exact specId
- [ ] 3. Set effect / fireMode / gate / aoeShape / selfBuffKind (or customId)
- [ ] 4. Passive? case in _applyPassive
- [ ] 5. Rare cast? AbilityCustomId + named helper in KitNamedCasts
- [ ] 6. Optional VFX: boltStyle / AbilityVfxSpec
- [ ] 7. Optional HUD buff glow: _abilityBuffActive in dungeon_party_hud.dart
- [ ] 8. Tests (existence / cast / passive)
- [ ] 9. flutter analyze + targeted flutter test
```

### ClassAbilityDef essentials

- `specId:` required — `forSpec` never falls back
- `effect` + `tier` + `coeff` + `cooldown` + `resourceCost` + `unlockLevel`
- `fireMode:` `cast` (default) · `swingRider` · `onBlock` · `dotTick` · `onHitBounce` · `passive`
- `showInHud: false` for passives and white-hit dumps that never cast (Combat Eviscerate)
- HUD shows `showsInHud` rows; ready-glow is only for `fireMode.cast`
- `requiresShield` when needed
- Resource is always `SpatialActor.rage` (0–100); labels from `SpecResource`
- Gates live on `gate:` (`packMin`, `executeHpFrac`, `comboMin`, ranges, …) — not AbilityId switches
- `selfBuffKind` instead of matching "haste"/"shield" in the name
- `aoeShape` (`nova` / `fan` / `rain` / `ground` / `chain`) instead of name keywords

### Effect kinds

`passive`, `damage`, `aoe`, `heal`, `absorb`, `selfBuff`, `root`, `grantResource`, `emergencyDefend`, `emergencyHeal`, `taunt`

## Pitfalls

| Symptom | Cause |
|---------|--------|
| In catalog, never fires | `passive` / `onBlock` / rider without `customId`; wrong/missing `specId` |
| HUD green but never casts | Missing `fireMode` (rider shown as `cast`) |
| Wrong class | Bad `specId` |
| Never selected | Bad tier / `gate` (execute, pack, cost vs regen) |
| requiresShield starved | No off-hand shield |
| Offline “broken” | Same step path — don’t fork ability logic |
| Passive no mul | Missing `_applyPassive` case |
| Buff is haste instead of amp | Missing `selfBuffKind` |

## Tests

| File | Use |
|------|-----|
| `test/class_kits_combat_test.dart` | Live casts via build+step |
| `test/kit_honesty_fix_test.dart` | HUD chips / typed buffs / named casts |
| `test/kit_passives_test.dart` | Passives |
| `test/warrior_abilities_test.dart` | Kit existence / unlock |
| `test/starter_gear_test.dart` | Every spec has `forSpec` rows |
| `test/spell_vfx_test.dart` | Bolt styles |

**Cast recipe:** `SpatialCombat.build` → place near enemies → fill `rage` → zero `abilityCd[id.name]` → `step` loop → assert HP/CD/timers.
