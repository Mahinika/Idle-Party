# Class audit report — Protection Paladin

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only)  
**Specs in scope:** `protPaladin`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** no — code + prior tank-kit patterns; no fresh live meter pass

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients / tooltips / BiS.

## Summary

Prot Paladin is a **recognizable holy plate tank** on the shared kit runner: Righteous Fury passive, Avenger’s Shield / SoR ST, HotR / Consecration / Holy Wrath AoE, Divine Protection + taunt (Hand of Reckoning). Biggest gap: **Holy Shield is emergency-only** (fires when HP low) instead of a must-keep maintain, so the Wrath “keep HS up” beat is missing and the two DR CDs feel stacked.

## Audit DoD

- [x] Wowhead links filled (or N/A + reason)
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Threat / taunt
- [x] Gear / armor fantasy
- [x] Unlock / roster / PARTY / copy
- [x] Multi-chamber + boss (code)
- [x] Offline path (shared runner — assumed OK; no dedicated PPROT offline test)
- [x] Assets + VFX (code paths)
- [x] A11y spot-check (chips/labels present; not re-shot live)
- [x] Identity score + verdict
- [x] All P0 listed (none)
- [x] Live meter notes (N/A this run — code inference)
- [x] Tunings concrete if proposed
- [x] Pet N/A
- [x] Composition / modes / save / perf / pitch

---

### `HeroSpecId.protPaladin` — PPROT

**Verdict:** tune  
**Depth:** full (code-primary)  
**Wowhead role page family:** tank  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | https://www.wowhead.com/wotlk/guide/classes/paladin/protection/tank-overview-pve | y (JS-thin; patch 3.4.3 noted) |
| Rotation / cooldowns / abilities | Wowhead Prot Pala rotation URL + Icy Veins / Warcraft Tavern bucket names | y |
| Talents / builds (identity only) | skipped (point spreads) | n |
| Other | Icy Veins / Warcraft Tavern Prot Pala rotation summaries | y |

Patch note on Wowhead page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Holy plate shield tank: Holy Shield uptime, strong AoE threat, mana care | Plate mana tank with holy AoE + DR CDs | partial |
| Role job | Main / offtank; ST + pack pull | `SpecRoleTag.tank`, meter **T** | covered |
| **Strengths** | AoE threat (Cons / HotR / AS bounce); strong personals; blessings / utility | HotR + Cons + Holy Wrath; Divine Protection; HoR taunt; RF passive DR | partial (no bounce AS; thin raid util) |
| **Weaknesses** | Mana pressure; less mobile; HS uptime skill | Mana resource + costs present; no mobility tool; HS not a maintain | weakness partly inverted (HS not uptime skill — it’s emergency) |
| Party utility | Blessings, judgements, auras, peels | none beyond tank hold | missing |

**WotLK identity score:** **3 / 5**  
(Readable holy tank; missing maintain Holy Shield + utility keeps it from 4.)

**Player pitch:**  
> Holy plate tank — smashes packs with consecrated ground and shields the party through spikes.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Shield of Righteousness, Hammer of the Righteous (ST too) | SoR + Avenger’s Shield | present |
| **Maintain / DoT / buff** | Holy Shield (always), seals / Sacred Shield | Righteous Fury passive only; Holy Shield is emergency | **missing** (must-keep) |
| **Finisher / dump** | Judgement on CD; Hammer of Wrath execute | none | weak / OK-to-drop |
| **AoE / cleave** | Consecration, HotR, Avenger’s Shield bounce, Holy Wrath | HotR, Cons, Holy Wrath; AS is ST damage | present (AS bounce missing) |
| **Offensive CD / burst** | Avenging Wrath | Holy Wrath signature AoE | weak / present-ish |
| **Defensive / emergency** | Divine Protection, Divine Sacrifice / LoH / Ardent Defender | Divine Protection; Holy Shield as 2nd emergency | present (HS mis-bucketed) |
| **Control / kite** | Hand of Reckoning, AS silence/interrupt feel | Hand of Reckoning | present |
| **Raid / party utility** | Blessings, judgements, auras | none | missing |
| **Proc / reaction** | Guardians / block-related talents | generic kit block window on tank emergencyDefend | weak |

