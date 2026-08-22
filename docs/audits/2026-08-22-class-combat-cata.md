# Class & combat audit — Cataclysm reference

**Date:** 2026-08-22  
**Auditor:** Cursor agent (senior combat/class pass)  
**Depth:** full (systems) + quick (27 specs) + deep (4 stickprov)  
**Specs in scope:** all 31 `HeroSpecId`  
**Playtest:** no (code + public Cata facts only)  
**Build / branch:** working tree ~1.12.41  

**Reference expansion:** **Cataclysm 4.0–4.3** (patch 4.0.1 stat overhaul, Mastery, block redesign).  
**Product note:** Idle Party **lore/copy** still reads Wrath (zones, AGENTS). This audit compares **combat mechanics** to Cata — not a zone rebrand request.

**Legal:** Wowhead / wiki used for **structure + identity** only. No tooltip coefficients, talent point spreads, or BiS pasted here (`AGENTS.md`).

---

## Executive summary

Idle Party ships **31 Wrath-named specs** with a **pre-Cata combat motor**: one unified `attack` pool, instant AI-driven abilities, percent-armor mitigation, and timed defensive windows. Kit **identity** (Hot Streak, Shield Block + Revenge, Penance bolts, etc.) is often strong; **stat/combat systems** lag Cataclysm on almost every axis the owner asked about.

| Question | Cata had it? | Idle today | Verdict |
|----------|--------------|------------|---------|
| Spells (named + schools) | Yes | Named yes; **melee/spell split no** | **Add pipeline split**, not 200 new rows |
| Cast time | Yes (+ haste on cast) | Instant + projectile stagger | **Add signature cast delays + haste** |
| Diminishing returns | Yes (dodge/parry + CC) | DR CDs only; no avoidance/CC DR | **Add for tanks + CC** |
| Mastery | **Yes (Cata core)** | `kitOutMul` passives only | **P0 — 31 spec hooks + gear secondary** |
| Ability damage formula | AP / SP × coeff | `attack × coeff × kitMul` | **P0 split pools** |
| Tank avoidance | Dodge/parry/block via mastery | Armor + timed block window | **P0 mastery block + dodge/parry** |

**Biggest gap:** no **Mastery** layer and no **proc avoidance** — tanks are armor + cooldown sponges, not Cata Prot profiles.

**Biggest strength:** `ClassAbilityDef` + `AbilityEffectRunner` + gates already mirror Cata **rotation shape** as auto-AI — good foundation for Cata mechanics without manual cast bars.

---

## Audit DoD

- [x] Cata combat facts summarized with external sources
- [x] Idle combat path documented with file references
- [x] Six owner questions answered (Ja/Nej/Alternativ)
- [x] Four stickprov specs: Protection Warrior, Protection Paladin, Fire Mage, Restoration Shaman
- [x] 27-spec quick table (Cata mastery name + identity score + top gap)
- [x] P0/P1/P2 roadmap (implementation deferred — report only)
- [x] Medveten Wrath-lore vs Cata-mechanics avgränsning

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

## Part 2 — Idle Party combat path (today)

### Data flow

```
PartyHero + gear
  → CombatRatings.fromHeroSheet (lib/models/combat_ratings.dart)
  → GameState.effectiveHeroAttack / ratingsFor (lib/core/game_state.dart)
  → SpatialCombat.build → SpatialActor (attack, defense, blockValue, spirit regen)
  → AbilityEffectRunner._tickSpecKit (lib/spatial/ability_effects.dart)
  → _castDamage: attack × coeff × kitOutMul × casterTax
  → CombatRatings.mitigateByArmor (both directions)
  → _applyHeroIncomingDamage (DR timers, block window, absorb)
```

### Ability damage (authoritative)

```dart
// ability_effects.dart ~1012–1014
raw = max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
```

- Caster tax: `SpatialCombat.casterAbilityTax` (0.92) for `SpecRoleTag.caster`.
- White hits: separate path in `spatial_combat.dart` ~3437+ with crit roll on autos only.
- Fireball: **hardcoded 28% crit** in `kit_migrated_casts.dart` — not sheet spell crit.

### Sheet stats vs combat

| Stat | On sheet | Combat use today |
|------|----------|------------------|
| Str / Agi | Yes | AP → physical `attack` |
| Int / SP | Yes | Caster `attack` (~Int full + gear Int/SP ÷3) — **unified pool** |
| Armor | Yes → DEF | Percent mitigation |
| Agi | Yes | **DEF crumb** (`agi/8`), not dodge % |
| Crit / Haste | Gear + forge | Crit mostly **auto-attacks**; haste **swing speed only** |
| Spirit | Yes | Flat regen `1.25 + Spirit×0.06`/s — **no 5SR** (`combat_ratings.dart` ~263–268) |
| Mp5 | Gear | `mp5/5` mana/s — **Cata removed Mp5 from gear** |
| Mastery | **No** | Approximated by per-spec `kitOutMul` / `kitHealMul` passives |

