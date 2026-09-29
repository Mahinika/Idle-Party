---
name: enemy-art
description: >-
  Idle Party enemy, elite, and boss sprites in fights and the CODEX list.
  Use when a monster shows the wrong picture, two caves share a monster,
  a new enemy needs art, or the owner says "fienden ser fel ut", "det är en
  fladdermus", or "monstren ser likadana ut". Do not use for heroes
  (character-paper-doll), whole-cave look (zone-art-identity), new zones
  (new-dungeon), or legal art rules alone (assets-legal).
---

# Enemy art (Idle Party)

Owned art only, through the helpers (`assets-legal`).

## Files

- Every combat enemy PNG is flat in `assets/custom/enemies/`.
- Bosses are `boss_<dungeonId>.png`. Exception: Crystal uses
  `crystal_boss.png`.
- Zone units are `<zone>_<role>.png`: `mite`, `elite`, `brute`, `tank`,
  `ranged`, `swarm`, `support`, `wraith`, `guard`. Shared generics: `slime`,
  `rat`, `bat`, `spider`, `snake`, `ghost`, `cultist`, `cyclops`, `crab`,
  `golem`.
- Sizes mix 96×96 (older) and 32×32 (craft scripts). Both load at width 128,
  so either works. New art from the scripts is 32×32.
- Zone portraits in `assets/custom/portraits/` are cave art, not monsters.

## How a fight picks a picture

1. Path constant in `lib/assets/custom_assets.dart` (`CustomAssets.enemy*`),
   alias in `lib/assets/kenney_assets.dart`.
2. The roster per cave is `ZoneArt.byId(id).enemies` (`ZoneEnemyArt`) in
   `lib/models/zone_art.dart`. Boss and elite pick by role; everyone else
   picks by archetype with fallbacks (brute/tank → elite, ranged/glass/
   support → trash).
3. `KenneyAssets.enemySpriteFor(unit, dungeonId:)` returns the path.
   `spatial_combat.dart` stores its `enemySpriteCatalogIndex` as `assetIndex`.
4. `lib/ui/dungeon_paint_actors.dart` draws it: boss ×1.42 with a tinted
   ring, elite ×1.18, normal ×0.9. One frame; motion is a bob.

CODEX and the hideout stash pick by **display name** through
`KenneyAssets.enemySpriteForCodexName`. Unknown names fall back to
heuristics, often a bat. That is how "Goblin Slinger shows a bat" happened
(fixed in `d676375b` with `goblin_ranged.png`).

## Add or fix an enemy picture

1. Make the art: extend `tool/craft_early_enemy_art.py` or
   `tool/craft_late_enemy_art.py` (32×32), or add an owned PNG.
2. Add the `CustomAssets` constant and the `KenneyAssets` alias.
3. **Append** it to `KenneyAssets.enemySpriteCatalog`. Never insert in the
   middle; saved `assetIndex` values would point at the wrong picture.
4. Point the cave's `ZoneEnemyArt` slot at it.
5. Give every name in `lib/core/enemy_flavor.dart` that uses this slot an
   explicit case in `enemySpriteForCodexName`, so CODEX matches the fight.
6. A boss's CODEX name is `DungeonDef.bossName`; it must resolve to the
   same file as the combat boss.

## Verify

1. `flutter test test/zone_art_test.dart test/asset_catalog_test.dart test/kenney_assets_test.dart test/custom_assets_test.dart test/hideout_stash_test.dart`
   These check that files exist, each cave has its own boss and one sprite
   of its own, the CODEX boss matches the fight boss, and named units such
   as Goblin Slinger map right.
2. A56: enter that cave, look at trash, an elite, and the boss, then open
   CODEX and check the same monsters show the same pictures.

## Gotchas

- Renaming trash in `enemy_flavor.dart` without a CODEX case brings the bat
  back.
- Pets must never reuse an enemy path (`zone_art_test`).
- The `hideout_stash_test` title still says "combat bat" but asserts the
  goblin ranged sprite.
