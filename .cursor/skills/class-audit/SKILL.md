---
name: class-audit
description: >-
  Audits Idle Party hero specs against WotLK identity (Wowhead guide
  structure) plus wiring, range/AI, gear, unlock/roster, offline, pets,
  assets/VFX, composition, FARM/PUSH/challenges, save migrate, perf, and
  player pitch. Use for class/kit/spec audits, WotLK/Wowhead comparison,
  PROT/DISC/FIRE/COM, or "klass-audit".
---

# Class audit (Idle Party)

Compare kits to **Wrath** design identity via Wowhead guide *structure*, then verify Idle Party systems end-to-end.

**Legal:** Read Wowhead for names, buckets, strengths/weaknesses. **Never** paste tooltips, numbers, talent spreads, glyphs, or BiS into the repo (`AGENTS.md`). Art only from `assets/kenney/` or owned `assets/custom/`.

## Scope inputs

1. **Specs?** (default: `protection`, `discipline`, `fire`, `combat`)
2. **Depth?** `quick` | `full`
3. **Fix now?** report-only vs fix P0

## Wowhead map

| Wowhead slice | Use in audit |
|---------------|--------------|
| Class index (tank/heal/melee/ranged) | role family |
| Overview | fantasy, strengths/weaknesses |
| Rotation / CDs / abilities | ST / AoE / maintain / CD / def / util / proc buckets |
| Talents / glyphs | identity only — skip point spreads |
| BiS / stats / consumables / PvP | **skip** |

Example:  
`https://www.wowhead.com/wotlk/guide/classes/mage/fire/dps-rotation-cooldowns-abilities-pve`

## Source of truth (code)

| Layer | Path |
|-------|------|
| Specs / range / armor | `lib/models/hero_spec.dart` |
| Kits | `lib/models/class_ability.dart` |
| Effects / bursts / bolts / AI hooks | `lib/spatial/ability_effects.dart`, `lib/spatial/spatial_combat.dart` |
| Unlock / roster | `lib/core/game_logic.dart`, `lib/core/game_state.dart` |
| HUD / meter / chips | `lib/ui/is2_shell.dart` |
| Guides / copy | `lib/core/game_guides.dart`, tips overlays |
| Sprites | `lib/ui/kenney_assets.dart`, `lib/ui/custom_assets.dart`, `lib/ui/hero_paper_doll.dart`, `lib/ui/spatial_dungeon_view.dart` |
| Offline | `GameLogic.simulateSpatialOffline` / director offline path |
| Tests | `test/class_kits_combat_test.dart`, `*_abilities_test.dart` |
| Report | `docs/CLASS_AUDIT_TEMPLATE.md` |
| Archive | `docs/audits/YYYY-MM-DD-<specs>.md` |

## Workflow

```
Class audit progress:
- [ ] 1. Wowhead slices
- [ ] 2. Strengths / weaknesses + fantasy + player pitch
- [ ] 3. Rotation buckets
- [ ] 4. Code inventory + wiring
- [ ] 5. Range / AI / threat / triage
- [ ] 6. Gear / unlock / roster / copy
- [ ] 7. Multi-chamber / boss / offline / FARM·PUSH·challenges / save / perf
- [ ] 8. Pet/guardian (or N/A)
- [ ] 9. Assets & VFX + a11y
- [ ] 10. Numbers / pacing
- [ ] 11. Composition fit (party of 4)
- [ ] 12. Playtest (full)
- [ ] 13. Report + verdicts
- [ ] 14. Fix P0 (if asked)
```

### Rotation buckets

| Bucket | Examples (names only) |
|--------|------------------------|
| ST filler / builder | Fireball, Sinister Strike, Devastate |
| Maintain / DoT / buff | Living Bomb, Slice and Dice, Power Word: Shield |
| Finisher / dump | Eviscerate, Pyroblast (proc) |
| AoE / cleave | Shockwave, Blade Flurry |
| Offensive CD | Combustion, Killing Spree |
| Defensive / emergency | Shield Wall, Ice Block, Pain Suppression |
| Control | Taunt, Frost Nova, Kidney Shot |
| Party utility | Fortitude, Arcane Intellect, Demo Shout |
| Proc / reaction | Hot Streak → Pyro (auto-friendly) |

Idle has **no opener**. Missing must-keep bucket = **P0/P1**.

### Range, AI, threat, triage

- Melee `preferredRange` in face; casters backline; mobility tools fire when fantasy needs them.
- Targets: alive, non-dormant; don’t idle on next chamber forever.
- Tank: holds packs / taunt on lose. Healer: lowest HP + emergencies; no full-HP spam.
- Multi-chamber wake + boss floor: signature/emergency still show up.
- Offline/AFK spatial: kit still works; no soft-lock.

### Gear, unlock, roster, copy

- `armorTypes` / BEST / auto-equip match fantasy.
- Unlock hint + seed level; PARTY roster selectable.
- `shortLabel`, chip names, guides/tips not stale.

### Pets

If spec is pet-family (BM, Demo, …): combat pet present, AI/leash OK, licensed sprite, HUD/meter if intended. Else mark **N/A**.

### Modes, save, perf, pitch

- **FARM / PUSH / challenges:** kit still readable; no mode-specific soft-lock.
- **Save/migrate:** loading an older save keeps unlocks/kit; no blank abilities.
- **Perf:** signature/AoE VFX must not tank the ~60 FPS combat target; note `reducedVfx`.
- **Player pitch:** one sentence that matches live feel (for PARTY/UI/store).

### Composition fit

With a normal 1 tank / 1 heal / 2 DPS party: clear job, acceptable overlap, no soft hole if swapped out, any buff/cleave synergy.

### Assets & VFX

Hero sprite, chips, `SpellBoltStyle`, bursts, maintain/AoE/emergency telegraphs, `reducedVfx`, a11y at ~390×844. Silent signature or wrong art = **P0/P1**.

### Numbers

DPS peers ~0.6×–1.4×; tank ≪ DPS; healer on H/s. Resource edge cases don’t soft-lock. Tunings = Idle fields only.

### Report / fixes

Fill `docs/CLASS_AUDIT_TEMPLATE.md`. Verdict: **ship** | **tune** | **WIP**.  
Fix only after report (or audit+fix). Analyze + tests. No commit unless asked.

## Anti-patterns

- Pasting Wowhead numbers / talent calculators / BiS into git
- Full WotLK button parity as a pass condition
- PvP / glyph spreadsheets / raw stat weights
- All ~30 specs unless asked
- Global AL retune inside a class audit
- Unlicensed commercial art/SFX
- Skipping live VFX glance on `full` depth