### Cast / resource model

- **No GCD, no cast bar, no interrupts.**
- Cooldowns: wall-clock seconds per ability id.
- Resources: single `SpatialActor.rage` 0–100 holds rage/mana/energy/runic.
- “Channels”: projectile delay only (Penance, Chain Lightning hops).
- AI priority: emergency → taunt → signature → filler (`ability_effects.dart` ~324–430).

### Incoming damage (tanks)

```dart
// spatial_combat.dart ~1322–1339 — no dodge/parry roll
mul = kitInMul;
if (shieldWallTimer) mul *= 0.45;
if (painSuppressionTimer) mul *= 0.55;
if (shieldBlockTimer) { mul *= 0.55; blocked = true; }
dealt = max(1, (rawDamage * mul).round());
if (blocked) dealt = max(1, dealt - blockValue); // Str/20
```

- Block is **active window**, not mastery proc chance.
- No crits vs tanks modeled (Cata: uncrittable by role — **partial match**).

### CC

- Single `rootTimer` — refresh without category DR.
- “DR” in ability names = **damage reduction**, not CC diminishing.

---

## Part 3 — Answers to six questions (Cata-tung)

### 1. Ska vi lägga till spells?

| | Recommendation |
|--|----------------|
| **Ja** | Split **physical vs spell** damage; tag `damageSchool` on `ClassAbilityDef`. |
| **Ja** | Keep named abilities — Cata removed **ranks**, not identities. |
| **Nej** | Don't add hundreds of manual spell rows. |
| **Behåll** | Auto-AI rotation — Cata priority as gates, not player cast bar. |

### 2. Cast time?

| | Recommendation |
|--|----------------|
| **Ja** | Signature delays (Fireball, Healing Wave, Pyro) 0.8–2.5s + “Casting…” chip. |
| **Ja** | **Haste reduces cast delay** (Cata gap — haste today = autos only). |
| **Nej** | Boss interrupt / pushback PvE on phone idle. |
| **Bevis** | Penance stagger already works (`kit_migrated_casts.dart`). |

### 3. Diminishing returns?

| Type | Recommendation |
|------|----------------|
| Dodge/Parry rating → % | **Ja** (with DR curve) |
| Mastery rating → effect | **Ja** |
| Crit/Haste high stacks | **P2** — keep 75% crit cap as idle simplification if needed |
| CC (root/stun) | **Ja** per category |
| DR cooldowns | Document current multiplicative windows; tune later |

### 4. Stats som Mastery?

| | Recommendation |
|--|----------------|
| **Ja — P0** | One **Mastery effect per spec** (31), combat hook + name in UI. |
| **Ja** | Secondary **Mastery budget** on gear (like Crit/Haste), not BiS score crumb. |
| **Nej** | Same % bonus for all specs. |
| **Bridge** | Today’s `kitOutMul` passives = **baseline mastery**; rating adds scaling on top. |

**Important:** Mastery is **Cataclysm**, not Wrath. Adding it aligns with **this audit**, not with current AGENTS “WotLK fantasy” wording — product should pick “Cata mechanics / Wrath skin” explicitly.

### 5. Hur bestäms ability damage?

**Today:** `attack × coeff × kitMul`.

**Cata target:**

```
melee  = f(AP, coeff, mastery?)
spell  = f(spellPower_from_Int, spellCoeff, mastery?)
heal   = f(SP, coeff, DeepHealing?, kitHealMul)
DoT    = snapshot/refresh rules; Fire mastery amplifies periodic portion
```

**P0:** Split pools in `combat_ratings.dart`; extend `_castDamage` inputs — keep SpatialCombat sole authority.

### 6. Avoidance för tanks?

| Layer | Cata | Idle | Rec |
|-------|------|------|-----|
| Uncrittable | Stance/presence | Implicit | **Formalize tank flag** |
| Armor | Yes | Yes | Keep |
| Dodge/Parry | Rating + DR | Missing | **Add** |
| Block | Mastery chance, −30% dmg | Timed Shield Block only | **Add passive proc + keep CD** |
| Active DR | Yes | Yes | Keep overlay |

```
incomingMelee → crit? → dodge/parry? → block(−30%)? → armor → DR CDs → absorb
```

**Agi:** should feed **dodge**, not DEF crumb — avoid double dip.

---

## Part 4 — Stickprov (full depth)

