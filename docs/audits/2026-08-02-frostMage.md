# Class audit report — Frost Mage

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; mid-band sim notes; no fresh browser playtest)  
**Specs in scope:** `frostMage`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — `tool/out/class_balance_latest.md` mid Prot+Disc

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Frost reads as a **control caster** with Frostbolt, Ice Lance, Cone, Nova, Icy Veins, and Ice Block on the shared runner. The signature **Water Elemental is fake** — `selfBuff` haste window, no combat pet/actor. Ice Block is generic `emergencyDefend` (not true immunity). Mid share **~67% HIGH** = systemic caster ceiling. Kit identity otherwise solid.

## Audit DoD

- [x] Wowhead / identity
- [x] Buckets + wiring
- [x] Range / AI / gear / unlock
- [x] Pet section (missing elemental)
- [x] Sims / VFX / modes / pitch / P0s

---

### `HeroSpecId.frostMage` — FRST

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** caster-dps  
**Has pet/guardian?** advertised yes (Water Elemental) — **missing in combat**

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Frost control / Water Elemental feel | y |
| Rotation / CDs / abilities | https://www.wowhead.com/wotlk/guide/classes/mage/frost/dps-rotation-cooldowns-abilities-pve | y (structure) |
| Talents | identity only | n |

Patch note: 3.4.x family

#### 1. Overview

| | WotLK | Idle Party today | Gap |
|--|-------|------------------|-----|
| Fantasy | Chill control + Water Elemental | Frost bolts + Nova + Veins | **partial** (no elemental) |
| Role | Ranged DPS | caster | covered |
| **Strengths** | Control, Elemental, shatter | Nova/Cone/root; Veins window | partial |
| **Weaknesses** | Ramp / fragile | Frost Armor DR; glass | covered |
| Utility | Utility slows | Nova / Lance chill fantasy | weak (no shatter) |

**WotLK identity score:** **3 / 5** (signature pet gap)

**Player pitch:**  
> Cloth frost caster — bolts and novas packs, pops Icy Veins (Water Elemental is currently a haste window, not a pet).

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Frostbolt | frostbolt | present |
| Maintain / chill | Frostbite / FoF | Frost Armor passive root bonus | weak |
| Finisher | Ice Lance (shatter) | iceLance (plain nuke) | weak |
| AoE | Cone / Blizzard | coneOfCold | present |
| Offensive CD | Icy Veins / Elemental | icyVeins; summonWaterElemental | present / **fake pet** |
| Defensive | Ice Block | frostMageIceBlock | weak |
| Control | Frost Nova | frostNovaMage | present |
| Party util | AI | none | missing (OK vs Fire) |
| Proc | FoF | N/A | OK-to-drop |

**Must-keep:** Frostbolt, Nova, Icy Veins, Ice Block, Water Elemental (or honest rename).  
**OK-to-drop:** Deep Freeze weaves, Cold Snap resets.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Kit path | `_tickSpecKit` | OK |
| Passive | frostArmor: in×0.92, out×0.65, rootBonus | OK |
| Signature | summonWaterElemental → `_selfBuff` (name contains `water`) → PI+haste | **no pet spawn** |
| Ice Block | emergencyDefend | not `iceBlockTimer` |

**Abilities**

| AbilityId | Unlock | Path | Bucket | Notes |
|-----------|--------|------|--------|-------|
| frostArmor | 1 | passive | util/def | OK |
| frostbolt | 3 | runner dmg | ST | frost bolt |
| iceLance | 5 | runner dmg | ST/finisher | no shatter mul |
| coneOfCold | 7 | runner AoE | AoE | pack-gated |
| frostNovaMage | 9 | runner root | control | OK |
| icyVeins | 11 | selfBuff | CD | PI+haste |
| summonWaterElemental | 13 | selfBuff | CD | **P0/P1 fake pet** |
| frostMageIceBlock | 15 | emergencyDefend | def | weak vs Fire |

#### 4. Range / AI — ok (4.0 / 5.0 backline; pack AoE; shared focus)

#### 5. Gear / unlock — cloth; AL 3; FRST label ok

#### 6. Content contexts

| Context | Status |
|---------|--------|
| Offline | ok |
| Mid PUSH | HIGH share 67.2%; clear 17% LOW |
| Pet | **missing** |
| Perf | ok |

#### 7. Live read (sims)

| Band | Share | DPS | Note |
|------|-------|-----|------|
| mid Prot+Disc | 67.2% HIGH | 272 | clear 17% |
| mid ProtPala+Holy | 60.0% | 235 | wipe-heavy |

#### 8. Assets & VFX

Frost bolts / Cone / Nova styles mapped — ok. No Water Elemental sprite/actor. Ice Block generic.

#### 9. Findings

- **P0 (kit):** Water Elemental signature does not spawn a combat pet — haste buff only (rename or spawn actor)
- **P0 (numbers):** Mid share HIGH ~67% — systemic caster haste/white ceiling
- **P1:** Ice Block → `iceBlockTimer`; Ice Lance shatter-when-rooted lite
- **P2:** Chill telegraph on Frostbolt

## Composition

Caster DPS with control niche; overlaps Arcane/Fire. Without real Elemental, Frost’s unique beat is mostly Nova+Veins.

## Proposed tunings

| Spec | Change | Why |
|------|--------|-----|
| frostMage | Spawn temporary pet on Water Elemental **or** rename to “Frozen Orb / Veins Burst” | honest fantasy |
| shared | selfBuff haste double-dip | systemic |