**Must-keep for idle:** Holy Shield maintain, SoR / AS ST, Cons or HotR AoE, Divine Protection, taunt.  
**OK-to-drop:** 9-6-9 weave, seal dance, judgement choice, Hammer of Wrath execute, full blessing matrix.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | tank / `HeroRole.warrior` — match |
| Resource + regen | mana; spiritRegen + hit refund (~4) + passive tick | OK (mana fantasy present) |
| Resource edge cases | costs gate casts; no soft-lock observed in code | OK |
| Kit path | `ClassKits.forSpec` + `AbilityEffectRunner._tickSpecKit` (non-legacy) | OK |
| Baseline AA / kit muls | RF: `kitInMul *= 0.82`, `kitOutMul *= 0.97` | OK |
| Unlock curve | L1 Fury → L15 Divine Protection; HoR L4 | OK |
| Wiring overall | **OK** — all 9 kit rows resolve via effect kinds | gaps = design buckets, not missing wires |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| righteousFury | 1 | passive | 0 | 0 | `_applyPassive` | no | Righteous Fury | maintain | DR + slight out tax |
| avengersShield | 3 | filler | 8 | 18 | runner `damage` | yes | Avenger’s Shield | ST | no bounce; melee slash unless far |
| handOfReckoning | 4 | signature | 8 | 10 | runner `taunt` | yes | Hand of Reckoning | control | tank taunt priority |
| holyShield | 5 | emergency | 10 | 15 | runner `emergencyDefend` | yes | Holy Shield | def | **should be maintain** |
| hammerOfTheRighteous | 7 | filler | 6 | 12 | runner `aoe` → nova | yes | Hammer of the Righteous | AoE | pack≥2 or elite |
| consecration | 9 | filler | 9 | 20 | runner `aoe` → `_groundNova` | yes | Consecration | AoE | holy ground ring |
| shieldOfRighteousness | 11 | filler | 5.5 | 20 | runner `damage` | yes | Shield of Righteousness | ST | |
| holyWrath | 13 | signature | 22 | 25 | runner `aoe` | yes | Holy Wrath | AoE / CD | held on long sig rules |
| divineProtection | 15 | emergency | 55 | 0 | runner `emergencyDefend` | yes | Divine Protection | def | HP≤35% / ally low gate |

Tests: `combat_authority_audit_test` (taunt + mana regen/block), `kit_passives_test` (passive muls), `spell_vfx_test` (Holy Wrath / Consecration → holy).

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| preferredRange / attackRange | melee | 1.2 / 1.75 | ok |
| Kite / charge | AS as ranged opener fantasy | no gap tool; AS usually melee | weak / N/A |
| Target selection | alive non-dormant | shared smart focus | ok |
| Pack vs single | AoE on clumps | HotR/Cons gated | ok |
| Tank threat / taunt | hold + pull leaks | RF + HoR + emergency soft taunt | ok |
| Healer triage | N/A | — | N/A |
| DPS focus | N/A | — | N/A |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| armorTypes | `_plate` | ok |
| Unlock path | `AL 3`; `canUnlockSpec` | ok |
| Roster / PARTY | unlock adds roster hero `Bulwark` | ok |
| shortLabel / meter | **PPROT** (readable but clunky vs PROT) | ok / polish |
| Ability chip copy | Fury hidden; AShield/HShield/HotR/Cons/SoR/Wrath/DProt/HoR | ok |
| Guides / Codex / tips | New Game only names starter Protection warrior | stale / N/A for PPROT |

#### 6. Content contexts

| Context | What to watch | Status |
|---------|---------------|--------|
| Multi-chamber wake | HoR + AoE when packs wake | ok (code) |
| Boss floor | AoE allowed on lone elite; emergencies | ok (code) |
| Offline / AFK | same `_tickSpecKit` | ok (assumed) |
| Wipe / revive | standard | ok |
| FARM | identity readable on packs | ok (inferred) |
| PUSH | not live-tested | N/A |
| Challenges / hardmode | not live-tested | N/A |
| Save / migrate | unlock via metaDepth; kit by specId | ok |
| Perf | Consecration ground nova + holy bolts; fine under `reducedVfx` | ok |

#### 7. Pet / guardian

N/A

#### 8. Live read

