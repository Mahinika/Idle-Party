# Town assets

Owned Idle Party pixel art for the out-of-dungeon town.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-placed pixel materials (stone courses, tile rows, cloth folds, chibi townsfolk). No foreign packs. |
| External packs | None |
| License | Same as the rest of `assets/custom/` — original game art |

Three painted facade tiers (timber / plaster or ashlar / banners). AL10
pennants and AL20 lanterns are owned pixel strips. Townsfolk frames share
one sheet. `TownFolkSheet` in Dart uses the same 96×112 cells and
draws them beside the party with nearest-neighbor.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same warm ink as the heroes |
| Light | Upper-left, in clusters on each stone, tile, and fold |
| Ground | Varied lawn, worn track, cobbles, flowers, shade |
| Roofs | Individual tiles. Guild slate, houses terracotta, market a folded awning |
| Windows | Amber glass, wood mullions |
| People | Smith, courier, and gardener. Idle + 4 walk frames |
| Scale | `FilterQuality.none`. Folk are authored for the 48×56 yard |

## Files

| File | Use |
|------|-----|
| backdrop.png | Banded sky, clouds, ridge, distant roof |
| ground.png | Repeating lawn, 240×240, wraps |
| path.png | Cobble course, 360×52, transparent gaps |
| alert.png | Claim spark on guild and vault |
| tree_round.png / tree_tall.png | Leaf clumps, blossoms, fruit |
| flowers.png / shrub.png / wild.png / herbs.png | Four different plantings |
| meadow.png / thicket.png / scuff.png | Unique lawn clumps, placed once |
| worn.png | Small worn patch for a doorway |
| contact.png | Dark grass under a building |
| folk.png | 3 people × 5 frames, 96×112 cells |
| well.png | Stone well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Ironbound chest on a plinth |
