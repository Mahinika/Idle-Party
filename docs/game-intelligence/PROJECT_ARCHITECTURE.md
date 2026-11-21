# Project architecture

Idle Party is a Flutter idle RPG. One `GameDirector` holds a `GameState` and
the live `SpatialCombat` world. Rules are pure functions on `GameLogic` and
the part files next to it. UI is `ChangeNotifier` plus widgets. No Riverpod.

Ship version lives in `pubspec.yaml` and `ChangelogCatalog.currentVersion`
(`lib/core/changelog.dart`). Product locks and the live navigation map stay in
`AGENTS.md`.

## Repository map

| Tree | Role |
|------|------|
| `lib/core/` | `GameDirector`, `GameLogic`, saves, hub chase, offline, ads, Remote Config (`remote_tune.dart`) |
| `lib/spatial/` | `SpatialCombat`, floors, placement, ability runners |
| `lib/models/` | Heroes, gear, dungeons, meta depth, kits |
| `lib/ui/shell/` | `PlayShell`, `HomeShell`, fight HUD, bottom nav, menu sheets |
| `lib/ui/shell/home/` | Fight-first home layout, town viewport, gold dock |
| `lib/ui/hub/` | Classic hub, TODAY card, PATH |
| `lib/ui/meta/` | Welcome Back, settings, overlays |
| `test/` | Unit, widget, and golden tests (`test/goldens/after/*_a56.png`) |
| `tool/` | Playtest, adb, gear art, CI install scripts |
| `docs/` | Play, floors, growth, **TESTING.md** |

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
HomeTopBar + goal line (ChaseContract.goalLine)
FightViewport (Is2Shell homeChrome)  |  CampViewport / TownViewport
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

First boss stays on **floor 2** (`GameLogic.firstBossFloor`). The first climb
coach (`FirstClimbCoach`) and hub chase share `ChaseContract.goalLine`.

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

## Testing

See [docs/TESTING.md](../TESTING.md). CI runs `flutter test --exclude-tags sim`;
agents run analyze plus targeted tests for their batch.

## What this folder is

`docs/game-intelligence/` holds audits and architecture notes. The living
product description stays in `AGENTS.md`.