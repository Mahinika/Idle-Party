# Class audit report — Restoration Druid

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid-band sim from `tool/out`)  
**Specs in scope:** `restorationDruid`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid healer table flags **LOW CLEAR 0%**; no fresh browser pass  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Resto Druid has the **HoT-kit names** (Rejuv, Regrowth, Wild Growth, Lifebloom, Nourish, Tranq) on the shared runner, but Wild Growth / Tranquility are **single-target heals**, Tree of Life heal mul is **weaker** than peer healer passives (1.18 vs 1.32), and the emergency is **Barkskin (`emergencyDefend`)** — on ally-crit it **self-DRs instead of healing**, consuming the panic slot. Latest mid: **0% clear / 100% wipe**. Verdict: **WIP**.

## Audit DoD

- [x] Wowhead links / identity
- [x] Buckets / inventory / wiring
- [x] Range / triage (**emergency wrong**)
- [x] Gear / unlock / copy
- [x] Content / offline / modes / save / perf
- [x] Assets / VFX code
- [x] Mid sim + composition + pitch
- [x] P0 listed · report only

---

### `HeroSpecId.restorationDruid` — RDRU

**Verdict:** WIP  
**Depth:** full  
**Wowhead role page family:** healer  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | https://www.wowhead.com/wotlk/guide/classes/druid/restoration/healer-pve-guide | y (structure; JS-thin) |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/druid/restoration/healer-rotation-cooldowns-abilities-pve | y |
| Talents (identity only) | skipped | n |

Patch note on guide family: 3.4.x

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Leather HoT raid healer: WG blanket, Rejuv, Lifebloom tank, NS+HT panic | Leather mana healer with weak ST pulses + self Barkskin | **missing** HoT blanket + panic heal |
| Role job | Raid HoTs + smart AoE | `SpecRoleTag.healer` | **fail mid** (0% clear) |
| **Strengths** | Wild Growth; Rejuv blanket; Lifebloom; Swiftmend | Names present | WG **partial** (ST) |
| **Weaknesses** | Weaker pure ST than HPal | Mid wipe table; weak coeffs + wrong emergency | weakness **amplified** |
| Party utility | Innervate, Rebirth, Mark | none | missing |

**WotLK identity score:** **2 / 5**

**Player pitch:**  
> Leather HoT healer — blanket Wild Growth and Rejuv, Lifebloom the tank, Tranq the spike — *not live yet*.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler** | Nourish, Regrowth | Nourish, Regrowth | present (low coeff) |
| **Maintain / HoT** | Rejuvenation, Lifebloom ×3 | Rejuv pulse; Lifebloom absorb | weak |
| **Finisher** | Swiftmend | — | missing (OK→NS) |
| **AoE** | Wild Growth | Wild Growth **ST** | **missing** |
| **Offensive CD** | — | — | N/A |
| **Defensive / emergency** | NS + Healing Touch; Tranquility | Barkskin self DR; Tranq ST heal | **wrong** emergency |
| **Control** | Roots / Cyclone | none | OK-to-drop |
| **Party utility** | Innervate, Rebirth, MotW | none | missing |
| **Proc** | Omen / Clearcasting | none | OK-to-drop |

**Must-keep for idle:** Rejuv, Wild Growth (multi), Lifebloom, Nourish, Tranq, **heal** emergency (NS/Swiftmend).  
**OK-to-drop:** LB stack micromanagement, Revitalize spreadsheets, form dance.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Role | healer — OK |
| Armor | leather — OK |
| Resource | mana kit regen |
| Kit path | AbilityEffectRunner |
| Passive | Tree of Life → `kitHealMul *= 1.18` (**lowest** healer amp; peers 1.32) |
| Unlock | AL≥3 |
| Wiring | **P0** Barkskin emergency; **P0** fake AoE; weak baseline |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|------------|--------|-------|
| treeOfLife | 1 | passive | 0 | 0 | passive | no | Tree of Life | maintain | 1.18 mul **weak** |
| rejuvenation | 3 | filler | 4.5 | 12 | heal | yes | Rejuvenation | maintain | coeff **0.95**; not HoT |
| regrowth | 5 | filler | 5 | 18 | heal | yes | Regrowth | ST | |
| wildGrowth | 7 | filler | 8 | 24 | heal | yes | Wild Growth | AoE | **P0** ST despite “party” |
| lifebloom | 9 | filler | 9 | 16 | absorb | yes | Lifebloom | maintain | absorb stand-in OK-ish |
| nourish | 11 | filler | 6 | 20 | heal | yes | Nourish | ST | |
| tranquility | 13 | signature | 45 | 35 | heal | yes | Tranquility | CD | ST; long-CD gate |
| barkskinResto | 15 | emergency | 45 | 0 | **emergencyDefend** | yes | Barkskin | def | **P0** self DR on ally crit |

