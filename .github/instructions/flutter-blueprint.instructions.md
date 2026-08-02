---
description: "Use when working on Flutter/Dart files in Idle-Party."
applyTo: "**/*.dart"
---

- All game rules belong in `GameLogic` (stateless). `GameDirector` only orchestrates — no logic there.
- State is immutable: always update via `GameState.copyWith()` inside `GameLogic` methods.
- Use `GameDirector.preview()` (in-memory) in tests — never real `SharedPreferences`.
- All asset paths go through `KenneyAssets` constants — never hardcode paths.
- Render sprites with `KenneySprite` (`filterQuality: none`, `isAntiAlias: false`) to preserve pixel art.
- Run `flutter analyze` after every change; the project targets zero warnings.
- Enemy scaling lives in one place (`GameLogic.createEnemy`) — do not add level bonuses in both the factory and the model constructor.
- Dungeon floors are deterministic: `DungeonGenerator.generateFloor` seeds `Random(floor × 7919)` — never introduce unseeded randomness in floor/room generation.
- No Riverpod or Provider — state flows via `ChangeNotifier` + `AnimatedBuilder`/`Listenable.merge`.
- See [AGENTS.md](../../AGENTS.md) for full architecture, build commands, and conventions.