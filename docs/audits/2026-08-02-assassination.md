# Class audit report — Assassination Rogue

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only)  
**Specs in scope:** `assassination`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims; no fresh browser pass

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Assassination is a **poison/dagger kit on paper** (Improved Poisons, Mutilate, Envenom, Garrote, Rupture, Cold Blood, Vendetta, Cloak) fully on the shared runner. **Poisons/bleeds are not real maintains** (instant damage + passive kitOut), and **Slice and Dice is absent**. Finisher Envenom + Vendetta CD exist. Mid share mild-low (~44%); Prot+Disc mid left ASSN at **53% HP** (fragile). Verdict: **tune**.

## Audit DoD

- [x] Full report-only DoD

---

### `HeroSpecId.assassination` — ASSN

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** melee-dps  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Assassination feel (Mut / Envenom / Rupture / Hunger / Vendetta-era CB) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/rogue/assassination/dps-rotation-cooldowns-abilities-pve | y (structure; JS-thin) |
| Talents / builds | skipped | n |

Patch note on guide: 3.4.3

#### 1. Overview

| | WotLK | Idle Party today | Gap |
|--|-------|------------------|-----|
| Fantasy one-liner | Poison dagger finisher | Leather energy melee | partial |
| Role job | Melee DPS | meleeDps / energy | covered |
| **Strengths** | Poisons; Mut; Envenom; Hungry? | Mut / Env / Vendetta / CB | weak poisons |
| **Weaknesses** | Squishy; energy | Cloak DR; energy 11/s | covered |
| Party utility | Tricks | — | missing |

**WotLK identity score:** **3 / 5**  
**Player pitch:**  
> Poison dagger rogue — Mutilates, Envenoms, and Vendettas marked prey.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Mutilate | Mutilate | present |
| Maintain | SnD, Rupture, poisons | Rupture/Garrote instant; poisons passive | **weak** |
| Finisher | Envenom | Envenom | present |
| AoE | Fan of Knives | — | missing |
| Offensive CD | Cold Blood, Vendetta (later) | CB + Vendetta | present |
| Defensive | Cloak, Evasion | Cloak emergency | present |
| Control | Garrote silence feel | Garrote dmg | weak |
| Party utility | Tricks | — | missing |
| Proc | Deadly Brew | passive poisons | weak |

**Must-keep:** Mutilate, Envenom, poison/Rupture feel, SnD or haste maintain, Cloak.  
**OK-to-drop:** Hunger For Blood micro, Expose Armor.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Passive | improvedPoisons kitOut×1.40 | strong flat; not DoT |
| Vendetta/Cold Blood | selfBuff → combustion/haste paths | OK-ish amp |
| SnD | absent | **P1** |
| Fan of Knives | absent | P1 AoE |
| Kit path | AbilityEffectRunner | OK |

#### 4–6. Range / gear / contexts

Melee 1.2/1.8; leather; AL3 — ok. Fragile mid HP% 53 on Prot+Disc — watch PUSH deaths.

#### 7. Live read (sims)

| Band | Share | DPS | Note |
|------|-------|-----|------|
| mid Prot+Disc | 44.1% | 123 | mild under; **hp 53%** |
| mid ProtPala+Holy | 44.0% | 113 | fair |

#### 8. Assets & VFX

Custom rogue (shared with Sub/Combat) — muddy. No poison tick telegraph — weak. Cloak = shield ring — weak.

#### 9. Findings

- **P0:** none hard wire break; if SnD+poison DoTs treated as must-keep → elevate maintain to P0. Here **P1** with identity score 3.
- **P1:** Slice and Dice maintain; Rupture/Garrote DoTs; Fan of Knives; poison VFX; survivability crumb.
- **P2:** Tricks; spec tint vs Combat/Sub.

**Pet:** N/A

## Composition fit

ST poison melee — clear vs Combat cleave if maintains land; currently muddy vs Sub (both leather energy).

## Proposed tunings

| Spec | Ability | Change | Why |
|------|---------|--------|-----|
| assassination | SnD | maintain haste buff | must-feel |
| assassination | Rupture | DoT | bleed cycle |
| assassination | kitIn or Cloak | mild ↑ | mid hp% 53 |

## Test gaps

- [ ] Envenom after builders
- [ ] Vendetta window amp

## Compared to previous audit

**Previous:** none · **Delta:** first Assassination sheet.
