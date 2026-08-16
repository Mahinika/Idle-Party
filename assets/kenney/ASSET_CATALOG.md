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
| Floors dirt | 0–3, 24 | `floorDirt*`, `floorDirtDetail` |
| Floors sand | 48–49 | `floorSand*` (avoid legacy edged sand tile 30 as fill) |
| Floors stone | 42 | `floorStone*` |
| Walls | 28–29, 40, 57 | `wallBanner*`, `wallStone*` |
| Doors | 6, 45–47 | `doorArch`, `doorClosed/Open/Variant` |
| Stairs / exit | 17–19 | `stairsDown`, `stairs`, `exitPad` |
| Hazards | 32, 41 | `hazardWater`, `hazardLava` / `trapSpikes` |
| Markers | 60–62 | `corridor*`, `target`, `slash`, `claw` |
| Props | 8, 20, 56, 63–66, 72–74, 82, 89–92 | torch, crate, graves, chests, barrel… |
| Heroes (fallback tiles) | 85–87, 98, 100 | villager / bearded / soldier / woman / elder |
| Enemies (fallback tiles) | unused in combat | combat uses `assets/custom/enemies/` |
| Gear | 101–106, 113–119, 125–131 | shields, weapons, potions, staves |

## Extras (not Tiny Dungeon)

`assets/kenney/extras/` — `book.png`, `coin_gold.png`, `ring.png`

## Custom identity art (`assets/custom/`)

Owned Idle Party pixel art. Preferred over Tiny Dungeon for heroes, enemies, pets, gear slot icons, dungeon portraits, and painted backdrops.

| Folder | Use |
|--------|-----|
| `custom/heroes/` | 10 class dolls: knight, paladin, hunter, rogue, healer, deathknight, shaman, wizard, warlock, druid |
| `custom/enemies/` | Combat + Codex sprites (slime, rat, bat, spider, ghost, cultist, cyclops, crab, golem, bosses, crystal_*) |
| `custom/pets/` | Egg + ember_pup / cave_bat / loot_sprite / warden_cub (other species remap to nearest) |
| `custom/icons/` | Armor/jewelry slot icons + tome |
| `custom/portraits/` + `custom/ui/backdrops/` | Per-dungeon hub identity (7 zones) |
| `custom/ui/` | intro/hub/dungeon scenes and the World Path map (launcher/store icon source lives in `tool/art_backups/app_icon.png`, outside the bundle) |

Codex names resolve via `KenneyAssets.enemySpriteForCodexName` (keyword + exact maps; no hash lottery).

Integrity gate: `test/asset_catalog_test.dart`.

## UI packs (unchanged)

- `ui_adventure/` panels & buttons
- `ui_bars/` HP bar slices
- `icons/` HUD icons (`door` = More, `shield_icon` = Settings)
- `runes/` relics
- `roguelike_char/` paper-doll sheet (`HeroPaperDoll`)

## Why tile IDs

Previous semantic filenames had **duplicate MD5** (e.g. `boots` == `stairs`, `prop_skull` == `hero_wizard`, `enemy_cultist` == `enemy_boss`). IDs cannot lie.
