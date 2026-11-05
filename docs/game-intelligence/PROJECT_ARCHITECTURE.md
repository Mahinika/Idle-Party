# Project architecture

Idle Party is a Flutter idle RPG. One `GameDirector` holds a `GameState` and
the live `SpatialCombat` world. Rules are pure functions on `GameLogic` and
the part files next to it. UI is `ChangeNotifier` plus widgets. No Riverpod.

Ship version lives in `pubspec.yaml` and `ChangelogCatalog.currentVersion`
(`lib/core/changelog.dart`). This note does not restate the product locks in
`AGENTS.md`.

## Boot

`main.dart` → loading → Play update gate → intro → title → save slot →
`PlayShell`.

`PlayShell` (`lib/ui/shell/play_shell.dart`):

- `HomeLayout.home` → `HomeShell` (fight-first). New phone saves land here
  (`GameDirector.startNewGame`).
- `HomeLayout.classic` → hub `HubScreen` or dungeon `Is2Shell`, plus
  `AppBottomBar` and `MenuSurface`.

## Home shell

```
HomeTopBar
FightViewport (Is2Shell homeChrome)  |  CampViewport
FightSeam          (only in a cave)
UpgradePanel       (SPLIT)  |  HomeGoldDock (FULL)
sheet: EssenceTilesScreen | MapScreen | MenuSurface
HomeNavBar: HEROES · ESSENCE · FIGHT · MAP · SHOP
```

`MenuRouter` (`lib/core/menu_router.dart`) is the open sheet. Home tabs come
from `MenuRouter.visibleHomeTabs`. MORE is the top MENU icon, not a tab.
GOLD is not a tab. FIGHT is “close the sheet”.

## Fight

`Is2Shell` paints `SpatialDungeonView`. With `homeChrome: true` it does not
build `DungeonTopHud`. The seam under the viewport owns Repeat/Next, the
fist, leave, and the party row.

Offline dungeon progress uses `OfflineSim`, not a second combat ruleset.

## Meta menus

| Job | Home | Classic |
|---|---|---|
| Gear | HEROES | GEAR |
| Forge, market, camp tracks | Panel or dock under the fight | GOLD, ESSENCE → CAMP |
| Blessing, relics, pets | ESSENCE tiles | ESSENCE |
| Caves and hunts | MAP | Hub PATH / ENDGAME |
| Shop | SHOP | SHOP |
| Quests, craft, settings | MENU | MORE |

Both call the same director methods. See `GAME_FEATURE_MATRIX.md` for which
home buttons currently fail to call them.

## Save

`GameState.toJson` / `fromJson`. Ascend keeps hero levels, zones, essence,
and `metaDepth` (including `homeLayout`). It resets gold, forge tracks, and
worn drops. Do not add or rename JSON fields in a UI wiring pass.

## What this folder is

`docs/game-intelligence/` is the audit for the home-shell wiring job. The
living product description stays in `AGENTS.md`.
