# Class audit report — Discipline Priest

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code + mid-band sim; no fresh browser playtest)  
**Specs in scope:** `discipline`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `6d23109`  
**Playtest?** partial — mid-band sim (Prot+Fire · Disc vs other healers)

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Discipline is **recognizable** (PW:S, PoM, Penance, Fort, PS, PI, Inner Fire) and fully wired on the legacy healer ticker, but mid-band healing **fails the role job**: Disc clear 25% / party HP 24% vs Holy Pala 58% / 95%. Root cause: **Penance is DPS-first with a single weak side-heal**, so the signature heal channel under-delivers when the party is dying. Verdict before fix: **tune** (P0 heal-mode Penance + absorb/heal throughput).

## Audit DoD

- [x] Wowhead links filled (or N/A + reason)
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Heal triage
- [x] Gear / armor fantasy
- [x] Unlock / roster / PARTY / copy
- [x] Multi-chamber + boss (code-path; same ticker)
- [x] Offline path (same `_tickPriestAbilities`)
- [x] Assets + VFX
- [x] A11y spot-check (chips readable from prior)
- [x] Identity score + verdict
- [x] All P0 listed
- [x] Live meter notes (from mid sim)
- [x] Tunings concrete if proposed
- [x] Pet N/A
- [x] Composition / modes / save / perf / pitch

---

### `HeroSpecId.discipline` — DISC

**Verdict:** ship (P0 heal-mode Penance + throughput closed same session)  
**Depth:** full (code + sim)  
**Wowhead role page family:** healer  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | (JS-thin fetch; used Wrath Disc identity: absorb + Penance) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/priest/discipline/healer-rotation-cooldowns-abilities-pve | y (structure) |
| Talents / builds (identity only) | skipped | n |

Patch note on Wowhead page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (Wrath) | Idle Party today | Gap |
|--|---------------|------------------|-----|
| Fantasy one-liner | Cloth absorb healer: bubbles, Penance, PI | Cloth mana healer with shields + holy bolts | covered |
| Role job | Prevent damage + efficient triage | `SpecRoleTag.healer`, meter H | **weak mid** — party dies |
| **Strengths** | PW:S, Penance heal, PoM, PS, PI | PW:S / PoM / PS / PI / Fort present | Penance heal **partial** |
| **Weaknesses** | Weaker pure throughput vs Holy; mana | Mid sim shows **worse** throughput than Holy Pala | weakness **inverted** (too weak) |
| Party utility | Fort, PI | Fort + PI wired | covered |

**WotLK identity score:** **3 / 5**  
(Looks Disc; Penance heal fantasy incomplete.)

**Player pitch:**  
> Cloth absorb healer — shields the party, Penances the hurt, and PI’s the carry.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Smite (optional) | Penance damage mode | present (too dominant) |
| **Maintain / DoT / buff** | PW:S, Inner Fire | PW:S, Inner Fire | present |
| **Finisher / dump** | — | Flash Heal | present (reactive) |
| **AoE / cleave** | Prayer of Healing (raid) | PoM bounce | present (idle-OK) |
| **Offensive CD** | Power Infusion | PI | present |
| **Defensive / emergency** | Pain Suppression | PS @ <32% | present |
| **Control** | — | N/A | N/A |
| **Party utility** | Fortitude | Fort | present |
| **Proc / reaction** | PoM bounce | PoM on hit | present, idle-safe |

