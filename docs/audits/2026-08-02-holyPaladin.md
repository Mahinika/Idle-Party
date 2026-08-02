# Class audit report — Holy Paladin

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid-band sim from `tool/out`)  
**Specs in scope:** `holyPaladin`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid healer table (Prot+Fire · F5); no fresh browser pass  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Holy Paladin is **recognizable as a plate ST healer** (Holy Light / Shock / Flash / Sacred Shield / LoH) on the shared kit runner, but Beacon is a **self haste buff** (not tank maintain + transfer), LoH copy claims party top while resolving as **single-ally** `emergencyHeal`, and mid clear% is volatile/weak in the latest sweep. Biggest gap: Beacon identity + fake “party” emergency vs true tank-heal fantasy. Verdict: **tune**.

## Audit DoD

- [x] Wowhead links filled (or N/A + reason)
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Heal triage
- [x] Gear / armor fantasy
- [x] Unlock / roster / PARTY / copy
- [x] Multi-chamber + boss (same runner; signature gate noted)
- [x] Offline path (AbilityEffectRunner — same as live)
- [x] Assets + VFX (code paths)
- [x] A11y spot-check (chips/shortLabels)
- [x] Identity score + verdict
- [x] All P0 listed
- [x] Live meter notes (mid sim)
- [x] Tunings proposed (Idle fields only)
- [x] Pet N/A
- [x] Composition / modes / save / perf / pitch

---

### `HeroSpecId.holyPaladin` — HOLY

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** healer  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | https://www.wowhead.com/wotlk/guide/classes/paladin/holy/healer-pve-guide (JS-thin; used Wrath HPal identity + Icy Veins/Tavern structure) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/paladin/holy/healer-rotation-cooldowns-abilities-pve | y (structure) |
| Talents / builds (identity only) | skipped | n |

Patch note on guide family: 3.4.x Wrath Classic

#### 1. Overview — strengths & weaknesses *(Wowhead-style)*

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Plate tank healer: Beacon + Holy Light spam, Hands, Favor | Plate mana backliner with big ST heals + LoH panic | partial |
| Role job | Keep tank up; splash via Beacon/Glyph HL | `SpecRoleTag.healer`; meter H | clear job muddy mid |
| **Strengths** | Beacon transfer; Holy Light throughput; Hands / Favor / AW kit | Holy Light / Shock / Flash / Sacred Shield / LoH present | Beacon **missing** as transfer |
| **Weaknesses** | Weak pure raid AoE; low mobility | No real multi-target heal path (shared runner) | weakness **still true** / amplified |
| Party utility | Blessings / auras / Hands | Devotion passive heal mul only | partial |

**WotLK identity score:** **3 / 5**  
(Looks Holy; Beacon fantasy broken.)

**Player pitch (one line):**  
> Plate tank-healer — Shock and Holy Light the lowest ally, bubble them, and LoH when someone is about to die.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Holy Light, Flash of Light | Holy Light, Flash of Light, Holy Shock | present |
| **Maintain / DoT / buff** | Beacon, Sacred Shield, Judgement uptime | Sacred Shield absorb; Beacon = self haste | Beacon **wrong** |
| **Finisher / dump** | — | — | N/A |
| **AoE / cleave** | Glyph Holy Light splash | none (single-target heals only) | missing |
| **Offensive CD / burst** | Avenging Wrath / Divine Favor | Divine Favor (self haste) | weak / wrong feel |
| **Defensive / emergency** | Lay on Hands, Hands | Lay on Hands | present (ST only) |
| **Control / kite** | — | N/A | N/A |
| **Raid / party utility** | Blessings, auras | Devotion passive | weak |
| **Proc / reaction** | Illumination / FoL haste | none | missing (OK-to-drop) |

