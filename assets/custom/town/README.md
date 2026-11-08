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
pennants and AL20 lanterns are Flutter overlays. Townsfolk frames share
one sheet. `TownFolkSheet` in Dart uses the same 96×112 cells and
draws them at about half size with nearest-neighbor.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same warm ink as the heroes |
| Light | Upper-left, in clusters on each stone, tile, and fold |
| Ground | Quiet meadow, stepping stones, four different plantings |
| Roofs | Individual tiles. Guild slate, houses terracotta, market a folded awning |
| Windows | Amber glass, wood mullions |
| People | Three villagers at hero source size, idle + 4 walk frames |
| Scale | `FilterQuality.none`. Folk source is 96×112 and draws near 48×56 |

## Files

| File | Use |
|------|-----|
| backdrop.png | Banded sky, clouds, ridge, distant roof |
| ground.png | Repeating grass tile |
| path.png | One ragged stepping-stone course, 360×40, transparent gaps |
| tree_round.png / tree_tall.png | Clumped canopies |
| flowers.png / shrub.png / wild.png / herbs.png | Four different plantings |
| meadow.png / thicket.png / scuff.png | Unique lawn clumps, placed once |
| worn.png | Small worn patch for a doorway |
| contact.png | Dark grass under a building |
| folk.png | 3 people × 5 frames, 96×112 cells |
| well.png | Stone well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Ironbound chest on a plinth |
