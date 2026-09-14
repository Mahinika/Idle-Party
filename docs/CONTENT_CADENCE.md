# Idle Party — monthly content cadence

**Standing principles:** [GROWTH_MANDATE.md](GROWTH_MANDATE.md) — no numbered
programs; owner names work. This file is the **tag rhythm** (balance + What’s
New). Do not restore AL20.

Optional background: [archive/TOP_GAMES_RESEARCH.md](archive/TOP_GAMES_RESEARCH.md). Live
contracts: [CHASE_CONTRACT.md](CHASE_CONTRACT.md) ·
[GEAR_BUDGET.md](GEAR_BUDGET.md) · [FLOOR_BLUEPRINT.md](FLOOR_BLUEPRINT.md) ·
[PLAY_GROWTH.md](PLAY_GROWTH.md).

## Cadence (every 2–3 weeks)

Each tagged `1.x.y` release should include:

1. **One visible slice** — What’s New in **one sentence a new player understands**.
   Owner names the slice (first session / listing / crawl / named endgame).
2. **Balance pass** — iterate with share-only, then gate:
   - Fast: `flutter test test/class_balance_share_fast_test.dart` (or `--focus=specA,specB` via harness args)
   - CI: `test/class_balance_gate_test.dart` (live light, fails on DPS `**HIGH**`)
3. **Release notes** — What’s New in `lib/core/meta_systems.dart`; `test/changelog_sync_test.dart` keeps pubspec ↔ version ↔ zone tokens honest.

### Success-spår (hold)

1. **Activation** — new Play save reaches combat early when possible; day-one
   chrome stays light when it helps.
2. **Habit** — one TODAY job a new player can do on day 1 and day 2–7 (Play return).
3. **Store** — D1 pasted **2026-09-14** (not readable); listing experiment when visitors suffice.

AL20 chase / wipe advice / kit depth stay **quality gates**, not the default slice.
Endgame copy and GEAR follow-up only against play notes. New zone / class when
the goal needs them.

## Decision table (when unsure)

| Om ni tvekar mellan … | Välj |
|------------------------|------|
| AL20 polish vs first session | First-hour chrome + time-to-combat (`GROWTH_MANDATE.md`) |
| Ny spec vs polisha kit | Ask if they want a new spec; otherwise trim HIGH |
| Ny zon vs listing/onboarding | Prefer listing + first session unless they asked for a zon |
| Cool affinity-nudge vs budget | Budget |
| Skippa test “för att CI flakar” | Fixa kontraktet — gutta inte |
| Stor rewrite vs small ship | Small ship + synlig What’s New a new player can read |
| Vagt “gör bättre” vs explicit bredare mål | Ask once. Do not restore AL20 |
| Två stolar oense | `.cursor/rules/studio-seats.mdc` — EP + UX + Marketing vinner; Game/Tech/Art veto enligt stolen |

## Non-goals (unless the batch needs them)

- SpatialCombat rewrite
- iOS or web-as-product
- Gacha / whale ladder
- God-object cleanup as the quarter’s story

## Checklist before tagging

- [ ] `flutter analyze` clean; `flutter test` green (CI on push).
- [ ] Kit / combat changes exercised via SpatialCombat path (live + offline share the same step).
- [ ] Changelog entry for this version; `seenChangelogVersion` will auto-prompt What’s New.
- [ ] First-hour / hub: `first_hour_plain_test` + hub smoke on A56 when those surfaces moved.
- [ ] If Android: AAB/APK only after owner play OK **and** they ask (see [PLAY_STORE.md](PLAY_STORE.md)).

## Agent tooling

| Need | Path |
|------|------|
| Mandate | `docs/GROWTH_MANDATE.md` |
| Share iterate | `tool/sim_class_balance.dart` `--share-only` / `--focus=` |
| Changelog sync | `test/changelog_sync_test.dart` |
| Hub / first hour | `.cursor/skills/hub-smoke` + `test/first_hour_plain_test.dart` |
| Play listing | `.cursor/skills/play-store-prep` |
| Cursor MCP | `.cursor/mcp.json` → `idle-party` |

## Out of cadence

Do not couple rewrites of SpatialCombat, new account servers, or commercial art dumps to the train. Optional stretch (Windows zip, score-share image) only if the owner asks.
