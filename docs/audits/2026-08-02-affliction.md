# Class audit report — Affliction Warlock

> **Status (2026-08):** Roadmap graduated Affliction (coeffs + Drain damage path). This audit is **historical** — re-run class-audit before treating Verdict WIP as current.

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; mid-band sim notes; no fresh browser playtest)  
**Specs in scope:** `affliction`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Affliction **names** the DoT fantasy (Corruption, UA, Haunt, Agony, Drain Life) but the kit is **not Affliction in play**: every DoT is an instant shadow bolt, and **Drain Life is `AbilityEffectKind.heal`** — it only tops injured allies and deals **no damage**. That is a must-bucket wiring failure. Mid share HIGH (~62%) is systemic; clear **8%** is poor. Verdict **WIP**.

## Audit DoD

- [x] Identity / buckets / wiring (Drain Life P0)
- [x] Range / unlock / pet N/A
- [x] Sims / VFX / pitch

---

### `HeroSpecId.affliction` — AFF

**Verdict:** WIP  
**Depth:** full  
**Wowhead role page family:** caster-dps  
**Has pet/guardian?** no (Aff pet optional in Wrath — N/A for idle)

#### Wowhead sources

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Affliction DoT / Haunt / Drain feel | y |
| Rotation / CDs | https://www.wowhead.com/wotlk/guide/classes/warlock/affliction/dps-rotation-cooldowns-abilities-pve | y (structure) |
| Talents | identity only | n |

#### 1. Overview

| | WotLK | Idle today | Gap |
|--|-------|------------|-----|
| Fantasy | Multi-DoT shadow drain | Shadow bolt spam + ally heal | **missing** |
| Role | Ranged DPS | caster | covered |
| **Strengths** | DoT ramp, Haunt, Drain | Haunt Burst signature | missing |
| **Weaknesses** | Ramp / fragile | Soulburn emergency | partial |
| Utility | Curses / drains | Drain Life heals party | **inverted** |

**WotLK identity score:** **2 / 5**

**Player pitch:**  
> Cloth affliction warlock — should be DoTs and Drain Life; today Drain Life heals allies and DoTs are one-shot bolts.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Shadow Bolt / Drain | haunt as nuke | weak |
| **Maintain DoT** | Corr / UA / Agony | bolts only | **missing** |
| Finisher | Haunt | hauntBurst | present |
| AoE | Seed | none | missing (OK) |
| Offensive CD | — | hauntBurst | present |
| Defensive | — / Sac | soulburn | present |
| Control | — | none | N/A |
| Party util | — | drainLife heal | **wrong** |
| Proc | — | — | N/A |

**Must-keep:** Corruption/UA maintain, Haunt, Drain Life (dmg+self heal).  
**OK-to-drop:** Seed weaving, glyph curse swaps.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Kit path | `_tickSpecKit` | OK shell |
| Passive | soulSiphon out×0.70 heal×1.06 | OK |
| **P0** | drainLife = `heal` → `_castHeal` on hurt ally, **no enemy damage** | broken |
| DoTs | corruption / UA / agony / haunt = damage bolts | no ticks |
| Unlock | AL 6 | OK |

**Abilities**

| AbilityId | Unlock | Path | Bucket | Notes |
|-----------|--------|------|--------|-------|
| soulSiphon | 1 | passive | util | OK |
| corruption | 3 | runner dmg | maintain | bolt |
| unstableAffliction | 5 | runner dmg | maintain | bolt |
| haunt | 7 | runner dmg | ST | OK as nuke |
| drainLife | 9 | **heal** | ST/sustain | **P0 wrong kind** |
| curseOfAgony | 11 | runner dmg | maintain | bolt |
| hauntBurst | 13 | runner dmg | signature | OK |
| soulburn | 15 | emergencyDefend | def | OK |

#### 4. Range / AI — ok 4.0/5.0; Drain Life steals filler GCDs when allies hurt

#### 5. Gear / unlock — cloth; AL 6; AFF ok; warlock sprite OK

#### 6. Content contexts

| Context | Status |
|---------|--------|
| Mid Prot+Disc | share 61.9% HIGH; clear **8%** LOW |
| Mid ProtPala+Holy | share 51.7%; clear 0% |
| Offline | path ok; identity wrong |
| Pet | N/A |

#### 7. Live read

| Band | Share | DPS | Clear |
|------|-------|-----|-------|
| mid Prot+Disc | 61.9% HIGH | 229 | 8% |
| mid ProtPala+Holy | 51.7% | 178 | 0% |

#### 8. Assets & VFX

Shadow bolts for Corr/UA/Haunt — ok. No DoT tick marks. Drain Life shows heal sparks (wrong fantasy).

#### 9. Findings

- **P0:** Drain Life → damage + self-heal (not party heal triage)
- **P0:** Maintain DoT bucket missing (Corruption/UA/Agony need ticks or honest rename)
- **P0 (numbers):** Mid share HIGH — systemic
- **P1:** LOW clear mid — retest after Drain Life fix
- **P2:** Curse telegraph

## Composition

Should be DoT caster niche vs Destro nukes; currently a generic shadow bolt kit with a heal trap.

## Proposed tunings

| Spec | Change | Why |
|------|--------|-----|
| affliction | drainLife → damage bolt with `onHitHealCaster` or self heal | fantasy |
| affliction | Corr/UA/Agony → Living-Bomb-style ticks | must-bucket |
