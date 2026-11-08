---
name: camera-follow
description: >-
  Proves a dungeon camera or picture slide stays with the body.
  Use when the camera lags, a charge hops, or dungeonCamEase changes,
  or the owner says "kameran halkar". Do not use for kit numbers
  (spatial-combat-change) or room size (floor-feel).
---

# Camera follow

Read the current thresholds from the code. Do not copy a tile count
from an old note.

## Procedure

1. Read `dungeonCamEase` in `lib/ui/dungeon_camera.dart` for the
   retarget distance, and `FightFrameBudget.steps` in
   `lib/core/fight_frame_budget.dart` for how many sim steps one paint
   runs. Pace 2 is two steps. A previous tick slower than the budget's
   late cutoff forces one step. The speed scroll is a separate
   multiplier on `dt`, not pace 2.
2. Add a bounded test that charges or moves, then samples the real
   ease at one step, pace 2, pace 2 plus one catch-up step, and one
   larger `dt`. Include a death and a pinned hero against the party mean.
3. Gameplay position, root, damage, and health stay on the sim step.
   The drawn point may trail. The test says how far.
4. A tile gap is not a frame time. This repo has no frame-time probe.
   Do not call the test a phone feel.

## Done when

- The new test is green and names the pace it covered.
- `flutter test test/dungeon_camera_test.dart` is green when that file moved.
