# Town assets

Owned Idle Party pixel art for the out-of-dungeon town.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL). Daylight palette, warm ink from `gear_style.py` |
| External packs | None |
| License | Same as the rest of `assets/custom/` — original game art |

Three painted facade tiers (timber / plaster / banners). AL10 pennants and
AL20 lanterns are Flutter overlays. Townsfolk frames share one sheet.
`TownFolkSheet` in Dart uses the same 18×26 cells.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style

| Rule | Choice |
|------|--------|
| Ink (32, 22, 18), 1 px contour | Same ink as the heroes |
| Light | Upper-left bands, not a gradient |
| Square | Grass, dirt path, trees, flowers, daylight sky |
| Roofs | Red tile, green or cream awnings |
| Windows | Warm amber, not blue glass |
| People | Three original figures, idle + 4 walk frames |
| Scale | `FilterQuality.none` |

The cave-brown paving pass was replaced after the owner saw it on device
and asked for a lighter, living town. Dungeon art is unchanged.

## Files

| File | Use |
|------|-----|
| backdrop.png | Sky, clouds, sun, hills, distant trees |
| ground.png | Repeating grass tile |
| path.png | Dirt path strip |
| tree_round.png / tree_tall.png | Plaza trees |
| flowers.png | Flower cluster |
| folk.png | 3 people × 5 frames (idle, walk×4), 18×26 cells |
| well.png | Well |
| forge / market / inn / guild `_t0..t2` | Facades |
| vault_shut.png / vault_open.png | Daily chest |