Emergency cast order (`allyFrac ≤ 0.32`): tries emergency tier first; Barkskin always succeeds (no heal triage) → **panic button fails the dying ally**.

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| Range | backline | 3.2 / 4.0 | ok |
| Triage | lowest + heal emergency | Barkskin self on crit | **wrong** |
| Pack heal | WG multi | ST only | **wrong** |
| Full-HP spam | avoid | heal `<92%` | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| Armor | leather | ok |
| Unlock | AL 3 | ok |
| shortLabel | RDRU | ok |
| Chips | Rejuv / Regrow / WG / Bloom / Nourish / Tranq / Bark | ok names / false party copy |
| Guides | thin | N/A |

#### 6. Content contexts

| Context | Status | Notes |
|---------|--------|-------|
| Multi-chamber / boss | soft | wrong panic + weak HPS |
| Offline | ok path / weak kit | same runner |
| **FARM / PUSH** | **0% clear** latest | **LOW CLEAR** |
| Wipe / revive | Barkskin wastes panic | weird |
| Save / migrate | ok | |
| Perf | ok | |

#### 7. Pet / guardian

N/A

#### 8. Live read *(mid · Prot+Fire · F5 · latest)*

| Signal | Observed |
|--------|----------|
| clear / wipe / partyHP | **0% / 100% / 0** — total fail |
| Fires | ST fillers; Barkskin on crit; Tranq rare (gate) |
| Never as fantasy | WG blanket; Tranq channel party; heal panic |
| Note | older `mid_final` had RDruid 58%/100% — **sim noise**; Barkskin + fake WG + low mul are hard P0s regardless |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Sprite | ok | `CustomAssets.heroDruid` |
| Bolts | nature class default | heal sparks for casts |
| WG / Tranq | weak | single spark, not party bloom |
| Barkskin | ok as self DR ring | wrong for healer emergency |
| Lifebloom | absorb ring | ok-ish |
| reducedVfx | ok | |

**A11y:** RDRU OK. Status: ok

**VFX findings:** P0 none for art legality; P1 WG multi-ally bloom rings.

#### 10. Findings

- **P0:** Replace healer emergency with heal panic (Nature’s Swiftness / Swiftmend / Healing Touch) — Barkskin must not consume ally-crit emergency as self-only DR
- **P0:** Wild Growth + Tranquility → multi-ally heals (must-keep HoT/AoE buckets)
- **P0:** Raise Tree of Life `kitHealMul` toward peer 1.32 and/or lift Rejuv/WG/Nourish coeffs — mid wipe + weakest passive
- **P1:** Real short HoT ticks for Rejuv/WG; Lifebloom bloom pop; signature CD gate exception for heal CDs
- **P2:** Innervate / Rebirth utility crumbs; Clearcasting skip

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job | HoT / raid healer | **muddy / broken mid** |
| Overlap RSham/HPriest | all want pack heals; all ST today | redundant weak |
| Hole if only RDRU heal | **party soft** (0% clear) | party soft |

## Cross-party balance

| Spec | Meter | vs peers | Verdict |
|------|-------|----------|---------|
| restorationDruid | **0% clear** | under | **WIP** |

## P0 / P1 backlog

1. Heal emergency (not Barkskin self) on ally crit
2. Wild Growth / Tranquility multi-target
3. Tree / coeff throughput floor vs Disc/HPal peers
4. Mid re-sim after fixes

## Proposed tunings

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| restorationDruid | barkskinResto | emergencyDefend → emergencyHeal *or* add NS heal + demote Bark | Panic must save ally |
| restorationDruid | wildGrowth | ST heal → heal 3–4 lowest | WG bucket |
| restorationDruid | tranquility | ST → party heal | signature |
| restorationDruid | treeOfLife mul | 1.18 → ~1.30 | peer amp |
| restorationDruid | rejuvenation.coeff | 0.95 → ≥1.1 | mid floor |

## Explicitly out of scope

BiS / haste-cap theory / glyph sheets / Wowhead numbers / PvP.

## Test gaps

- [ ] Ally ≤32%: heal emergency casts (not only self Bark)
- [ ] WG hits ≥3 allies
- [ ] Mid clear/HP in peer band vs Holy/Disc
- [ ] Offline RDRU cast smoke

## Compared to previous audit

**Previous:** none · **Delta:** first sheet; user flagged weak mid clear — **confirmed** (0%) + emergency/AoE wiring root causes

## Out of scope / follow-ups

- Shared party-heal / HoT runner primitives
- Tree form visual distinguish
