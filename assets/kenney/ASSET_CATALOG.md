# Tiny Dungeon asset catalog

Kenney pack is **132 tiles** (`tile_0000` … `tile_0131`), sheet **12×11**.
Game files live at `assets/kenney/tiny_dungeon/tile_XXXX.png`.

Semantic names are **only** in `lib/ui/kenney_assets.dart` via `KenneyAssets.tile(id)`.

Rebuild from originals:

```powershell
powershell -File tool/rebuild_tiny_dungeon_assets.ps1
```

Contact sheet (indexed): `tool/_tiny_dungeon_sheet.png`

## Categories (game mapping)

| Category | Tile IDs | Getters |
|----------|----------|---------|
| Floors dirt | 0–3 | `floorDirt*` |
| Floors sand | 30–32 | `floorSand*` |
| Floors stone | 42–44 | `floorStone*` |
| Walls | 28–29, 39–40 | `wallBanner*`, `wallStone*` |
| Doors | 6, 45–47 | `doorArch`, `doorClosed/Open/Variant` |
| Stairs / exit | 17–19 | `stairsDown`, `stairs`, `exitPad` |
| Hazards | 41, 50, 55 | `trapSpikes`, `hazardWater/Lava` |
| Markers | 60–62 | `target`, `slash`, `claw` |
| Props | 63–66, 70–75, 81–83, 89–92 | graves, torches, chests, barrel… |
| Heroes | 84–88, 96–100 | wizard → elder |
| Enemies | 108–112, 120–124 | slime → snake |
| Gear | 101–106, 113–119, 125–131 | shields, weapons, potions, staves |

## Extras (not Tiny Dungeon)

`assets/kenney/extras/` — `book.png`, `coin_gold.png`, `ring.png`

## UI packs (unchanged)

- `ui_adventure/` panels & buttons
- `ui_bars/` HP bar slices
- `icons/` HUD icons
- `runes/` relics

## Why tile IDs

Previous semantic filenames had **duplicate MD5** (e.g. `boots` == `stairs`, `prop_skull` == `hero_wizard`, `enemy_cultist` == `enemy_boss`). IDs cannot lie.
