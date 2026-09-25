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

Keep the steering shape:

- Play-upload lock stays in `product-locks`, `owner-preferences`, and
  `session_start.dart` only.
- `growth-mandate`, `studio-seats`, and `game-ux-director` stay
  `alwaysApply: false`.
- `AGENTS.md` is the map. It points at docs. It does not hardcode the ship
  version or restate the rules.
- `.github/instructions/flutter-blueprint.instructions.md` stays a pointer
  plus Dart facts that still match the code.
- Do not paste growth, AL20, or Play-upload essays back into every rule.
- Do not restore `init-slash` or `repo-audit-slash`. Slash entry is
  `.cursor/commands/` plus the skill (`disable-model-invocation: true`).
- Do not restore a skill map in `vibe-coder-autopilot` or
  `suggesting-skills`. Owner phrases live in each skill `description`.

## Procedure

1. **Snapshot truth (read, don’t guess)**
   - `pubspec.yaml` version ↔ `MetaSystems.currentVersion` / What’s New
   - `AGENTS.md` (architecture, meta, combat authority, build/test, MCP/skills)
   - `.cursor/rules/` (`product-locks`, `owner-preferences`, `definition-of-done`, `vibe-coder-autopilot`, `growth-mandate`, `studio-seats`, `game-ux-director`, others)
   - **Keep** six studio seats; do not restore a 40-role org
   - Key systems: `GameDirector`, `GameLogic`, `SpatialCombat`, hub/dungeon UI, `DungeonCatalog`, `metaDepth`, Ascend keep/reset
   - Docs that claim “current”: `docs/PLAY_STORE.md`, `docs/CONTENT_CADENCE.md`,
     `docs/GROWTH_MANDATE.md`, `docs/LEARNINGS.md` (owner names work; no standing program)
   - Optional fast honesty: `flutter test test/ship_smoke_test.dart` and/or MCP `changelog_check` / `zone_identity` if helpful

2. **Diff claims vs code**
   - Floor/chamber model, SpatialCombat as combat authority, hub AFK vs dungeon AFK
   - Meta that survives Ascend vs what resets
   - World path zones (ids/names/count), Gauntlet gates, Weekly/Will/seasons if documented
   - Build/verify commands, MCP server name, skill list
   - Live look is `a56-playtest` (Samsung A56 emulator), not web-server tabs
   - Owner prefs (language, Play vs sideload, commit/propose behavior) — update only if product reality changed
   - **Keep** owner-names-work default. The one AL20 sentence lives in `owner-preferences`.

3. **Edit**
   - Update **`AGENTS.md`** so architecture + conventions + tooling match code
   - Update **`.cursor/rules/*.mdc`** only where they contradict current behavior or owner prefs
   - Keep rules **short and actionable**; don’t dump audits into rules
   - Prefer one source per concern — no preference essays in `AGENTS.md`
   - Do not turn `growth-mandate`, `studio-seats`, or `game-ux-director` back into always-on rules
   - Do **not** invent new systems; do **not** expand scope into feature work unless drift blocks accurate docs

4. **Report (plain Swedish)**
   - 3–8 bullets: what was wrong / what you fixed
   - Note anything still uncertain (needs playtest) without blocking the doc sync
   - **Commit locally when green** (`owner-preferences`); push when the batch needs it; **never Play AAB without owner ask**

## Out of scope for /init

- Large refactors, balance retunes, new content
- Pushing unless the user already said yes this turn (local commit when green is OK)
- Rewriting or treating `docs/archive/audits/` snapshots as current kit truth (archive
  only; re-run `class-audit` for live verdicts)

## Done when

- `AGENTS.md` and touched rules match how the game works **now**
- No contradictory “source of truth” between AGENTS and always-on rules
