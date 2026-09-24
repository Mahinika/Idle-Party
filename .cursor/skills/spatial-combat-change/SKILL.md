---
name: spatial-combat-change
description: >-
  Guides combat, chamber, gate, AI, enemy packs/tells, and offline changes
  where SpatialCombat is the single authority. Use when combat feels wrong,
  AFK catch-up diverges, chambers/gates misbehave, enemies feel the same
  (fiender tråkiga / samma PULSE), or editing spatial_combat / ability_effects /
  tile maps / enemy_flavor. Do not use for a single broken cast (add-ability),
  zone sprite reskins (zone-art-identity), or DPS-only trim (grinding-until-pass).
---

# Spatial combat changes (Idle Party)

## Authority

- **Only** `SpatialCombat.build` / `SpatialCombat.step` (`lib/spatial/spatial_combat.dart`) for live and in-dungeon offline combat.
- Live: `GameDirector` ~60Hz → `step`
- Offline: `GameLogic.simulateSpatialOffline` → same `build`/`step` (`threatScale: 1.0`, `afkAssist: true`, VFX forced to `minimal`)
- Hub AFK (`!inDungeon`) = sanctuary gold only — **no** combat

Do **not** add a second combat simulator for offline.

## Floor / chamber model

- One combat wave per floor; boss on `5 + ascensionLevel` (`DungeonCatalog.bossFloor`)
- Generation: **FloorBlueprint** (`floor_blueprint.dart`) → **PlacementPlan** (`placement_plan.dart`) → **ZoneLayoutKit** (`zone_layout_kit.dart`) → `RoomLayouts` / `SpatialCombat.build`
- Multi-chamber maps + corridor gates: `lib/spatial/tile_map.dart` (`RoomLayouts`, `TileKind.gate`)
- Later chambers start **dormant**; wake when prior chambers clear (`_updateChambers`)
- Soft-unlock if only dormant packs remain or path blocked — preserve these safeties
- Clear: all dead → vacuum ground loot → walk to exit → `roomCleared` → `completeCurrentRoom`

## State rules

- Persistable: immutable `GameState` via `copyWith` in `GameLogic` / director
- Sim: `SpatialWorld` / `SpatialActor` are **mutable** during step; HP syncs back through `SpatialStepResult.state`
- Never invent a parallel HP/combat path outside `step`

## Knobs

| Knob | Role |
|------|------|
| `threatScale` | Scales enemy HP/ATK in `build` |
| `afkAssist` | Offline/boot catch-up assists (flask / God Hand pacing) |
| `reducedVfx` / `VfxQuality` | Skips floaters/bursts (offline forces `minimal`) |
| `GameDirector.preview()` | Tests: in-memory, no spatial timer |

## Touch map

| Change | Files |
|--------|-------|
| Kits / cast AI | `ability_effects.dart`, `spatial_combat.dart` |
| Movement / focus / threat | `spatial_combat.dart` |
| Zone packs / names / mix | `lib/core/enemy_flavor.dart` + `encounter_factory.dart` |
| Enemy specials / boss tells | `lib/spatial/enemy_specials.dart` + `lib/core/boss_tells.dart` (repeated shape). Unique tells stay named functions |
| Chambers / gates / blueprint | `floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart`, `tile_map.dart`, `spatial_combat.dart` |
| Offline catch-up | `game_logic.dart` (call sites only) |
| Live loop / rebuild | `game_director.dart` |
| Presentation only | `spatial_dungeon_view.dart` |

## Pitfalls

- Double-awarding loot/gold on room clear (live banking vs `completeCurrentRoom`)
- Mutating world outside `step` → desync with director `_rebuildSpatial`
- **Hub → dungeon enter must start the floor.** `GameLogic.enterX` only sets `inDungeon`. Live play needs `GameDirector._rebuildSpatial()` + `_startSpatialLoop()` (same as `enterDungeon` / Gauntlet / Rift / GR). Skip that → `SpatialDungeonView` stays on **Loading floor…** (`spatial == null`) even if tells exist in a test `step`. Ashen Crown hit this in 1.12.152.
- Gate/dormant bugs soft-lock AFK parties
- Forking ability logic for offline
- “Enemies feel the same” is fight identity, not missing sprites (`zone-art-identity` is the wrong skill). Fix pack jobs + zone mix/names + one boss tell in the same `step`
- Enemy list order **is** chamber order (spawns fill room 1 → 2 → 3). First third of `createEnemyGroup` = first fight room
- Unique boss tells stay near old PULSE power; AFK uses the same soften. Do not spawn adds mid-fight
- Signature kits hold on healthy trash unless **3** nearby are awake. Three-room floors hide later packs as dormant — kit tests that need a pack must wake dormant bodies, not only the first chamber

## Verify

```bash
flutter analyze lib test --no-fatal-infos
flutter test test/class_kits_combat_test.dart test/kit_passives_test.dart
```

```
Spatial change:
- [ ] Single authority preserved (no offline fork)
- [ ] Chamber/gate wake still safe
- [ ] Tests via preview + SpatialCombat.build/step
- [ ] New hub enter (Ashen / Gauntlet / Rift / Daily) asserts `director.spatial != null`
- [ ] flutter analyze + combat tests green
```
