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

Make `AGENTS.md` and `.cursor/rules/*.mdc` accurate for **today’s** codebase and product decisions — not the last roadmap wish list.

## Procedure

1. **Snapshot truth (read, don’t guess)**
   - `pubspec.yaml` version ↔ `MetaSystems.currentVersion` / What’s New
   - `AGENTS.md` (architecture, meta, combat authority, build/test, MCP/skills)
   - `.cursor/rules/` (`vibe-coder-autopilot`, `owner-preferences`, `definition-of-done`, others)
   - Key systems: `GameDirector`, `GameLogic`, `SpatialCombat`, hub/dungeon UI, `DungeonCatalog`, `metaDepth`, Ascend keep/reset
   - Docs that claim “current”: `docs/PLAY_STORE.md`, `docs/CONTENT_CADENCE.md`,
     `docs/STRATEGY_90D.md` (only if AGENTS/rules point at stale claims)
   - Optional fast honesty: `flutter test test/ship_smoke_test.dart` and/or MCP `changelog_check` / `zone_identity` if helpful

2. **Diff claims vs code**
   - Floor/chamber model, SpatialCombat as combat authority, hub AFK vs dungeon AFK
   - Meta that survives Ascend vs what resets
   - World path zones (ids/names/count), Gauntlet gates, Weekly/Will/seasons if documented
   - Build/verify commands, MCP server name, skill list
   - Owner prefs (language, Play vs sideload, commit/propose behavior) — update only if product reality changed

3. **Edit**
   - Update **`AGENTS.md`** so architecture + conventions + tooling match code
   - Update **`.cursor/rules/*.mdc`** only where they contradict current behavior or owner prefs
   - Keep rules **short and actionable**; don’t dump audits into rules
   - Do **not** invent new systems; do **not** expand scope into feature work unless drift blocks accurate docs

4. **Report (plain Swedish)**
   - 3–8 bullets: what was wrong / what you fixed
   - Note anything still uncertain (needs playtest) without blocking the doc sync
   - Propose commit if changes are ship-shaped (`owner-preferences`)

## Out of scope for /init

- Large refactors, balance retunes, new content
- Committing/pushing unless the user already said yes this turn
- Rewriting historical audits under `docs/audits/` (add a one-line “historical” note only if AGENTS wrongly treats them as current)

## Done when

- `AGENTS.md` and touched rules match how the game works **now**
- No contradictory “source of truth” between AGENTS and always-on rules