**Must-keep for idle:** Beacon-on-tank (or transfer feel), Holy Light, Sacred Shield, LoH.  
**OK-to-drop:** Judgement weaving, Divine Plea windows, Light’s Grace stacks, opener checklist.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | healer / `HeroRole.healer` — OK |
| Resource + regen | mana via rage pool; kit regen ~9/s + spirit/mp5 |
| Resource edge cases | can starve on HL spam — OK, not soft-lock |
| Kit path | **AbilityEffectRunner** `_tickSpecKit` (not legacy) |
| Baseline AA / `kitOutMul` | Devotion → `kitHealMul *= 1.32` |
| Unlock curve | L1 Aura … L15 LoH |
| Wiring overall | OK cast path; **identity gaps** on Beacon / party LoH |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| holyLightAura | 1 | passive | 0 | 0 | runner passive | no | Devotion-style | maintain | heal mul |
| holyShock | 3 | filler | 6 | 18 | runner heal | yes | Holy Shock | ST | heal-only (OK idle) |
| flashOfLight | 5 | filler | 4.5 | 16 | runner heal | yes | Flash of Light | ST | triage `<92%` |
| sacredShield | 7 | filler | 8 | 20 | runner absorb | yes | Sacred Shield | maintain | absorb gate |
| holyLight | 9 | filler | 7 | 28 | runner heal | yes | Holy Light | ST | highest-cost filler |
| beaconOfLight | 11 | filler | 30 | 15 | runner **selfBuff** | yes | Beacon of Light | maintain | **P0** haste, not transfer |
| divineFavor | 13 | signature | 40 | 10 | runner selfBuff | yes | Divine Favor | CD | haste via PI timer; long-CD gate |
| layOnHands | 15 | emergency | 60 | 0 | runner emergencyHeal | yes | Lay on Hands | def | copy says party; **ST only** |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| `preferredRange` / `attackRange` | caster backline | 3.0 / 3.8 | ok |
| Kite / blink / charge | N/A Holy | none | N/A |
| Target selection | lowest ally for heals | `_lowestAlly` | ok |
| Pack vs single | ST tank heal fantasy | always ST | ok for fantasy / weak for packs |
| Tank threat | N/A | — | N/A |
| Healer triage | lowest + emergency; no full-HP spam | heal `<92%`; absorb gates; LoH on ≤32% | ok |
| DPS focus | don’t park dormant | focus via `_pickSmartFocus` | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| `armorTypes` / gear fantasy | plate (`_plate`) | ok |
| Unlock path | AL≥1 or 25 essence; hint “Spend 25e in Prestige Shop” | ok |
| Roster / PARTY UI | selectable when unlocked | ok |
| `shortLabel` / meter tag | HOLY | ok |
| Ability chip copy | Shock / Flash / SShield / Light / Beacon / Favor / LoH | ok |
| Guides / Codex / tips | not called out like starter Disc | N/A / thin |

#### 6. Content contexts

| Context | What to watch | Status |
|---------|---------------|--------|
| Multi-chamber wake | heals on newly damaged tank | ok (same runner) |
| Boss floor | Favor/LoH readable | **weak** — long sig gated unless elite/pack/execute |
| Offline / AFK spatial | kit runner + reducedVfx | ok |
| Wipe / revive | LoH / fillers resume | ok |
| **FARM** | identity readable | ok / clear% volatile |
| **PUSH** | mid Prot+Fire table | **weak clear** in latest |
| **Challenges** | not re-swept | N/A |
| **Save / migrate** | forSpec kit; unlocks in metaDepth | ok |
| **Perf** | heal sparks/rings mild | ok |

#### 7. Pet / guardian

N/A

#### 8. Live read *(mid · Prot+Fire · F5 · `tool/out/class_balance_latest.md`)*

| Signal | Observed |
|--------|----------|
| Meter (clear / wipe / partyHP) | **17% / 83% / 100%** (surviving clears healthy) |
| Buckets that fire | ST heals + absorb when hurt; LoH on crit |
| Buckets that never fire | true Beacon transfer; party LoH |
| Resource | mana spend on HL/Shock OK |
| Range / AI | backline OK |
| Role red flags | clear% far below Holy Priest (58%) same table; older `mid_final` showed HPal strong — **sim noise**, but Beacon wiring is hard fact |

#### 9. Assets & VFX

