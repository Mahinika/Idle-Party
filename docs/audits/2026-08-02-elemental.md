# Class audit report — Elemental Shaman

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; mid-band sim notes; no fresh browser playtest)  
**Specs in scope:** `elemental`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Elemental is one of the **healthiest kit-path casters**: Lightning Bolt, Lava Burst, Chain Lightning (real hop path), Thunderstorm rain, Elemental Mastery, Earth Shock signature, Astral Shift. Mail fantasy + AL 4 unlock. Mid Prot+Disc share **~44% (in band)** — unlike peer cloth casters. No kit wiring P0. Verdict **ship** for kit; watch healer-swap sims where share climbs.

## Audit DoD

- [x] Identity / buckets / wiring / VFX hooks
- [x] Range / gear / unlock / pet N/A
- [x] Sims / modes / pitch

---

### `HeroSpecId.elemental` — ELE

**Verdict:** ship  
**Depth:** full  
**Wowhead role page family:** caster-dps  
**Has pet/guardian?** no (totems N/A for idle)

#### Wowhead sources

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Elemental LB/LvB/CL feel | y |
| Rotation / CDs | https://www.wowhead.com/wotlk/guide/classes/shaman/elemental/dps-rotation-cooldowns-abilities-pve | y (structure) |
| Talents | identity only | n |

#### 1. Overview

| | WotLK | Idle today | Gap |
|--|-------|------------|-----|
| Fantasy | Mail lightning / lava caster | Mail ranged caster | covered |
| Role | Ranged DPS | caster | covered |
| **Strengths** | CL AoE, LvB, EM | CL hops; LvB; EM; Storm | covered |
| **Weaknesses** | Fragile vs cloth? / totem care | Astral Shift; mail | covered |
| Utility | Totems / interrupts | Earth Shock as nuke (no interrupt) | partial |

**WotLK identity score:** **4 / 5**

**Player pitch:**  
> Mail stormcaster — Lightning Bolts and Lava Bursts, Chain Lightning hops packs, Elemental Mastery for burns.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Lightning Bolt | lightningBolt | present |
| Maintain | Flame Shock | none | OK-to-drop / weak |
| Finisher | Lava Burst | lavaBurst | present |
| AoE | Chain Lightning / Thunderstorm | CL + thunderstorm | present |
| Offensive CD | Elemental Mastery | elementalMastery | present |
| Defensive | — / shamanistic | astralShift | present |
| Control | Thunderstorm knock | thunderstorm AoE | present |
| Party util | Totems | none | OK-to-drop |
| Proc | — | — | N/A |

**Must-keep:** LB, Lava Burst, Chain Lightning, EM.  
**OK-to-drop:** Totem weaving, Shock interrupt micro.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Kit path | `_tickSpecKit` | OK |
| Passive | elementalFocus out×0.68 haste×1.05 | OK |
| CL | dedicated `_chainLightning` hop | **strong** |
| Thunderstorm | `_rainBolts` | OK |
| Unlock | AL 4 | OK |
| Armor | mail (`loot_equip_audit_test`) | OK |

**Abilities**

| AbilityId | Unlock | Path | Bucket | Notes |
|-----------|--------|------|--------|-------|
| elementalFocus | 1 | passive | util | OK |
| lightningBolt | 3 | runner dmg | ST | lightning |
| lavaBurst | 5 | runner dmg | ST | fire bolt |
| chainLightning | 7 | runner AoE hops | AoE | signature feel |
| thunderstorm | 9 | rain AoE | AoE/control | OK |
| elementalMastery | 11 | selfBuff | CD | PI+haste |
| earthShock | 13 | runner dmg | signature | interrupt fantasy → nuke OK |
| astralShift | 15 | emergencyDefend | def | OK |

#### 4. Range / AI — ok 4.0/5.0; AoE pack-gated

#### 5. Gear / unlock — mail caster; AL 4; ELE ok

#### 6. Content contexts — offline/modes ok; no soft-lock; perf OK

#### 7. Live read

| Band | Share | DPS | Note |
|------|-------|-----|------|
| mid Prot+Disc | **43.6%** (fair) | 240 | clear 42% — best caster peer here |
| mid ProtPala+Holy | 58.9% HIGH | 252 | healer-swap outlier |

#### 8. Assets & VFX

Shaman sprite; lightning/fire/nature styles for LB/LvB/CL/Storm — ok. Tests cover CL/LvB styles.

#### 9. Findings

- **P0:** none for kit wiring
- **P1:** Optional Flame Shock maintain for LvB fantasy; watch ProtPala+Holy HIGH share
- **P2:** Earth Shock interrupt telegraph (flavor)

## Composition

Clear mail caster DPS; less cloth overlap; good party fit. Synergy niche vs Enh melee.

## Proposed tunings

Only if systemic caster pass still needed under other healers — prefer shared selfBuff haste fix over ELE-only nerfs.
