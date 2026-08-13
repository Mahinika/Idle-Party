# Gear budget contract

Idle Party item power follows one pipeline: **iLvl → budget → role split → stats → combat / UPGRADE**.

Auto Equip, green **UPGRADE**, and bag **BEST** must use the same predicate. Soft score crumbs (affinity, preferred-armor flats, rarity×N, set completion flats) are **not** allowed on the upgrade path.

## Budget

Source of truth: `EquipmentFactory.budgetForItemLevel` in `lib/core/equipment_factory.dart`.

- Inputs: display **item level**, **rarity** (quality mul), **slot** (and 2H mul).
- ~`0.88` primary points per iLvl on a main-hand rare before armor carve / affix slice.
- Rarity mainly raises shown iLvl via `itemLevelFor`; quality mul keeps epic/legendary denser at the same iLvl.

New drops, merge output, and Apex craft should spend this budget — not invent a parallel power curve.

## Stat split

Configured in `EquipStatWeights.lootShares` / `forSpec` (`lib/models/equip_stat_weights.dart`).

| Role bucket | Primaries (typical) | Secondaries |
|-------------|---------------------|-------------|
| Tank | Sta + Str (+ Armor carve) | Crit / Haste sparingly |
| Str melee | Str + Sta | Crit, Haste |
| Agi melee / hunter | Agi + Sta (+ some Str) | Crit, Haste |
| Caster | Int + Sta + Spell Power | Crit, Haste |
| Healer | Int + Sta + SP + Spirit | Mp5, Crit, Haste |

Rules:

- At most **two** secondaries on new loot.
- **No Move** on loot budget.
- Affinity on an item is **drop bias / tooltip flavour**, not equip-score.

Combat conversion (must stay aligned with equip weights):

- Melee ATK from Str/Agi via `CombatRatings` (kAp = 4).
- Caster/healer throughput: **Intellect full**, **Spell Power ≈ half** into the ATK pool.

## Equip score (`itemBudgetScore`)

Used by `specEquipScore` / `slotEquipScore` / BiS / Auto Equip.

**Counts**

- Role-weighted stat mass (Str/Agi/Sta/Int/Spi/SP/Armor/Crit/Haste/Mp5/flat ATK) — same DNA as `EquipStatWeights.forSpec`.
- Gear effects that spend real effect value (lifesteal, crit, haste, …).
- Apex tier bonus (soul-kept craft power).
- 1H vs 2H net: `score(2H)` vs `score(1H) + best bag OH` (and 2H minus worn OH).

**Does not count**

- Affinity match flats
- Preferred-armor soft ±flats (proficiency stays a **hard** `canEquip` gate)
- `rarity.index * N`
- Flat set-completion equip bonus (`GearSets.equipScoreBonus` = 0 on upgrade path)
- Raw `effectiveItemLevel` added on top of stats (stats already come from the iLvl budget)

## Upgrade bar

`isMeaningfulEquipUpgrade`:

1. `newScore - curScore <= 0` → not an upgrade.
2. Empty slot → fill only if score/mass clears a level-scaled floor (`emptySlotWorthFilling`).
3. Worn slot → delta must clear `max(6, ~3% of curScore)`; lower-iLvl candidates need a stricter real-stat jump.
4. Non-Apex never replaces Apex.

**BEST** = highest `powerDelta` among candidates with `isUpgrade == true`.

## Set / Apex / Merge

- **Set 2pc/4pc:** real combat bonuses only; shown on tooltips. No ghost BiS points.
- **Apex:** own tier + hard-lock vs normal drops.
- **Merge:** identity (`setId`, affixes) from **primary** only; fuel adds budget/stats.

## Player-facing copy

- iLvl is the readable power size.
- Green **UPGRADE** means Auto Equip would swap.
- Guides / What’s New should stay honest to this contract.