| Surface | Path / check | Status | Notes |
|---------|--------------|--------|-------|
| Hero body | `CustomAssets.heroPaladin` | ok | plate paladin |
| Spec vs Prot/Ret | same class sprite | muddy | HOLY chip distinguishes |
| Ability HUD chips | shortLabels | ok | |
| Auto-attack bolt | `SpellBoltStyle.holy` | ok | |
| Signature / CD burst | Favor ring / LoH heal spark | ok / weak | Favor = haste, not crit-heal fantasy |
| Maintain telegraphs | Sacred Shield absorb ring | ok | Beacon no tank mark |
| AoE telegraph | none | N/A | |
| Emergency VFX | LoH heal floater | ok | |
| `reducedVfx` | announce skipped; sparks may drop | ok | |
| Audio | N/A | N/A | |

**On-screen (full):** Holy Light / Shock / Sacred Shield should read holy; Beacon does **not** read as Beacon.

**A11y / readability:** HOLY + chips OK at phone scale. Status: ok

**Asset / VFX findings**

- P0: none (art OK)
- P1: Beacon needs a maintain telegraph on the buffed ally (tank), not self haste ring
- P2: distinguish Holy vs Prot paladin silhouette later

#### 10. Findings

- **P0:** Rewire `beaconOfLight` from self haste to **tank-maintain** (absorb or heal-redirect feel); stop spending filler GCDs on PI-haste named Beacon
- **P0:** `layOnHands` copy says full-party top but is single-target — either splash all allies or fix copy (shared “party heal is ST” runner debt)
- **P1:** Divine Favor should amplify next heal(s), not only haste timer; long-CD signature gate blocks Favor on trash
- **P1:** Mid clear% consistency (re-sim after Disc buff @ `851c72b`; latest table may predate it)
- **P2:** Blessings / aura fantasy beyond Devotion passive; Judgement-of-Light optional skip

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Spec's job in that party | ST tank healer | clear fantasy / muddy mid numbers |
| Overlap with Disc | Disc = absorb/Penance; Holy = throughput | ok if Beacon fixed |
| Hole if missing | party soft without another heal | covered by Disc/HPriest when tuned |
| Synergy | none unique yet | none |

## Cross-party balance

| Spec | Meter | vs peers | vs WotLK role | Range/AI | Modes (F/P/C) | Perf | Verdict |
|------|-------|----------|---------------|----------|---------------|------|---------|
| holyPaladin | mid clear 17% / HP 100% | under clear | ST healer OK | ok | weak mid clear | ok | **tune** |

**Player pitches (roster):**

| Spec | Pitch one-liner |
|------|-----------------|
| holyPaladin | Plate tank-healer — Shock and Holy Light the lowest ally, bubble them, and LoH when someone is about to die. |

## P0 / P1 backlog

1. **P0** Beacon → tank maintain / transfer fantasy (not self haste)
2. **P0** LoH party claim vs ST resolve (fix effect or copy)
3. **P1** Favor heal-amp + healer-friendly CD gate
4. **P1** Re-run mid healer sweep post-Disc commit

## Proposed tunings

| Spec | Ability / field | From → To | Why (idle feel + WotLK bucket) |
|------|-----------------|-----------|--------------------------------|
| holyPaladin | beaconOfLight.effect | selfBuff → absorb or heal-mark on tank | Must-keep Beacon bucket |
| holyPaladin | layOnHands | ST emergencyHeal → heal all injured allies *or* rewrite description | Match copy / Hands fantasy |
| holyPaladin | divineFavor | haste-only → short healMul window | Favor identity |

## Explicitly out of scope

BiS / gems / enchants / consumables / phase gear / PvP / talent calculators / glyph spreadsheets / raw stat weights.

## Test gaps

- [ ] Beacon transfer / maintain unit test
- [ ] LoH multi-ally cast
- [ ] Mid healer re-sim after Disc @ 851c72b
- [ ] Offline HOLY cast smoke
- [ ] Guide blurb for Prestige unlock

## Compared to previous audit

**Previous:** none for HOLY · **Delta:** first full sheet; Disc mid buff is peer context

## Out of scope / follow-ups

- Global healer runner “party heal” kind (helps Hymn / Chain / WG too)
- Avenging Wrath as separate offensive CD
