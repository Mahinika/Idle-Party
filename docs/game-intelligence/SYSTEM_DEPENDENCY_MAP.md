# System dependency map

Arrows mean “calls or reads”. No new systems.

```
PlayShell
  ├─ HomeLayout.home → HomeShell
  │    ├─ HomeTopBar → HubChase (text) · cycleCombatPace · MENU
  │    ├─ FightViewport → Is2Shell(homeChrome)
  │    │    └─ SpatialDungeonView → SpatialCombat
  │    │         └─ GameDirector.spatialTick / godHandAtWorld
  │    ├─ FightSeam → setDungeonMode · godHandAtFocus · leave · setHomePanelFull
  │    │    └─ PartyCornerHud → useConsumable · kit strip · HEROES
  │    ├─ UpgradePanel | HomeGoldSheet
  │    │    ├─ ForgeOverlay → director_forge upgrades
  │    │    ├─ SanctuaryOverlay → upgradeSanctuary
  │    │    └─ MarketOverlay → MarketService / listings
  │    ├─ EssenceTilesScreen → EssenceKeepPanel · RelicsOverlay · BeastOverlay
  │    │    └─ Codex / Apex via MenuRoute.more
  │    ├─ MapScreen → enterDungeon · confirm* hunts · KeystoneSheet
  │    └─ MenuSurface → InventoryDock · ShopDock · JobsOverlay · MoreList
  └─ HomeLayout.classic → HubScreen + Is2Shell + DungeonTopHud + WispGiftOverlay

GameDirector  (ChangeNotifier, one save)
  ├─ GameLogic / part files (immutable GameState.copyWith)
  ├─ SpatialCombat (live) and OfflineSim (away)
  ├─ MenuRouter (which sheet). Does not own rules.
  └─ platform: ads, billing, Play Games, notifications
        UI may open those screens. Purchase and ad result code stays in
        shop_billing.dart / ad_rewarded.dart / director_platform.dart.

ChaseDispatcher.plan → runChasePlan
  ├─ claims: claimDailyVault / claimMission board / claimMonthPass
  ├─ nav: MenuRouter.open (gear, market, key, info)
  └─ confirms: gauntlet, rift, greater rift, ashen, ascend, daily

WipeAdvice.hubNavFor → NavIntent → hubAfterWipe → PlayShell applies it
  on the way out of the cave. HomeShell then drops MenuRoute.gold.

MenuTabs gates (menu_alerts.dart) read GameLogic.showDailyChase,
plainPlayerChrome, endgameUnlocked. They hide tabs. They do not delete saves.
```

Save fields stay on `GameState` / `MetaDepthState`. Ascend keep/reset is
`GameLogic` ascend (`lib/core/game_logic_ascend.dart`). This pass does not
change that.
