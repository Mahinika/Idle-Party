# Gear budget contract

Idle Party item power follows one pipeline: **iLvl → budget → role split → stats → combat / UPGRADE**.

Auto Equip, green **UPGRADE**, and bag **BEST** must use the same predicate. Soft score crumbs (affinity, preferred-armor flats, rarity×N, set completion flats) are **not** allowed on the upgrade path.

## Budget

Source of truth: `EquipmentFactory.budgetForItemLevel` in `lib/core/equipment_factory.dart`.

- Inputs: display **item level**, **rarity** (quality mul), **slot** (and 2H mul).
- ~`0.88` primary points per iLvl on a main-hand rare before armor carve / affix slice.
- Rarity mainly raises shown iLvl via `itemLevelFor`; quality mul keeps epic/legendary denser at the same iLvl.
- KEY loot bonus is `Keystone.lootItemLevelBonus` (`key * 2`) — KEY +10 is +20 iLvl, not `key ~/ 4`.

New drops, merge output, and Apex craft should spend this budget — not invent a parallel power curve.

## Drop slots

Kill loot rolls one **family** at a time (`LootPipeline.dropFamilies`): weapon,
off-hand, ranged, eight armor pieces, cloak, neck, **one** ring, **one** trinket.
`ring2` / `trinket2` are equip slots only — Auto Equip still fills either finger.

Then it picks a living party member who can actually wear that family (ranged /
off-hand are skipped if nobody uses them). Shield-users get extra off-hand
weight so a Prot tank sees shields instead of a silent remap into extra weapons.

## Stat split

Configured in `EquipStatWeights.lootShares` / `forSpec` (`lib/models/equip_stat_weights.dart`).

| Role bucket | Primaries (typical) | Secondaries |
|-------------|---------------------|-------------|
| Tank | Sta + Str (+ Armor carve) | Crit / Haste sparingly |
| Str melee | Str + Sta | Crit, Haste |
| Agi melee / hunter | Agi + Sta (+ some Str) | Crit, Haste |
| Caster | Int + Sta + Spell Power | Crit, Haste |
| Healer | Int + Sta + SP + Spirit | **Mp5, Crit** (Haste last — heals ignore haste) |

Rules:

- At most **two** secondaries on new loot.
- Healer loot fills **Mp5 then Crit** (weapons/gloves do not haste-first). Haste is the leftover line.
- **No Move** on loot budget.
- Affinity on an item is **drop bias / tooltip flavour**, not equip-score.
- **Armor type is a hard `canEquip` gate** (plate / mail / leather / cloth per class). Auto Equip never scores a Paladin into leather.
- **Weapons / off-hand / ranged are the same hard gate** (WotLK class lists). Auto Equip never puts a dagger on a Paladin or a bow on a Death Knight.

Combat conversion (must stay aligned with equip weights):

- Melee ATK from Str/Agi via `CombatRatings` (kAp = 4). Plate: 2 AP/Str. Rogue-family: 1 AP/Str + **2 AP/Agi**.
- Sheet DEF is gear Armor + tank guard + a small Agi crumb (`CombatRatings.agilityToDefense`). Plate tanks stay ahead of leather DPS.
- Caster/healer: **level Intellect full**; **gear Int and Spell Power both ≈ 1/3** into ATK. Int still adds spell crit.
- Healer Spirit → mana: `1.25 + Spirit × 0.06` /s. Mp5 → `value / 5` /s.
- Physical hits use percent armor (`CombatRatings.mitigateByArmor`) — more DEF always helps, never immune.

## Equip score (`itemBudgetScore`)

Used by `specEquipScore` / `slotEquipScore` / BiS / Auto Equip.

**Counts**

