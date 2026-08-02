# Class audit report — Holy Priest

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid-band sim from `tool/out`)  
**Specs in scope:** `holyPriest`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** partial — mid healer table (Prot+Fire · F5); no fresh browser pass  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Holy Priest has the **right name kit** (Renew, Flash, CoH, GS, Hymn, DP) and led the latest mid healer clear% table, but **Holy Nova is enemy `aoe` and wins filler priority in packs**, stealing heal GCDs while party is hurt. CoH / Hymn claim splash/party and resolve as **single-ally** `heal`. Biggest gap: Nova damage-first filler under triage. Verdict: **tune**.

## Audit DoD

- [x] Wowhead links filled
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths
- [x] Range / AI / triage
- [x] Gear / unlock / roster / copy
- [x] Multi-chamber / boss / offline / modes / save / perf
- [x] Assets + VFX (code)
- [x] Identity + verdict + P0
- [x] Mid sim notes
- [x] Pet N/A / composition / pitch

---

### `HeroSpecId.holyPriest` — HPR

**Verdict:** tune  
**Depth:** full  
**Wowhead role page family:** healer  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | https://www.wowhead.com/wotlk/guide/classes/priest/holy/healer-pve-guide | y (structure; page JS-thin) |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/priest/holy/healer-rotation-cooldowns-abilities-pve | y |
| Talents / builds (identity only) | skipped | n |

Patch note on Wowhead rotation page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Cloth raid healer: CoH, PoM, Renew, GS, Hymn | Cloth mana healer with ST heals + Nova damage | partial |
| Role job | Top the raid; GS the tank | `SpecRoleTag.healer` | clear mid; AoE heal fake |
| **Strengths** | CoH / PoH / PoM AoE; GS; Hymn | CoH/Hymn/GS names present | AoE **partial** (ST resolve) |
| **Weaknesses** | Mana hungry; contested vs Disc/RDruid | Nova wastes GCDs on damage | weakness **new** (self-sabotage) |
| Party utility | Fort / Hymn of Hope | none unique (Disc owns Fort) | weak |

**WotLK identity score:** **3 / 5**

**Player pitch:**  
> Cloth raid healer — Renew and Flash the hurt, CoH the pack, Hymn when the floor drops, GS before a lethal spike.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler** | Flash Heal, Greater Heal | Flash Heal, Renew | present |
| **Maintain** | Renew, PoM | Renew (pulse heal) | weak (no true HoT tick) |
| **Finisher / dump** | — | — | N/A |
| **AoE / cleave** | Circle of Healing, Prayer of Healing | CoH (ST); Hymn (ST); Nova = **enemy AoE** | **wrong** Nova |
| **Offensive CD** | — | Holy Nova damage | accidental |
| **Defensive / emergency** | Guardian Spirit, Desperate Prayer | GS absorb; DP emergencyHeal | present / GS wrong flavor |
| **Control** | — | N/A | N/A |
| **Party utility** | Fort, Hymn of Hope | — | missing |
| **Proc / reaction** | Serendipity, Surge of Light | none | OK-to-drop |

**Must-keep for idle:** Renew, Flash, CoH (multi), GS, Hymn, DP.  
**OK-to-drop:** Serendipity stacks, Binding Heal weave, Hymn of Hope.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| Role | healer / healer — OK |
| Resource | mana ~9/s + spirit/mp5 |
| Kit path | AbilityEffectRunner `_tickSpecKit` |
| Passive | Spirit of Redemption → `kitHealMul *= 1.32` (name is fantasy-wrong; effect is heal amp) |
| Unlock | L1 Spirit … L15 DP; unlock AL≥2 |
| Wiring | **P0** Nova `aoe` preferred in packs |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|------------|--------|-------|
| spiritOfRedemption | 1 | passive | 0 | 0 | passive | no | Spirit of Redemption | util | amp only; not post-death |
| renew | 3 | filler | 5 | 14 | heal | yes | Renew | maintain | instant pulse, not HoT |
| holyPriestFlash | 5 | filler | 4 | 18 | heal | yes | Flash Heal | ST | |
| circleOfHealing | 7 | filler | 8 | 24 | heal | yes | Circle of Healing | AoE | **no splash** despite copy |
| guardianSpirit | 9 | signature | 35 | 15 | absorb | yes | Guardian Spirit | def | absorb ≠ anti-death |
| holyPriestNova | 11 | filler | 10 | 20 | **aoe (damage)** | yes | Holy Nova | AoE | **P0** pack priority |
| divineHymn | 13 | signature | 40 | 30 | heal | yes | Divine Hymn | CD | ST; long-CD gate |
| desperatePrayer | 15 | emergency | 50 | 0 | emergencyHeal | yes | Desperate Prayer | def | heals lowest (not self-only) |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| Range | backline | 3.4 / 4.2 | ok |
| Triage | lowest + emergency | heal `<92%`; DP on ≤32% | ok |
| Pack behavior | CoH/Hymn | **Nova first** when `nearby ≥ 2` | **wrong** |
| Full-HP spam | avoid | heal gate | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| Armor | cloth | ok |
| Unlock | AL 2 | ok |
| shortLabel | **HPR** (not HOLY — good vs Pala) | ok |
| Chips | Renew / Flash / CoH / GS / Nova / Hymn / DP | ok |
| Guides | thin vs Disc starter | N/A |

