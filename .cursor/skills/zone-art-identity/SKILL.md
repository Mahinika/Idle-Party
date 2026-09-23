---
name: zone-art-identity
description: >-
  Checklist so Idle Party dungeon zones read as distinct (not crystal/hell
  reskins). Use when a cave looks like its neighbor, or the owner says a zone
  "looks the same". Do not use for full dungeon catalog wiring (new-dungeon)
  or for pack jobs and boss tells (spatial-combat-change).
---

# Zone art identity (Idle Party)

Legal: owned `assets/custom/` only. See [assets-legal](../assets-legal/SKILL.md).
`KenneyAssets` is the old name of that catalog. Do not import a Kenney pack.

Each zone already has its own boss and trash in `ZoneArt`. A cave that looks
like its neighbor is missing a sprite, wash, or prop. Do not reuse the neighbor.

## Must differ from nearest neighbor

For each new `dungeonId`, verify against the closest old zone (e.g. tide ≠ crystal, ember ≠ hell):

| Layer | File | Pass when |
|-------|------|-----------|
| Portrait | `lib/assets/custom_assets.dart` | Not the same const as the neighbor |
| Backdrop | `lib/assets/custom_assets.dart` | Not the same const as the neighbor |
| Boss sprite | `ZoneArt` via `KenneyAssets.enemySpriteForRole` | Owned PNG, not the neighbor's boss |
| Codex name map | `enemySpriteForCodexName` | Boss name → **same** asset as combat boss role |
| Trash/elite | `enemySpriteFor` archetypes | Mix differs (swarm/brute/ranged) |
| Ambient wash | `dungeon_environment.dart` | Clear hue/alpha vs neighbor |
| Floor/wall/props | `CustomAssets` (catalog name `KenneyAssets`) | Props/floor differ from the neighbor |
| Hub icon | `dungeonIconFor` | Not identical to neighbor |

## Checklist

```
Zone identity:
- [ ] 1. Portrait / backdrop aliases documented (or dedicated PNG under assets/custom/)
- [ ] 2. Boss role sprite ≠ nearest zone boss
- [ ] 3. Codex boss name matches combat boss sprite (asset_catalog_test)
- [ ] 4. Atmosphere wash + ambient distinct
- [ ] 5. Props / floor / hub icon distinct
- [ ] 6. Lore + What’s New name the zone
- [ ] 7. Apex shard name does not collide with another zone
```

## When the zone needs a new picture

1. Place under `assets/custom/portraits/` and `assets/custom/ui/backdrops/`
2. Wire getters on `CustomAssets` (no raw `assets/...` in UI)
3. `FilterQuality.none` via `KenneySprite`
4. New enemy sprites append to the catalog. Do not insert in the middle
   (the painter looks them up by index)

## Verify

```bash
flutter test test/asset_catalog_test.dart test/dungeon_environment_test.dart
```

## Related

- [new-dungeon](../new-dungeon/SKILL.md)
- `test/asset_catalog_test.dart` (codex ↔ combat boss)
