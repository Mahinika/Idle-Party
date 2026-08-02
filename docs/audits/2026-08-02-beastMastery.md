# Class audit report — Beast Mastery

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code-primary; Wowhead structure/identity only; mid sims from `tool/out/class_balance_latest.md`)  
**Specs in scope:** `beastMastery`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `851c72b`  
**Playtest?** no live dungeon glance — meter from balance sims only  

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients / talent spreads / BiS.

## Summary

BM is a **named shot kit without a beast**. Abilities wire through `AbilityEffectRunner` (arrows, Multi fan, haste buffs, root, emergency shield), but there is **no combat pet/guardian actor** tied to the spec — `Kill Command` / `Intimidation` / `Bestial Wrath` are hunter-self effects. Meta hatch pets (`state.activePet`) are party cosmetics, not BM identity. Mid Prot+Disc share is a **LOW** outlier (~38%). Verdict: **WIP**.

## Audit DoD

- [x] Wowhead links filled
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Threat N/A (DPS)
- [x] Gear / armor / unlock / roster / copy
- [x] Multi-chamber / boss / offline / modes / save / perf
- [x] Assets + VFX
- [x] Identity score + verdict
- [x] All P0 listed
- [x] Live meter notes (sims)
- [x] Pet/guardian section (required — **missing**)
- [x] Composition / pitch

---

### `HeroSpecId.beastMastery` — BM

**Verdict:** WIP  
**Depth:** full  
**Wowhead role page family:** ranged-dps  
**Has pet/guardian?** **no** (required for BM; only optional meta hatch pet)

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | Wrath BM fantasy (pet DPS + Bestial Wrath) — overview URL now redirects off-Wrath; used Wrath rotation + common Wrath guide structure | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/hunter/beast-mastery/dps-rotation-cooldowns-abilities-pve | y (structure; JS-thin) |
| Talents / builds | identity only (Beast Within / pet focus) | y |
| Other | skipped | n |

Patch note on Wowhead rotation page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | Ranged hunter whose **pet** is half the DPS | Mail bow user; **no combat pet** | **missing** |
| Role job | Ranged DPS | `SpecRoleTag.rangedDps`, mana, preferredRange 4.2 | covered |
| **Strengths** | Pet damage, Kill Command, Bestial Wrath window, simple priority | Named shots + Multi + dual haste CDs | **partial** (pet half gone) |
| **Weaknesses** | Pet deaths / positioning; mana | Feign as shield; no pet to manage | inverted / N/A |
| Party utility | Misdirection, traps, Mark | none | **missing** |

**WotLK identity score:** **2 / 5**  
(Readable shot names; core pet fantasy absent.)

**Player pitch:**  
> Mail bow DPS that should fight **with** a beast — today it shoots alone; Kill Command is just a heavy arrow.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Steady / Arcane Shot | Arcane Shot | present |
| **Maintain / DoT / buff** | Serpent Sting, Hunter’s Mark | Aspect of the Hawk (`kitOutMul`) | weak (no sting/mark) |
| **Finisher / dump** | Kill Shot | — | missing (OK-to-drop) |
| **AoE / cleave** | Multi-Shot, Volley, Explosive Trap | Multi-Shot fan bolts | present |
| **Offensive CD / burst** | Bestial Wrath (+ Beast Within), Rapid Fire, Call of the Wild | Bestial Wrath + The Beast Within (both haste) | present (self-only) |
| **Defensive / emergency** | Feign Death, Deterrence | Feign Death → `emergencyDefend` shield | **wrong** (no aggro drop) |
| **Control / kite** | Intimidation (pet stun), Concussive | Intimidation root | partial |
| **Raid / party utility** | Misdirection | — | missing |
| **Proc / reaction** | Kill Command (off-GCD pet) | Kill Command = self damage bolt | **missing pet link** |

