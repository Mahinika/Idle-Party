# Class audit report — Destruction Warlock

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; mid-band sim notes; no fresh browser playtest)  
**Specs in scope:** `destruction`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Destruction is a **readable fire nuke kit** on the shared runner: Incinerate, Conflagrate, Immolate bolt, Shadowfury AoE, Backdraft, Chaos Bolt, Shadow Ward. Bolt styles are fire/shadow-correct and tested. Immolate is not a real DoT; Conflag has no Immolate prerequisite (OK for idle). Mid share **~68% HIGH** and clear **17%** — numbers systemic. No hard wiring P0. Verdict **tune**.

## Audit DoD

- [x] Identity / buckets / wiring / VFX tests
- [x] Range / unlock / pet N/A
- [x] Sims / modes / pitch / P0s

---

### `HeroSpecId.destruction` — DESTRO

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** caster-dps  
**Has pet/guardian?** no (optional Imp — N/A)

#### Wowhead sources

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Destro Chaos / Conflag / Immolate feel | y |
| Rotation / CDs | https://www.wowhead.com/wotlk/guide/classes/warlock/destruction/dps-rotation-cooldowns-abilities-pve | y (structure) |
| Talents | identity only | n |

#### 1. Overview

| | WotLK | Idle today | Gap |
|--|-------|------------|-----|
| Fantasy | Fire nuke Chaos Bolt | Cloth fire/shadow bolts | covered |
| Role | Ranged DPS | caster (4.2/5.2 slightly longer) | covered |
| **Strengths** | Chaos, Conflag, Backdraft | Chaos signature; Backdraft; Shadowfury | covered |
| **Weaknesses** | Fragile; Immolate upkeep | Shadow Ward; glass | covered |
| Utility | Shadowfury stun | Shadowfury AoE | present |

**WotLK identity score:** **4 / 5**

**Player pitch:**  
> Cloth destruction warlock — Incinerates, Conflags, and drops Chaos Bolt; Shadowfury for packs.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Incinerate | incinerate | present |
| Maintain | Immolate | immolateDestro bolt | weak |
| Finisher | Chaos Bolt / Conflag | chaosBolt; conflagrate | present |
| AoE | Shadowfury / Rain | shadowfury | present |
| Offensive CD | Backdraft / trinket | backdraft selfBuff | present |
| Defensive | Shadow Ward | shadowWard | present |
| Control | Shadowfury | shadowfury AoE | present |
| Party util | — | none | N/A |
| Proc | Backlash / ISB | N/A | OK-to-drop |

**Must-keep:** Incinerate, Immolate (or honest bolt), Chaos Bolt, Shadowfury.  
**OK-to-drop:** Soul Fire execute weaves, exact Conflag Immolate consume.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Kit path | `_tickSpecKit` | OK |
| Passive | cataclysm out×0.66 | OK |
| Chaos / Incin / Conf / Immo | fire bolt styles | OK (tests) |
| Shadowfury | AoE nova shadow | OK |
| Unlock | Clear Hell Maw | OK |

**Abilities**

| AbilityId | Unlock | Path | Bucket | Notes |
|-----------|--------|------|--------|-------|
| cataclysm | 1 | passive | util | OK |
| incinerate | 3 | runner dmg | ST | fire |
| conflagrate | 5 | runner dmg | ST/finisher | no Immo gate — OK idle |
| immolateDestro | 7 | runner dmg | maintain | bolt not DoT |
| shadowfury | 9 | runner AoE | AoE/control | OK |
| backdraft | 11 | selfBuff | CD | PI+haste |
| chaosBolt | 13 | runner dmg | signature | fire coeff 2.0 |
| shadowWard | 15 | emergencyDefend | def | OK |

#### 4. Range / AI — ok 4.2/5.2; pack AoE gated

#### 5. Gear / unlock — cloth; Hell Maw clear; DESTRO ok

#### 6. Content contexts

| Context | Status |
|---------|--------|
| Mid Prot+Disc | share 68.4% HIGH; clear 17% |
| Mid ProtPala+Holy | share 60.7%; clear 0% |
| Offline / modes | ok |
| Perf | ok; Chaos+Incin bolt spam fine w/ reducedVfx |
| Pet | N/A |

#### 7. Live read

| Band | Share | DPS | Clear |
|------|-------|-----|-------|
| mid Prot+Disc | 68.4% HIGH | 290 | 17% |
| mid ProtPala+Holy | 60.7% | 229 | 0% |

#### 8. Assets & VFX

Warlock sprite; fire bolts for Incin/Conf/Immo/Chaos; shadow for Shadowfury — ok (`spell_vfx_test`).

#### 9. Findings

- **P0:** Mid share HIGH ~68% — **systemic** caster ceiling (selfBuff white haste double-dip)
- **P1:** Immolate maintain ticks (optional Conflag bonus when marked)
- **P2:** Shadow Ward absorb VFX distinct from generic DR

No kit-path “ability never fires” bugs found.

## Composition

Primary fire-nuke warlock; overlaps Fire Mage. Distinct from Aff (should be) and Demo (should be pet). Currently the strongest-feeling warlock kit.

## Proposed tunings

| Spec | Change | Why |
|------|--------|-----|
| shared casters | fix selfBuff PI+haste double apply | mid HIGH |
| destruction | optional Immolate DoT | maintain bucket |
| destruction | mild Chaos/Incin coeff trim **after** shared fix | if still HIGH |
