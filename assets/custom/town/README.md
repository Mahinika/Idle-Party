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
one sheet. `TownFolkSheet` in Dart uses the same 40×48 cells.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same warm ink as the heroes |
| Light | Upper-left, in clusters on each stone, tile, and fold |
| Ground | Grass clumps and a repeating cobble, not a flat wash |
| Roofs | Individual tiles. Guild slate, houses terracotta, market a folded awning |
| Windows | Amber glass, wood mullions |
| People | Three chibi figures at hero scale, idle + 4 walk frames |
| Scale | `FilterQuality.none`. Folk draw at native size and only shrink to fit a short yard |

## Files

| File | Use |
|------|-----|
| backdrop.png | Banded sky, clouds, ridge, distant roof |
| ground.png | Repeating grass tile |
| path.png | Repeating cobble tile |
| tree_round.png / tree_tall.png | Clumped canopies |
| flowers.png | Flower cluster |
| folk.png | 3 people × 5 frames, 40×48 cells |
| well.png | Stone well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Ironbound chest on a plinth |