#### 6. Content contexts

| Context | Status | Notes |
|---------|--------|-------|
| Multi-chamber / boss | ok / weak Hymn gate | same runner |
| Offline | ok | |
| FARM / PUSH | latest mid **best clear** among healers | Nova still wrong |
| Save / migrate | ok | |
| Perf | Nova nova-strike mild | ok |

#### 7. Pet / guardian

N/A (GS is a spell, not a pet)

#### 8. Live read *(mid · Prot+Fire · F5 · latest)*

| Signal | Observed |
|--------|----------|
| clear / wipe / partyHP | **58% / 42% / 92%** — best clear in table |
| Never fire as fantasy | CoH splash; Hymn party; true GS save |
| Red flag | older `mid_final` had HPriest **weak** — variance; wiring P0 still stands |
| Peer context | Disc just buffed @ HEAD; this table may predate heal-mode Penance |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Sprite | ok | `CustomAssets.heroHealer` (shared Disc/Holy) |
| Bolts | ok | holy; Nova id → holy |
| GS absorb ring | ok | reads shield more than spirit |
| Hymn / CoH | weak | single heal spark |
| reducedVfx | ok | |

**A11y:** HPR chips OK. Status: ok

**VFX findings:** P1 — CoH/Hymn need multi-ally rings; P2 — distinguish Holy vs Disc silhouette.

#### 10. Findings

- **P0:** `holyPriestNova` must not beat heal fillers when allies are hurt (retarget as party heal, or deprioritize vs heal when `allyFrac < 0.92`)
- **P0:** `circleOfHealing` / `divineHymn` advertised as splash/party but `_castHeal` hits one ally — add multi-heal or fix copy
- **P1:** Guardian Spirit → short DR / heal-amp / anti-wipe, not only absorb
- **P1:** Spirit of Redemption rename or post-death fantasy; long-CD Hymn gate for healers
- **P2:** Serendipity idle-safe skip; Renew as real HoT ticks

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job | raid/pack healer | muddy until CoH multi |
| Overlap Disc | Disc absorb/Penance; Holy throughput/AoE | ok if Nova fixed |
| Hole if missing | covered by other heals when tuned | covered |

## Cross-party balance

| Spec | Meter | vs peers | Verdict |
|------|-------|----------|---------|
| holyPriest | 58% clear / 92% HP | over clear / fair HP | **tune** (wiring, not starve) |

## P0 / P1 backlog

1. Nova vs triage priority (or convert Nova to ally heal)
2. CoH / Hymn multi-target resolve
3. GS fantasy; Hymn CD gate for healers

## Proposed tunings

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| holyPriest | holyPriestNova | aoe damage → heal/splash *or* cast gate when ally hurt | Must not DPS while party dying |
| holyPriest | circleOfHealing | ST heal → heal 2–4 lowest | CoH bucket |
| holyPriest | divineHymn | ST heal → party heal | Hymn bucket |

## Explicitly out of scope

BiS / glyphs / talent spreads / PvP / Wowhead numbers.

## Test gaps

- [ ] Nova not cast when ally `<92%` and heal fillers ready
- [ ] CoH hits ≥2 allies
- [ ] Mid re-sim vs buffed Disc

## Compared to previous audit

**Previous:** none · **Delta:** first sheet; Disc mid buff is peer context

## Out of scope / follow-ups

- Shared `AbilityEffectKind` party-heal for all healers
