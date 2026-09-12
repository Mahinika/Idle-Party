---
name: init
description: >-
  /init — audit how Idle Party actually works now and refresh AGENTS.md plus
  .cursor/rules so agent guidance matches reality. Use when the user types
  /init or asks to resync agents docs/rules with the live game.
disable-model-invocation: true
---

# /init — resync agent truth with the game

When the user runs **`/init`**, do this job (do not ask which files to touch):

> **Gå igenom spelet och uppdatera `AGENTS.md` + regler så de stämmer med hur spelet funkar nu.**

## Goal

Make `AGENTS.md` and `.cursor/rules/*.mdc` accurate for **today’s** codebase and product decisions.

**Do not revert** `docs/GROWTH_MANDATE.md` / `.cursor/rules/growth-mandate.mdc`
to the old AL20-default slice while that done bar is incomplete. Sync
architecture facts; keep the growth program as default work.

## Procedure

1. **Snapshot truth (read, don’t guess)**
   - `pubspec.yaml` version ↔ `MetaSystems.currentVersion` / What’s New
   - `AGENTS.md` (architecture, meta, combat authority, build/test, MCP/skills)
   - `.cursor/rules/` (`growth-mandate`, `studio-seats`, `product-locks`, `vibe-coder-autopilot`, `owner-preferences`, `definition-of-done`, others)
   - **Keep** six studio seats; do not restore a 40-role org or AL20 expert panel
   - Key systems: `GameDirector`, `GameLogic`, `SpatialCombat`, hub/dungeon UI, `DungeonCatalog`, `metaDepth`, Ascend keep/reset
   - Docs that claim “current”: `docs/PLAY_STORE.md`, `docs/CONTENT_CADENCE.md`,
     `docs/GROWTH_MANDATE.md` (keep mandate until done bar is complete)
   - Optional fast honesty: `flutter test test/ship_smoke_test.dart` and/or MCP `changelog_check` / `zone_identity` if helpful

2. **Diff claims vs code**
   - Floor/chamber model, SpatialCombat as combat authority, hub AFK vs dungeon AFK
   - Meta that survives Ascend vs what resets
   - World path zones (ids/names/count), Gauntlet gates, Weekly/Will/seasons if documented
   - Build/verify commands, MCP server name, skill list
   - Live look is `a56-playtest` (Samsung A56 emulator), not web-server tabs
   - Owner prefs (language, Play vs sideload, commit/propose behavior) — update only if product reality changed
   - **Keep** growth mandate as default work until `docs/GROWTH_MANDATE.md` done bar is complete

3. **Edit**
   - Update **`AGENTS.md`** so architecture + conventions + tooling match code
   - Update **`.cursor/rules/*.mdc`** only where they contradict current behavior or owner prefs
   - Keep rules **short and actionable**; don’t dump audits into rules
   - Prefer one source per concern (`product-locks` vs workstyle vs skill map) — no preference essays in `AGENTS.md`
   - Do **not** invent new systems; do **not** expand scope into feature work unless drift blocks accurate docs

4. **Report (plain Swedish)**
   - 3–8 bullets: what was wrong / what you fixed
   - Note anything still uncertain (needs playtest) without blocking the doc sync
   - **Commit locally when green** (`owner-preferences`); ask before push

## Out of scope for /init

- Large refactors, balance retunes, new content
- Pushing unless the user already said yes this turn (local commit when green is OK)
- Rewriting or treating `docs/audits/` snapshots as current kit truth (archive
  only; re-run `class-audit` for live verdicts)

## Done when

- `AGENTS.md` and touched rules match how the game works **now**
- No contradictory “source of truth” between AGENTS and always-on rules
