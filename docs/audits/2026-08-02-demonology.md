# Class audit report — Demonology Warlock

> **Status (2026-08):** Roadmap graduated Demonology (coeffs + classpet spawn). This audit is **historical** — re-run class-audit before treating Verdict WIP as current.

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; mid-band sim notes; no fresh browser playtest)  
**Specs in scope:** `demonology`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Demonology is a **pet-family fantasy with no combat demon**. Kit has Shadow Bolt, Hand of Gul’dan AoE, Immolate bolt, Metamorphosis / Demon Charge haste buffs, Chaos Bolt, Sacrifice. Passive copy says “pet lean” but `SpatialCombat` only spawns the meta `activePet` companion — never a Demo guardian. Mid share **~68% HIGH** is systemic. Verdict **WIP** until a pet exists or copy/passive drop the pet claim.

## Audit DoD

- [x] Identity / buckets / wiring
- [x] **Pet section — missing**
- [x] Sims / VFX / unlock / pitch

---

### `HeroSpecId.demonology` — DEMO

**Verdict:** WIP  
**Depth:** full  
**Wowhead role page family:** caster-dps  
**Has pet/guardian?** **should yes — missing**

#### Wowhead sources

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Demo pet / Meta feel | y |
| Rotation / CDs | https://www.wowhead.com/wotlk/guide/classes/warlock/demonology/dps-rotation-cooldowns-abilities-pve | y (structure) |
| Talents | identity only | n |

#### 1. Overview

| | WotLK | Idle today | Gap |
|--|-------|------------|-----|
| Fantasy | Demon pet + Meta windows | Solo shadow/fel bolts + haste buffs | **missing pet** |
| Role | Ranged DPS | caster (preferredRange 3.8 slightly closer) | covered |
| **Strengths** | Pet damage, Meta | Meta/Charge haste; HoG AoE; Chaos | partial |
| **Weaknesses** | Pet management | Sacrifice emergency | partial |
| Utility | Demons | Demonic Knowledge personal mul | inverted |

**WotLK identity score:** **2 / 5**

**Player pitch:**  
> Cloth demonologist — should fight with a demon; today Meta/Charge are haste windows and there is no combat pet.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Shadow Bolt | shadowBolt | present |
| Maintain | Immolate / curses | immolateDemo bolt | weak |
| Finisher | Chaos Bolt | chaosBoltDemo | present |
| AoE | Hand of Gul’dan | handOfGuldan | present |
| Offensive CD | Metamorphosis | metamorphosis selfBuff | present |
| Defensive | Sacrifice / Soul Link | sacrifice | present |
| Control | — | demonCharge (haste, not dash) | weak |
| **Pet** | Felguard / etc. | **none** | **missing** |
| Proc | — | — | N/A |

**Must-keep:** Shadow Bolt, Meta, Chaos Bolt, **combat pet**.  
**OK-to-drop:** Demon charge weaving, exact curse list.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Kit path | `_tickSpecKit` | OK shell |
| Passive | demonicKnowledge out×0.65; copy “pet lean” | **no pet** |
| Pets in build | only `state.activePet` meta companion | not Demo |
| Meta / Charge | `_selfBuff` via name (`meta` / `charge`) → PI+haste | no form/dash |
| Unlock | AL 6 | OK |

**Abilities**

| AbilityId | Unlock | Path | Bucket | Notes |
|-----------|--------|------|--------|-------|
| demonicKnowledge | 1 | passive | util | pet claim false |
| shadowBolt | 3 | runner dmg | ST | OK |
| handOfGuldan | 5 | runner AoE | AoE | shadow |
| immolateDemo | 7 | runner dmg | maintain | fire bolt |
| metamorphosis | 9 | selfBuff signature | CD | haste window |
| demonCharge | 11 | selfBuff | mobility | **not a charge** |
| chaosBoltDemo | 13 | runner dmg | signature | fire |
| sacrifice | 15 | emergencyDefend | def | OK |

#### 4. Range / AI — ok (3.8/4.8 slightly forward of cloth peers)

#### 5. Gear / unlock — cloth; AL 6; DEMO ok; warlock sprite OK

#### 6. Pet / guardian

| Check | Status |
|-------|--------|
| Pet exists in combat | **missing** |
| Pet AI / leash | N/A |
| Pet VFX / sprite | N/A |
| Pet in meter / HUD | N/A |

Compare: meta pets spawn at `SpatialCombat.build` when `state.activePet != null` — unrelated to Demo kit.

#### 7. Live read

| Band | Share | DPS | Clear |
|------|-------|-----|-------|
| mid Prot+Disc | 68.0% HIGH | 303 | 17% |
| mid ProtPala+Holy | 47.7% | 214 | 33% |

#### 8. Assets & VFX

Shadow/fire bolts for SB/HoG/Immo/Chaos — ok (tests cover immolateDemo). No demon actor/sprite for kit.

#### 9. Findings

- **P0:** Spawn a licensed combat demon on Demo (or strip pet fantasy from passive/copy)
- **P0 (numbers):** Mid share HIGH ~68% — systemic
- **P1:** Demon Charge → real dash/close like Blink inverse; Meta VFX form tint
- **P1:** Immolate maintain ticks
- **P2:** Felguard vs Imp choice (later)

## Composition

Should be the pet DPS caster vs Aff DoTs / Destro nukes. Without pet, overlaps Destro heavily (Chaos Bolt shared fantasy).

## Proposed tunings

| Spec | Change | Why |
|------|--------|-----|
| demonology | Combat pet actor (Kenney/custom) on enter / Meta | pet-family DoD |
| demonology | Rename Knowledge if pet delayed | honest copy |
