# Class & combat audit — Cataclysm reference

**Original date:** 2026-08-22  
**Re-audit:** 2026-09-11  
**Auditor:** Cursor agent (senior combat/class pass)  
**Depth:** full (systems) + quick (31 specs) + deep (4 stickprov)  
**Specs in scope:** all 31 `HeroSpecId`  
**Playtest:** no (code + public Cata facts + `cata_combat_v2_test`)  
**Build / branch:** `main` @ **1.12.136**

**Reference expansion:** **Cataclysm 4.0–4.3** (patch 4.0.1 stat overhaul, Mastery, block redesign).  
**Product note:** Idle Party **lore/copy** still reads Wrath (zones, AGENTS). Combat layer is **Cata-shaped since v2 (Aug 2026)**; this doc tracks **honest gaps** vs full Cata fidelity.

**Legal:** Wowhead / wiki used for **structure + identity** only. No tooltip coefficients, talent point spreads, or BiS pasted here (`AGENTS.md`).

**Implementation companion:** [2026-08-22-class-combat-cata-implementation.md](2026-08-22-class-combat-cata-implementation.md) (slice checklist, updated 2026-09-11).

---

## Executive summary (2026-09-11)

Idle Party now runs a **Cata v2 combat motor** on top of the same auto-AI kit layer. The August audit’s **P0 systems shipped** (`combat_ratings.dart`, `combat_avoidance.dart`, `spec_mastery.dart`, Aug 2026). Since then: **Druid form pass (1.12.134)**, **kit/balance polish (1.12.135)**, ongoing fairness gate.

| Question | Cata had it? | Idle today (1.12.136) | Verdict |
|----------|--------------|------------------------|---------|
| Spells (named + schools) | Yes | Named yes; **physicalAttack / spellPower split** | **Shipped** — expand `inferUsesSpellPower` coverage |
| Cast time | Yes (+ haste on cast) | **10** abilities with `castDelaySeconds`; haste shrinks delay | **Partial** — not all signatures tagged |
| Diminishing returns | Yes (dodge/parry + CC) | Dodge/parry rating DR + **CC root DR stacks** | **Shipped** (idle-tuned) |
| Mastery | **Yes (Cata core)** | **31 kinds** + gear secondary + combat hooks | **Shipped** — tune magnitudes; some procs thin |
| Ability damage formula | AP / SP × coeff | `_abilityPower` × coeff × mastery shape | **Shipped** |
| Tank avoidance | Dodge/parry/block via mastery | Uncrittable + dodge/parry + mastery block **−30%** + Shield Block CD | **Shipped** — no separate “crit block” proc |

**Biggest remaining gaps:** **Mp5 still on healer loot** (Cata removed it), **Elemental Overload** (and a few proc masteries) not fully wired in sim, **ability crit from rating** still mostly auto-only, **no hit/expertise/reforge**.

**Biggest strength:** SpatialCombat stays single authority; mastery changes **shape** (DoT amp, Deep Healing, block %) without breaking fairness gate; DODGE / PARRY / BLOCK floaters on tanks.

---

## Audit DoD

- [x] Cata combat facts summarized with external sources
- [x] Idle combat path documented with file references
- [x] Six owner questions answered (Ja/Nej/Alternativ)
- [x] Four stickprov specs: Protection Warrior, Protection Paladin, Fire Mage, Restoration Shaman
- [x] 31-spec quick table (Cata mastery name + identity score + top gap)
- [x] P0/P1/P2 roadmap + **re-audit status (2026-09-11)**
- [x] Medveten Wrath-lore vs Cata-mechanics avgränsning

---

## Re-audit snapshot — 2026-09-11

### Shipped since original audit (Aug 2026 → now)

