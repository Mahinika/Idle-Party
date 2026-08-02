# Class audit report

**Date:** YYYY-MM-DD  
**Auditor:**  
**Depth:** quick | full  
**Specs in scope:** (e.g. protection, discipline, fire, combat)  
**Build / branch:**  
**Playtest?** no | yes  

**WotLK reference rules:** Use Wowhead *Wrath Classic* guides for **structure + identity** only (overview, rotation shape, strengths/weaknesses).  
Do **not** paste tooltips, coefficients, talent point spreads, glyph IDs, or BiS lists into the repo (`AGENTS.md`).

## Summary

One short paragraph: kit health vs WotLK identity, plus the single biggest gap.

## Audit DoD

- [ ] Wowhead links filled (or N/A + reason)
- [ ] Strengths / weaknesses vs Idle Party
- [ ] Rotation buckets mapped (ST / AoE / maintain / CD / defensive / utility / proc)
- [ ] Every in-scope ability has effect path (`runner` / `spatial` / `missing` / `passive`)
- [ ] Range / positioning + combat AI checked
- [ ] Threat (tank) / heal triage (healer) checked or N/A
- [ ] Gear / armor fantasy + auto-equip bias checked
- [ ] Unlock / roster / PARTY UI / copy checked
- [ ] Multi-chamber + boss-floor behavior checked (full) or N/A (quick)
- [ ] Offline / AFK spatial path checked or N/A
- [ ] Assets + VFX checked (sprite, HUD chips, bolts/bursts, `reducedVfx`)
- [ ] A11y / readability spot-check
- [ ] Each spec: WotLK identity score + Idle verdict (`ship` / `tune` / `WIP`)
- [ ] All **P0** listed
- [ ] If `full`: live meter + cast notes
- [ ] Tunings are Idle Party field changes (not Wowhead numbers)
- [ ] Pet/guardian section filled or marked N/A
- [ ] Composition fit (1 tank / 1 heal / 2 DPS) checked or N/A
- [ ] Difficulty contexts: FARM / PUSH / challenges checked or N/A
- [ ] Save / migrate / old-save kit OK or N/A
- [ ] Perf note (VFX/spam vs ~60 FPS target)
- [ ] Player pitch one-liner written

---

## Per-spec sheet

Copy once per `HeroSpecId`.

### `HeroSpecId.________` — shortLabel

**Verdict:** ship | tune | WIP  
**Depth:** quick | full  
**Wowhead role page family:** tank | healer | melee-dps | ranged-dps | caster-dps  
**Has pet/guardian?** no | yes (which)

#### Wowhead sources (read, don’t scrape)

Fill URLs from `wowhead.com/wotlk/guide/classes/<class>/<spec>/…` (PVE pages).

| Guide slice | URL | Used? |
|-------------|-----|-------|
| Overview (if any) | | y/n |
| Rotation / cooldowns / abilities | | y/n |
| Talents / builds (identity only) | | y/n |
| Other (optional) | | y/n |

Patch note on guide (e.g. 3.4.x): ____

#### 1. Overview — strengths & weaknesses *(Wowhead-style)*

| | WotLK (from guide feel) | Idle Party today | Gap |
|--|-------------------------|------------------|-----|
| Fantasy one-liner | | | |
| Role job | | `SpecRoleTag` + live | |
| **Strengths** (3 bullets) | | | covered / partial / missing |
| **Weaknesses** (2–3) | | | still true / inverted / N/A |
| Party utility | buffs / debuffs / peels | | |

**WotLK identity score:** 1–5 (1 wrong · 3 recognizable · 5 nails idle fantasy)

