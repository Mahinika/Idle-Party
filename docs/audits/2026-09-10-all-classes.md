# All-classes catalog audit

**Date:** 2026-09-10  
**Auditor:** agent (class-audit skill, catalog depth)  
**Depth:** catalog (code + share board; no A56 live meter)  
**Specs in scope:** all 31 `HeroSpecId` across 10 classes  
**Build / branch:** `main` @ 1.12.134 (Druid form pass landed same day)  
**Playtest?** code + `class_balance_gate_test` only  

**WotLK reference:** Wowhead Wrath guide *structure* only (role, rotation buckets, strengths). No tooltips, coeffs, talents, or BiS pasted.

## Summary

Idle Party’s **kits are broadly shippable**: every spec has 8–13 abilities in `ClassKits`, SpatialCombat is the single authority, masteries are wired (Eclipse/combo/Hot Streak/Arcane charges all have engine paths post-Druid fix), and the **full live DPS gate passes with no HIGH/LOW flags** (median share ~53%, band ±20%).

The **biggest class-wide gap** is still **silhouette honesty for “always-on form” fantasies** — but Druid’s P0 is **fixed in 1.12.134** (moonkin / cat / bear / tree PNGs). **Shadow Priest** is the other good reference (owned `shadow.png`). Every other spec reads as **tinted paper-doll** on one of four body families — fine for humanoid kits, muddy when three siblings share the same body at phone scale.

**Numbers watch (not gate failures):** Combat Rogue (~44% share), Fury / Ret / Frost DK (~43%) sit on the **low edge**; Shadow / Demo / Elemental (~60%) on the **high edge**. Trim only when you pick a balance batch — identity audit does not demand global retune.

## Audit DoD

- [x] Fantasy contract — 31 rows below
- [x] Reference-era notes per class (Wrath names; honest later splits)
- [x] Kit inventory (`ClassKits.forSpec` counts)
- [x] Form / unique sprite / companion matrix
- [x] Wiring smoke (Eclipse, combo, Hot Streak, Arcane charges, masteries)
- [x] Copy↔ability mismatches flagged
- [x] Live share board (`class_balance_gate_test`, 6 trials, sandy F5)
- [x] Per-class verdict + bullets
- [x] Ranked P0/P1 backlog (~15 items)
- [x] Composition fit
- [ ] A56 meter per spec (deferred — owner play)
- [x] Compared to prior audits

---

## Fantasy contract (31 specs)

| Spec | Role | Unlock | Body family | Unique sprite | Companion | Form / stance claim | 360×780? | Verdict |
|------|------|--------|-------------|---------------|-----------|---------------------|----------|---------|
| PROT | tank | starter | warrior | — | — | Defensive Stance passive | tint OK | **ship** |
| ARMS | melee DPS | zone1 / AL1 | warrior | — | — | Battle Stance passive | tint OK | **tune** |
| FURY | melee DPS | zone0 / AL2 | warrior | — | — | Berserker passive | tint OK | **tune** |
| HOLY (Pala) | healer | AL1 / 25e | healer | — | — | Illumination passive | tint OK | **ship** |
| PPal | tank | AL3 | warrior | — | — | Righteous Fury passive | tint OK | **ship** |
| RET | melee DPS | zone2 | warrior | — | — | Retribution Aura passive | tint OK | **tune** |
| BM | ranged DPS | AL2 | rogue | — | **Hunter Pet** | Beast Mastery passive | pet helps | **ship** |
| MM | ranged DPS | zone3 | rogue | — | — | Marksmanship passive | tint OK | **ship** |
| SV | ranged DPS | AL4 | rogue | — | — | Survivalist passive | tint OK | **ship** |
| ASSN | melee DPS | AL3 | rogue | — | — | Assassin's Grace passive | tint OK | **ship** |
| COM | melee DPS | Ascend | rogue | — | — | Combat Potency passive | tint OK | **tune** |
| SUB | melee DPS | zone4 | rogue | — | — | Shadow Dance = “stealth window” | tint OK | **tune** |
| DISC | healer | starter | healer | — | — | Atonement passive | tint OK | **ship** |
| HolyP | healer | AL2 | healer | — | — | Serendipity passive | tint OK | **ship** |
| Shdw | caster DPS | zone5 | mage | **shadow.png** | — | Shadowform passive | **yes** | **ship** |
| BLOOD | tank | AL5 | warrior | — | — | Blood Presence passive | tint OK | **ship** |
| Frost | melee DPS | AL5 | warrior | — | — | Frost Presence passive | tint OK | **tune** |
| Unhly | melee DPS | zone6 | warrior | — | **Ghoul** | Unholy Presence passive | ghoul helps | **ship** |
| ELE | caster DPS | AL4 | mage | — | — | Elemental Focus passive | tint OK | **ship** |
| ENH | melee DPS | AL4 | rogue | — | temp wolves | Enhancement passive | tint OK | **ship** |
| Resto (Sham) | healer | AL3 | healer | — | — | Restorative passive | tint OK | **ship** |
| ARC | caster DPS | AL2 | mage | — | — | Arcane Savant passive | tint OK | **ship** |
| FIRE | caster DPS | starter | mage | — | — | Hot Streak passive | tint OK | **ship** |
| FRST | caster DPS | AL3 | mage | — | — | Frostbite passive | tint OK | **ship** |
| AFF | caster DPS | AL6 | mage | — | — | Soul Siphon passive | tint OK | **ship** |
| DEMO | caster DPS | AL6 | mage | — | **Felguard** | Demonology passive | pet helps | **tune** |
| DESTRO | caster DPS | zone5 | mage | — | — | Destruction passive | tint OK | **ship** |
| BAL | caster DPS | AL4 | mage | **moonkin.png** | — | Moonkin Form passive | **yes** (1.12.134) | **tune** |
| FERAL | melee DPS | AL4 | rogue | **feral.png** | — | Cat Form passive | **yes** (1.12.134) | **tune** |
| GUARD | tank | AL5 | warrior | **guardian.png** | — | Bear Form passive | **yes** (1.12.134) | **tune** |
| Tree | healer | AL3 | healer | **tree.png** | — | Tree of Life passive | **yes** (1.12.134) | **tune** |