| System | Evidence | Notes |
|--------|----------|-------|
| **S1** Sheet split | `CombatRatings.physicalAttack`, `spellPower`, `masteryPoints`, dodge/parry % | Tanks skip Agi→DEF crumb |
| **S2** Spell vs melee | `ClassAbilityDef.inferUsesSpellPower`, `ability_effects._abilityPower` | Casters use SP pool in combat |
| **S3** Tank avoidance | `combat_avoidance.dart`, `spatial_combat._applyHeroIncomingDamage` | DODGE / PARRY / BLOCK floaters |
| **S4–S5** Mastery 31 | `spec_mastery.dart` — damage/heal/dot/block/proc hooks | Labels in GEAR + party HUD |
| **S6** Cast delay | `castDelaySeconds` on 10 defs; `_castDelaySeconds` ÷ haste | Fireball, Pyro, Healing Wave, Penance, … |
| **S7** CC DR | `CombatAvoidance.ccRootDuration`, `ccRootDrLevel` on enemies | Frost Nova spam shortens |
| **S8** Spirit 5SR | `spiritManaRegenPerSec(inCombat, recentlyDamaged)`, `spiritRegenPaused` on hit | **Mp5 still rolls on new healer loot** |
| **Gear mastery** | `loot.masteryBonus`, `equipment_factory` secondary pool | Not in `itemBudgetScore` upgrade path |
| **Kit polish** | 1.12.134–135 | Druid forms + Eclipse; Subtlety Shadow Dance; share trims |

**Verify (2026-09-11):** `cata_combat_v2_test` 8/8, `combat_ratings_test` 9/9, `class_balance_gate_test` green on `main`.

### Still open vs Cata 4.0–4.3

| Gap | Priority | Detail |
|-----|----------|--------|
| Mp5 on healer drops | **P1** | Cata Spirit-only; `GEAR_BUDGET.md` + `equip_stat_weights` still weight Mp5 |
| Cast delays on all signatures | **P1** | Only ~10 abilities tagged; most casts still instant |
| Elemental Overload duplicate cast | **P1** | Enum + label exist; **no spatial proc hook** |
| Hunter vs Wild stamina link | **P2** | Generic mastery damage crumb only |
| Ability crit from rating | **P2** | Fireball still proc-driven Hot Streak; sheet crit mostly autos |
| Hit / Expertise | **P2** | Not modeled |
| Reforge-like meta | **P2** | Not modeled |
| Critical Block “crit block” double | **P2** | Block −30% yes; separate crit-block proc no |
| Mastery in upgrade score | **P2** | Intentionally combat-only per v2 design |
| Full cast bar / interrupts | **Skip** | Phone idle product lock |

### Post–Cata v2 kit work (not in Aug audit)

| Batch | Version | Cata relevance |
|-------|---------|----------------|
| Druid forms + Eclipse mastery buffs | 1.12.134 | Balance `SpecMasteryKind.eclipse` now has arcane/nature window hooks |
| Subtlety Shadow Dance | 1.12.135 | Kit identity; Executioner mastery unchanged |
| Combat / Demo / melee plate share | 1.12.135 | Fairness trim — not Cata systems |

---

## Part 1 — Cataclysm 4.0–4.3 combat facts

