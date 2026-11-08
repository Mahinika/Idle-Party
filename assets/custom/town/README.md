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

These PNGs are the v1 **shipped** town look (tier 0). Higher-tier facades
in `docs/TOWN_DESIGN.md` are proposals, not extra files.

Regenerate:

```
python3 tool/generate_town_art.py
```

## Files

| File | Size | Use |
|------|------|-----|
| backdrop.png | 360×400 | Sky, hills, dirt square |
| building_forge.png | 96×128 | Chimney, anvil, fire |
| building_market.png | 96×128 | Awning, crates |
| building_inn.png | 96×128 | Thatch, hanging mug sign |
| ground.png | 360×64 | Cobble strip |
| preview_a56.png | 360×780 | Layout composite (not a Flutter screenshot) |
| buildings_sheet.png | 320×160 | Three facades for review |

Paint with `FilterQuality.none` via `CustomAssets.town*`.
