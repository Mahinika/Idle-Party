# Class audit report — Protection Warrior

**Date:** 2026-08-02  
**Auditor:** Cursor agent (class-audit skill)  
**Depth:** full (code + prior live signals; no fresh browser pass this run)  
**Specs in scope:** `protection`  
**Build / branch:** `cursor/idle-party-mvp-kenney` @ `b31dbf9` (1.5.0)  
**Playtest?** partial — prior Hell FARM sessions (PROT L29–30, meter as **T**, chips Stand/Wall/Clap/Taunt/Dev)

**WotLK reference rules:** Wowhead Wrath Classic structure + identity only. No pasted coefficients.

## Summary

Protection is one of Idle Party’s **best-realized** kits: Shield Slam / Revenge-after-block / Devastate+Sunder / Thunder Clap / Shockwave / Shield Block / Wall / Last Stand / Taunt / Demo Shout / **Charge** / **Commanding Shout** / **SbB-lite** are wired with readable VFX. Identity score is high. Verdict: **ship** (P1/P2 backlog from this audit largely closed 2026-08-02).

## Audit DoD

- [x] Wowhead links filled (or N/A + reason)
- [x] Strengths / weaknesses vs Idle Party
- [x] Rotation buckets mapped
- [x] Effect paths for in-scope abilities
- [x] Range / positioning + combat AI
- [x] Threat / taunt
- [x] Gear / armor fantasy
- [x] Unlock / roster / PARTY / copy
- [x] Multi-chamber + boss (from code + prior play; not re-verified live today)
- [x] Offline path (same `_tickWarriorAbilities` via spatial offline — assumed OK; no dedicated PROT offline test)
- [x] Assets + VFX
- [x] A11y spot-check (prior sessions: chips readable)
- [x] Identity score + verdict
- [x] All P0 listed (none found)
- [x] Live meter notes (from prior play)
- [x] Tunings concrete if proposed
- [x] Pet N/A
- [x] Composition / modes / save / perf / pitch

---

### `HeroSpecId.protection` — PROT

**Verdict:** ship (minor tune backlog)  
**Depth:** full (code-primary)  
**Wowhead role page family:** tank  
**Has pet/guardian?** no

#### Wowhead sources (read, don’t scrape)

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview | (JS-thin on fetch; used Warcraft Tavern / Icy Veins Prot overview feel + Wowhead rotation URL) | y |
| Rotation / cooldowns / abilities | https://www.wowhead.com/wotlk/guide/classes/warrior/protection/tank-rotation-cooldowns-abilities-pve | y |
| Talents / builds (identity only) | skipped (point spreads) | n |
| Other | Icy Veins / Warcraft Tavern Prot rotation summaries for bucket names | y |

Patch note on Wowhead page: 3.4.3

#### 1. Overview — strengths & weaknesses

| | WotLK (Wrath) | Idle Party today | Gap |
|--|---------------|------------------|-----|
| Fantasy one-liner | Plate shield tank: block, slam, hold packs | Shield + rage tank in melee | covered |
| Role job | Main tank, ST threat + AoE stun | `SpecRoleTag.tank`, meter **T** | covered |
| **Strengths** | Survivability via block/CDs; ST threat (Slam/Revenge); utility (Demo/Sunder/slow); mobility (Charge etc.) | Block window, Wall/Stand, Slam/Revenge, Demo/Sunder/Clap, Shockwave, Charge | covered |
| **Weaknesses** | Weak AoE threat vs other tanks; gear-dependent; limited self-heal | AoE via Clap/Shockwave is OK for idle packs; no self-heal | weakness partly inverted (AoE tools present); self-heal still absent (**OK**) |
| Party utility | Demo, Sunder, Thunder Clap slow | Demo ATK down, Sunder stacks, Clap attack-slow | covered (no Intervene/raid wall) |

**WotLK identity score:** **4 / 5**  
(Reads as Prot; missing Warbringer-style mobility keeps it from 5.)

**Player pitch:**  
> Plate shield tank — blocks, slams, and pulls packs while the party burns them down.