**Body families** map via `gearAffinity` → `BodyFamilyCatalog` (warrior / healer / mage / rogue undertunic + spec wash). **Unique sprites** bypass paper-doll + gear overlays (`CustomAssets.hasUniqueHeroSprite`).

**Companions** (permanent): BM pet, Demo felguard, Unholy ghoul (`spatial_combat.dart` companion rebuild). **Temporary:** Enhancement Feral Spirit, Unholy Army of the Dead (`kit_migrated_casts`).

---

## Kit inventory (ability rows per spec)

| Spec | Abilities | Maintain-DoT gates | Notes |
|------|----------:|-------------------:|-------|
| protection | 13 | 0 | Richest kit; starter tank |
| blood, guardian, subtlety | 10 | 1–2 | |
| affliction, assassination, balance, blood, demonology, destruction, elemental, fire, frostMage, fury, holyPaladin, shadow, survival | 9 | 0–3 | |
| arcane, beastMastery, combat, discipline, enhancement, frostDk, holyPriest, marksmanship, restorationDruid, restorationShaman, retribution, unholy | 8 | 0–2 | |

All specs include one **passive** row (`AbilityEffectKind.passive` → `_applyPassive` numerics). HUD chips come from unlocked non-passive abilities with `showInHud` / tier rules.

---

## Wiring smoke (identity-relevant)

| System | Specs | Status |
|--------|-------|--------|
| Eclipse buffs | Balance | **wired** — Wrath/Starfire set `eclipse_nature` / `eclipse_arcane` (1.12.134) |
| Combo points | Feral, Combat, Assn, Sub | **wired** — build/spend in `ability_effects` + HUD pips |
| Hot Streak | Fire | **wired** — `kit_migrated_casts` Pyro gate |
| Arcane charges | Arcane | **wired** — Blast build, Missiles dump |
| Mastery procs | Arms, MM, Combat, … | **wired** — `SpecMastery` + spatial auto-swing hooks |
| Shadow Dance “stealth” | Subtlety | **gap** — CD is `selfBuff` haste; no `vanishTimer`; meet hook says “stealth openers” |
| Vanish | Combat (and shared) | **wired** — `AbilityCustomId.vanish` |
| Companions | BM / Demo / Unholy | **wired** — pet actors + meter labels |
| Druid forms visual | All four Druid | **wired** — unique PNG path in dungeon + GEAR + HUD (1.12.134) |

No **dead mastery** paths found on post-1.12.134 Balance (Eclipse was the template bug).

---

## Live share board

**Source:** `class_balance_gate_test` (live, sandy F5, Prot+Disc party, 6 trials, AL0, L12). **Median DPS share:** 53.2%. **Gate:** no HIGH/LOW flags.

