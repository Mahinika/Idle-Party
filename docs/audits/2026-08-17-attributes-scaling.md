# Attributes / stat scaling audit — 2026-08-17

**Depth:** full (code + WotLK identity structure, no Wowhead number scrape)  
**Playtest:** no  
**Scope:** primary stats, CombatRatings, gear budget, Auto Equip honesty, armor in SpatialCombat.  
**Not in scope:** 31-spec kit rotations (see `2026-08-10-all-specs-quick.md`).

WotLK is used for **shape** only (what a stat is *for*). Idle numbers stay Idle.

## Verdict

The five primaries (STR / AGI / STA / INT / SPI) are real and wired. Warrior STR and STA→HP match the intended WotLK-lite. The live sheet (`CombatRatings.fromHeroSheet`) is the combat authority.

Biggest gap: **three different caster conversions** plus **subtractive armor** that treats incoming and outgoing hits differently. Auto Equip can disagree with the sheet for Int vs Spell Power.

**Open P0:** 0 (combat still runs; saves OK).  
**Open P1:** 3 (honesty + armor feel).  
**Open P2:** 2 (AGI AP identity; PARTY chips have no “what this does”).

## Pipeline (what actually happens)

```
HeroSpec.startingStats
  + CombatRatings.levelGains(gearAffinity) × (level − 1)
  + worn gear primaries / armor / crit% / haste% / mp5 / flat ATK
  + party meta (Forge ATK/DEF/STA, AL, Blessing, soulbound, pet, relics)
  → CombatRatings.fromHeroSheet
  → SpatialActor.attack / defense / maxHp / spiritRegen
  → white hits + kit casts (SpatialCombat)
```

Gear drops: `iLvl → budgetForItemLevel → EquipStatWeights.lootShares → stats`.  
Auto Equip / UPGRADE: `itemBudgetScore` with `EquipStatWeights.forSpec` — **not** a second combat sim.

## Keep (working as designed)

| Piece | Why |
|-------|-----|
| STA → 10 HP | Same as Classic/WotLK; `plate_armor_ahead_test` covers DEF identity |
| Warrior AP = `2×STR + 3×level` | Matches WotLK plate melee shape |
| `kAp = 4` (not 14) | Idle number scale; do not copy WoW 14 AP = 1 DPS |
| AGI → DEF is `/8` crumb | Classic 2 armor/AGI would let leather beat plate |
| Tank guard `1 + level` | Plate tanks stay ahead of leather DPS (`plate_armor_ahead_test`) |
| Crit from AGI/INT uses a level divisor (cap 60) | Same idea as WoW ratings getting worse per level |
| Crit hard cap 75%; Forge % soft-cap | Idle anti-explode |
| Slot multipliers + iLvl soft-cap after 100 | Idle stand-in for expansion rating inflation |
| Spirit always regen (no 5SR) | Correct for AFK |
| No hit / expertise / dodge tables | First hour must stay calm |
| Caster kit tax `0.72` | Int spam vs Str melee; applied once in `_abilityOutScale` |
| Loot: one power primary + STA (casters + SP; healers + Spirit) | Phone-readable WotLK itemization |

## P1 — honesty (caster Int / Spell Power)

Three formulas, one player-facing “ATK”:

| Path | Formula |
|------|---------|
| Worn gear sheet | `grown.intel + (gearInt + gearSP) ~/ 3` |
| Soulbound → party meta ATK | `intel + SP~/2` (then `max` vs melee AP) |
| Auto Equip weights | Int `10`, SP `5` (docs: “Int full, SP ≈ half”) |
| Compare `atkDelta` chip | raw `STR+AGI+INT+SP+flatATK` (no AP conversion) |

Live combat treats **gear Int and gear SP as equal ATK** (`~/3` each). Only **naked/level Int** is full. Docs and soulbound still describe Cata-style “Int full, SP half”.

`test/equip_stat_priority_test.dart` locks “Int beats equal SP” for Fire — that is fair because Int also feeds spell crit — but it does **not** lock sheet ATK.

