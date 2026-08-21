# Dungeon

När `inDungeon` — [[SpatialCombat]] kör fighten.

## Skärm

- **Stage** — kameran följer partyt (`SpatialDungeonView`)
- **FARM / PUSH** — lugnare farm vs pusha djupare
- **God Hand** — tryck: styr + AOE (CD)
- Party-HUD + flask + target-panel
- Bottenrad: [[PARTY]] · [[POWER]] · [[META]] · **HUB** (lämna → [[Hub]])

## Flow per våning

FloorBlueprint → rum/chambers → kill → loot vacuum → stairs → nästa

## Offline / AFK i dungeon

Samma `SpatialCombat.step` med `afkAssist` — inte en andra sim.

## Upp

- [[App]]
- [[SpatialCombat]]
- [[FLOOR_BLUEPRINT]]