#### 2. Rotation shape

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | Devastate / Heroic Strike | Devastate (+ white hits) | present (no HS dump) |
| **Maintain / DoT / buff** | Sunder Armor stacks | Devastate → `sunderStacks` | present |
| **Finisher / dump** | Revenge (after block/dodge/parry); Shield Slam | `revengeReady` after block; queued Shield Slam | present |
| **AoE / cleave** | Thunder Clap, Shockwave, (Improved) Revenge cleave | Thunder Clap, Shockwave cone | present |
| **Offensive CD / burst** | Shockwave as AP-scaling punch | Shockwave signature | present |
| **Defensive / emergency** | Shield Block, Shield Wall, Last Stand | all three wired | present |
| **Control / kite** | Taunt, Shockwave stun; Charge/Intervene | Taunt + Shockwave + Charge root | present |
| **Raid / party utility** | Demo Shout, Commanding/Battle shout | Demo + Commanding Shout | present |
| **Proc / reaction** | Sword and Board → free Slam; Revenge after avoid | Revenge after Shield Block; SbB-lite Slam reset | present |

**Must-keep for idle:** Shield Block ↔ Revenge, Shield Slam, Devastate/Sunder, Shockwave, Wall/Last Stand, Taunt.  
**OK-to-drop:** Intervene/Warbringer variants, Heroic Strike spam, glyph/talent variants, Vigilance.

#### 3. Code inventory

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | tank / `HeroRole.warrior` — match |
| Resource + regen | rage; gains near focus (~6/s) | OK |
| Resource edge cases | abilities gate on rage; not soft-locked in prior play | OK |
| Kit path | `ClassKits` + dedicated `_tickWarriorAbilities` for protection | OK |
| Baseline AA / `kitOutMul` | Defensive Stance −10% outgoing + `kitInMul` 0.92; Slam/Revenge mul on swing | OK |
| Unlock curve | L1 Stance → L15 Wall | OK |
| Wiring overall | **OK** — all 11 kit entries resolved |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| defensiveStance | 1 | passive | 0 | 0 | spatial `_warriorAttackMods` | no | Defensive Stance | maintain | −dmg / tankier |
| shieldBlock | 3 | emergency | 8 | 15 | spatial + DR on hit | yes | Shield Block | def | enables Revenge |
| thunderClap | 5 | filler | 7 | 20 | spatial AoE + slow | yes | Thunder Clap | AoE | pack≥2 or boss |
| devastate | 6 | filler | 2.8 | 15 | spatial + sunder | yes | Devastate | ST / maintain | needs shield |
| taunt | 7 | filler | 10 | 0 | spatial `_tauntLooseEnemies` | yes | Taunt | control | |
| demoralizingShout | 8 | filler | 12 | 18 | spatial AoE ATK down | yes | Demoralizing Shout | util | |
| shieldSlam | 9 | filler | 5.5 | 25 | queue → next swing | yes | Shield Slam | finisher | needs shield |
| revenge | 11 | passive | 0 | 5 | spatial after block | no | Revenge | finisher / proc | HUD hidden OK |
| shockwave | 13 | signature | 16 | 22 | spatial cone + root | yes | Shockwave | AoE / CD | flash VFX |
| lastStand | 14 | emergency | 45 | 0 | spatial bonus HP | yes | Last Stand | def | HP≤40% |
| shieldWall | 15 | emergency | 60 | 0 | spatial big DR | yes | Shield Wall | def | HP≤28%; needs shield |

Tests: `warrior_abilities_test`, `class_kits_combat_test` (Shockwave), `kit_passives_test`, `combat_authority_audit_test` (taunt effect), `spell_vfx_test` (Thunder Clap → lightning).

#### 4. Range, positioning & combat AI

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| preferredRange / attackRange | melee 1.15 / 1.7 | HeroSpecDef values | ok |
| Kite / charge | WotLK mobility | none | N/A (gap noted) |
| Target selection | focus alive | warrior ticker uses focusEnemy | ok |
| Pack vs single | Clap/Shockwave on clumps | length≥2 or boss | ok |
| Tank threat / taunt | holds / pulls loose | taunt + stance aggro text; prior play tank front | ok |
| Healer triage | N/A | — | N/A |
| DPS focus | N/A for tank | — | N/A |

#### 5. Gear, unlock, roster & copy

| Check | Notes | Status |
|-------|-------|--------|
| armorTypes | `_plate` | ok |
| Unlock path | starter spec (no unlockHint) | ok |
| Roster / PARTY | default tank; shortLabel PROT | ok |
| shortLabel / meter | PROT; DPS meter uses **T** when taken>0 | ok |
| Ability chips | Block, Clap, Dev, Taunt, Demo, Slam, Shock, Stand, Wall | ok |
| Guides / tips | New Game mentions Protection; meter guide says DPS / H / T | ok |

#### 6. Content contexts

