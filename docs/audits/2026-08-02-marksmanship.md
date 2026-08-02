# Class audit report — Marksmanship

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid sims from `tool/out/class_balance_latest.md`)  
**Specs in scope:** `marksmanship`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** no live dungeon glance — meter from balance sims only  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients / talent spreads / BiS.

## Summary

MM is the healthiest Idle hunter kit: Steady / Aimed / Chimera / Rapid Fire / Trueshot / Deterrence all wire on the shared runner with arrow VFX. Mid Prot+Disc share sits near the peer median (~50%). Biggest gaps vs Wrath feel are **no maintain sting**, **Trueshot Aura is personal not party**, and **no Misdirection** — identity is recognizable but thinner than BM’s hole. Verdict: **tune**.

## Audit DoD

- [x] Wowhead links filled
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Threat N/A (DPS)
- [x] Gear / unlock / roster / copy
- [x] Content contexts / offline / modes / save / perf
- [x] Assets + VFX
- [x] Identity score + verdict
- [x] All P0 listed
- [x] Live meter notes (sims)
- [x] Pet/guardian N/A (MM not pet-primary in Idle)
- [x] Composition / pitch

---

### `HeroSpecId.marksmanship` — MM

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** ranged-dps  
**Has pet/guardian?** no (Wrath MM still has a pet, but Idle MM fantasy is shot mastery — mark **N/A** for required guardian; optional meta hatch pet only)

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath MM feel (Chimera / Aimed / Trueshot Aura) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/hunter/marksmanship/dps-rotation-cooldowns-abilities-pve | y (structure; JS-thin) |
| Talents / builds | identity only (Readiness / Chimera focus) | y |
| Other | skipped | n |

Patch note on Wowhead rotation page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Precision shots; Chimera + Aimed; raid AP aura | Mail bow; Steady/Aimed/Chimera/Trueshot | covered |
| Role job | Ranged DPS | `rangedDps`, mana, preferredRange 4.5 | covered |
| **Strengths** | Chimera priority, Aimed, Rapid Fire, Trueshot Aura | Chimera+Aimed+Rapid+Trueshot wired | partial (aura personal) |
| **Weaknesses** | Mana, setup | Deterrence emergency; Scatter root | covered |
| Party utility | Trueshot Aura, Misdirection | personal `kitOutMul` only | **partial / missing** |

**WotLK identity score:** **4 / 5**  
(Shot kit reads well; aura/utility soft.)

**Player pitch:**  
> Mail marksman — Steady fills, Aimed and Chimera punch, Rapid Fire and Trueshot open the window.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Steady Shot | Steady Shot | present |
| **Maintain / DoT / buff** | Serpent Sting (Chimera refresh), Trueshot Aura | Trueshot Aura passive only | weak |
| **Finisher / dump** | Kill Shot; Chimera as heavy | Chimera Shot (always on CD) | present (no execute) |
| **AoE / cleave** | Multi / Volley / Trap | — | **missing** |
| **Offensive CD / burst** | Rapid Fire, Readiness, Call of the Wild | Rapid Fire + Trueshot | present |
| **Defensive / emergency** | Deterrence, Feign | Deterrence → emergencyDefend | present |
| **Control / kite** | Scatter Shot, Silencing Shot | Scatter Shot root | present |
| **Raid / party utility** | Trueshot Aura, Misdirection | personal mul | weak |
| **Proc / reaction** | Improved Steady / Readiness | — | OK-to-drop |

**Must-keep for idle:** Steady, Aimed or Chimera, Rapid Fire, Deterrence.  
**OK-to-drop:** Readiness double-weave, Silencing macros, Kill Shot, trap weave.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Role | rangedDps; legacyRole rogue | OK |
| Resource | mana ~9/s + spirit/mp5 | OK |
| Kit path | `_tickSpecKit` | OK |
| Baseline | Trueshot Aura `kitOutMul` 1.14 + haste 1.06 | OK (personal) |
| Unlock | `cleared >= 3` (Underworld); hint matches | OK |
| Wiring | OK | OK |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| trueshotAura | 1 | passive | 0 | 0 | passive mul+haste | no | Trueshot Aura | util | **personal**, not party |
| steadyShot | 3 | filler | 5 | 14 | runner damage bolt | yes | Steady Shot | ST | OK |
| aimedShot | 5 | filler | 7 | 18 | runner damage bolt | yes | Aimed Shot | ST | OK |
| chimeraShot | 7 | filler | 8 | 20 | runner damage bolt | yes | Chimera Shot | ST | no sting refresh |
| scatterShot | 9 | filler | 14 | 12 | runner root | yes | Scatter Shot | control | OK |
| rapidFire | 11 | filler | 32 | 15 | runner selfBuff haste | yes | Rapid Fire | CD | name→haste |
| trueshot | 13 | signature | 45 | 20 | runner selfBuff haste | yes | Trueshot (signature) | CD | held elite/pack |
| deterrence | 15 | emergency | 50 | 0 | runner emergencyDefend | yes | Deterrence | def | OK |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| preferredRange / attackRange | backline | 4.5 / 5.5 | ok |
| Kite tools | optional | Scatter root only | ok / weak |
| Target / packs | non-dormant; no MM AoE | no AoE bucket | weak |
| DPS focus | shared | ok | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| armorTypes | mail set | ok |
| Unlock | Clear Underworld (`highestDungeonCleared >= 3`) | ok |
| Roster | unlockSpec → roster | ok |
| shortLabel | MM | ok |
| Chips | Steady/Aimed/Chim/… | ok |
| Guides | no MM-specific tips found | N/A |

