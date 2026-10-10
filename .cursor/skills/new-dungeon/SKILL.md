---
name: new-dungeon
description: >-
  Adds or extends an Idle Party dungeon zone (DungeonCatalog, FloorBlueprint,
  enemies, portraits, party-mean-level unlock, lore). Use when creating a new
  zone, boss, or unlock gate, or when the owner says "ny zon" / "new dungeon".
  Do not use for art-only reskins (zone-art-identity).
---

# New dungeon (Idle Party)

## Unlock rule

```dart
highestDungeonCleared >= def.number - 1
  || partyLevel >= DungeonCatalog.unlockHeroLevel(def)
```

Party **mean level** gates even steps Lv1…100 across 15 zones. Wallet gold and
`lifetimeGoldEarned` do **not** unlock dungeons (`DungeonCatalog.isUnlocked`).
Entry: `GameLogic.enterDungeon`.

## Source of truth

| Layer | Path |
|-------|------|
| Catalog | `lib/models/dungeon_def.dart` (`DungeonCatalog.all`) |
| Floor gen | `lib/spatial/floor_blueprint.dart` → `placement_plan.dart` → `zone_layout_kit.dart` |
| Layouts / chambers | `lib/spatial/tile_map.dart` (`RoomLayouts.forFloor`) |
| Portraits/backdrops | `lib/assets/custom_assets.dart` |
| Enemy sprites / floors | `lib/assets/kenney_assets.dart` |
| Ambient | `lib/ui/dungeon_environment.dart` |
| Names/pools | `EnemyFlavor.trashName` / `eliteName` / `addName` (`lib/core/enemy_flavor.dart`) + `encounter_factory.dart` |
| Lore | `lib/core/story_lore.dart` |
| Achievements | `lib/models/achievement_def.dart` (`clear_<id>`) + `MetaSystems` evaluators |
| Hub PATH | `lib/ui/hub/hub_world_map.dart` (continent marker, not a scroll row) |

Layouts: `cave` / `hideout` / `fort` / `arena`. Boss floor = `5 + AL`.

## Checklist

```
New dungeon:
- [ ] 1. Append DungeonDef (sequential number, unique id, layout, boss, blurb)
- [ ] 2. PNGs under assets/custom/portraits/, ui/backdrops/, enemies/ (owned art)
- [ ] 3. Wire CustomAssets + KenneyAssets enemy/floor maps
- [ ] 4. FloorBlueprint / PlacementPlan / ZoneLayoutKit beats
- [ ] 5. dungeon_environment ambient/wash
- [ ] 6. EnemyFlavor trash/elite/add names (+ boss via catalog)
- [ ] 7. StoryLore enter/clear lines
- [ ] 8. clear_<id> achievement if needed
- [ ] 9. Confirm hub unlock (mean level + prior clear) and a marker on the atlas
- [ ] 10. Tests: asset_catalog, custom_assets, dungeon_environment, story_lore, meta_systems
```

Follow **assets-legal** for all art (helpers only, no commercial dumps).
Follow **zone-art-identity** so the zone does not read as a crystal/hell reskin.

## Boss / clear

Push boss clear bumps `highestDungeonCleared` to `def.number` in room-advance paths. Keep catalog `number` sequential so unlock chaining stays correct.

## Verify

```bash
flutter test test/asset_catalog_test.dart test/custom_assets_test.dart test/dungeon_environment_test.dart test/story_lore_test.dart test/meta_systems_test.dart
```

## Done when

- The Verify tests above and `flutter test test/ship_smoke_test.dart` are green.
- The zone passes the `zone-art-identity` checklist against its nearest neighbor.
- `docs/FLOOR_BLUEPRINT.md` and the World path table in `AGENTS.md` name the zone (AGENTS edit belongs to that zone batch, not this cleanup).