**Must-keep for idle:** combat pet, Kill Command → pet, Bestial Wrath, ST shot, Multi.  
**OK-to-drop:** openers, trap weave, glyph/Readiness dances, hit caps, Call of the Wild as pet talent.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | rangedDps; `legacyRole: rogue` (gear/legacy map) — OK for casting via `forSpec` |
| Resource + regen | mana; kit path ~9/s near combat + spirit/mp5 | OK |
| Resource edge cases | spenders gated by rage pool; no soft-lock | OK |
| Kit path | `AbilityEffectRunner._tickSpecKit` (not legacy) | OK |
| Baseline AA / `kitOutMul` | Aspect Hawk ×1.18; arrow autos | OK |
| Unlock curve | AL ≥ 2; `unlockHint: AL 2` | OK |
| Wiring overall | casts OK; **pet identity gaps** | **gaps** |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| aspectOfHawk | 1 | passive | 0 | 0 | passive `kitOutMul` | no | Aspect of the Hawk | maintain | personal ranged power |
| arcaneShot | 3 | filler | 4 | 12 | runner damage → arrow bolt | yes | Arcane Shot | ST | OK |
| killCommand | 5 | filler | 6 | 18 | runner damage → **hero** bolt | yes | Kill Command | ST / proc | copy “Pet-style”; **no pet** |
| multiShot | 7 | filler | 8 | 22 | runner aoe → `_fanBolts` | yes | Multi-Shot | AoE | OK |
| bestialWrath | 9 | filler | 30 | 10 | runner selfBuff → haste | yes | Bestial Wrath | CD | self-only; **cheap → starved** vs Multi/KC |
| intimidation | 11 | filler | 16 | 15 | runner root | yes | Intimidation | control | no pet stun actor |
| beastWithin | 13 | signature | 40 | 20 | runner selfBuff → haste | yes | The Beast Within | CD | held for elite/pack |
| feignDeath | 15 | emergency | 45 | 0 | runner emergencyDefend | yes | Feign Death | def | **shield, not drop aggro** |

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| preferredRange / attackRange | backline bow | 4.2 / 5.2, ranged | ok |
| Kite / mobility | Disengage-like when pressed | none on BM kit | N/A |
| Target selection | non-dormant focus | shared smart focus | ok |
| Pack vs single | Multi on clumps | AoE gated nearby≥2 | ok |
| Tank / heal | N/A | — | N/A |
| DPS focus | not parking dormant | shared path | ok |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| armorTypes | mail (+leather/cloth bias set) | ok |
| Unlock path | AL 2; seed via `unlockSpec` | ok |
| Roster / PARTY | selectable once unlocked | ok |
| shortLabel | BM | ok |
| Ability chips | Hawk/ArcShot/KC/Multi/… | ok |
| Guides / Codex | no hunter-specific guide hits | stale / N/A |

#### 6. Content contexts

| Context | Status |
|---------|--------|
| Multi-chamber wake | ok (kit casts on wake) |
| Boss floor | Beast Within held for elite — ok |
| Offline / AFK spatial | same runner; reducedVfx OK |
| Wipe / revive | ok |
| FARM | identity weak (no pet) |
| PUSH | no soft-lock; throughput LOW |
| Challenges | ok / no kit-specific break |
| Save / migrate | unlocks via metaDepth.unlockedSpecs |
| Perf | arrow fans OK; reducedVfx OK |

#### 7. Pet / guardian

| Check | Notes | Status |
|-------|-------|--------|
| Pet exists in combat | No BM-spawned `SpatialActor`. Only optional `state.activePet` hatch companion (party-wide, not BM). | **missing** |
| Pet AI / leash | Hatch pet follows leader + melee chip — unrelated to Kill Command | N/A for BM |
| Pet VFX / sprite | Hatch pets use PetCatalog; no BM beast sprite | **missing** |
| Pet in meter / HUD | Hatch pet damage not recorded as hero DPS (`isPet` skipped); Beast Pen is meta UI | silent / N/A |
| Ability coupling | Kill Command / Intimidation / Bestial Wrath ignore pets | **missing** |

#### 8. Live read (sims)

Equal-ish mid band, Prot+Disc + solo DPS, F5 (`class_balance_latest.md`).

| Signal | Observed |
|--------|----------|
| Meter | share **38.2%** (LOW vs median ~49%), DPS ~128 |
| Buckets that fire | Arcane / KC / Multi / haste CDs / root (expected) |
| Buckets that never fire | real pet attacks; true Feign threat drop |
| Resource | mana spenders; Bestial Wrath cheap vs Multi → under-cast risk |
| Range / AI | backline OK |
| Role red flags | **no beast**; mid share LOW |