#### 6. Content contexts

| Context | Status |
|---------|--------|
| Multi-chamber / boss | ok; Trueshot held for elite |
| Offline / AFK | same runner | ok |
| FARM | identity readable | ok |
| PUSH | mid share fair | ok |
| Challenges / save | ok |
| Perf | arrow bolts light | ok |

#### 7. Pet / guardian

| Check | Notes | Status |
|-------|-------|--------|
| Pet exists | Not required for Idle MM identity | N/A |
| Meta hatch pet | Optional party companion only | N/A |

#### 8. Live read (sims)

| Signal | Observed |
|--------|----------|
| Meter | Prot+Disc mid share **50.5%**, DPS ~125 — fair vs median ~49% |
| Buckets that fire | Steady / Aimed / Chimera / Rapid / Trueshot / Scatter / Deter |
| Never | AoE Multi/Volley; party Trueshot Aura |
| Resource | cost-sorted fillers prefer Chimera → Aimed → Rapid | OK |
| Red flags | none hard |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Hunter sprite | ok | shared with BM/SV |
| Arrow bolts | ok | Aimed/Steady/Chimera mapped |
| Rapid / Trueshot haste ring | ok | |
| Deterrence shield | ok | |
| AoE telegraph | none | no AoE ability |
| reducedVfx | ok | |
| Spec distinguishability | muddy | P2 |

**A11y:** MM tag + chips OK at ~390×844.

**Asset / VFX findings**

- P0: none  
- P1: Chimera could use dual-tint (nature/frost) vs plain arrow — polish  
- P2: shared hunter body  

#### 10. Findings

- **P0:** none for wire/soft-lock (kit casts; numbers fair)  
- **P1:** No AoE bucket (Multi/Volley/Trap) — packs lean on whites + ST  
- **P1:** Trueshot Aura copy/fantasy is raid AP; Idle is personal mul — fix copy or party buff  
- **P1:** No Serpent Sting maintain (Chimera doesn’t refresh a DoT)  
- **P2:** Misdirection absent; Chimera VFX generic arrow  

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job | primary ranged physical | clear |
| Overlap | BM without pet ≈ thinner MM | ok if BM gets pet |
| Hole if missing | SV/BM can cover bow niche | covered |
| Synergy | no party AP | weak |

## Cross-party balance

| Spec | Meter | vs peers | vs WotLK | Range/AI | Modes | Perf | Verdict |
|------|-------|----------|----------|----------|-------|------|---------|
| marksmanship | ~50% mid | fair | ok | ok | ok | ok | **tune** |

**Player pitch:** Precision bow DPS — Aimed and Chimera on CD, Rapid Fire when the pack opens.

## P0 / P1 backlog

1. **P1** Add light AoE (Multi or Volley-lite) so packs don’t go ST-only  
2. **P1** Trueshot Aura → party ranged/AP crumb **or** rewrite chip to “personal crit lean” (already matches code)  
3. **P1** Optional Serpent Sting maintain (or Chimera-tagged DoT)  
4. **P2** Chimera dual-element VFX  

## Proposed tunings

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| MM | new Multi or share BM Multi | missing → filler aoe | pack bucket |
| MM | trueshotAura | personal → party crumb **or** copy fix | utility identity |
| MM | chimeraShot VFX | arrow → nature+frost tint | signature read |

## Explicitly out of scope

BiS / gems / enchants / consumables / PvP / talent calculators / glyphs.

## Test gaps

- [ ] MM pack AoE once added  
- [ ] Party aura if implemented  
- [ ] Cast smoke / unlock Underworld gate  
- [ ] Offline  

## Compared to previous audit

**Previous:** none · **Delta:** first MM pass  

## Out of scope / follow-ups

- Readiness double-burst (idle-unfriendly)  
- Kill Shot execute (optional)  
