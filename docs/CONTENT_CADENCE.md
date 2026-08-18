# Idle Party — monthly content cadence

Operational rhythm for solo / small-time shipping. Ties to the yearly plan in [ROADMAP.md](ROADMAP.md) (Q4 “Månadsrytm”).

## Cadence (every 2–4 weeks; aim monthly)

Each tagged `1.x.y` release should include:

1. **Balance pass** — iterate with share-only, then gate:
   - Fast: `flutter test test/class_balance_share_fast_test.dart` (or `--focus=specA,specB` via harness args)
   - Reads `tool/out/class_balance_share.json` + markdown board
   - CI: `test/class_balance_gate_test.dart` (live light, fails on DPS `**HIGH**`)
   - Mid band still manual / long (`class_balance_mid_sim_test`) when casters feel spicy
2. **Content slice** — one player-visible piece: dungeon beat, kit identity, meta sink, **local season week row**, Weekly/Gauntlet beat, or a11y/save polish. Prefer one hero feature per quarter (see ROADMAP).
3. **Release notes** — What’s New in `lib/core/meta_systems.dart`; `test/changelog_sync_test.dart` keeps pubspec ↔ version ↔ zone tokens honest.

### Success-spår (research-backed)

Ship habit → second layer → content cadence:

1. **Habit** — hub TODAY READY/ALMOST always visible on phone; claim/progress CTAs.
2. **Local season** — `lib/core/local_season.dart` week/month rows (reuse SpatialCombat + vault/Gauntlet).
3. **Zones / kits** — owner lock **2026-08-18:** no new zones or classes. Prefer **core-loop feel** (power beats, combat juice) + kit fantasy polish. Play 12×14 stays background.

See [ROADMAP.md](ROADMAP.md) “Success-spår”.  
Near-term (90 days): [STRATEGY_90D.md](STRATEGY_90D.md).

## Checklist before tagging

- [ ] `flutter analyze` clean; `flutter test` green (CI on push).
- [ ] Kit / combat changes exercised via SpatialCombat path (live + offline share the same step).
- [ ] Changelog entry for this version; `seenChangelogVersion` will auto-prompt What’s New.
- [ ] Hub smoke (optional but recommended): `.cursor/skills/hub-smoke` via web playtest.
- [ ] If Android: AAB/APK from tag workflow or local `flutter build appbundle` (see [PLAY_STORE.md](PLAY_STORE.md)).

## Agent tooling

| Need | Path |
|------|------|
| Share iterate | `tool/sim_class_balance.dart` `--share-only` / `--focus=` |
| Share JSON | `tool/out/class_balance_share.json` (gitignored under `tool/out/`) |
| Changelog sync | `test/changelog_sync_test.dart` |
| Hub UX smoke | `.cursor/skills/hub-smoke` |
| Zone identity | `.cursor/skills/zone-art-identity` |
| Cursor MCP | `.cursor/mcp.json` → `idle-party` (`tool/mcp_idle_party/`; UI may show `user-idle-party`) |
| Grind / PR babysit | `.cursor/skills/grinding-until-pass`, `babysitting-pr`, `parallel-ci-triage` |
| Browser verify / a11y | `.cursor/skills/verifying-in-browser`, `accessibility-auditing` |
| Suggest / author skills | `.cursor/skills/suggesting-skills`, `building-skills-from-patterns` |

## Out of cadence

Do not couple rewrites of SpatialCombat, new account servers, or commercial art dumps to the monthly train. Stretch (Windows zip, score-share image) stays optional per ROADMAP Q4.