**Must-keep for idle:** PW:S, Penance **heal**, Flash, PS.  
**OK-to-drop:** Weakened Soul weaving, Grace stacks, hymn channels.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | healer / `HeroRole.healer` — OK |
| Resource + regen | mana via `rage` pool; ~7/s in combat + spirit/mp5 |
| Resource edge cases | can starve if Penance+Flash+Shield spam — OK not soft-lock |
| Kit path | legacy `_tickPriestAbilities` |
| Baseline | Inner Fire → `kitHealMul=1.28`, `kitInMul=0.94` |
| Unlock curve | L1 Inner … L15 PI |
| Wiring overall | **gaps** on Penance heal priority |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|------------|--------|-------|
| innerFire | 1 | passive | 0 | 0 | spatial passive | no | Inner Fire | maintain | OK |
| powerWordShield | 3 | filler | 7 | 20 | spatial absorb | yes | PW:S | maintain | skip if absorb>4 |
| prayerOfMending | 5 | filler | 9 | 18 | spatial + bounce | yes | PoM | AoE/react | OK |
| penance | 7 | signature | 8 | 28 | spatial bolts + 1 side heal | yes | Penance | ST/heal | **P0** DPS-first |
| powerWordFortitude | 9 | filler | 30 | 25 | spatial buff | yes | Fort | util | +12% max HP / 20s |
| flashHeal | 11 | filler | 5 | 22 | spatial heal | yes | Flash Heal | dump | only if HP\<75% |
| painSuppression | 13 | emergency | 40 | 10 | spatial DR | yes | Pain Supp | def | \<32% HP |
| powerInfusion | 15 | signature | 55 | 15 | spatial haste | yes | PI | CD | partyStable gate |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| preferredRange / attackRange | backline | 3.2 / 4.0 | ok |
| Target selection | triage lowest | PW:S/Flash/PoM lowest; Penance needs enemy | **wrong** for heal Penance |
| Healer triage | emergency first | PS → Fort → Shield → Flash → PoM → PI → Penance | ok order; Penance heal missing |
| Full-HP spam | avoid | Flash\<75%, Shield\<92% | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| armorTypes | cloth | ok |
| Unlock | starter (New Game party) | ok |
| Roster / PARTY | selectable starter | ok |
| shortLabel | DISC | ok |
| Guides | starter trio mentions Disc | ok |

#### 6. Content contexts

| Context | Status | Notes |
|---------|--------|-------|
| Multi-chamber / boss | ok | same ticker |
| Offline / AFK | ok | same path |
| FARM / PUSH | **weak mid** | Disc HP/clear lag Holy Pala |
| Challenges | N/A skim | |
| Save / migrate | ok | legacy healer |
| Perf | ok | 3 Penance bolts; reducedVfx OK |

#### 7. Pet / guardian

N/A

#### 8. Live read (mid sim · Prot+Fire · F5)

| Signal | Observed |
|--------|----------|
| Healer table | Disc 25% clear / 24% partyHP; HolyPala 58% / 95%; RSham 67% / 71% |
| Role red flags | Disc cannot keep party alive mid |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Hero sprite | ok | `CustomAssets.heroHealer` |
| HUD chips | ok | Shield / PoM / Penance / Flash / PS / PI |
| Bolts | ok | `SpellBoltStyle.holy` |
| PW:S bubble | ok | burst on target |
| PS / PI / Fort | ok | floaters + rings |
| reducedVfx | ok | |

**A11y:** ok (prior chip sessions)

#### 10. Numbers / pacing

| Check | Notes | Status |
|-------|-------|--------|
| vs peer healers | Disc ≪ Holy Pala mid clear/HP | **fail** |
| Penance heal | ~0.9 ATK once / 8s | **too low** |
| PW:S | ~1.92 ATK / 7s | light for mid |
| Flash | 1.4×kitHeal / 5s if \<75% | reactive |

**Proposed tunings (Idle fields only):**
1. **P0** Penance: heal-channel when ally \<85% (3 ticks × kitHealMul); damage mode when party stable
2. PW:S shield mul ↑; Flash threshold/coeff; Inner Fire heal mul ↑ slightly
3. Penance catalog `effect` stays dual-purpose; heal path uses `kitHealMul`

#### 11. Composition fit

| Check | Status |
|-------|--------|
| Clear healer job | **weak** until P0 |
| Overlap with Holy | OK if Disc = absorb/PI and Holy = throughput |
| Soft hole if Disc is only heal | **yes mid** — P0 |

## P0 / P1 backlog

- **P0:** Penance heal-mode when party injured (3 heal ticks with `kitHealMul`); stop requiring enemy-only cast for triage
- **P0:** Raise Disc absorb/heal baseline (PW:S, Flash, Inner Fire) so mid partyHP approaches Holy Pala ballpark
- **P1:** Optional Weakened Soul / Grace fantasy (skip for idle)
- **P2:** Guide blurb calling out absorb-first play

## Fix log (same session)

- Penance: heal-channel (3 ticks × `kitHealMul`) when ally \<85%; damage mode when stable
- PW:S / Flash / PoM / Inner Fire throughput bump; Penance CD/cost eased
- Mid healer probe after fix (Prot+Fire · F5): Disc **42% clear / 99% partyHP** (was 25% / 24%)
- Kit tests green; verdict → **ship** (minor P1 optional)