Wowhead reference family: **Cataclysm Classic** class guides (structure only).

### `HeroSpecId.protection` — Protection Warrior

**Verdict:** tune (identity strong, Cata tank motor weak)  
**Cata Mastery:** Critical Block (+ block chance + critical block chance)  
**Idle equivalent:** `shieldBlockTimer` + `blockValue` + Revenge on block — **no passive block %**

| Bucket | Cata fantasy | Idle ability | Wired? |
|--------|--------------|--------------|--------|
| Maintain | Sunder stacks | Devastate | yes |
| AoE threat | Thunder Clap, Shockwave | Thunder Clap, Shockwave | yes |
| Block CD | Shield Block | Shield Block | yes — **timed DR**, not Cata proc |
| Emergency | Last Stand, Shield Wall | Last Stand, Shield Wall | yes |
| Signature | Shockwave cone | Shockwave | yes |
| Passive stance | Defensive Stance | Defensive Stance | yes — `kitInMul` |

**Mastery gap:** no Critical Block scaling; no crit-block; block not −30% Cata rule.

**Avoidance gap:** no dodge/parry tables.

**WotLK identity score (kit names):** 4/5  
**Cata mechanics score:** 2/5  

**Player pitch:** “Hold the pack, clap slows, block then revenge” — **matches feel**; **doesn’t match Cata mitigation math**.

---

### `HeroSpecId.protPaladin` — Protection Paladin

**Verdict:** tune  
**Cata Mastery:** Divine Bulwark (+ block chance)  
**Idle equivalent:** Holy Shield → `AbilitySelfBuffKind.block` sets block timer (`ability_effects.dart`)

| Bucket | Cata | Idle |
|--------|------|------|
| Ranged pull | Avenger's Shield | Avenger's Shield | yes |
| Block buff | Holy Shield | Holy Shield | yes — active window |
| AoE | HotR, Consecration | HotR, Consecration | yes |
| Single target | Shield of Righteousness | SoR | yes |
| Taunt | Hand of Reckoning | HoR | yes |
| Passive | Righteous Fury | Righteous Fury | yes — threat + `kitInMul` |

**Mastery gap:** Divine Bulwark should raise **passive block chance**, not only Holy Shield window.

**Cata note:** Consecration + mastery reduced damage while standing in it (later expansions changed) — optional P2 flavor.

**Cata mechanics score:** 2/5  

---

### `HeroSpecId.fire` — Fire Mage

**Verdict:** tune (best Cata proc analog in repo)  
**Cata Mastery:** Increases **periodic fire damage** (Ignite / DoT theme)  
**Idle equivalent:** Living Bomb + Combustion amp; **no mastery scaling on DoT ticks**

| Bucket | Cata | Idle |
|--------|------|------|
| ST filler | Fireball | Fireball | yes — instant, 28% hardcoded crit |
| DoT / spread | Living Bomb, Ignite | Living Bomb | partial — no Ignite mastery chain |
| Proc | Hot Streak → Pyro | Hot Streak → Pyro | **strong** |
| AoE | Blast Wave, Flamestrike | Blast Wave | partial |
| CD | Combustion | Combustion | yes — `combustionTimer` ×1.22 |
| Control | Frost Nova | Frost Nova | yes — **no CC DR** |

**Cast gap:** Fireball/Pyro should have cast delay; haste should shrink it.

**Damage gap:** all fire uses unified `attack`; Cata wants SP + **DoT mastery**.

**Cata mechanics score:** 3/5 (best of stickprov)  

---

### `HeroSpecId.restorationShaman` — Restoration Shaman

**Verdict:** tune  
**Cata Mastery:** Deep Healing (+ healing to low-HP targets)  
**Idle equivalent:** `ancestralAwakening` passive → flat `kitHealMul × 1.32` — **not missing-HP scaling**

| Bucket | Cata | Idle |
|--------|------|------|
| HoT | Riptide | Riptide | yes |
| ST heal | Healing Wave | Healing Wave | yes |
| Chain | Chain Heal | Chain Heal | yes |
| Absorb | Earth Shield | Earth Shield | yes |
| AoE | Healing Rain | Healing Rain | yes |
| Signature | Spirit Link | Spirit Link | yes |
| Passive amp | Ancestral Awakening | Ancestral Awakening | flat mul only |

**Mana gap:** Spirit flat regen + **Mp5 still on Idle gear** — opposite of Cata (Spirit-only).

**Mastery gap:** Deep Healing should scale heal coeff by target missing HP %.

**Cata mechanics score:** 2/5  

---

## Part 5 — All 31 specs (quick pass)

