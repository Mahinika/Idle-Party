# Class audit report — Restoration Shaman

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid-band sim from `tool/out`)  
**Specs in scope:** `restorationShaman`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid healer table flags **LOW HP**; no fresh browser pass  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Resto Shaman **names** the Wrath loop (Riptide, Healing Wave, Chain Heal, Earth Shield, NS) and is fully on the kit runner, but **Chain Heal / Healing Rain / Spirit Link are single-target `heal`** — no bounce, no ground AoE, no party mend. Latest mid sweep: **33% clear / 21% partyHP** (LOW HP outlier). Wiring works (casts fire); throughput fantasy for the AoE healer is **hollow**. Verdict: **tune** (near-WIP on identity).

## Audit DoD

- [x] Wowhead links / identity
- [x] Buckets / inventory / wiring
- [x] Range / triage
- [x] Gear / unlock / copy
- [x] Content contexts / offline / modes / save / perf
- [x] Assets / VFX code
- [x] Mid sim + composition + pitch
- [x] P0 listed · report only

---

### `HeroSpecId.restorationShaman` — RSHA

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** healer  
**Has pet/guardian?** no (totems N/A as combat pets)

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | https://www.wowhead.com/wotlk/guide/classes/shaman/restoration/healer-pve-guide | y (structure; JS-thin) |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/shaman/restoration/healer-rotation-cooldowns-abilities-pve | y |
| Talents (identity only) | skipped | n |

Patch note on Wowhead rotation page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Mail Chain Heal raid healer + Earth Shield tank + totems | Mail mana healer with ST pulses + absorb | **missing** Chain bounce |
| Role job | AoE heal + utility | `SpecRoleTag.healer` | job **weak mid HP** |
| **Strengths** | Chain Heal; Riptide→Tidal Waves; Earth Shield; totems | Riptide / Wave / Chain / EShield / NS names | Chain **partial** |
| **Weaknesses** | Jack of all trades; low personal defensives | Mid partyHP **21%** | weakness **inverted** (too weak) |
| Party utility | Totems, Purge, etc. | none | missing |

**WotLK identity score:** **2 / 5**  
(Readable names; signature AoE heal bucket empty.)

**Player pitch:**  
> Mail Chain healer — Riptide and Earth Shield the tank, bounce Chain through the party, NS when someone is about to drop.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler** | Healing Wave, LHW | Healing Wave | present |
| **Maintain** | Earth Shield, Water Shield, Riptide HoT | Earth Shield absorb; Riptide pulse | partial |
| **Finisher** | — | — | N/A |
| **AoE** | Chain Heal (+ Riptide consume) | Chain Heal **ST**; Healing Rain **ST** | **missing** |
| **Offensive CD** | — | — | N/A |
| **Defensive / emergency** | Nature’s Swiftness + HW | Nature’s Swiftness emergencyHeal | present |
| **Control** | Hex / interrupts | none | OK-to-drop |
| **Party utility** | Totems, Mana Tide | none | missing |
| **Proc / reaction** | Tidal Waves | none | missing (idle-OK) |

**Must-keep for idle:** Earth Shield, Riptide, Chain Heal (multi), NS.  
**OK-to-drop:** Totem swaps, Tidal Waves stacks, Earthliving weapon uptime micromanagement.  
**Note:** Healing Rain / Spirit Link are post-Wrath names — OK as idle signatures if they **actually** party-heal.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Role | healer — OK |
| Armor | mail — OK |
| Resource | mana kit regen |
| Kit path | AbilityEffectRunner |
| Passive | Ancestral Awakening → `kitHealMul *= 1.32` |
| Unlock | AL≥3 |
| Wiring overall | casts OK; **AoE heal path missing** |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | WotLK / name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|--------------|--------|-------|
| ancestralAwakening | 1 | passive | 0 | 0 | passive | no | Ancestral Awakening | maintain | heal mul |
| riptide | 3 | filler | 5.5 | 14 | heal | yes | Riptide | maintain | pulse, not HoT |
| healingWave | 5 | filler | 5 | 18 | heal | yes | Healing Wave | ST | |
| chainHeal | 7 | filler | 7 | 24 | heal | yes | Chain Heal | AoE | **P0** no bounce (`chain` hop is damage-only) |
| earthShield | 9 | filler | 10 | 20 | absorb | yes | Earth Shield | maintain | OK absorb stand-in |
| healingRain | 11 | filler | 12 | 28 | heal | yes | Healing Rain (post-Wrath) | AoE | **P0** ST despite copy |
| spiritLink | 13 | signature | 40 | 25 | heal | yes | Spirit Link (post-Wrath) | CD | ST; long-CD gate |
| natureSwiftness | 15 | emergency | 55 | 0 | emergencyHeal | yes | Nature’s Swiftness | def | OK panic |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| Range | backline | 3.2 / 4.0 | ok |
| Triage | lowest + NS | `_lowestAlly`; emergency ≤32% | ok |
| Pack heal | Chain bounce | single lowest only | **wrong** |
| Full-HP spam | avoid | heal `<92%` | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| Armor | mail | ok |
| Unlock | AL 3 | ok |
| shortLabel | RSHA | ok |
| Chips | Rip / Wave / Chain / EShield / Rain / Link / NS | ok names / false AoE copy |
| Guides | thin | N/A |

