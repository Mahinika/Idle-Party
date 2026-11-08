# Town assets

Owned Idle Party pixel art for the out-of-dungeon town hub.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL). Palette measured from Sandy floor/wall, `gear_style.py` ramps, and `ui/hub_scene.png` |
| External packs | None. No Kenney, no marketplace, no paid downloads |
| License | Same as the rest of `assets/custom/` — original game art |

Three **painted** facade tiers (timber / stone / banners). AL10 pennants and
AL20 lantern arcade are drawn in Flutter on top of these sprites.

Deterministic: no RNG. Regenerate:

```
python3 tool/generate_town_art.py
```

## Style rules (same game)

| Rule | Source |
|------|--------|
| Warm ink (32, 22, 18), 1 px outer contour | `tool/gear_style.py` |
| Upper-left light | `LIGHT_DIR` in `gear_style.py` |
| Sand stone, not grey brick | `dungeon/sandy/tiles/floor_a.png`, `wall_a.png` |
| Amber windows, torch light | Sandy backdrop + chest highlight |
| Gatehouse guild | `ui/hub_scene.png` arch and banners |
| Nearest-neighbor only | `FilterQuality.none` |

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×400 | Ochre sky, ridges, cave mouth |
| ground.png | 360×48 | Repeating sand flags (paint 1:1, no cover-scale) |
| well.png | 56×68 | Well (non-interactive) |
| forge_t0/t1/t2.png | 120×156 | Smithy. Chimney on the right |
| market_t0/t1/t2.png | 120×140 | Stall, not a house |
| inn_t0/t1/t2.png | 120×160 | Jetty inn |
| guild_t0/t1/t2.png | 156×176 | Crenellated gatehouse |
| vault_shut.png / vault_open.png | 88×104 | Bound chest |
| buildings_sheet.png | tier strip for review |

Paint with `FilterQuality.none` via `CustomAssets.town*`.