Identity score = **Cata mechanics + kit names** (1 wrong · 3 recognizable · 5 nails).  
Top gap = single highest-impact missing Cata system for that spec.

| Spec | Cata Mastery (reference name) | Idle passive / analog | Score | Top gap |
|------|------------------------------|------------------------|-------|---------|
| arms | Strikes of Opportunity | `armsStance` kitOutMul | 3 | No extra attack proc |
| fury | Unshackled Fury | `berserkerStance` | 3 | Enrage mastery shape |
| protection | Critical Block | Shield Block window | 2 | Passive block + crit block |
| holyPaladin | Illuminated Healing | heal passives | 2 | Absorb-on-heal mastery |
| protPaladin | Divine Bulwark | Holy Shield block buff | 2 | Passive block chance |
| retribution | Hand of Light | `sealOfCommand` | 3 | Holy strike bonus split |
| beastMastery | Master of Beasts | pet + `aspectOfHawk` | 3 | Pet damage mastery scale |
| marksmanship | Wild Quiver | `trueshotAura` | 3 | Extra shot proc |
| survival | Hunter vs Wild | `trapMastery` | 3 | Stamina/pet link |
| assassination | Master Poisoner | `improvedPoisons` | 3 | Poison dmg mastery |
| combat | Main Gauche | `masterOfSubtlety`/combo | 3 | Off-hand proc |
| subtlety | Executioner | stealth passives | 3 | Execute-phase mastery |
| discipline | Shield Discipline | absorb kit | 2 | Shield strength mastery |
| holyPriest | Echo of Light | `spiritOfRedemption` | 2 | HoT-on-heal mastery |
| shadow | Empowered Shadow | dot passives | 3 | Periodic shadow mastery |
| blood | Blood Shield | `bloodPresence` | 2 | DS absorb mastery |
| frostDk | Frozen Power | `frostPresence` | 3 | Frozen target bonus |
| unholy | Dreadblade | `unholyPresence` + ghoul | 3 | Shadow dmg mastery |
| elemental | Elemental Overload | overload-ish procs | 3 | Duplicate cast proc |
| enhancement | Enhanced Elements | `enhancementWeapons` | 3 | Elemental dmg mastery |
| restorationShaman | Deep Healing | `ancestralAwakening` | 2 | Missing-HP heal scale |
| arcane | Mana Adept | arcane charge kit | 3 | Mana→dmg mastery |
| fire | Fire periodic dmg | Hot Streak + Bomb | 3 | DoT mastery on ticks |
| frostMage | Frostburn | shatter on root | 3 | Frozen dmg mastery |
| affliction | Potent Afflictions | dot stack kit | 3 | DoT dmg mastery |
| demonology | Master Demonologist | pet/meta | 3 | Demon dmg mastery |
| destruction | Flashburn | chaos bolt tier | 3 | Direct fire mastery |
| balance | Eclipse | eclipse-style buffs | 3 | Arcane/nature swap mastery |
| feral | Razor Claws | `catForm` | 3 | Bleed mastery |
| guardian | Savage Defense | `bearForm` | 2 | Absorb on hit mastery |
| restorationDruid | Harmony | `treeOfLife` | 2 | HoT amp mastery |

**Pattern:** melee/caster DPS score **3** (passives approximate shape); **tanks/healers 2** (avoidance + mastery + mana model gaps).

---

## Part 6 — Recommended roadmap (if building Cata layer)

Report-only — no implementation in this batch.

| Prio | System | Why |
|------|--------|-----|
| **P0** | Mastery per spec (hook + gear secondary) | Defines Cata identity |
| **P0** | Melee vs spell + Int→SP sheet | Caster/tank split |
| **P0** | Tank dodge/parry + mastery block (−30%) + uncrittable | Prot fantasy |
| **P1** | Cast delay + haste-on-cast | Caster/healer gear meaning |
| **P1** | CC diminishing | Multi-chamber fairness |
| **P1** | Spirit 5SR; remove Mp5 from new loot | Healer Cata mana |
| **P2** | Hit/expertise (simplified PvE) | Gear chase |
| **P2** | Ability crit from rating | Hot Streak honesty |
| **P2** | Reforge-like hub meta | Stat targeting without NPC |
| **Skip** | Full GCD + interrupt | Phone idle |
| **Skip** | Defense rating | Not Cata |
| **Skip** | Resilience | PvE irrelevant |
| **Skip** | MoP+ talent/prune systems | Scope |

**Fairness:** every P0 batch runs `class_balance_gate_test` — mastery must change **shape**, not +50% raw ATK.

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

*End of audit — 2026-08-22. Re-run when implementing Cata combat v2 (see Part 10 slices) or after major kit refactors.*
