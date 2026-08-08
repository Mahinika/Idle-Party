---
name: zone-art-identity
description: >-
  Checklist so Idle Party dungeon zones read as distinct (not crystal/hell
  reskins). Use when adding a dungeon, remapping Kenney sprites, or polishing
  Tide/Ember-style zone identity without new commercial art.
---

# Zone art identity (Idle Party)

Legal: only `assets/kenney/` (CC0) or `assets/custom/` (owned). See [assets-legal](../assets-legal/SKILL.md).

Dedicated PNGs are ideal; until then, **identity = remap + wash + props + hub icon**, not a copy of a neighbor zone.

## Must differ from nearest neighbor

For each new `dungeonId`, verify against the closest old zone (e.g. tide ≠ crystal, ember ≠ hell):

| Layer | File | Pass when |
|-------|------|-----------|
| Portrait | `lib/ui/custom_assets.dart` | Not the same const as the neighbor |
| Backdrop | `lib/ui/custom_assets.dart` | Not the same const as the neighbor |
| Boss sprite | `KenneyAssets.enemySpriteForRole(boss)` | Distinct family (crab/golem/… not twin of neighbor) |
| Codex name map | `enemySpriteForCodexName` | Boss name → **same** asset as combat boss role |
| Trash/elite | `enemySpriteFor` archetypes | Mix differs (swarm/brute/ranged) |
| Ambient wash | `dungeon_environment.dart` | Clear hue/alpha vs neighbor |
| Floor/wall/props | `kenney_assets.dart` | Props/floor differ (water/lava/…) |
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

## Prefer owned art when polish budget allows

1. Place under `assets/custom/portraits/` and `assets/custom/ui/backdrops/`
2. Wire getters on `CustomAssets` (no raw `assets/...` in UI)
3. `FilterQuality.none` via `KenneySprite`
4. Keep Kenney remaps for trash until custom enemies exist

## Related

- [new-dungeon](../new-dungeon/SKILL.md)
- `test/asset_catalog_test.dart` (codex ↔ combat boss)
