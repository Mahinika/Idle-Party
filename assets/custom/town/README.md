# Town assets

Owned Idle Party pixel art for the out-of-dungeon town. Target look:
autumn dusk (`docs/art/TOWN_AUTUMN_DUSK.md`, owner pick B).

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` + `tool/town_autumn_art.py` + `tool/town_life_art.py` |
| Method | Hand-placed pixel materials (stone courses, tile rows, cloth folds, leaves, pumpkins, chibi townsfolk). No foreign packs. |
| External packs | None |
| License | Same as the rest of `assets/custom/` — original game art |

Three painted facade tiers (timber / plaster or ashlar / banners). AL10
pennants and AL20 lanterns are owned pixel strips. Townsfolk frames share
one sheet. `TownFolkSheet` in Dart uses the same 96×112 cells and
draws them beside the party with nearest-neighbor.

Every sprite except the sky, the square, and the UI plates goes through
`town_autumn_art.dusk_grade`: a mild violet shade that leaves windows,
fire, and jack-o-lantern faces lit. Falling leaves, the campfire glow and
low mist are painted live by `TownAmbienceLayer` (Dart), not baked.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same warm ink as the heroes |
| Light | Upper-left on materials; warm point lights (windows, fire, lanterns) |
| Sky | Purple to ember bands, far skyline pinned to the square's top edge |
| Ground | Dark dusk cobbles, 64×64, seamless, fallen leaves |
| Roofs | Individual tiles. Dark red tile; guild tower spire |
| Windows | Amber glass, wood mullions, kept lit by the grade |
| People | Smith, courier, and gardener. Idle + 4 walk frames |
| Scale | `FilterQuality.none`. Folk are authored for the 48×56 yard |

## Files

| File | Use |
|------|-----|
| backdrop.png | Dusk sky, clouds, far skyline, autumn crowns (bottom-aligned) |
| ground.png | Dusk cobbles with leaves, 64×64, edges meet |
| path.png / path_b.png | Cobble street, 360×36, leaf drifts at the ends |
| approach.png | Cobble spur, 36×192, mortar meets at the wrap |
| alert.png | Claim spark on guild and vault |
| tree_round.png / tree_tall.png | Autumn crowns, gold leaves, fruit |
| flowers.png | Pumpkin patch with a jack-o-lantern |
| shrub.png | Rust-red autumn bush |
| wild.png | Corn sheaf |
| herbs.png | Hay bale and apple basket |
| meadow.png | Leaf pile, pumpkins, basket |
| thicket.png | Iron lamp post in a red bramble |
| scuff.png | Leaves blown across the stones |
| worn.png | Small cobble step for a doorway |
| contact.png | Shade under a wall |
| folk.png | 3 people × 5 frames, 96×112 cells |
| campfire.png | Stone-ring campfire at the square's center |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Round iron vault door in a stone arch |