#### 6. Content contexts

| Context | Status | Notes |
|---------|--------|-------|
| Multi-chamber / boss | ok / Link gated | |
| Offline | ok | same runner |
| **FARM / PUSH** | **LOW HP 21%** latest | verify wiring → AoE hollow |
| Save / migrate | ok | |
| Perf | ok | |

#### 7. Pet / guardian

N/A (no totem actors)

#### 8. Live read *(mid · Prot+Fire · F5 · latest)*

| Signal | Observed |
|--------|----------|
| clear / wipe / partyHP | **33% / 67% / 21%** — **LOW HP** flag |
| Fires | ST heals + EShield; NS on crit |
| Never as fantasy | Chain bounce; Rain AoE; Link party |
| Note | older `mid_final` had RSham high HP / low clear — **variance**; single-target “AoE” is structural |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Sprite | ok | `CustomAssets.heroShaman` |
| Class bolt | lightning default | heals use heal sparks (OK) |
| Chain | **silent bounce** | no hop VFX (because no hop) |
| Rain | weak | single spark, not ground zone |
| Link / NS | ok / weak | |
| reducedVfx | ok | |

**A11y:** RSHA OK. Status: ok

**VFX findings:** P0 — Chain hop telegraph when multi-heal lands; P1 — Rain ground ring.

#### 10. Findings

- **P0:** Implement Chain Heal as multi-ally bounce (2–3 lowest) — must-keep Wrath bucket; current ST heal explains mid HP collapse under pack damage
- **P0:** Healing Rain / Spirit Link should heal multiple injured allies (or stop advertising AoE/party)
- **P1:** Riptide as short HoT or Chain amplify mark; healer-friendly signature CD gate
- **P1:** Re-sim mid after multi-heal + post-Disc table refresh
- **P2:** Totem / Mana Tide party utility crumb; Earthliving rename skip

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job | AoE / Chain healer | **muddy** until bounce |
| Overlap HPriest | both want pack heals | redundant if both ST |
| Hole if missing | mid party soft (sim) | **party soft** |

## Cross-party balance

| Spec | Meter | vs peers | Verdict |
|------|-------|----------|---------|
| restorationShaman | 33% clear / **21% HP** | under HP | **tune** |

## P0 / P1 backlog

1. Chain Heal bounce (multi-ally)
2. Rain / Link multi-heal
3. Mid re-sim + optional Riptide mark

## Proposed tunings

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| restorationShaman | chainHeal | ST heal → bounce 2–3 allies | Wrath AoE bucket |
| restorationShaman | healingRain | ST → heal all heroes in radius / lowest N | Rain copy |
| restorationShaman | spiritLink | ST → party mend | signature |
| restorationShaman | riptide.coeff / HoT | mild ↑ or tick HoT | mid HP |

## Explicitly out of scope

BiS / totem theorycraft spreadsheets / Wowhead numbers / PvP.

## Test gaps

- [ ] Chain Heal hits ≥2 allies
- [ ] Mid healer HP ≥ peer band after fix
- [ ] Wiring / cast smoke for RSHA offline

## Compared to previous audit

**Previous:** none · **Delta:** first sheet; user flagged weak mid HP — **confirmed** in latest table + hollow AoE wiring

## Out of scope / follow-ups

- Shared party-heal effect kind
- Totem actors (large scope)
