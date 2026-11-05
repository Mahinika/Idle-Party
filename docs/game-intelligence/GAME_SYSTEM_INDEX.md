# Game system index

Audited **2026-11-05** on `cursor/ui-shell-polish-a824` (Robert’s Brick Inc shell).
Claims cite the type and file that own the rule. This is not a design wishlist.

New phone saves with no prior save boot into `HomeLayout.home` and
`homePanelFull: true` (`GameDirector.startNewGame` in
`lib/core/director_save.dart`). `PlayShell` then builds `HomeShell`
(`lib/ui/shell/play_shell.dart`). Classic hub + `DungeonTopHud` stays
available from SETTINGS **NEW LAYOUT (BETA)** when a git stamp or debug
build is present (`SettingsOverlay` in `lib/ui/shell/settings_overlay.dart`).

| System | Rule owner | Player mutation | What it does |
|---|---|---|---|
| Fight sim | `SpatialCombat` `lib/spatial/spatial_combat.dart` | `GameDirector.spatialTick` `lib/core/director_fight.dart` | Live cave. One step per refresh. |
| Offline cave | `OfflineSim` `lib/core/offline_sim.dart` | boot catch-up in `director_save.dart` | Same authority as live, via `GameLogic.simulateSpatialOffline`. |
| Hub AFK gold | `GoldIncome` `lib/core/gold_income.dart` | shown by `showHubIncomeSheet` | Gold + slow essence while out of a cave. Not combat. |
| Zones / floors | `DungeonCatalog` `lib/models/dungeon_def.dart`, `GameLogic.enterDungeon` path | `GameDirector.enterDungeon` / `leaveDungeon` | Sandy through Mothveil. Unlock is party mean level or prior clear. |
| Floor travel | `GameLogic.canTravelToFloor` / `travelToFloor` | `GameDirector.travelToFloor` | Jump to a cleared floor. |
| FARM / PUSH | `DungeonMode` | `GameDirector.setDungeonMode` | Repeat the floor or climb. |
| FARM intensity | `FarmIntensity` `lib/core/farm_intensity.dart` | `setFarmIntensity` / `tryFarmIntensity` | 1× / 2× / 4× packs on a cleared farm floor. |
| HOLD stairs | exit hold on the world | `GameDirector.startExitHold` | Skip the walk after a clear. |
| God Hand | `GameLogic.upgradeGodHand`, style on `metaDepth.godHandStyle` | `godHandAtFocus`, `upgradeGodHand`, `upgradeGodHandCd`, `setGodHandStyle`, `claimGodHandMastery` | Smash. Style BAL / FOCUS / WIDE. |
| Flasks / bandages | `MarketService` `lib/core/market_service.dart` | `buyMarketFlask`, `buyMarketBandage`, `useConsumable` | Buy in market, drink from the party row. |
| Forge tracks | `lib/core/game_logic_forge.dart` | `GameDirector.upgradePartyTrack` and the typed upgrades in `director_forge.dart` | Run gold buys. Reset on Ascend. |
| Market listings | `MarketListingsService` | `buyMarketListing`, `refreshMarketListings` | Buy a listed upgrade. |
| Camp tracks | sanctuary fields on `GameState` | `upgradeSanctuary` / `upgradeSanctuaryBulk` | Essence buys that stay. UI name CAMP. |
| Blessing / stars / REBORN | `lib/core/blessing_constellation.dart` | `lightConstellationNode`, `rebornAtCap`, `buyPrestigeShopItem` | ESSENCE → BLESSING. Prestige shop is inside that panel. |
| Relics | `lib/core/relics.dart` | `unlockRelic`, `upgradeRelicTier`, `salvageRelic`, `exchangeCinders`, `buyCinderWithTickets` | ESSENCE → RELICS. |
| Pets | `lib/core/pet_service.dart` | `hatchPet`, `hatchPetEgg`, `levelUpPet`, `setActivePet`, `sendPetErrand`, `claimPetErrand`, … | ESSENCE → PETS. |
| Gear | `GearService` / `director_bag.dart` | equip, unequip, `autoEquipBetterGear`, `combineGear`, `cleanBagJunk`, `autoMergeJunk` | HEROES: GEAR / BAG / MERGE. |
| Bag size | `RunStashShop` | `buyGoldBagExpansion`, `buyCinderBagExpansion` | Buttons on the bag dock. |
| Roster / 5th slot | `lib/core/game_logic_party.dart` `unlockPartySlot5` | `setActiveParty`, `unlockSpec` | 4th hero at first Ascend. 5th slot 80e at AL2. |
| Quests | `MissionBoard` `lib/core/mission_board.dart` | `claimMission`, `rerollQuestSlot` | MENU → QUESTS. |
| Daily vault | `GameLogic.claimDailyVault` | `GameDirector.claimDailyVault` | Clear target, then claim. |
| Daily run | `GameLogic` daily helpers | `enterDaily` via `confirmDailyRun` | One echo cave. |
| Scrolls / ads | `AdRewarded`, `hub_powerups.dart` | `spendPowerupBuff`, `watchPowerupAd`, `watchWipeReviveAd`, `claimScrollWellFree` | Tickets and hour buffs. Shop IAP is separate. |
| Shop IAP | `ShopCatalog`, `shop_billing.dart` | `buyShopItem`, `restoreShopPurchases`, `redeemCoupon` | SHOP. Billing logic stays put. |
| Wisp lantern | `WispGift` `lib/core/wisp_gift.dart` | `tapWispGift`, `watchWispGiftAd` | `WispGiftOverlay` is the only tap target. |
| KEY | `Keystone` `lib/core/keystone.dart` | `setHardmodeLevel`, enter cave | Dial on KEY sheet. |
| Gauntlet | `lib/core/game_logic_ladders.dart`, `GauntletPacts` | `enterGauntlet` | MAP → ENDGAME or KEY fold. |
| Farm Rift | `Rift` | `enterRift` | Stormwake. |
| Ranked GR | `GreaterRift` | `enterGreaterRift` | Mothveil clock. |
| Ashen Crown | `AshenCrown` | `enterAshenCrown` | Weekly ticket. |
| Craft / Apex | `ApexForge` | `craftApex`, `startApexTrial`, `upgradeApex` | MENU → CRAFT. Trial is not a hub hunt. |
| Ascend | `lib/core/game_logic_ascend.dart` | `GameDirector.ascend` | `confirmAscend`. Keeps levels, zones, essence, meta. |
| Offline return | `OfflineProgress` | `claimReturnRewards`, `continueClearableFloor` | `showOfflineProgressDialog`. |
| Chase | `HubChase` + `ChaseDispatcher` | `runChasePlan` | Camp ENTER runs it. The fight chase line is text only. |
| Check-in / month | meta season | `claimMonthPass`, `syncMetaPayoffs` | Fired by chase ops, not a separate shop. |
| Friend tip | `FriendReferral` | `shareFriendInvite`, `applyFriendCode` | MENU grid block. |
| Wipe / revive | `director_fight.dart` | `retryAfterWipe`, `hubAfterWipe`, revive ads / cinders | `DungeonWipePanel`. |
| Boards | `PlayGamesBridge` | scores from clears | KEY fold BOARDS and MAP RANKS. |
| Settings / guides / notes | overlays | audio, zoom, save, `markChangelogSeen` | MENU. |

Combat kits, enemy tells, and floor art are content under the fight sim.
They are not separate menus. See `lib/models/kits/` and `lib/spatial/`.