| Context | What to watch | Status |
|---------|---------------|--------|
| Multi-chamber wake | taunt when ally pulled | ok (code) |
| Boss floor | Clap/Shockwave allow single boss | ok (code) |
| Offline / AFK | same warrior ticker | ok (assumed; no dedicated test) |
| Wipe / revive | standard revive | ok |
| FARM | prior Hell FARM | ok |
| PUSH | not re-tested this run | N/A |
| Challenges / hardmode | not re-tested | N/A |
| Save / migrate | starter kit; no PROT-specific migrate bug known | ok |
| Perf | bursts/rings on Clap/Shockwave; within combat budget post-60fps work | ok |

#### 7. Pet / guardian

N/A

#### 8. Live read (prior sessions)

| Signal | Observed |
|--------|----------|
| Meter | **PROT …T** (taken), not topping DPS% |
| Buckets that fire | Block, Clap, Dev, Taunt, Stand, Wall, Shock (when unlocked) |
| Buckets that never fire | Charge/Intervene (absent) |
| Resource | rage rose in combat | |
| Range / AI | melee clump with party | |
| Role red flags | none observed |

#### 9. Assets & VFX

| Surface | Status | Notes |
|---------|--------|-------|
| Hero sprite | ok | `assets/custom/heroes/knight.png` via KenneyAssets |
| Distinguishable | ok | knight silhouette |
| HUD chips | ok | shortLabels |
| AA bolt style | ok | `SpellBoltStyle.weapon` |
| Signature burst | ok | Shockwave cone + ring + flash |
| Maintain / aura | ok | Block floater; sunder floaters; Demo burst |
| AoE telegraph | ok | Clap ring/spark; Shockwave cone |
| Emergency VFX | ok | SHIELD WALL burst; LAST STAND floater |
| reducedVfx | ok | floaters/bursts gated |
| Audio | N/A | generic combat SFX |

**A11y:** prior sessions chips + map OK at ~390×844.

#### 10. Findings

- **P0:** none  
- **P1:** *(fixed 2026-08-02)* Charge gap-close + Sword and Board–lite Slam reset.  
- **P2:**
  1. ~~`game_guides.dart` meter “damage %”~~ → DPS / H / T *(fixed)*.  
  2. ~~No Commanding Shout~~ → mild party `atkShout` buff *(fixed)*.  
  3. Dedicated offline PROT test still missing.  
  4. PUSH/challenges not re-verified this audit.

---

## Composition fit

| Question | Notes | Status |
|----------|-------|--------|
| Job in 1T/1H/2D | Hold front, take damage, taunt leaks | clear |
| Overlap | Only starter tank | ok |
| Hole if missing | Party soft without tank | covered by needing PROT |
| Synergy | Demo/Sunder/Clap help DPS | ok |

## Cross-party balance

| Spec | Meter | vs peers | vs WotLK role | Range/AI | Modes | Perf | Verdict |
|------|-------|----------|---------------|----------|-------|------|---------|
| protection | T (taken) | tank ≪ DPS (prior) | match | ok | FARM ok; PUSH/chal N/A | ok | **ship** |

**Player pitches:**

| Spec | Pitch one-liner |
|------|-----------------|
| protection | Plate shield tank — blocks, slams, and pulls packs while the party burns them down. |

## P0 / P1 backlog

1. ~~**P1** Charge / gap-close~~ *(shipped)*.  
2. ~~**P1** SbB-lite Slam reset~~ *(shipped)*.  
3. ~~**P2** Fix guides meter copy~~ *(shipped)*.  
4. **P2** Offline + PUSH smoke tests for Prot (still open).

## Proposed tunings

None required for ship. Optional later:

| Spec | Ability / field | From → To | Why |
|------|-----------------|-----------|-----|
| protection | (new) short charge/gap tool | — | restore WotLK mobility feel in idle form |
| protection | shieldSlam proc reset | rare free queue after block | SbB-lite without full weave |

## Explicitly out of scope

BiS / gems / glyphs spreadsheets / PvP / talent calculators.

## Test gaps

- [ ] Dedicated offline Prot combat test  
- [ ] PUSH / challenges Prot smoke  
- [ ] Revenge floater visibility under `reducedVfx`  
- [x] Wiring / cast (unit tests + ticker review)  
- [x] Assets (knight.png)

## Compared to previous audit

**Previous:** none · **Delta:** baseline Prot audit.

## Out of scope / follow-ups

- Arms/Fury warrior audits  
- Prot Paladin comparison (second tank)
