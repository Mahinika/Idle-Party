---
name: add-ability
description: >-
  Wires Idle Party hero abilities end-to-end (AbilityId, ClassAbilityDef,
  AbilityEffectRunner, HUD, VFX, tests). Use when adding or fixing a kit
  ability, spell, passive, taunt, a new spell, a broken kit, or when an ability shows in HUD but never fires.
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
`ClassAbilityDef.customId` — not a second combat engine. Shared cast helpers
live on public `SpatialCombat` / `AbilityEffectRunner` (see
`lib/spatial/combat_primitives.dart`).

## Source of truth

| Layer | Path |
|-------|------|
| Specs | `lib/models/hero_spec.dart` |
| Kits | `lib/models/class_ability.dart` + `lib/models/kits/<class>.dart` |
| Effects | `lib/spatial/ability_effects.dart` |
| Named casts | `lib/spatial/kit_migrated_casts.dart` |
| Cast surface | `lib/spatial/combat_primitives.dart` (exports) |
| Combat | `lib/spatial/spatial_combat.dart` |
| HUD | `lib/ui/shell/dungeon_party_hud.dart` |
| Offline | `GameLogic.simulateSpatialOffline` |
| Guides (copy only) | `lib/core/game_guides.dart` |

## Checklist

```
Add ability:
- [ ] 1. AbilityId enum (camelCase) in class_ability.dart
- [ ] 2. ClassAbilityDef in the matching lib/models/kits/<class>.dart (specId exact)
- [ ] 3. Set effect / fireMode / gate / aoeShape / selfBuffKind
- [ ] 4. Passive? set passiveOutMul / passiveInMul / passiveHealMul / passiveHasteMul / passiveRootBonus / innerFire on the row
- [ ] 5. Temp pets? summonCount / summonDuration / summonAtkScale / summonName / summonIdPrefix (optional summonHasteSeconds)
- [ ] 6. Rare cast that step already owns (bomb / bounce / combo / queued rider)? customId + KitNamedCasts helper
- [ ] 7. Optional VFX: boltStyle / AbilityVfxSpec
- [ ] 8. Optional HUD buff glow: _abilityBuffActive in dungeon_party_hud.dart
- [ ] 9. Tests (existence / cast / passive)
- [ ] 10. flutter analyze + targeted flutter test
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
- Passives: explicit mul fields (no silent default crumb)
- Summons: summon* fields; `customId` only when `step` already owns a unique field

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
| Passive no mul | Missing passive* fields on the row |
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