**Fix shape (if we take this):** pick the sheet as source of truth, make soulbound + `GEAR_BUDGET.md` + EquipStatWeights comments match `CombatRatings`, add a conversion test. Do not scrape WoW coefficients.

## P1 — armor feel (subtract, not percent)

WoW: `taken = hit × K / (armor + K)`, cap ~75%. Always useful, never immune.

Idle **incoming** (enemy → hero), `spatial_combat.dart`:

- `raw = max(20% pierce, enemyATK − DEF×0.55)` (AFK: DEF×0.75, then ×0.45)

Idle **outgoing** (hero → enemy):

- White / bolt / pet: `hit − enemyDEF` (full). AFK: DEF÷3 on hero shots.
- Melee kit hit: `raw − enemyDEF` (full, no pierce floor)

So hero DEF is discounted + pierce-floored; enemy DEF is full-subtract. High DEF on packs can flatten white hits; high hero DEF can still leak 20%. Tanks and later zones both feel this.

**Fix shape:** one percent formula both ways, K scaled with floor/zone so later enemies still sting. This is a SpatialCombat change → share-fast + gate after.

## P2 — AGI attack power identity

WotLK shape (identity only):

- Plate melee: 2 AP per STR
- Rogue / cat / enh: ~2 AP per AGI + 1 per STR
- Hunter ranged: 2 RAP per AGI

Idle `meleeAttackPower`:

- Warrior affinity: `2×STR + 3×level` (Ret, DKs, Guardian use this — OK)
- Rogue affinity: `STR + AGI + 2×level` (Combat, Assa, Sub, Feral, Enh, all three Hunters)

Loot already prefers AGI for those specs (`EquipStatWeights` AGI 10–11 vs STR 4–8.5). Sheet ATK does not double AGI, so Auto Equip “AGI is best” is only half-true in combat.

Enhancement is the hybrid that wants both; hunters are ranged but share the rogue AP bucket.

## P2 — PARTY chips vs gold upgrades

PARTY shows STR/AGI/STA/INT/SPI plus DMG/DEF/HP/CRIT/HASTE. Forge still buys ATK/DEF/STA (party-wide flats into meta). Guides explain loot primaries; chips themselves have no tap-explain.

Players can see two “STA”s: hero Stamina (HP via ratings) vs Forge STA (meta vitality). Copy in-game stays English; this is a clarity gap, not a formula bug.

## Also noted (not P1)

- **Guardian** uses warrior AP (STR) on leather. Fantasy is bear/agi in WotLK; Idle tank-guard + STA loot is the survival identity. Leave unless Guardian feels thin.
- **Holy Paladin** is healer affinity (Int sheet), not STR→SP. Correct for idle.
- **Crit/Haste on loot are already percents**, not ratings. Level divisor only applies to AGI/INT→crit. Fine for a phone idle.
- **atkDelta** on compare is a stat-sum, not sheet ATK. UPGRADE itself uses `itemBudgetScore` (good). Don’t show atkDelta as “DMG” without converting.
- **Enemies** still use flat ATK/DEF/HP (`Stats.enemy`) — no primary model. Intentional v1.

## Tests that lock this

| Test | What it proves |
|------|----------------|
| `plate_armor_ahead_test` | AGI crumb ≠ 2 armor; plate Prot DEF > leather Combat |
| `equip_stat_priority_test` | BiS weights: Str vs Sta, Int vs SP vs Spirit |
| `equipment_wow_lite_test` | iLvl/budget/slot/sets |
| `gear_balance_sim_test` | Mage vs rogue gear power band |
| **Missing** | CombatRatings Int/SP → ATK; soulbound vs worn; outgoing vs incoming armor |

## Recommended order

1. **Int/SP honesty** — cheapest, no dungeon-feel rewrite. Align soulbound + docs + a conversion test to the sheet.
2. **Armor percent** — biggest feel/fairness win; needs combat + gate.
3. **2 AP per AGI** for rogue affinity (optional hunter 2×) — identity; then share-fast.

Do **not** add hit-cap, expertise, dodge/parry diminishing, or 5-second mana rule.
