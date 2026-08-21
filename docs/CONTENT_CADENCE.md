# Idle Party — monthly content cadence

Operational rhythm after 90d M1–M3 shipped. Optional background:
[TOP_GAMES_RESEARCH.md](TOP_GAMES_RESEARCH.md). Live contracts:
[CHASE_CONTRACT.md](CHASE_CONTRACT.md) · [GEAR_BUDGET.md](GEAR_BUDGET.md) ·
[FLOOR_BLUEPRINT.md](FLOOR_BLUEPRINT.md).

## Cadence (every 2–4 weeks; aim monthly)

Each tagged `1.x.y` release should include:

1. **Balance pass** — iterate with share-only, then gate:
   - Fast: `flutter test test/class_balance_share_fast_test.dart` (or `--focus=specA,specB` via harness args)
   - Reads `tool/out/class_balance_share.json` + markdown board
   - CI: `test/class_balance_gate_test.dart` (live light, fails on DPS `**HIGH**`)
   - Mid band still manual / long (`class_balance_mid_sim_test`) when casters feel spicy
2. **Content slice** — one player-visible piece: dungeon beat, kit identity, meta sink, **local season week row**, Weekly/Gauntlet beat, or a11y/save polish. Prefer **core-loop feel** over new zones/classes (owner lock).
3. **Release notes** — What’s New in `lib/core/meta_systems.dart`; `test/changelog_sync_test.dart` keeps pubspec ↔ version ↔ zone tokens honest.

### Success-spår (research-backed)

1. **Habit** — hub TODAY READY/ALMOST always visible on phone; claim/progress CTAs.
2. **Local season** — `lib/core/local_season.dart` week/month rows (reuse SpatialCombat + vault/Gauntlet).
3. **Feel / kits** — owner lock **2026-08-18:** no new zones or classes. Prefer **core-loop feel** (power beats, combat juice) + kit fantasy polish. Play 12×14 stays background.

## Decision table (when unsure)

| Om ni tvekar mellan … | Välj |
|------------------------|------|
| Ny spec vs polisha kit | Polisha kit |
| Ny zon vs mer hub-chrome | Core-loop feel först (inga nya zoner). Hub-chrome bara om chase ljuger. |
| Cool affinity-nudge vs budget | Budget |
| Skippa test “för att CI flakar” | Fixa kontraktet — gutta inte |
| Stor rewrite vs small ship | Small ship + synlig What’s New |

## Non-goals (unless owner asks)

- IAP / paid shop (optional hub **POWERUPS** rewarded ads are OK)
- iOS or web-as-product
- SpatialCombat rewrite
- God Hand philosophy redesign
- Play production as the main work track
- Many new specs “for the list”

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

Do not couple rewrites of SpatialCombat, new account servers, or commercial art dumps to the monthly train. Optional stretch (Windows zip, score-share image) only if the owner asks.
