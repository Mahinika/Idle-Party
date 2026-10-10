---
name: class-audit
description: >-
  Audits Idle Party hero specs against WotLK identity (Wowhead structure),
  silhouettes/forms, wiring, range/AI, gear, offline, and player pitch. Use for
  class/kit/spec audits, shapeshift checks, WotLK comparison, PROT/DISC/FIRE/COM,
  or "klass-audit". Do not use for a single missing cast (add-ability) or
  DPS-only trim (grinding-until-pass).
---

# Class audit (Idle Party)

Compare kits to **Wrath** design identity via Wowhead guide *structure*, then verify Idle Party systems end-to-end.

**Legal:** Read Wowhead for names, buckets, strengths/weaknesses. **Never** paste tooltips, numbers, talent spreads, glyphs, or BiS into the repo (`AGENTS.md`). Art only from owned `assets/custom/`.

## Scope inputs

1. **Class or specs?** If a class is named, audit **every shipped spec in that
   class** plus how players distinguish them. If specs are named, audit those.
2. **Depth?** `quick` | `full`
3. **Fix now?** report-only vs audit+fix. If not stated, write the report first.
   A real product/design fork: read `.cursor/rules/decide-a-fork.mdc` and decide once.

Before ability details, write a **class fantasy contract**:

- canonical role and one-line fantasy for every in-scope spec
- canonical body/silhouette, form, stance/presence, or companion
- whether that state is persistent, conditional, or a temporary cooldown
- where it must read: dungeon actor, PARTY HUD, GEAR/roster doll, ability VFX
- what distinguishes sibling specs at phone scale

An always-on form represented only by text or a HUD chip is **not implemented
visually**.

For Wowhead slices, rotation buckets, form contracts, and numbers guidance, read
**[reference.md](reference.md)** when filling those sections.

## Source of truth (code)

| Layer | Path |
|-------|------|
| Specs / range / armor | `lib/models/hero_spec.dart` |
| Kits | `lib/models/class_ability.dart` |
| Effects / bursts / bolts / AI hooks | `lib/spatial/ability_effects.dart`, `lib/spatial/spatial_combat.dart` |
| Unlock / roster | `lib/core/game_logic.dart`, `lib/core/game_state.dart` |
| HUD / meter / chips | `lib/ui/shell/dungeon_party_hud.dart` |
| Guides / copy | `lib/core/game_guides.dart`, tips overlays |
| Identity / forms | `lib/core/hero_identity.dart`, `lib/visual/rig/hero_rig_painter.dart` (the moving hero, skill `hero-rig`), `lib/visual/`, `lib/ui/hero_doll_sprite.dart` (still fallback), `lib/ui/spatial_dungeon_view.dart` |
| Asset helpers | `lib/assets/kenney_assets.dart`, `lib/assets/custom_assets.dart` |
| Offline | `GameLogic.simulateSpatialOffline` / director offline path |
| Tests | `test/class_kits_combat_test.dart`, `test/kit_passives_test.dart`, `test/kit_honesty_fix_test.dart`, `test/kit_honesty_form_test.dart`, `test/kit_hud_chips_test.dart`, `test/kit_meet_fantasy_test.dart`, `test/warrior_abilities_test.dart` |
| Report | `docs/CLASS_AUDIT_TEMPLATE.md` |
| Archive | `docs/archive/audits/YYYY-MM-DD-<specs>.md` |

## Workflow

```
Class audit progress:
- [ ] 1. Class fantasy contract + era note
- [ ] 2. Wowhead slices (reference.md)
- [ ] 3. Strengths / weaknesses + player pitch
- [ ] 4. Body/form/stance/companion contract on every surface (reference.md)
- [ ] 5. Rotation buckets (reference.md)
- [ ] 6. Code inventory + wiring
- [ ] 7. Range / AI / threat / triage (reference.md)
- [ ] 8. Gear / unlock / roster / copy
- [ ] 9. Multi-chamber / boss / offline / FARM·PUSH·challenges / save / perf
- [ ] 10. Assets, animations, VFX + a11y
- [ ] 11. Numbers / pacing (reference.md)
- [ ] 12. Composition + sibling-spec distinction (reference.md)
- [ ] 13. Playtest (full)
- [ ] 14. Report + verdicts
- [ ] 15. Fix authorized findings and verify
```

### Report / fixes

Fill `docs/CLASS_AUDIT_TEMPLATE.md`. Verdict: **ship** | **tune** | **WIP**.  
Report-only means no gameplay edits. For audit+fix, verify matching tests plus
A56 live form/silhouette, then follow the repo's normal local-commit rule.

## Anti-patterns

- Pasting Wowhead numbers / talent calculators / BiS into git
- Full WotLK button parity as a pass condition
- PvP / glyph spreadsheets / raw stat weights
- All 31 specs unless asked
- Global AL retune inside a class audit
- Unlicensed commercial art/SFX
- Treating an always-on animal/form passive as “done” because its HUD chip exists
- Calling different tints on the same humanoid body distinct class forms
- Confusing Guardian Druid (tank spec) with a summoned guardian/companion
- Skipping live VFX glance on `full` depth

## Done when

- `flutter analyze lib test --no-fatal-infos` is clean and the kit tests above are green.
- Kit numbers moved: `flutter test test/class_balance_share_fast_test.dart` and `flutter test test/class_balance_gate_test.dart` are green (no HIGH).
- HUD, guides, and PATCH NOTES still say what the kit does.
