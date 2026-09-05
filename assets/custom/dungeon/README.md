# Custom dungeon interiors

Owned tiles + floor props for combat rooms (migration off Kenney `tiny_dungeon`).

```
dungeon/
  sandy/ … veil/     # all 15 zones
    tiles/           # 16×16 floor, wall, stairs, doors
    props/           # 32×32 MapPropKind sprites (full set per zone)
    hub_icon.png
```

Style rules: `docs/DUNGEON_ART.md`.

Code: `CustomAssets.customDungeonZones` → `KenneyAssets` with `dungeonId`.
Zones opt in via `ZoneArt.customDungeonArt` (all shipped zones).

Regenerate all zone art: `py tool/generate_dungeon_art.py`