**Player pitch (one line):**  
> ____  
(How you'd describe this spec in UI / PARTY / store — must match live feel.)

#### 2. Rotation shape *(maps Wowhead “Rotation & Abilities”)*

Idle combat is **always sustained auto** — no opener weaving. Judge whether the *priority buckets* exist.

| Bucket | WotLK beats (names only) | Idle Party analog | Status |
|--------|--------------------------|-------------------|--------|
| **ST filler / builder** | e.g. Fireball, Sinister Strike | | present / weak / missing |
| **Maintain / DoT / buff** | e.g. Living Bomb, SnD, PW:S | | |
| **Finisher / dump** | e.g. Eviscerate, Pyroblast on proc | | |
| **AoE / cleave** | e.g. Blade Flurry, Shockwave | | |
| **Offensive CD / burst** | e.g. Combustion, Killing Spree | | |
| **Defensive / emergency** | e.g. Shield Wall, Ice Block, Pain Supp | | |
| **Control / kite** | e.g. Frost Nova, Kidney, Taunt | | |
| **Raid / party utility** | e.g. Fort, AI, Demo Shout | | |
| **Proc / reaction** | e.g. Hot Streak → Pyro | | idle-safe? y/n |

**Must-keep for idle (2–4 beats):**  
**OK-to-drop (stance dance, multi-GCD weaves, glyphs, hit caps):**  

#### 3. Code inventory *(required: quick + full)*

| Field | Notes |
|-------|--------|
| `SpecRoleTag` / `legacyRole` | match Wowhead role? |
| Resource + regen | spend pressure like WotLK fantasy? |
| Resource edge cases | rage@0 / OOM / energy cap — OK / soft-lock / wrong |
| Kit path `forSpec` vs `forRole` | |
| Baseline AA / `kitOutMul` | |
| Unlock curve | L?: … |
| Wiring overall | OK / gaps |

**Abilities**

| AbilityId | Unlock | Tier | CD | Cost | Effect path | HUD? | Wowhead / WotLK name | Bucket | Notes |
|-----------|--------|------|----|------|-------------|------|----------------------|--------|-------|
| | | | | | runner / spatial / missing / passive | | | ST / AoE / maintain / CD / def / util / proc | |

#### 4. Range, positioning & combat AI *(required)*

| Check | Expected | Observed | Status |
|-------|----------|----------|--------|
| `preferredRange` / `attackRange` | melee in face / caster backline | | ok / wrong / missing |
| Kite / blink / charge tools | fire when WotLK fantasy needs them | | ok / never / N/A |
| Target selection | alive, non-dormant, sensible focus | | ok / sticks on dead / idle |
| Pack vs single | AoE bucket on clumps | | ok / weak / N/A |
| Tank threat / taunt | holds packs; taunt on lose | | ok / leaks / N/A |
| Healer triage | lowest HP / emergency first; no full-HP spam | | ok / spam / N/A |
| DPS focus | not parking on dormant next chamber | | ok / wrong |

#### 5. Gear, unlock, roster & copy *(required)*

| Check | Notes | Status |
|-------|-------|--------|
| `armorTypes` / gear fantasy | plate/mail/leather/cloth bias in BEST / auto-equip | ok / wrong / N/A |
| Unlock path | `unlockHint`, cost/condition, seed level on unlock | ok / unclear / broken |
| Roster / PARTY UI | selectable, active slot, level shows | ok / missing |
| `shortLabel` / meter tag | PROT/DISC/FIRE/COM-style readable | ok / wrong |
| Ability chip copy | names match fantasy; not blank/`---` | ok / wrong |
| Guides / Codex / tips | mentions kit if player-facing | ok / stale / N/A |

#### 6. Content contexts *(full required; quick = skim or N/A)*

| Context | What to watch | Status |
|---------|---------------|--------|
| Multi-chamber wake | taunt/AoE/mobility when next room wakes | ok / soft-lock / N/A |
| Boss floor | emergency + signature readable vs trash-only | ok / weak / N/A |
| Offline / AFK spatial | kit still casts; no soft-lock; `afkAssist`/`reducedVfx` OK | ok / broken / N/A |
| Wipe / revive | kit recovers sensibly | ok / weird / N/A |
| **FARM** | stable clear pace; identity readable | ok / weak / N/A |
| **PUSH** | pressure / deaths don't soft-lock kit | ok / soft-lock / N/A |
| **Challenges / hardmode** | kit still makes sense under toggles | ok / breaks / N/A |
| **Save / migrate** | old save loads kit; unlocks/abilities not wiped wrongly | ok / broken / N/A |
| **Perf** | burst/bolt spam OK vs ~60 FPS; no hitch on signature | ok / heavy / N/A |

#### 7. Pet / guardian *(fill or N/A)*

| Check | Notes | Status |
|-------|-------|--------|
| Pet exists in combat | BM / Demo / etc. | ok / missing / N/A |
| Pet AI / leash | stays useful, not stuck | ok / bad / N/A |
| Pet VFX / sprite | licensed asset | ok / missing / N/A |
| Pet in meter / HUD | if intended | ok / silent / N/A |

#### 8. Live read *(required: full)*

Equal-ish level/gear, FARM, 1–2 floors (+ boss peek if available).

| Signal | Observed |
|--------|----------|
| Meter (DPS / H/s / T/s) | |
| Buckets that fire | |
| Buckets that never fire | |
| Resource (starved / full dump) | |
| Range / AI notes | |
| Role red flags | |

#### 9. Assets & VFX *(required: quick code paths; full = on-screen)*

Legal: sprites only via `KenneyAssets` / owned `assets/custom/` — no third-party game art (`AGENTS.md`). Pixel art → `FilterQuality.none`.

| Surface | Path / check | Status | Notes |
|---------|--------------|--------|-------|
| Hero body / class sprite | `KenneyAssets` / `CustomAssets` / paper doll | ok / wrong / missing | matches class fantasy? |
| Spec distinguishable in party | 4 heroes readable at phone scale | ok / muddy | |
| Ability HUD chips | labels / icons in `_PartyCornerHud` | ok / wrong / generic | |
| Auto-attack bolt style | `SpellBoltStyle` for spec | ok / generic / missing | |
| Signature / CD burst | `SpatialBurst` / floater on cast | ok / weak / silent | |
| Maintain / aura telegraphs | shield bubble, bomb tick, SnD, etc. | ok / weak / none | |
| AoE telegraph | ground pulse / ring | ok / weak / none | |
| Emergency VFX | Wall / Ice Block / Vanish | ok / weak / none | |
| `reducedVfx` path | still understandable when on | ok / breaks identity | |
| Audio (optional) | cast/hit cues if wired | ok / silent / N/A | |

**On-screen (full):** 2–3 casts that *look* like the WotLK fantasy.

**A11y / readability:** chips + meter + map controls usable at ~390×844; semantics not broken. Status: ok / issues: ____

**Asset / VFX findings**

- P0:
- P1:
- P2:

#### 10. Findings

- **P0** (wire / role / must-bucket / art / soft-lock):
- **P1** (identity / AI / gear / VFX / unlock UX / modes):
- **P2** (polish / curve / copy / timing / perf):

---

## Composition fit

Default party: **1 tank / 1 healer / 2 DPS** (or note actual roster).

| Question | Notes | Status |
|----------|-------|--------|
| Spec's job in that party | | clear / muddy |
| Overlap with another active spec | e.g. two casters same niche | ok / redundant |
| Hole if this spec is missing | | covered / party soft |
| Synergy (buffs/peels/cleave) | | ok / none / anti |

## Cross-party balance

DPS peers ~**0.6×–1.4×**. Tank ≪ DPS. Healer on **H/s**. Compare roles to Wowhead class index (Tank / Healer / Melee / Ranged).

| Spec | Meter | vs peers | vs WotLK role | Range/AI | Modes (F/P/C) | Perf | Verdict |
|------|-------|----------|---------------|----------|---------------|------|---------|
| | | under / fair / over | | ok / issues | ok / issues | ok / heavy | |

**Player pitches (roster):**

| Spec | Pitch one-liner |
|------|-----------------|
| | |

## P0 / P1 backlog

1. …
2. …

## Proposed tunings

Idle Party fields only — **no** Wowhead coefficients.

| Spec | Ability / field | From → To | Why (idle feel + WotLK bucket) |
|------|-----------------|-----------|--------------------------------|
| | | | |

## Explicitly out of scope (Wowhead pages we skip)

BiS / gems / enchants / consumables / phase gear / PvP / full talent calculators / glyph spreadsheets / raw stat-weight theorycrafting.

## Test gaps

- [ ] …
- [ ] Wiring / cast
- [ ] Range or AI
- [ ] Unlock / roster
- [ ] Offline
- [ ] Assets
- [ ] Composition / modes
- [ ] Save migrate
- [ ] Perf

## Compared to previous audit

**Previous:** · **Delta:**  

## Out of scope / follow-ups

-
