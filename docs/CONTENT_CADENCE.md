# Idle Party — monthly content cadence

**Active program (2026-09-12):** [GROWTH_MANDATE.md](GROWTH_MANDATE.md)
**Program 2** — hide-until-unlock + Play smoke. Program 1 (time-to-combat +
funnel) shipped the same day. This file is the **tag rhythm** (balance +
What’s New) under that program.

Optional background: [TOP_GAMES_RESEARCH.md](TOP_GAMES_RESEARCH.md). Live
contracts: [CHASE_CONTRACT.md](CHASE_CONTRACT.md) ·
[GEAR_BUDGET.md](GEAR_BUDGET.md) · [FLOOR_BLUEPRINT.md](FLOOR_BLUEPRINT.md) ·
[PLAY_GROWTH.md](PLAY_GROWTH.md).

## Cadence (every 2–3 weeks)

Each tagged `1.x.y` release should include:

1. **One Program 2 slice** — next unchecked box on `GROWTH_MANDATE.md` Program 2
   (first-hour chrome, TODAY honesty, starter kit HUD, Play smoke).
   Play What’s New in **one sentence a new player understands**.
2. **Balance pass** — iterate with share-only, then gate:
   - Fast: `flutter test test/class_balance_share_fast_test.dart` (or `--focus=specA,specB` via harness args)
   - CI: `test/class_balance_gate_test.dart` (live light, fails on DPS `**HIGH**`)
3. **Release notes** — What’s New in `lib/core/meta_systems.dart`; `test/changelog_sync_test.dart` keeps pubspec ↔ version ↔ zone tokens honest.

### Success-spår (Program 2)

1. **Activation** — new save combat in ≤90 s; day-one bar hides GOLD/SHOP/ESSENCE
   until they mean something; TODAY stays grow-the-party until the first boss.
2. **Habit** — one TODAY job a new player can do on day 1 and day 2–7.
3. **Store** — Play publish + SHOP/POWERUPS smoke; D1 when traffic exists.

AL20 chase / wipe advice / kit depth are **quality gates**, not the default
slice. Endgame copy and GEAR follow-up only against play notes. No new zones or classes (soft lock).

## Decision table (when unsure)

| Om ni tvekar mellan … | Välj |
|------------------------|------|
| AL20 polish vs first session | First-hour chrome + time-to-combat (`GROWTH_MANDATE.md` Program 2) |
| Ny spec vs polisha kit | Trim HIGH only; no specs for the list |
| Ny zon vs listing/onboarding | Listing + first session. Ny zon bara om ägaren ber |
| Cool affinity-nudge vs budget | Budget |
| Skippa test “för att CI flakar” | Fixa kontraktet — gutta inte |
| Stor rewrite vs small ship | Small ship + synlig What’s New a new player can read |
| Vagt “gör bättre” vs explicit bredare mål | Följ `GROWTH_MANDATE.md` Program 2 |
| Två stolar oense | `.cursor/rules/studio-seats.mdc` — EP + UX + Marketing vinner; Game/Tech/Art veto enligt stolen |

## Non-goals (unless owner asks)

- New zone #16 / new class
- SpatialCombat rewrite / God Hand philosophy redesign
- iOS or web-as-product
- Gacha / whale ladder
- Scaled paid UA before D1 is known
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