| Tier | Specs | Share% (approx) |
|------|-------|-----------------|
| High edge | shadow, demonology, elemental | 60–60 |
| Mid | frostMage, affliction, BM, SV, MM, arcane, feral, destruction, balance, assassination, fire | 50–58 |
| Low edge | unholy, arms, subtlety, enhancement, **combat**, fury, retribution, frostDk | 43–48 |

**Focused fast sim** (`share-fast` with `--focus=`) flags **LOW combat** (39%) and **HIGH demonology** (63%) on 2 trials — useful for trim targeting; **full gate still green**.

Tanks / healers are **not** on the DPS share board (qualitative: threat, H/s, triage — all wired in spatial AI).

---

## Composition fit

Default party **1 tank / 1 heal / 2 DPS** works across all classes. No spec forces a second tank or healer. **Overlap notes:**

- **Plate melee cluster** (Arms, Fury, Ret, Frost DK, Enhancement) — same body family + similar melee range; tints + ability VFX must carry identity.
- **Caster cloth cluster** (Fire, Frost, Arcane, three Warlocks) — bolt styles + maintain buckets differentiate; Shadow + Druid Balance break silhouette.
- **Hunter trio** — pet (BM) vs aimed (MM) vs traps (SV) reads clearly in guides + abilities.
- **Rogue trio** — poisons (Assn) vs blade flurry/combo (Com) vs shadow knives (Sub); Sub stealth copy is the weak link.

---

## Ranked backlog (pick next batch)

Identity and honesty first; number trims when you name a balance pass.

| # | Pri | Item | Class / spec |
|---|-----|------|----------------|
| 1 | P1 | A56 verify Druid form silhouettes + Eclipse floaters after 1.12.134 | Druid |
| 2 | P1 | Subtlety: Shadow Dance → vanish window **or** soften “stealth opener” copy / meet hook | Rogue |
| 3 | P1 | Combat Rogue share trim (~44%, focus sim LOW) | Rogue |
| 4 | P1 | Demonology share trim (~60%, focus sim HIGH) | Warlock |
| 5 | P1 | Melee plate low band: Fury / Ret / Frost DK gentle bump or arms-style proc tune | Warrior / Pala / DK |
| 6 | P2 | Warrior / Paladin sibling distinction at 360px (three tints, one body each) | Warrior, Paladin |
| 7 | P2 | Companion readability (pet / felguard / ghoul) at combat scale | BM, Demo, Unholy |
| 8 | P2 | Enhancement wolf temp summon VFX + meter clarity | Shaman |
| 9 | P2 | Optional Balance crumbs (Force of Nature) — identity not parity | Druid |
| 10 | P2 | Shadow Priest as template for future “owned silhouette” passes | Priest |
| 11 | P2 | Protection 13-ability HUD density — ensure chips stay readable | Warrior |
| 12 | P2 | `barkskinResto` AbilityId rename honesty | Druid Resto |
| 13 | P2 | Party MotW / raid utility — OK-to-drop unless owner wants buff meta | Druid |
| 14 | P2 | Form animation clips (walk/attack) for unique sprites — static PNG OK for idle? | Druid, Shadow |
| 15 | P2 | Re-run full class audit after next identity or balance batch | All |

**Done since Druid-only audit:** items 1 + Eclipse + combo + Guardian Swipe copy (1.12.134).

---

## Warrior

**Verdict:** **tune** (PROT **ship** as starter; Arms/Fury low-share edge)

- **PROT (13 abilities):** Shield Slam, Revenge, Shield Block, Shield Wall — tank buckets present; starter spec.
- **ARMS:** Sweeping Strikes / Bladestorm cleave; mastery extra swings wired; ~47% share.
- **FURY:** Rage fantasy; Bloodthirst / Recklessness; lowest warrior share ~43%.
- **Identity:** all three = warrior undertunic + wash; no form contract breach.
- **Pick next:** Fury/Arms band tune or PROT HUD density (P2).

---

## Paladin

**Verdict:** **ship**

- **HOLY:** Beacon / Holy Shock fantasy; plate healer distinct from priest cloth.
- **PPal:** Consecration + Holy Shield; mana tank — reads different from PROT rage.
- **RET:** Crusader Strike pressure; ~43% share (low edge, in band).
- **Identity:** tints on warrior/healer bodies; no false animal-form claims.

---

## Hunter

**Verdict:** **ship**

- **BM:** permanent pet (`Hunter Pet`); Kill Command synergy; ~56% share.
- **MM:** Aimed / Volley; Wild Quiver mastery proc wired.
- **SV:** Traps + Explosive Shot; shorter range in spec def.
- **Identity:** pet carries BM; MM/SV differentiated by range + abilities.

