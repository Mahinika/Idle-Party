# Class audit report — Enhancement Shaman

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only)  
**Specs in scope:** `enhancement`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims; no fresh browser pass

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Enhancement is a **mail melee storm kit** (Stormstrike, Lava Lash, Fire Nova, Frost Shock, Shamanistic Rage, Astral Shift) with readable fire/frost/lightning VFX. **Feral Spirit is a haste selfBuff, not spirit wolves** — the Wrath pet-window identity is missing. Maelstrom/LB weave is absent (acceptable for idle). Mid share ~40% (mild low). Verdict: **tune**.

## Audit DoD

- [x] Full report-only DoD

---

### `HeroSpecId.enhancement` — ENH

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** melee-dps  
**Has pet/guardian?** **yes in Wrath (Feral Spirit) — Idle: no** (buff only)

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Enh feel (SS / LL / Maelstrom / Spirits) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve | y (structure; JS-thin) |
| Talents / builds | skipped | n |

Patch note on guide: 3.4.3

#### 1. Overview

| | WotLK | Idle Party today | Gap |
|--|-------|------------------|-----|
| Fantasy one-liner | Dual-wield totemic melee; wolf CD | Mail melee shocks + strikes | partial |
| Role job | Melee DPS | meleeDps / mana / legacy rogue | covered |
| **Strengths** | Stormstrike; Fire Nova; Feral Spirit; SR | SS / LL / Nova / SR | **partial** (no wolves) |
| **Weaknesses** | Squishy melee; melee range | Astral DR; preferredRange 1.3 | covered |
| Party utility | Totems / Heroism | — | missing |

**WotLK identity score:** **3 / 5**  
**Player pitch:**  
> Mail storm dual-wielder — Stormstrikes, Lava Lashes, and Fire Novas the pack.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Stormstrike, Lava Lash | SS, LL | present |
| Maintain | Flametongue / WF / shocks | Enhanced Weapons passive | weak |
| Finisher | Maelstrom → LB | — | missing (OK idle) |
| AoE | Fire Nova, Magma | Fire Nova | present |
| Offensive CD | Feral Spirit | feralSpirit **haste buff** | **weak / missing pets** |
| Defensive | Shamanistic Rage, Astral | SR grantResource + Astral emergency | present |
| Control | Frost Shock, Wind Shear | Frost Shock root | present |
| Party utility | Totems / BL | — | missing |
| Proc | Maelstrom Weapon | — | OK-to-drop |

**Must-keep:** Stormstrike, Lava Lash, Fire Nova, Feral Spirit *feel*, SR.  
**OK-to-drop:** LB weave, Wind Shear, totem micromanagement.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Passive | enhancementWeapons kitOut×1.38 | OK |
| Kit path | AbilityEffectRunner | OK |
| feralSpirit | selfBuff; name contains `spirit` → haste | **not pets** |
| shamanisticRage | signature grantResource 30 | OK |
| Wiring | fireNova / frostShock VFX tested in `spell_vfx_test` | OK |

**Abilities:** enhancementWeapons, stormstrike, lavaLash, fireNova, feralSpirit, frostShock, shamanisticRage, enhancementAstral — all resolve.

#### 4–6. Range / gear / contexts

Melee 1.3/1.9; mail; unlock AL4 — ok. Mid clear 58% HIGH with share 40% — durable but mild under-DPS.

#### 7. Live read (sims)

| Band | Share | DPS | Note |
|------|-------|-----|------|
| mid Prot+Disc | 40.0% | 164 | mild under median |
| mid ProtPala+Holy | 44.5% | 126 | fair |

#### 8. Assets & VFX

Custom shaman; Fire Nova / Frost Shock / Stormstrike styles — ok. No wolf sprites — **P1**.

#### 9. Findings

- **P0:** none hard soft-lock; pet window is identity **P1** (elevate if treating Enh as pet-family).
- **P1:** Feral Spirit combat pets or distinct pet-window VFX/meter; mild kitOut/coeff bump for share; Windfury telegraph.
- **P2:** Heroism party crumb; Maelstrom optional.

**Pet / guardian:** Wrath Feral Spirit = temporary wolves. Idle: **missing** (haste only). Status: **missing**.

## Composition fit

Melee DPS with unique mail/shock niche — clear. No party Heroism — ok for idle.

## Proposed tunings

| Spec | Field | Change | Why |
|------|-------|--------|-----|
| enhancement | feralSpirit | spawn timed pets or unique burst | Wrath CD identity |
| enhancement | kitOut / coeffs | mild ↑ | share ~40% |

## Test gaps

- [ ] Feral Spirit pet if added
- [ ] Fire Nova pack gate

## Compared to previous audit

**Previous:** none · **Delta:** first Enh sheet.