- Role-weighted stat mass (Str/Agi/Sta/Int/Spi/SP/Armor/Crit/Haste/Mp5/flat ATK) — same DNA as `EquipStatWeights.forSpec`.
- **Crit fades** once the hero's sheet crit is 70+ (zero at the 75 combat cap) so Auto Equip does not chase a clamped stat.
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
3. Worn slot → delta must clear `max(6, ~3% of curScore)` (AL20 / level 50+: `max(8, ~4%)`); lower-iLvl candidates need a stricter real-stat jump.
4. Non-Apex never replaces Apex.

**BEST** = highest `powerDelta` among candidates with `isUpgrade == true`.

## Set / Apex / Merge

- **Set 2pc/4pc:** real combat bonuses only; shown on tooltips. No ghost BiS points.
- **Apex:** own tier + hard-lock vs normal drops. Stats use the same
  `lootShares` split as dungeon drops (no parallel Attack Power dump —
  `attackBonus` is flat sheet ATK, ~2× a Strength point).
- **Merge:** identity (`setId`, affixes) from **primary** only; fuel adds ~50%
  stats. RESULT preview shows the SCORE jump. If both pieces have an on-item
  effect, the stronger value wins.
- **Charms (trinkets):** always roll an on-item effect (other slots still use
  rarity chance). Charm names match the CHARM slot.

## Player-facing copy

- iLvl is the readable power size.
- Green **UPGRADE** means Auto Equip would swap.
- Guides / What’s New should stay honest to this contract.

## Code ownership (Factory vs Service vs Pipeline)

Keep new gear features on the right side of this line:

| Layer | Path | Owns |
|-------|------|------|
| **Factory** | [`lib/core/equipment_factory.dart`](../lib/core/equipment_factory.dart) | Rolling new items: iLvl budget, stat split, rarity, slot, effects, merge output, Apex craft rolls. `budgetForItemLevel`, loot generation helpers. |
| **Stash** | [`lib/core/gear/gear_stash.dart`](../lib/core/gear/gear_stash.dart) | Bag capacity, stash/overflow, find/remove. |
| **Equip** | [`lib/core/gear/gear_equip.dart`](../lib/core/gear/gear_equip.dart) | Equip/unequip, slot targets, illegal-gear migrate. |
| **Scorer** | [`lib/core/gear/gear_scorer.dart`](../lib/core/gear/gear_scorer.dart) | `itemBudgetScore`, upgrade predicates, compare/BEST. |
| **BiS** | [`lib/core/gear/gear_bis_planner.dart`](../lib/core/gear/gear_bis_planner.dart) | BiS plan cache, Auto Equip passes (empty slots first). |
| **Cleanup** | [`lib/core/gear/gear_cleanup.dart`](../lib/core/gear/gear_cleanup.dart) | Merge/sell/disassemble, bag unstick, loadout presets, `shouldKeepInBag` (BiS + near-iLvl slot backup). |
| **Grant** | [`lib/core/gear/loot_resolver.dart`](../lib/core/gear/loot_resolver.dart) | **Roll → Grant**: apply drops to wallet/bag/filters; `LootGrantResult` receipt. |
| **Facade** | [`lib/core/gear_service.dart`](../lib/core/gear_service.dart) | Stable public API — forwards to modules above. |
| **Pipeline** | [`lib/core/loot_pipeline.dart`](../lib/core/loot_pipeline.dart) | **Roll**: kill drops (slot family, who can wear it). Reads [`drop_tables.json`](../assets/data/drop_tables.json) via [`drop_tables.dart`](../lib/core/gear/drop_tables.dart). Calls Factory; hands results to Grant. |
| **Economy** | [`lib/core/economy_service.dart`](../lib/core/economy_service.dart) | Gold-find bonuses on wallet credit (combat, loot grant, market). |

**Glossary:** **Roll** = what dropped (`LootPipeline`). **Grant** = where it went (`LootResolver.grant` → gold/essence/stash/auto-sell).

**Rule:** if it creates item stats from iLvl → **Factory**. If it moves or scores existing items → **Service modules**. Never duplicate budget math in UI or `GameLogic` — delegate to one of the above.