| Signal | Observed |
|--------|----------|
| Meter (DPS / H/s / T/s) | not live this run — expect **T** when tanking |
| Buckets that fire | SoR, AS, HotR/Cons in packs, HoR, DProt/HShield when low |
| Buckets that never fire | Holy Shield as maintain; blessings/judgement |
| Resource | mana spend + spirit regen (code) |
| Range / AI | melee face | |
| Role red flags | dual emergency DR; empty maintain |

#### 9. Assets & VFX

| Surface | Path / check | Status | Notes |
|---------|--------------|--------|-------|
| Hero body | `CustomAssets.heroPaladin` | ok | owned custom |
| Spec distinguishable | paladin sprite vs knight warrior | ok | |
| Ability HUD chips | shortLabels | ok | |
| AA bolt style | `SpellBoltStyle.holy` (paladin) | ok | |
| Signature / CD burst | Holy Wrath nova + announce important path | ok | |
| Maintain / aura | RF silent passive | weak | no HS bubble maintain |
| AoE telegraph | Consecration `_groundNova` | ok | |
| Emergency VFX | ring + floater on emergencyDefend | ok | |
| `reducedVfx` | announce gated; rings skipped | ok | |
| Audio | N/A | N/A | |

**On-screen (full):** code expects Cons ring, holy SoR/AS sparks, DProt ring — not re-verified live.

**A11y / readability:** chips + shortLabels present; PPROT denser than PROT. Status: ok

**Asset / VFX findings**

- P0: none  
- P1: no Holy Shield maintain telegraph  
- P2: shortLabel `PPROT` polish; guides omit unlock tanks  

#### 10. Findings

- **P0:** none  
- **P1:**
  1. Retarget **Holy Shield** from emergencyDefend → maintain / selfBuff (uptime DR), keep **Divine Protection** as the big emergency.
  2. Add a light party-utility beat (one blessing- or judgement-flavored idle buff) or accept thin util and document.
- **P2:**
  1. Avenger’s Shield bounce / ranged pull feel.
  2. Rename shortLabel toward `PPAL` / `HPAL`-style clarity.
  3. Dedicated offline + PUSH smoke; guides mention unlock tanks.

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job in 1T/1H/2D | Front hold + pack AoE threat | clear |
| Overlap with Protection warrior | both plate tanks; Pala more AoE holy, less block-proc identity | ok |
| Hole if missing | covered by other tanks | covered |
| Synergy | no raid buffs today | none |

## Cross-party balance

| Spec | Meter | vs peers | vs WotLK role | Range/AI | Modes (F/P/C) | Perf | Verdict |
|------|-------|----------|---------------|----------|---------------|------|---------|
| protPaladin | T (expected) | tank band (inferred) | match role | ok | FARM ok; P/C N/A | ok | **tune** |

**Player pitches:**

| Spec | Pitch one-liner |
|------|-----------------|
| protPaladin | Holy plate tank — smashes packs with consecrated ground and shields the party through spikes. |

## P0 / P1 backlog

1. **P1** Holy Shield maintain (not emergency twin of Divine Protection).  
2. **P1** Optional light blessing/judgement party util.  
3. **P2** AS bounce / label / offline tests.

## Proposed tunings

Idle Party fields only — **no** Wowhead coefficients.

| Spec | Ability / field | From → To | Why (idle feel + WotLK bucket) |
|------|-----------------|-----------|--------------------------------|
| protPaladin | holyShield | emergencyDefend → selfBuff / maintain DR window on a short CD | restore must-keep HS uptime |
| protPaladin | divineProtection | keep emergencyDefend | sole big personal |
| protPaladin | (optional) blessing buff | new mild party `kitOut`/`def` crumb | raid util bucket |

## Explicitly out of scope

BiS / gems / enchants / consumables / PvP / talent calculators / glyph spreadsheets.

## Test gaps

- [ ] Offline Prot Pala combat  
- [ ] PUSH / challenges smoke  
- [ ] Holy Shield maintain once retuned  
- [x] Wiring / cast (runner + taunt test)  
- [x] Assets (paladin.png)  
- [x] Passive regen / block on syncPartyFromState  

## Compared to previous audit

**Previous:** none · **Delta:** baseline Prot Paladin audit.

## Out of scope / follow-ups

- Retribution / Holy Paladin audits  
- Side-by-side with `protection` warrior after HS maintain fix
