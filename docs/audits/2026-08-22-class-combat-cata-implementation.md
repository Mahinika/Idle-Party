# Cata combat v2 — implementation audit

**Date:** 2026-08-22  
**Reference plan:** [2026-08-22-class-combat-cata.md](2026-08-22-class-combat-cata.md) Part 10 slices  
**Ship:** code on working tree ~1.12.41 (no version bump in this batch)

---

## Slice checklist

| Slice | Status | Evidence |
|-------|--------|----------|
| **S1** CombatRatings split + mastery | **Done** | `combat_ratings.dart`: `physicalAttack`, `spellPower`, `masteryRating/Points`, dodge/parry %; tanks skip Agi→DEF |
| **S2** Spell vs melee damage | **Done** | `ClassAbilityDef.inferUsesSpellPower`, `ability_effects._abilityPower` |
| **S3** Tank avoidance | **Done** | `combat_avoidance.dart`, `spatial_combat._applyHeroIncomingDamage` melee path |
| **S4–S5** Mastery 31 specs | **Done** | `spec_mastery.dart` kinds + damage/heal/dot/block/proc hooks |
| **S6** Cast delay + haste | **Partial** | `castDelaySeconds` on Fireball/Pyro/Healing Wave; haste shrinks delay in `_castDelaySeconds` |
| **S7** CC DR | **Done** | `CombatAvoidance.ccRootDuration`, `ccRootDrLevel` on enemies |
| **S8** Spirit 5SR + gear mastery | **Done** | `spiritManaRegenPerSec(inCombat, recentlyDamaged)`, `spiritRegenPaused` on hit; `masteryBonus` on loot |

---

## Plan questions — implemented?

| Question | Shipped? | Notes |
|----------|----------|-------|
| Spells split | Yes | `_abilityPower` uses `spellPower` or `physicalAttack` |
| Cast time | Partial | Signature delays only; no GCD/interrupt |
| DR | Yes | Dodge/parry rating DR + CC root stacks |
| Mastery | Yes | 31 spec kinds; gear secondary; combat hooks |
| Ability damage | Yes | coeff × power × mastery shape (not flat ATK inflation) |
| Tank avoidance | Yes | Uncrittable, dodge/parry, mastery block −30%, Shield Block CD kept |

---

## Fairness tune (post-impl)

Initial full gear Int→SP spike broke balance gate (**arcane/affliction HIGH**). Fixed per owner **fairness first**:

- Caster **combat** SP = level Int + `(gearInt + gearSP) ~/ 3` (matches GEAR_BUDGET ROI)
- Mastery generic damage coeff reduced (`0.005` → `0.002` per point)
- DoT mastery cap tightened

`class_balance_gate_test` **green** after tune (LOW melee outliers remain acceptable).

---

## Files touched

**New**

- `lib/models/spec_mastery.dart`
- `lib/spatial/combat_avoidance.dart`
- `test/cata_combat_v2_test.dart`

**Modified**

- `lib/models/combat_ratings.dart`
- `lib/models/loot.dart`
- `lib/models/hero.dart`
- `lib/models/class_ability.dart`
- `lib/core/equipment_factory.dart`
- `lib/core/game_state.dart`
- `lib/spatial/spatial_combat.dart`
- `lib/spatial/ability_effects.dart`
- `test/combat_ratings_test.dart`
- `docs/audits/README.md`

---

## Verify run

```
flutter analyze lib test --no-fatal-infos   → clean
flutter test test/cata_combat_v2_test.dart  → 6/6
flutter test test/combat_ratings_test.dart → 9/9
flutter test test/combat_authority_audit_test.dart → 6/6
flutter test test/class_balance_gate_test.dart → pass
```

---

## Known gaps (honest)

- **Not shipped:** hit/expertise, full cast bar UX, reforge UI, MoP+ systems
- **Cast delays:** only 3 abilities tagged; expand per spec in follow-up
- **Mastery UI:** no player-facing “Mastery: Ignite” chip yet — hooks are sim-only
- **Lore:** zones/copy still Wrath; mechanics layer is Cata-shaped
- **LOW share** on arms/fury/ret/frost dk in gate — pre-existing band; not regressed to HIGH

---

## Phone test (AL20)

1. **Prot tank** — melee trash: watch **DODGE / PARRY / BLOCK** floaters; less spike damage than pre-patch on average
2. **Fire mage** — Fireball should feel slightly slower (cast delay); DPS similar after fairness tune
3. **Resto shaman** — low-HP ally heals should hit harder (Deep Healing mastery)
4. **Frost Nova spam** — same pack: roots get shorter (DR)

---

*Self-audit complete — 2026-08-22*
