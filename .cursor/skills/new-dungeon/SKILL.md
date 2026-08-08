---
name: new-dungeon
description: >-
  Adds a new Idle Party dungeon (DungeonCatalog, layouts, enemies,
  portraits/backdrops, unlock via lifetime gold, lore, achievements).
  Use when creating or extending a dungeon zone, boss, or unlock gate.
---

# New dungeon (Idle Party)

## Unlock rule

```dart
highestDungeonCleared >= def.number - 1
  || lifetimeGoldEarned >= def.unlockPrice
```

Wallet gold does **not** unlock dungeons. Entry: `GameLogic.enterDungeon`.

## Source of truth

| Layer | Path |
|-------|------|
| Catalog | `lib/models/dungeon_def.dart` (`DungeonCatalog.all`) |
| Floor gen | `lib/core/dungeon_generator.dart` |
| Layouts | `lib/spatial/tile_map.dart` (`RoomLayouts.forFloor`) |
| Portraits/backdrops | `lib/ui/custom_assets.dart` |
| Enemy sprites / floors | `lib/ui/kenney_assets.dart` |
| Ambient | `lib/ui/dungeon_environment.dart` |
| Names/pools | `GameLogic._zoneArchetypeName` / enemy creators |
| Lore | `lib/core/story_lore.dart` |
| Achievements | `lib/models/achievement_def.dart` (`clear_<id>`) + `MetaSystems` evaluators |
| Hub list | `lib/ui/hub_screen.dart` (iterates catalog) |

Layouts: `cave` / `hideout` / `fort` / `arena`. Boss floor = `5 + AL`.

## Checklist

```
New dungeon:
- [ ] 1. Append DungeonDef (sequential number, unique id, unlockPrice, layout, boss, blurb)
- [ ] 2. PNGs under assets/custom/portraits/, ui/backdrops/, enemies/ (owned art)
- [ ] 3. Wire CustomAssets + KenneyAssets enemy/floor maps
- [ ] 4. dungeon_environment ambient/wash
- [ ] 5. _zoneArchetypeName (+ boss via catalog)
- [ ] 6. StoryLore enter/clear lines
- [ ] 7. clear_<id> achievement if needed
- [ ] 8. Confirm hub unlock UI
- [ ] 9. Tests: asset_catalog, custom_assets, dungeon_environment, story_lore, meta_systems
```

Follow **assets-legal** for all art (helpers only, no commercial dumps).
Follow **zone-art-identity** so the zone does not read as a crystal/hell reskin.

## Boss / clear

Push boss clear bumps `highestDungeonCleared` to `def.number` in room-advance paths. Keep catalog `number` sequential so unlock chaining stays correct.