Alt mid ProtPala+Holy: share ~56% when clears rare — noisy; Prot+Disc LOW is the cleaner signal.

#### 9. Assets & VFX

| Surface | Path / check | Status | Notes |
|---------|--------------|--------|-------|
| Hero body | `CustomAssets.heroHunter` | ok | class fantasy OK |
| Spec distinguishable | same hunter sprite for BM/MM/SV | muddy | P2 |
| HUD chips | shortLabels | ok | |
| AA bolt | `SpellBoltStyle.arrow` | ok | |
| Signature / CD | haste ring via selfBuff | weak | no pet roar |
| Maintain | none | none | |
| AoE | Multi fan arrows | ok | |
| Emergency | Feign = blue shield ring | wrong | looks like Deterrence |
| reducedVfx | announces skip non-important | ok | |
| Audio | N/A | N/A | |

**On-screen (full):** not live-glanced this pass — infer from bolt/fan/haste paths.  
**A11y:** chips + BM tag readable at phone scale — ok.

**Asset / VFX findings**

- P0: no combat pet sprite / summon VFX  
- P1: Feign looks like generic shield  
- P2: BM/MM/SV share one body sprite  

#### 10. Findings

- **P0:** No combat pet/guardian for BM; Kill Command is hero damage; Intimidation/Bestial Wrath not pet-linked  
- **P0:** Feign Death copy (“drop aggro”) vs `emergencyDefend` shield — wrong role tool  
- **P0:** Mid DPS share LOW (~38%) — pet gap + CD starvation likely drivers  
- **P1:** Bestial Wrath is cheap **filler** → sorted behind Multi/KC; promote to signature or raise cost  
- **P1:** No Misdirection / Mark / Serpent maintain (party + maintain buckets thin)  
- **P2:** Dual haste windows (Wrath + Beast Within) feel same; guides silent on BM  

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job in 1T/1H/2DPS | should be pet+bow ranged | muddy (bow-only) |
| Overlap | overlaps MM as “arrow kit” | redundant without pet |
| Hole if missing | covered by MM/SV | covered |
| Synergy | none | none |

## Cross-party balance (this spec)

| Spec | Meter | vs peers | vs WotLK role | Range/AI | Modes | Perf | Verdict |
|------|-------|----------|---------------|----------|-------|------|---------|
| beastMastery | ~38% share mid | under | pet fantasy missing | ok | ok | ok | **WIP** |

**Player pitch:** Mail bow that should bring a beast — today the beast never shows up.

## P0 / P1 backlog

1. **P0** Spawn BM combat pet (licensed Kenney/custom), AI/leash, Kill Command hits via pet, Bestial Wrath buffs pet (+ hunter)  
2. **P0** Feign Death: clear/soft threat (or rename + keep shield)  
3. **P0** Retune mid throughput after pet lands (aim peer band)  
4. **P1** Bestial Wrath tier/cost so it isn’t starved  
5. **P1** Optional Misdirection / sting maintain lite  

## Proposed tunings

Idle Party fields only — **no** Wowhead coefficients.

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| BM | combat pet actor | missing → spawn with BM in party | must-bucket pet |
| BM | killCommand | hero bolt → pet special | Wrath KC fantasy |
| BM | bestialWrath | filler/cost 10 → signature or higher cost | CD actually fires |
| BM | feignDeath | emergencyDefend → threat dump (or copy fix) | match chip text |

## Explicitly out of scope

BiS / gems / enchants / consumables / PvP / full talent calculators / glyph spreadsheets.

## Test gaps

- [ ] BM combat pet spawn + leash  
- [ ] Kill Command damages via pet  
- [ ] Feign threat behavior  
- [ ] Wiring / cast smoke for BM kit  
- [ ] Mid share after pet  
- [ ] Offline with BM pet  
- [ ] Assets (pet sprite license)  

## Compared to previous audit

**Previous:** none · **Delta:** first BM pass  

## Out of scope / follow-ups

- Shared hunter sprite differentiation (MM/SV)  
- Demo pet system reuse when that audit lands  