---

## Rogue

**Verdict:** **tune**

- **ASSN:** poisons + maintain gates; mid share.
- **COM:** Sinister → Eviscerate; **~44% share** (focus sim LOW); Main Gauche mastery wired.
- **SUB:** Fan of Knives + shadow bolts; **Shadow Dance ≠ stealth** (P1 honesty).
- **Identity:** rogue body + strong washes; no unique sprites.

---

## Priest

**Verdict:** **ship**

- **DISC:** shields + Penance — starter healer.
- **HolyP:** circle / renew wave heals.
- **Shdw:** **owned shadow sprite** + Shadowform; top share ~60% but in band.
- **Identity:** Shadow is the gold standard for spec silhouette; Disc/Holy share healer body.

---

## Death Knight

**Verdict:** **tune** (Blood **ship**; Frost low edge)

- **BLOOD:** self-heal tank; Blood Shield mastery; diseases maintain.
- **Frost:** Hungering Cold / icy pressure; ~43% share.
- **Unholy:** ghoul companion + diseases; Army of the Dead temp summon.
- **Identity:** shared DK class art + washes; ghoul sells Unholy.

---

## Shaman

**Verdict:** **ship**

- **ELE:** Lightning / Lava Burst; ~60% share high edge.
- **ENH:** melee Stormstrike; Feral Spirit temp wolves (`AbilityCustomId.feralSpirit`).
- **Resto:** Riptide / Chain Heal; mail healer body.
- **Identity:** elemental bolts vs enh melee; no form lies.

---

## Mage

**Verdict:** **ship**

- **ARC:** Arcane Blast charges → Missiles dump wired.
- **FIRE:** Hot Streak → Pyro; starter caster; median share.
- **FRST:** freeze / shatter; Frostburn mastery on rooted targets.
- **Identity:** cloth mage body + bolt styles; all humanoid — OK.

---

## Warlock

**Verdict:** **tune** (Demo high edge)

- **AFF:** multi-DoT maintain gates; solid mid-high share.
- **DEMO:** Felguard companion; **~60% share** (focus sim HIGH).
- **DESTRO:** Chaos Bolt nukes; zone5 unlock.
- **Identity:** felguard sells Demo; cloth caster body otherwise.

---

## Druid

**Verdict:** **tune** (identity **much improved** vs morning audit)

- **Status:** 1.12.134 shipped moonkin / feral / guardian / tree PNGs; Insect Swarm; Eclipse; Feral combo → Bite; Guardian Swipe copy.
- **Re-check:** A56 form read + Solar/Lunar floaters; optional art polish / walk clips.
- **Detail:** see [2026-09-10-druid.md](2026-09-10-druid.md).

---

## Player pitches (roster one-liners)

| Spec | Pitch |
|------|-------|
| PROT | Hold the line — Shield Slam and Revenge. |
| ARMS | Cleave the pack — Bladestorm windows. |
| FURY | Rage forever — Bloodthirst spam. |
| HOLY / HolyP / Tree / Resto / DISC | Keep everyone alive — shields or HoTs. |
| PPal / BLOOD / GUARD | Consecrated or bear/thrash threat. |
| RET | Crusader strikes up close. |
| BM | Your pet fights with you. |
| MM | Aimed shots from the back. |
| SV | Traps and explosives. |
| ASSN / COM / SUB | Poisons, blades, or shadow knives. |
| Shdw | Void DoTs from a shadow body. |
| Frost / Unhly | Ice pressure or disease + ghoul. |
| ELE / ENH | Lightning bursts or stormstrike melee. |
| ARC / FIRE / FRST | Arcane charges, Hot Streak pyros, or shatter. |
| AFF / DEMO / DESTRO | Curses, felguard, or chaos bolts. |
| BAL / FERAL | Stars from moonkin or cat bleeds. |

---

## Compared to previous audits

| Prior | Delta |
|-------|-------|
| [2026-09-10-druid.md](2026-09-10-druid.md) | Druid P0 forms **fixed** same day (1.12.134); this master catalogues all classes |
| [2026-08-22-class-combat-cata.md](2026-08-22-class-combat-cata.md) | Cata *mechanics* gap list still valid; **SpecMastery** layer now exists — not re-audited here |

---

## Out of scope / follow-ups

- Per-spec Wowhead deep sheets (31×) — use template when fixing one class
- Global DPS retune without owner pick
- New zones / classes / specs
- A56 live meter for all 31
- BiS / talents / glyphs

**Next owner pick:** one class **fix batch** (like Druid A+B+C) from backlog #1–5.
