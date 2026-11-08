# Town assets

Owned Idle Party pixel art for the out-of-dungeon town hub.

## Provenance / license

| Field | Value |
|-------|--------|
| Author | Idle Party (this repository) |
| Tool | `tool/generate_town_art.py` |
| Method | Hand-specified pixel geometry (PIL), same path as `generate_floor_props.py` |
| External packs | None. No Kenney, no marketplace, no paid downloads |
| License | Same as the rest of `assets/custom/` — original game art |

Three **painted** facade tiers (timber / stone / banners). AL10 pennants and
AL20 lantern arcade are drawn in Flutter on top of these sprites.

Regenerate:

```
python3 tool/generate_town_art.py
```

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×520 | Sky, hills, dirt square |
| ground.png | 360×64 | Cobble strip |
| well.png | 48×56 | Square well (non-interactive) |
| forge_t0/t1/t2.png | 128×176 | Forge facades |
| market_t0/t1/t2.png | 128×176 | Market facades |
| inn_t0/t1/t2.png | 128×176 | Inn facades |
| guild_t0/t1/t2.png | 152×204 | Guild hall facades |
| vault_shut.png / vault_open.png | 88×112 | Daily Vault chest |
| preview_a56.png | 360×780 | Layout composite (not a Flutter screenshot) |
| buildings_sheet.png | 520×420 | Tier strip for review |

Paint with `FilterQuality.none` via `CustomAssets.town*`.
