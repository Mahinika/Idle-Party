---
name: floor-feel
description: >-
  Idle Party dungeon floor, room, hall, and camera sizes, so a fight fits one
  phone screen. Use when the owner says rooms, floors, or halls feel too big,
  too small, empty, cramped, or that zoom is wrong ("rummen är för stora",
  "golven är enorma", "zooma"). Do not use for enemy AI or pack jobs
  (spatial-combat-change), a cave that looks like its neighbor
  (zone-art-identity), or a new zone (new-dungeon).
---

# Floor feel (Idle Party)

Rule of thumb: at the default zoom, one fight room is about one A56 screen.

## Landed sizes (2026-09-29, commit e802ec62)

Floors swung from ~55×40 to ~250×250, then halved, then scaled rooms with
the map, then landed here. Do not grow the canvas or scale rooms with floor
number again without a before and after on the A56 (`owner-preferences`).

| Knob | Value | Where |
|------|-------|-------|
| Floor canvas | `104 + p×2` × `66 + p`, `p = layoutPressure` 0–10 (AL/4 + KEY/4) | `lib/spatial/tile_map.dart` `RoomLayouts._mapExtent` |
| Boss map / oval | `48 + e×2` × `40 + e` (e ≤ 6); oval 18×13 | `tile_map.dart` `_bossArena` |
| Room sizes | fixed phone tiles per beat, clamped only to the map | `tile_map.dart` `sizeFor` → `_fitRoom` |
| Approach / hub / elite | 15–17×11–12 / 18–19×13–14 / 14–15×12–13 | same |
| Choke | 8–9 × 12–14 (or turned) | same |
| Halls / chokes | 4 / 3 tiles wide | `_carveCorridorWithGate` |
| Fight room count | from enemy budget: 1–5 (≥16 enemies → 5) | `lib/spatial/floor_blueprint.dart` `_mainCombatRooms` |
| Camera | NEAR 16 / MID 20 / FAR 24 cols; pinch 12–36, saved as `dungeonViewCols` | `lib/models/dungeon_zoom.dart`, `spatial_dungeon_view.dart` |
| Terrain bake | 16 px per tile | `lib/ui/dungeon_floor_layer.dart` |

What scales with progress: pack size, fight room count, and a small canvas
bump from AL/KEY pressure. Room size does not.

## Before you change a number

1. Say which feel you are fixing (too much walking, cramped fights, empty
   rooms) and which one knob moves it. Change one knob per batch.
2. Keep live and offline the same: `SpatialCombat.build` is the only layout
   entry. Never add a second generator for AFK.
3. Bigger canvases cost bake memory. 250×250 at 16 px is ~4000×4000.
4. Room shape comes from `room_silhouette.dart` / `floor_theme.dart`;
   props from `placement_plan.dart`. They do not own sizes.

## Verify

1. `flutter test test/floor_blueprint_test.dart test/floor_look_test.dart test/meta_systems_test.dart`
   (size gates: canvas ≥104×66, widest chamber 14–22, tallest 10–18, gates
   3/4, pinch clamp 12–36). Update the gates in the same commit if the owner
   picked new sizes.
2. `flutter test test/spatial_combat_test.dart test/combat_positioning_test.dart`
3. A56: new save, first cave at MID zoom. One fight should fill the screen
   without panning. Pinch in and out once.
4. Update the size table in `docs/FLOOR_BLUEPRINT.md` and this skill.

## Gotchas

- The test named "boss arena grows with the floor" only sees the pressure
  bump; the oval is fixed.
- `fallbackRoomCount` only runs when the blueprint carve fails.
- The camera does not clamp to the map on purpose.
