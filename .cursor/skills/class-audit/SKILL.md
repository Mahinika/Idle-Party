---
name: class-audit
description: >-
  Audits Idle Party hero specs against WotLK identity (Wowhead guide
  structure) plus class-wide silhouettes/forms/stances, wiring, range/AI,
  gear, unlock/roster, offline, companions, assets/VFX, composition,
  FARM/PUSH/challenges, save migrate, perf, and player pitch. Use for
  class/kit/spec audits, shapeshift or visual-fantasy checks, WotLK/Wowhead
  comparison, PROT/DISC/FIRE/COM, or "klass-audit".
---

# Class audit (Idle Party)

Compare kits to **Wrath** design identity via Wowhead guide *structure*, then verify Idle Party systems end-to-end.

**Legal:** Read Wowhead for names, buckets, strengths/weaknesses. **Never** paste tooltips, numbers, talent spreads, glyphs, or BiS into the repo (`AGENTS.md`). Art only from `assets/kenney/` or owned `assets/custom/`.

## Scope inputs

1. **Class or specs?** If a class is named, audit **every shipped spec in that
   class** plus how players distinguish them. If specs are named, audit those.
2. **Depth?** `quick` | `full`
3. **Fix now?** report-only vs audit+fix. If not stated, write the report first
   and ask only when a real product/design fork remains.

Before ability details, write a **class fantasy contract**:

- canonical role and one-line fantasy for every in-scope spec
- canonical body/silhouette, form, stance/presence, or companion
- whether that state is persistent, conditional, or a temporary cooldown
- where it must read: dungeon actor, PARTY HUD, GEAR/roster doll, ability VFX
- what distinguishes sibling specs at phone scale

An always-on form represented only by text or a HUD chip is **not implemented
visually**.

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
| HUD / meter / chips | `lib/ui/shell/dungeon_party_hud.dart` |
| Guides / copy | `lib/core/game_guides.dart`, tips overlays |
| Identity / forms | `lib/core/hero_identity.dart`, `lib/visual/`, `lib/ui/hero_doll_sprite.dart`, `lib/ui/spatial_dungeon_view.dart` |
| Asset helpers | `lib/assets/kenney_assets.dart`, `lib/assets/custom_assets.dart` |
| Offline | `GameLogic.simulateSpatialOffline` / director offline path |
| Tests | `test/class_kits_combat_test.dart`, `*_abilities_test.dart` |
| Report | `docs/CLASS_AUDIT_TEMPLATE.md` |
| Archive | `docs/audits/YYYY-MM-DD-<specs>.md` |

## Workflow

```
Class audit progress:
- [ ] 1. Class fantasy contract + era note
- [ ] 2. Wowhead slices
- [ ] 3. Strengths / weaknesses + player pitch
- [ ] 4. Body/form/stance/companion contract on every surface
- [ ] 5. Rotation buckets
- [ ] 6. Code inventory + wiring
- [ ] 7. Range / AI / threat / triage
- [ ] 8. Gear / unlock / roster / copy
- [ ] 9. Multi-chamber / boss / offline / FARM·PUSH·challenges / save / perf
- [ ] 10. Assets, animations, VFX + a11y
- [ ] 11. Numbers / pacing
- [ ] 12. Composition + sibling-spec distinction
- [ ] 13. Playtest (full)
- [ ] 14. Report + verdicts
- [ ] 15. Fix authorized findings and verify
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

### Era honesty

Wrath is the identity baseline, not a taxonomy trap. Record divergence when the
shipped spec name or role belongs to another era. Example: Wrath Feral covered
cat DPS and bear tanking; Idle Party's separate **Feral** and **Guardian**
specs should still inherit the correct cat/bear identity. Do not force a
modern kit into false Wrath parity or rename a shipped spec during an audit.

### Body, form, stance & persistent-state contract

Audit the actor's embodiment before VFX polish:

- **Persistent form:** actor must use that silhouette in live dungeon combat
  and compact party read. A passive multiplier or chip alone fails.
- **Conditional/temporary state:** verify enter/exit timing, save/load default,
  death/revive, floor transitions, offline catch-up, and reduced-VFX fallback.
- **Animations:** idle, move, attack/cast, hit/recoil, and defeat must fit the
  form; never slide an otherwise static replacement sprite.
- **Surfaces:** dungeon actor is authoritative. PARTY HUD and roster/GEAR must
  identify the same spec even if a compact portrait is used.
- **Gear:** explicitly choose visible form-specific equipment or hidden gear.
  Never stretch humanoid paper-doll overlays onto an animal body.
- **Readability:** sibling specs need distinct silhouettes/colors at the
  360×780 A56 target, including colorblind and Minimal VFX modes.
- **Rules + art agree:** `HeroSpecDef`, passive ability, runtime actor state,
  `HeroIdentity`, painter, asset helper, and player copy must describe the same
  form.

For Druids, the expected class contract is explicit:

| Spec | Persistent combat body |
|------|-------------------------|
| Feral | cat |
| Guardian | bear |
| Balance | Moonkin (owlkin / owl-bear humanoid), not a normal caster body |
| Restoration | Tree of Life while its shipped passive says “Always on” |

Missing or wrong persistent silhouette is **P0 identity**. Missing
form-specific animation/portrait polish is usually **P1**.

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

### Companions

If spec is companion-family (BM, Demo, …): combat companion present, AI/leash
OK, legal sprite, HUD/meter if intended. Else mark **N/A**. A spec named
Guardian is not automatically a companion check; classify by behavior.

### Modes, save, perf, pitch

- **FARM / PUSH / challenges:** kit still readable; no mode-specific soft-lock.
- **Save/migrate:** loading an older save keeps unlocks/kit; no blank abilities.
- **Perf:** signature/AoE VFX must not tank the ~60 FPS combat target; note `reducedVfx`.
- **Player pitch:** one sentence that matches live feel (for PARTY/UI/store).

### Composition fit

With a normal 1 tank / 1 heal / 2 DPS party: clear job, acceptable overlap, no soft hole if swapped out, any buff/cleave synergy.

### Assets & VFX

Start with silhouette/form/persistent state, then inspect hero sprite, form
animations, chips, `SpellBoltStyle`, bursts, maintain/AoE/emergency telegraphs,
`reducedVfx`, and a11y at ~390×844. Silent signature or wrong art = **P0/P1**.

### Numbers

DPS peers ~0.6×–1.4×; tank ≪ DPS; healer on H/s. Resource edge cases don’t soft-lock. Tunings = Idle fields only.

### Report / fixes

Fill `docs/CLASS_AUDIT_TEMPLATE.md`. Verdict: **ship** | **tune** | **WIP**.  
Report-only means no gameplay edits. For audit+fix, verify matching tests plus
A56 live form/silhouette, then follow the repo's normal local-commit rule.

## Anti-patterns

- Pasting Wowhead numbers / talent calculators / BiS into git
- Full WotLK button parity as a pass condition
- PvP / glyph spreadsheets / raw stat weights
- All ~30 specs unless asked
- Global AL retune inside a class audit
- Unlicensed commercial art/SFX
- Treating an always-on animal/form passive as “done” because its HUD chip exists
- Calling different tints on the same humanoid body distinct class forms
- Confusing Guardian Druid (tank spec) with a summoned guardian/companion
- Skipping live VFX glance on `full` depth
