# GameDirector

Äger spelet medan appen kör.

## Jobb

- Håller `GameState` (immutable → ersätts via `GameLogic`)
- Sparar (`SharedPreferences`)
- ~60 Hz `spatialTick` bara i [[Dungeon]]
- Offline catch-up vid boot

## Tester

`GameDirector.preview()` — ingen timer / ingen disk.

## Upp

- [[App]] · [[AGENTS]]
