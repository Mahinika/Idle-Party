# Class audit report — Retribution Paladin

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only)  
**Specs in scope:** `retribution`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid sims; no fresh browser pass

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Ret is a **solid holy-plate melee kit**: Seal, Crusader Strike, Judgment, Divine Storm, Hammer of Wrath (execute-gated), Zealotry, Templar’s Verdict, Divine Shield — all wired with holy bolt styles. Wrath used Avenging Wrath more than Zealotry/TV (Cata names), but idle buckets are filled. Mid share fair (~46%). Verdict: **ship** with light identity polish.

## Audit DoD

- [x] Full DoD checklist covered for report-only

---

### `HeroSpecId.retribution` — RET

**Verdict:** ship  
**Depth:** full  
**Wowhead role page family:** melee-dps  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath Ret feel (CS / Judgment / DS / HoW / AW) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/paladin/retribution/dps-rotation-cooldowns-abilities-pve | y (structure; JS-thin) |
| Talents / builds | skipped | n |

Patch note on guide: 3.4.3

#### 1. Overview

| | WotLK | Idle Party today | Gap |
|--|-------|------------------|-----|
| Fantasy one-liner | Holy plate crusader | Plate melee holy strikes | covered |
| Role job | Melee DPS | meleeDps / mana | covered |
| **Strengths** | Art of War procs; DS AoE; HoW execute; AW burst | CS / DS / HoW / Zeal / TV | covered (no AoW proc — OK) |
| **Weaknesses** | Mana; gap close | mana 9/s; no charge | still true |
| Party utility | Blessings / Judgments | — | **missing** |

**WotLK identity score:** **4 / 5**  
**Player pitch:**  
> Holy plate crusader — Crusader Strikes, Divine Storms, and Hammers the dying.

#### 2. Rotation shape

| Bucket | WotLK | Idle | Status |
|--------|-------|------|--------|
| ST filler | Crusader Strike | CS | present |
| Maintain | Seal / Judgments | Seal passive + Judgment hit | weak/partial |
| Finisher | HoW; TV (later) | HoW execute + TV | present |
| AoE | Divine Storm | Divine Storm | present |
| Offensive CD | Avenging Wrath | Zealotry haste | present (name drift OK) |
| Defensive | Divine Shield / Prot | Divine Shield emergency | present (DR not true bubble) |
| Control | HoJ | — | missing OK |
| Party utility | Blessings | — | missing |
| Proc | Art of War | — | OK-to-drop |

**Must-keep:** CS, Divine Storm, HoW, offensive CD, Seal feel.  
**OK-to-drop:** AoW weave, Exorcism, sacred shield PvE micro.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Passive | sealOfCommand kitOut×1.38 | OK |
| Resource | mana via rage pool | OK |
| HoW | `_isExecuteAbility` explicit | OK |
| TV | signature ST dump | OK |
| Divine Shield | emergencyDefend → shieldWall | weak vs true immunity |

**Abilities:** sealOfCommand, crusaderStrike, judgment, divineStorm, hammerOfWrath, zealotry, templarsVerdict, divineShield — all runner paths OK; holy VFX for DS/CS/HoW/Judge.

#### 4–6. Range / gear / contexts

Melee 1.25/1.8; plate; unlock King’s Tomb — ok. Offline shared runner — ok. Mid clear 50% Prot+Disc (HIGH CLEAR outlier) with fair share — identity readable.

#### 7. Live read (sims)

| Band | Share | DPS | Note |
|------|-------|-----|------|
| mid Prot+Disc | 46.2% | 155 | fair |
| mid ProtPala+Holy | 45.4% | 127 | clear 0% (support) |

#### 8. Assets & VFX

Custom paladin; holy bolts/rings — ok. Bubble telegraph = generic shield ring — weak but readable.

#### 9. Findings

- **P0:** none (wiring + buckets OK; numbers in band).
- **P1:** Divine Shield as true immunize/iceblock-style; Blessing party crumb; Judgment maintain telegraph.
- **P2:** Rename Zealotry→Avenging Wrath for Wrath copy; TV acceptable as idle finisher.

## Composition fit

Clear holy melee DPS; overlaps Arms/Fury thematically but VFX distinct — ok.

## Proposed tunings

None required for ship; optional bubble fidelity.

## Test gaps

- [ ] HoW only ≤25% HP
- [ ] Divine Storm pack preference

## Compared to previous audit

**Previous:** none · **Delta:** first Ret sheet.