Sources: [Blizzard Stat Changes 4.0.1](https://www.bluetracker.gg/wow/topic/us-en/27187850231-stat-changes-in-401/), [Patch 4.0.1 (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/Patch_4.0.1), [Mastery (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/Mastery), [Wowhead Cata Mastery overview](https://www.wowhead.com/ptr/guide=cataclysm&mastery).

| System | In Cata 4.0–4.3? | Notes |
|--------|------------------|-------|
| **Mastery** | **Yes (new)** | Unique passive per **specialization**; rating → points → % effect |
| **Reforging** | Yes | 40% of one secondary → another (not already on item) |
| **Defense rating** | **Removed** | Tanks uncrittable via stance/presence/Righteous Fury |
| **Block redesign** | Yes | Blocked hit **−30% damage**; block **chance** from **Mastery** (Prot Warr/Pala) |
| **Intellect → Spell Power** | Yes | SP off most gear; caster **weapons** keep SP |
| **Mp5 on gear** | **Removed** | Healers lean **Spirit** |
| **Hit / Expertise** | Yes | Steeper rating curve; harder to cap at bis |
| **GCD + cast + pushback** | Yes | Haste affects **cast time** and melee |
| **Dodge / Parry rating** | Yes | Separate DR curves vs other ratings |
| **Spirit 5-second rule** | Yes | In-combat regen windowing |
| **Ability crit from rating** | Yes | Spell crit from Int + gear |
| **Spell ranks** | Removed | One rank per spell — matches Idle's ability rows |

**Not in scope (post-Cata):** MoP talent tiers, WoD pruning, Legion artifacts, Shadowlands borrowed power.

---

## Part 2 — Idle Party combat path (1.12.136)

### Data flow

```
PartyHero + gear
  → CombatRatings.fromHeroSheet (physicalAttack, spellPower, mastery, dodge/parry)
  → GameState.effectiveHeroAttack / ratingsFor
  → SpatialCombat.build → SpatialActor (+ uncrittable, blockChance, masteryPoints)
  → AbilityEffectRunner._tickSpecKit
  → _castDamage: _abilityPower × coeff × kitOutMul × SpecMastery.damageMul
  → DoT ticks: SpecMastery.dotTickMul
  → Heals: SpecMastery.healMul (Deep Healing missing-HP scale)
  → CombatRatings.mitigateByArmor
  → _applyHeroIncomingDamage → CombatAvoidance.resolveIncomingMelee (dodge/parry/block −30%)
  → DR CDs + absorb overlays
```

### Ability damage (authoritative)

```dart
// ability_effects.dart — power split + mastery shape
raw = max(2, (_abilityPower(hero, def) * def.coeff * _abilityOutScale(hero)).round());
// × SpecMastery.damageMul(...) in _castDamage path
```

- Caster tax: `SpatialCombat.casterAbilityTax` (0.92) for casters.
- White hits: `spatial_combat.dart` swing path; Arms/MM/Combat mastery procs → **SWING** floaters.
- Fireball: cast delay 1.8s (haste-scaled); Hot Streak proc chain — sheet spell crit still **P2**.

### Sheet stats vs combat

| Stat | On sheet | Combat use today |
|------|----------|------------------|
| Str / Agi | Yes | `physicalAttack` (plate 2 AP/Str; rogue-family 1+2 Agi) |
| Int / SP | Yes | `spellPower` — level Int + gear Int/SP ÷3 in combat |
| Armor | Yes → DEF | Percent mitigation |
| Agi | Yes | Tanks: **dodge %**; non-tanks: small DEF crumb |
| Crit / Haste | Gear + forge | Crit mostly **autos**; haste on **swing + cast delay** |
| Spirit | Yes | `spiritManaRegenPerSec` with **5SR pause** on damage |
| Mp5 | Gear | Still on healer loot + `mp5/5` regen — **Cata mismatch** |
| Mastery | Yes | `masteryRating` → `masteryPoints` → `SpecMastery.*` hooks |

### Cast / resource model

- **No GCD, no cast bar, no interrupts** (unchanged product choice).
- **Cast delay:** 10 abilities with `castDelaySeconds`; `_castingUntil` gate in ability tick.
- Resources: single `SpatialActor.rage` 0–100 (rage/mana/energy/runic).
- Channels: Penance bolts, Chain Lightning hops, projectile stagger.
- AI priority: emergency → taunt → signature → filler.

### Incoming damage (tanks)

```dart
// spatial_combat.dart — melee path via CombatAvoidance
avoid = resolveIncomingMelee(
  dodgePercent: hero.dodgePercent,
  parryPercent: hero.parryPercent,
  blockChance: hero.blockChance + SpecMastery.blockChance(...),
  shieldBlockActive: hero.shieldBlockTimer > 0,
);
// blocked hits: −30% then flat blockValue; floaters DODGE / PARRY / BLOCK
```

- Passive mastery block + active Shield Block / Holy Shield window.
- `uncrittable` on tank specs (Cata stance analogue).

### CC

- Root duration scales with `ccRootDrLevel` (100% → 50% → 25% → immune).
- Ability-name “DR” = damage reduction cooldowns (separate from CC DR).

---

## Part 3 — Answers to six questions (status 2026-09-11)

### 1. Ska vi lägga till spells?

| | Aug 2026 rec | Status |
|--|--------------|--------|
| Split physical vs spell | **Ja** | **Done** — `_abilityPower` + `inferUsesSpellPower` |
| Keep named abilities | **Ja** | **Done** |
| No manual cast bar | **Behåll** | **Done** |
| `damageSchool` tags | Optional | **Open P2** — not required for split to work |

### 2. Cast time?

| | Aug 2026 rec | Status |
|--|--------------|--------|
| Signature delays | **Ja** | **Partial** — 10 abilities (Fireball, Pyro, Healing Wave, Penance, …) |
| Haste on cast | **Ja** | **Done** — `_castDelaySeconds` ÷ haste |
| Interrupt / pushback | **Nej** | **Skipped** (product) |
| Casting UI chip | Nice | **Open** — delay is sim-only |

### 3. Diminishing returns?

| Type | Status |
|------|--------|
| Dodge/Parry rating → % | **Done** — `CombatAvoidance.ratingToPercent` |
| Mastery rating → points | **Done** — `SpecMastery.masteryPointsFrom` |
| Crit/Haste high stacks | **Open P2** — 75% crit cap on sheet |
| CC root DR | **Done** — `ccRootDrLevel` |
| DR cooldowns | **Done** — Shield Wall, etc. (multiplicative) |

### 4. Stats som Mastery?

| | Status |
|--|--------|
| 31 spec hooks | **Done** — `spec_mastery.dart` |
| Gear secondary | **Done** — `masteryBonus` on loot |
| UI label | **Done** — GEAR panel + party HUD chip |
| `kitOutMul` baseline | **Kept** — mastery adds shape on top |

**Product:** mechanics are **Cata-shaped**; zones/copy remain Wrath-named.

### 5. Hur bestäms ability damage?

**Shipped:**

```
melee  = physicalAttack × coeff × kitOutMul × SpecMastery.damageMul
spell  = spellPower × coeff × kitOutMul × SpecMastery.damageMul
heal   = spellPower × coeff × SpecMastery.healMul(missing HP)
DoT    = tick × SpecMastery.dotTickMul (Ignite, Affliction, …)
```

### 6. Avoidance för tanks?

| Layer | Status |
|-------|--------|
| Uncrittable | **Done** |
| Armor | **Done** |
| Dodge/Parry | **Done** |
| Block mastery + −30% | **Done** + Shield Block CD |
| Active DR | **Done** |

**Agi:** tanks use dodge %, not DEF crumb — **done**.

---

## Part 4 — Stickprov (full depth)

Wowhead reference family: **Cataclysm Classic** class guides (structure only).

### `HeroSpecId.protection` — Protection Warrior

**Verdict:** **ship** (Cata tank motor wired; tune magnitudes on phone)  
**Cata Mastery:** Critical Block (+ block chance + critical block chance)  
**Idle equivalent:** `SpecMastery.blockChance` + `CombatAvoidance` + Shield Block CD + Revenge

| Bucket | Cata fantasy | Idle ability | Wired? |
|--------|--------------|--------------|--------|
| Maintain | Sunder stacks | Devastate | yes |
| AoE threat | Thunder Clap, Shockwave | Thunder Clap, Shockwave | yes |
| Block CD | Shield Block | Shield Block | yes — **timed DR**, not Cata proc |
| Emergency | Last Stand, Shield Wall | Last Stand, Shield Wall | yes |
| Signature | Shockwave cone | Shockwave | yes |
| Passive stance | Defensive Stance | Defensive Stance | yes — `kitInMul` |

**Mastery gap:** no separate **critical block** double-size proc (block −30% is correct).

**WotLK identity score (kit names):** 4/5  
**Cata mechanics score:** **4/5** (was 2/5)

**Player pitch:** “Hold the pack, clap slows, block then revenge” — **matches feel and mitigation math** on melee trash (watch DODGE/PARRY/BLOCK floaters).

---

### `HeroSpecId.protPaladin` — Protection Paladin

**Verdict:** **ship**  
**Cata Mastery:** Divine Bulwark (+ block chance)  
**Idle equivalent:** `SpecMastery.divineBulwark` passive block + Holy Shield active window

| Bucket | Cata | Idle |
|--------|------|------|
| Ranged pull | Avenger's Shield | Avenger's Shield | yes |
| Block buff | Holy Shield | Holy Shield | yes — active window |
| AoE | HotR, Consecration | HotR, Consecration | yes |
| Single target | Shield of Righteousness | SoR | yes |
| Taunt | Hand of Reckoning | HoR | yes |
| Passive | Righteous Fury | Righteous Fury | yes — threat + `kitInMul` |

**Mastery gap:** Consecration standing DR (Cata flavor) — optional P2.

**Cata mechanics score:** **4/5** (was 2/5)  

---

### `HeroSpecId.fire` — Fire Mage

**Verdict:** **ship** (best Cata proc analog in repo)  
**Cata Mastery:** Increases **periodic fire damage** (Ignite / DoT theme)  
**Idle equivalent:** `SpecMastery.ignite` on DoT ticks + Living Bomb + Hot Streak

| Bucket | Cata | Idle |
|--------|------|------|
| ST filler | Fireball | Fireball | yes — instant, 28% hardcoded crit |
| DoT / spread | Living Bomb, Ignite | Living Bomb | partial — no Ignite mastery chain |
| Proc | Hot Streak → Pyro | Hot Streak → Pyro | **strong** |
| AoE | Blast Wave, Flamestrike | Blast Wave | partial |
| CD | Combustion | Combustion | yes — `combustionTimer` ×1.22 |
| Control | Frost Nova | Frost Nova | yes — **no CC DR** |

**Cast gap:** delay shipped; expand to more fire spells optional.

**Damage gap:** SP pool + DoT mastery **shipped**; sheet crit on spells still P2.

**Cata mechanics score:** **4/5** (was 3/5)  

---

### `HeroSpecId.restorationShaman` — Restoration Shaman

**Verdict:** tune (mana model)  
**Cata Mastery:** Deep Healing (+ healing to low-HP targets)  
**Idle equivalent:** `SpecMastery.deepHealing` in `healMul` — scales with target missing HP %

| Bucket | Cata | Idle |
|--------|------|------|
| HoT | Riptide | Riptide | yes |
| ST heal | Healing Wave | Healing Wave | yes |
| Chain | Chain Heal | Chain Heal | yes |
| Absorb | Earth Shield | Earth Shield | yes |
| AoE | Healing Rain | Healing Rain | yes |
| Signature | Spirit Link | Spirit Link | yes |
| Passive amp | Ancestral Awakening | Ancestral Awakening | flat mul only |

**Mana gap:** Spirit 5SR **shipped**; **Mp5 still on new healer loot** — opposite of Cata.

**Cata mechanics score:** **3/5** (was 2/5)  

---

## Part 5 — All 31 specs (quick pass, re-audit 2026-09-11)

Score = **Cata mechanics + kit names** (1 wrong · 3 recognizable · 5 nails).  
Top gap = highest-impact **remaining** gap vs Cata 4.0–4.3.

| Spec | Cata Mastery | Idle hook | Score | Top gap |
|------|--------------|-----------|-------|---------|
| arms | Strikes of Opportunity | `extraSwingProcChance` + SWING floaters | 4 | Tune proc rate |
| fury | Unshackled Fury | rage-high `damageMul` | 4 | Enrage window clarity |
| protection | Critical Block | `blockChance` + avoidance | 4 | Crit-block double |
| holyPaladin | Illuminated Healing | `healMul` + absorb mul | 3 | Absorb-on-heal rider |
| protPaladin | Divine Bulwark | passive block + Holy Shield | 4 | Consecration DR zone |
| retribution | Hand of Light | holy strike `damageMul` | 4 | — |
| beastMastery | Master of Beasts | Kill Command `damageMul` | 4 | Pet AP mastery scale |
| marksmanship | Wild Quiver | `extraAutoShotProcChance` | 4 | — |
| survival | Hunter vs Wild | generic mastery crumb | 3 | Stamina/pet link |
| assassination | Master Poisoner | `dotTickMul` | 4 | — |
| combat | Main Gauche | `mainGaucheProcChance` | 4 | Share band (tuned 1.12.135) |
| subtlety | Executioner | execute-threshold `damageMul` + Shadow Dance | 4 | — |
| discipline | Shield Discipline | `absorbStrengthMul` | 3 | Shield strength UI |
| holyPriest | Echo of Light | `healMul` bump | 3 | HoT-on-heal rider |
| shadow | Empowered Shadow | `dotTickMul` + shadow form art | 4 | — |
| blood | Blood Shield | `absorbStrengthMul` | 3 | DS overheal → absorb sim |
| frostDk | Frozen Power | rooted `damageMul` | 4 | — |
| unholy | Dreadblade | `dotTickMul` | 4 | — |
| elemental | Elemental Overload | **label only** | 2 | **Duplicate cast proc** |
| enhancement | Enhanced Elements | elemental `damageMul` | 4 | — |
| restorationShaman | Deep Healing | missing-HP `healMul` | 3 | **Mp5 on loot** |
| arcane | Mana Adept | mana% `damageMul` | 4 | — |
| fire | Ignite | `dotTickMul` + cast delay | 4 | Spell crit from rating |
| frostMage | Frostburn | rooted `damageMul` | 4 | — |
| affliction | Potent Afflictions | `dotTickMul` | 4 | — |
| demonology | Master Demonologist | demon spell `damageMul` | 4 | Pet lean (trimmed 1.12.135) |
| destruction | Flashburn | direct fire `damageMul` | 4 | — |
| balance | Eclipse | eclipse buff `damageMul` + forms | 4 | — |
| feral | Razor Claws | `dotTickMul` + cat form | 4 | — |
| guardian | Savage Defense | `absorbStrengthMul` + bear form | 3 | Absorb-on-hit proc feel |
| restorationDruid | Harmony | `healMul` | 3 | HoT-after-direct rider |

**Pattern:** most DPS **4**; healers/tanks **3–4**; **elemental 2** (overload not wired); healer **Mp5** is cross-spec mana gap.

---

## Part 6 — Roadmap status (2026-09-11)

| Prio | System | Aug rec | Status |
|------|--------|---------|--------|
| **P0** | Mastery per spec + gear | Yes | **Shipped** Aug 2026 |
| **P0** | Melee vs spell + Int→SP | Yes | **Shipped** |
| **P0** | Tank dodge/parry + block −30% | Yes | **Shipped** |
| **P1** | Cast delay + haste-on-cast | Yes | **Partial** (10 abilities) |
| **P1** | CC diminishing | Yes | **Shipped** |
| **P1** | Spirit 5SR; remove Mp5 from new loot | Yes | **Half** — 5SR yes, Mp5 still on drops |
| **P1** | Elemental Overload proc | — | **Open** |
| **P2** | Hit/expertise | Yes | **Open** |
| **P2** | Ability crit from rating | Yes | **Open** |
| **P2** | Reforge-like hub meta | Yes | **Open** |
| **P2** | Expand cast delays to all signatures | — | **Open** |
| **Skip** | Full GCD + interrupt | Yes | **Skipped** |
| **Skip** | Defense rating | Yes | **Skipped** |
| **Skip** | MoP+ systems | Yes | **Skipped** |

**Fairness:** `class_balance_gate_test` green after v2 tune + 1.12.135 share trim.

---

## Part 9 — Mastery hook blueprint (31 specs)

Proposed **Idle Party combat hooks** when implementing Cata v2. Names follow Cata public mastery labels; **magnitudes tuned in-code**, not copied from Wowhead.

| Spec | Cata mastery (reference) | Proposed Idle hook | Hook site |
|------|--------------------------|-------------------|-----------|
| arms | Strikes of Opportunity | Extra white swing proc on melee abilities | `spatial_combat.dart` swing path |
| fury | Unshackled Fury | Scale enrage/`kitOutMul` windows from mastery rating | `ability_effects.dart` passives |
| protection | Critical Block | `blockChance` + `critBlockChance` on incoming melee | `_applyHeroIncomingDamage` |
| holyPaladin | Illuminated Healing | Absorb = % of direct heal (stack with Earth Shield) | heal resolution |
| protPaladin | Divine Bulwark | `blockChance` + optional consecration DR zone | incoming + ground AoE |
| retribution | Hand of Light | Holy splash on TV/Crusader/DS analog abilities | `_castDamage` rider |
| beastMastery | Master of Beasts | Pet damage × mastery factor | pet attack in spatial |
| marksmanship | Wild Quiver | Bonus auto shot proc | white hit path |
| survival | Hunter vs Wild | Pet/survival hybrid stat link | pet + hero AP share |
| assassination | Master Poisoner | DoT tick amp on poison abilities | dot tick loop |
| combat | Main Gauche | Off-hand strike proc on main-hand | swing rider |
| subtlety | Executioner | Finisher amp below execute threshold | gate + coeff mul |
| discipline | Shield Discipline | Absorb strength from mastery | absorb apply |
| holyPriest | Echo of Light | HoT on direct heal | heal resolution |
| shadow | Empowered Shadow | Periodic shadow tick amp | dot tick loop |
| blood | Blood Shield | DS absorb from overheal mastery | self-heal → absorb |
| frostDk | Frozen Power | Bonus vs rooted/frozen (`rootTimer`) | `_castDamage` shatter family |
| unholy | Dreadblade | Shadow/disease tick amp | dot + ghoul damage |
| elemental | Elemental Overload | Duplicate bolt at reduced coeff | projectile spawn |
| enhancement | Enhanced Elements | Fire/frost/nature ability mul | `_abilityOutScale` |
| restorationShaman | Deep Healing | Heal coeff × missing ally HP % | heal resolution |
| arcane | Mana Adept | Damage amp from mana pool % | `_castDamage` arcane family |
| fire | Ignite (periodic fire) | Living Bomb / ignite tick amp | dot tick loop |
| frostMage | Frostburn | Frozen target damage amp | shatter family |
| affliction | Potent Afflictions | DoT tick amp | dot tick loop |
| demonology | Master Demonologist | Pet/meta demon damage amp | pet + meta damage |
| destruction | Flashburn | Direct fire spell amp (not DoT) | `_castDamage` fire instant |
| balance | Eclipse | Arcane/nature phase amp when eclipse buff active | selfBuff windows |
| feral | Razor Claws | Bleed tick amp | dot tick loop |
| guardian | Savage Defense | Absorb proc on melee taken | incoming damage rider |
| restorationDruid | Harmony | HoT amp after direct heal | heal → hot apply |

**Gear:** add `masteryRating` secondary in loot budget (like Crit/Haste) → convert to `masteryPoints` on sheet → feed hooks above. **Not** part of `itemBudgetScore` upgrade path.

**Baseline bridge:** keep existing `kitOutMul` passives as **free tier-0 mastery**; gear mastery adds on top so old saves don't collapse.

---

## Part 10 — Implementation slices (when leaving report-only)

Execute in order; each slice = code + gate + short test list.

| Slice | Deliverable | Key files |
|-------|-------------|-----------|
| **S1** | `CombatRatings`: `meleeAttack`, `spellPower`, `masteryPoints`; Int→SP Cata sheet | `combat_ratings.dart`, `game_state.dart`, `GEAR_BUDGET.md` |
| **S2** | `_castDamage` school split + `usesSpellPower` on `ClassAbilityDef` | `class_ability.dart`, `ability_effects.dart` |
| **S3** | Tank incoming: uncrittable, dodge/parry DR, mastery block −30% | `spatial_combat.dart`, new `combat_avoidance.dart` |
| **S4** | Mastery hooks for **tanks + healers** (8 specs) | spec table above |
| **S5** | Mastery hooks for **remaining DPS** (23 specs) | spec table above |
| **S6** | Cast delay + haste-on-cast for signature spells | `kit_migrated_casts.dart`, AI tick |
| **S7** | CC DR categories | `spatial_combat.dart` root/stun fields |
| **S8** | Spirit 5SR; Mp5 off new loot (migrate old) | `combat_ratings.dart`, `equip_stat_weights.dart` |

Skip in v2: Defense rating, full GCD/interrupt, Resilience, raw reforge UI.

---

## Part 11 — Stickprov P0 lists (per spec)

### Protection Warrior — P0 if building Cata motor

1. Passive block chance from mastery (Critical Block shape).
2. Dodge/parry rating on sheet (Agi → dodge, not DEF crumb).
3. Blocked hits −30% before armor (Cata rule), keep Shield Block CD as extra window.
4. Revenge still fires on block proc.

### Protection Paladin — P0

1. Divine Bulwark → passive block chance (Holy Shield CD stays).
2. Same avoidance stack as Prot Warr.
3. Righteous Fury → uncrittable flag.

### Fire Mage — P0

1. Spell damage from SP pool, not unified attack.
2. Mastery amplifies DoT ticks (Living Bomb chain).
3. Fireball/Pyro cast delay; haste reduces delay.
4. Hot Streak stays proc-driven (sheet crit optional P2).

### Restoration Shaman — P0

1. Deep Healing mastery on heal coeff vs missing HP.
2. Spirit-only mana regen on new gear path (Mp5 legacy OK on old items).
3. Heals use SP pool; cast delay on Healing Wave optional P1.

---

## Part 7 — Product alignment note

| Topic | Today | Cata audit target | Owner decision |
|-------|-------|-------------------|----------------|
| Lore / zones | Wrath names | Cata **mechanics** | Mechanics first OK |
| SP on all gear | Wrath-like | Int + weapon SP | Migrate plan later |
| Auto combat | Core | Keep | Non-negotiable |
| AGENTS wording | “WotLK fantasy” | Update when committing to Cata motor | `/init` after choice |

---

## Part 8 — Explicit non-proposals

- Defense rating on gear (removed in Cata).
- Second combat sim (SpatialCombat stays authority).
- Manual rotation as primary UX.
- Wowhead numbers in repo.
- Balance changes without CI gate.
- MoP+ systems.

---

## Appendix — Key code references

| Topic | File | ~Lines |
|-------|------|--------|
| Unified attack / armor | `lib/models/combat_ratings.dart` | 142–210, 263–268 |
| Ability damage | `lib/spatial/ability_effects.dart` | 481–605 passives, 1004–1047 |
| Incoming / block | `lib/spatial/spatial_combat.dart` | 1303–1387 |
| Kit definitions | `lib/models/class_ability.dart` | 623+ |
| Class audit template | `docs/CLASS_AUDIT_TEMPLATE.md` | — |
| Fairness gate | `test/class_balance_gate_test.dart` | — |

---

*Original audit 2026-08-22. Re-audit 2026-09-11 @ 1.12.136. Next re-run after Mp5 migration, Elemental Overload wiring, or major kit refactors.*
