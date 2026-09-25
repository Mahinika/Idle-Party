---
description: "Use when working on Flutter/Dart files in Idle-Party."
applyTo: "**/*.dart"
---

- Map and conventions: [AGENTS.md](../../AGENTS.md).
- Hard locks: `.cursor/rules/product-locks.mdc`. Work loop: `.cursor/rules/owner-preferences.mdc`.
- Game rules live in `GameLogic`. `GameDirector` orchestrates.
- State is immutable: `copyWith` inside `GameLogic`. Tests use `GameDirector.preview()`.
- Sprite paths go through `CustomAssets` or `KenneyAssets`. Pixel sprites use `FilterQuality.none`.
- No Riverpod or Provider. `ChangeNotifier` + `AnimatedBuilder`.
- One fight sim: `SpatialCombat`. Enemy groups come from `EncounterFactory` / `GameLogic.createEnemyGroup`.
- Floor randomness stays seeded (`floorNumber * 7919` plus the existing dungeon and layout terms). Do not add an unseeded `Random`.
