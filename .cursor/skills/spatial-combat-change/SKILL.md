---
name: spatial-combat-change
description: >-
  Guides combat, chamber, gate, AI, and offline changes where SpatialCombat
  is the single authority. Use when editing spatial_combat, ability_effects,
  tile maps, rooms, dormant enemies, threatScale, AFK catch-up, or floor clear.
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
| Chambers / gates | `tile_map.dart`, `spatial_combat.dart` |
| Offline catch-up | `game_logic.dart` (call sites only) |
| Live loop / rebuild | `game_director.dart` |
| Presentation only | `spatial_dungeon_view.dart` |

## Pitfalls

- Double-awarding loot/gold on room clear (live banking vs `completeCurrentRoom`)
- Mutating world outside `step` → desync with director `_rebuildSpatial`
- Gate/dormant bugs soft-lock AFK parties
- Forking ability logic for offline

## Verify

```
Spatial change:
- [ ] Single authority preserved (no offline fork)
- [ ] Chamber/gate wake still safe
- [ ] Tests via preview + SpatialCombat.build/step
- [ ] flutter analyze + relevant combat tests
```
