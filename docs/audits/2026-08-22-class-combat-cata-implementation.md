# Cata combat v2 — implementation audit

**Original date:** 2026-08-22  
**Re-audit:** 2026-09-11  
**Reference plan:** [2026-08-22-class-combat-cata.md](2026-08-22-class-combat-cata.md)  
**Ship:** `main` @ **1.12.136**

---

## Slice checklist

| Slice | Status | Evidence |
|-------|--------|----------|
| **S1** CombatRatings split + mastery | **Done** | `combat_ratings.dart`: `physicalAttack`, `spellPower`, `masteryRating/Points`, dodge/parry %; tanks skip Agi→DEF |
| **S2** Spell vs melee damage | **Done** | `ClassAbilityDef.inferUsesSpellPower`, `ability_effects._abilityPower` |
| **S3** Tank avoidance | **Done** | `combat_avoidance.dart`, `spatial_combat._applyHeroIncomingDamage` melee path; DODGE/PARRY/BLOCK floaters |
| **S4–S5** Mastery 31 specs | **Done** | `spec_mastery.dart` kinds + damage/heal/dot/block/proc hooks; GEAR + party HUD labels |
| **S6** Cast delay + haste | **Partial** | **10** abilities with `castDelaySeconds`; haste shrinks delay in `_castDelaySeconds` |
| **S7** CC DR | **Done** | `CombatAvoidance.ccRootDuration`, `ccRootDrLevel` on enemies |
| **S8** Spirit 5SR + gear mastery | **Half** | `spiritManaRegenPerSec(inCombat, recentlyDamaged)`, `spiritRegenPaused` on hit; `masteryBonus` on loot — **Mp5 still on healer drops** |

---

## Plan questions — implemented?

| Question | Shipped? | Notes (2026-09-11) |
|----------|----------|---------------------|
| Spells split | **Yes** | `_abilityPower` uses `spellPower` or `physicalAttack` |
| Cast time | **Partial** | 10 signature delays; no GCD/interrupt/cast bar chip |
| DR | **Yes** | Dodge/parry rating DR + CC root stacks |
| Mastery | **Yes** | 31 spec kinds; gear secondary; combat hooks |
| Ability damage | **Yes** | coeff × power × mastery shape (not flat ATK inflation) |
| Tank avoidance | **Yes** | Uncrittable, dodge/parry, mastery block −30%, Shield Block CD kept |

---

## Post-v2 kit batches (Cata-adjacent)

| Version | Work | Cata tie-in |
|---------|------|-------------|
| 1.12.134 | Druid forms + Eclipse wiring | `SpecMasteryKind.eclipse` arcane/nature windows |
| 1.12.135 | Subtlety Shadow Dance, share trims | Executioner mastery unchanged; fairness gate |
| 1.12.136 | Dungeon floor layout | Out of scope for Cata combat |

---

## Fairness tune (post-impl)

Initial full gear Int→SP spike broke balance gate (**arcane/affliction HIGH**). Fixed per owner **fairness first**:

- Caster **combat** SP = level Int + `(gearInt + gearSP) ~/ 3` (matches GEAR_BUDGET ROI)
- Mastery generic damage coeff reduced (`0.005` → `0.002` per point)
- DoT mastery cap tightened

`class_balance_gate_test` **green** on 2026-09-11 after 1.12.135 trims.

---

## Files (authoritative)

**Core Cata v2**

- `lib/models/spec_mastery.dart`
- `lib/spatial/combat_avoidance.dart`
- `lib/models/combat_ratings.dart`
- `lib/spatial/spatial_combat.dart`
- `lib/spatial/ability_effects.dart`
- `lib/models/class_ability.dart` (`castDelaySeconds`, `inferUsesSpellPower`)
- `lib/core/equipment_factory.dart` (mastery secondary on loot)
- `test/cata_combat_v2_test.dart`

**UI**

- `lib/ui/character_equip_panel.dart` — mastery label + points
- `lib/ui/shell/dungeon_party_hud.dart` — in-dungeon mastery chip

---

## Verify run (2026-09-11)

```
flutter analyze lib test --no-fatal-infos   → clean
flutter test test/cata_combat_v2_test.dart  → 8/8
flutter test test/combat_ratings_test.dart  → 9/9
flutter test test/class_balance_gate_test.dart → pass
```

---

## Known gaps (honest, 2026-09-11)

| Gap | Priority |
|-----|----------|
| **Elemental Overload** — no duplicate-cast proc in spatial | P1 |
| **Mp5** still on healer loot (`equip_stat_weights`, `GEAR_BUDGET.md`) | P1 |
| Cast delays on ~21 remaining signature spells | P1 |
| Hit/expertise, reforge UI | P2 |
| Ability crit from rating (Hot Streak still proc-driven) | P2 |
| Critical Block “crit block” double proc | P2 |
| Casting… HUD chip during delay | P2 |
| Lore zones/copy still Wrath-named | Product OK |

---

## Phone test (AL20)

1. **Prot tank** — melee trash: **DODGE / PARRY / BLOCK** floaters; smoother spikes than pre-v2
2. **Fire mage** — Fireball cast delay (haste shrinks); Living Bomb + Hot Streak unchanged feel
3. **Resto shaman** — low-HP ally heals hit harder (Deep Healing); note Mp5 still on gear tooltips
4. **Frost Nova spam** — roots shorten (CC DR)
5. **Arms / MM / Combat** — occasional **SWING** floaters from mastery procs
6. **Elemental shaman** — **no** overload duplicate bolt yet (known gap)

---

*Self-audit original 2026-08-22. Re-audit 2026-09-11 @ 1.12.136.*
