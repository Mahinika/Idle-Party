# Feature matrix

Status is for **`HomeLayout.home`** (the shell in Robert’s screenshot), not the
classic bar. Evidence is the call site. Status words:

`IMPLEMENTED_AND_ACCESSIBLE` · `IMPLEMENTED_BUT_NO_UI` ·
`IMPLEMENTED_BUT_NOT_CONNECTED` · `PARTIALLY_IMPLEMENTED` ·
`UI_ONLY_PLACEHOLDER` · `UNUSED_OR_ABANDONED` · `UNKNOWN`

| Feature | Logic | UI entry on the home shell | Status |
|---|---|---|---|
| Live fight | `SpatialCombat` | `FightViewport` → `Is2Shell` (`homeChrome: true`) | IMPLEMENTED_AND_ACCESSIBLE |
| Repeat / Next (FARM / PUSH) | `GameDirector.setDungeonMode` | `FightSeam` segmented Repeat/Next | IMPLEMENTED_AND_ACCESSIBLE |
| SPLIT / FULL | `GameDirector.setHomePanelFull` | `FightSeam` label SPLIT or FULL | IMPLEMENTED_AND_ACCESSIBLE |
| Leave cave | `GameDirector.leaveDungeon` | `FightSeam` LEAVE → `PlayShell` confirm | IMPLEMENTED_AND_ACCESSIBLE |
| God Hand smash | `godHandAtFocus` | `FightSeam` `GodHandRing` | IMPLEMENTED_AND_ACCESSIBLE |
| God Hand long-press on the floor | `godHandAtWorld` | `SpatialDungeonView` long-press (unchanged by home chrome) | IMPLEMENTED_AND_ACCESSIBLE |
| Speed 1× / 2× | `cycleCombatPace` | `HomeTopBar` | IMPLEMENTED_AND_ACCESSIBLE |
| Drink flask / bandage | `useConsumable` | `PartyCornerHud` `DungeonFlaskButton` on the home row | IMPLEMENTED_AND_ACCESSIBLE |
| HEROES equip / bag / merge / roster | `director_bag.dart` | `HomeNavBar` HEROES → `MenuSurface` `InventoryDock`. Tabs via `HomeShell._gearThumb` | IMPLEMENTED_AND_ACCESSIBLE |
| Auto equip | `setAutoEquipUpgrades` / `autoEquipBetterGear` | GEAR dock button + SETTINGS toggle | IMPLEMENTED_AND_ACCESSIBLE |
| FORGE buy (in a cave, dock or split) | `director_forge.dart` | `UpgradePanel` / `HomeGoldSheet` → `ForgeOverlay` after `MenuTabs.showGold` (first boss or AL≥1) | IMPLEMENTED_AND_ACCESSIBLE |
| CAMP tracks (in a cave) | `upgradeSanctuary` | Same panel, CAMP → `SanctuaryOverlay` after `MenuTabs.showCamp` | IMPLEMENTED_AND_ACCESSIBLE |
| MARKET flasks and listings (in a cave) | `buyMarketFlask`, `buyMarketListing` | Same panel, MARKET → `MarketOverlay` | IMPLEMENTED_AND_ACCESSIBLE |
| FORGE / CAMP / MARKET while out of the cave | same | `HomeShell` draws the dock only when `state.inDungeon` (`showPanel`) | IMPLEMENTED_BUT_NOT_CONNECTED |
| GOLD / MARKET nav (wipe, bag, chase) | `NavIntent.gold` / `market` | `HomeShell._onRouter` closes `MenuRoute.gold` and opens nothing | IMPLEMENTED_BUT_NOT_CONNECTED |
| ESSENCE tiles | keep / relics / pets / codex / apex | `HomeNavBar` ESSENCE → `EssenceTilesScreen` after `MenuTabs.showCamp` | IMPLEMENTED_AND_ACCESSIBLE |
| Blessing, stars, REBORN, prestige shop, slot 5 | `essence_keep_panel.dart` callers | ESSENCE → BLESSING (`EssenceKeepPanel`, includes `PrestigeShopOverlay`) | IMPLEMENTED_AND_ACCESSIBLE |
| Relics and cinder exchange | `director_meta_actions.dart` | ESSENCE → RELICS | IMPLEMENTED_AND_ACCESSIBLE |
| Pets | `GameDirector.hatchPet` and pet methods | ESSENCE → PETS | IMPLEMENTED_AND_ACCESSIBLE |
| Codex rewards | `claimCodexReward` | ESSENCE → CODEX opens MORE info pane 1 (`CodexOverlay`) | IMPLEMENTED_AND_ACCESSIBLE |
| Apex craft | `craftApex` | ESSENCE → APEX and MENU → CRAFT | IMPLEMENTED_AND_ACCESSIBLE |
| MAP path + enter | `enterDungeon` | `MapScreen` after `MenuTabs.showGold` | IMPLEMENTED_AND_ACCESSIBLE |
| Gauntlet / Farm Rift / Ranked GR / Ashen | `enterGauntlet` / `enterRift` / `enterGreaterRift` / `enterAshenCrown` | MAP → ENDGAME cards, or KEY folds | IMPLEMENTED_AND_ACCESSIBLE |
| KEY dial | `ChallengeToggles` + `setHardmodeLevel` | MAP hunt card KEY, or top-bar key chip while MAP is open | IMPLEMENTED_AND_ACCESSIBLE |
| SHOP IAP / restore / redeem | `buyShopItem` | `HomeNavBar` SHOP → `ShopDock` after first boss | IMPLEMENTED_AND_ACCESSIBLE |
| QUESTS | `claimMission` | MENU grid and the fight rail (rail hidden when FULL) | IMPLEMENTED_AND_ACCESSIBLE |
| SETTINGS, GUIDES, PATCH NOTES, INFO | overlays | MENU grid `HomeCatalog` `HomePlace.menuGrid` | IMPLEMENTED_AND_ACCESSIBLE |
| SCROLLS, WATCH, WISP sheet, starter pouch | `openPowerupsSheet` | `FightSeamRails` only. `FightSeam.hideRails` is true when FULL. New games set FULL. | IMPLEMENTED_BUT_NOT_CONNECTED |
| Daily vault claim | `claimDailyVault` | Rail VAULT claims only when the target is met; otherwise the tap does nothing (`HomeCatalog` id `vault`). Chip on `DungeonTopHud` is not built when `homeChrome` | IMPLEMENTED_BUT_NOT_CONNECTED |
| Daily run | `confirmDailyRun` | Rail DAILY, and MAP card DAILY. Rail hidden in FULL. MAP exists after the first boss | PARTIALLY_IMPLEMENTED |
| Play update | `openPlayUpdate` | Right rail UPDATE. Hidden in FULL. Also SETTINGS when the notice is up | PARTIALLY_IMPLEMENTED |
| Friend invite | `FriendTipBlock` | MENU grid | IMPLEMENTED_AND_ACCESSIBLE |
| Ascend | `confirmAscend` → `ascend` | Camp ENTER when the chase says so, ESSENCE summary, camp secondary button | IMPLEMENTED_AND_ACCESSIBLE |
| Offline welcome | `showOfflineProgressDialog` | `HomePromptHost._maybeOffline` | IMPLEMENTED_AND_ACCESSIBLE |
| Wipe, retry, revive ad, cinder revive | `DungeonWipePanel` | Shown by `Is2Shell` when `awaitingWipeChoice` | IMPLEMENTED_AND_ACCESSIBLE |
| Wipe “OPEN ENDGAME” | `WipeAdvice.hubCtaLabelFor` | Label exists. `hubNavFor` returns null for those lines, so `hubAfterWipe` opens no map | IMPLEMENTED_BUT_NOT_CONNECTED |
| Camp ENTER / chase | `runChasePlan` | `CampViewport` button | IMPLEMENTED_AND_ACCESSIBLE |
| Fight chase line | `HubChase.forState` | `HomeTopBar` text. Not a button | PARTIALLY_IMPLEMENTED |
| FARM 1× / 2× / 4× | `FarmIntensity` | Only `DungeonTopHud`, which `Is2Shell` skips when `homeChrome` | IMPLEMENTED_BUT_NOT_CONNECTED |
| Floor jump | `travelToFloor` | Only `DungeonTopHud` floor menu | IMPLEMENTED_BUT_NOT_CONNECTED |
| HOLD after a clear | `startExitHold` | Only `DungeonTopHud` | IMPLEMENTED_BUT_NOT_CONNECTED |
| Ranked GR / Farm Rift clock | `RiftProgressHud` | Only `DungeonTopHud` | IMPLEMENTED_BUT_NOT_CONNECTED |
| KEY clock during a run | `Keystone.formatTimer` | Only `DungeonTopHud` place row | IMPLEMENTED_BUT_NOT_CONNECTED |
| Quest claim chip in the fight | `claimMission` | `DungeonTopHud` `MissionClaimChip`. QUESTS sheet still works from MENU | PARTIALLY_IMPLEMENTED |
| Active scroll timers | `ScrollBuffStack` | Not mounted when `homeChrome` (`Is2Shell`) | IMPLEMENTED_BUT_NOT_CONNECTED |
| Between-fight WATCH ticket button | `BoostAdButton` → `watchPowerupAd` | Not mounted when `homeChrome`. WATCH rail opens the scrolls sheet instead, and that rail is hidden in FULL | IMPLEMENTED_BUT_NOT_CONNECTED |
| Loot history | `director.noteLoot` | `DungeonLootLog` not mounted when `homeChrome`. World floaters still draw | PARTIALLY_IMPLEMENTED |
| Wisp lantern tap | `tapWispGift` | `WispGiftOverlay` is only in the classic `PlayShell` stack, not `HomeShell` | IMPLEMENTED_BUT_NOT_CONNECTED |
| DPS meter during a fight | `DpsMeter` | Hidden while `home && inDungeon` (`HomeTopBar.compactTop`) and hidden in `Is2Shell` home chrome | IMPLEMENTED_BUT_NOT_CONNECTED |
| Party abilities | kit chips | Second tap on a home party chip opens `_HomeKitStrip` | IMPLEMENTED_AND_ACCESSIBLE |
| Loadouts | save fields may remain | LOADOUTS tab hidden (`AGENTS.md`) | UNUSED_OR_ABANDONED |
| Feature-sheet template | none | `showFeatureSheet` in `feature_sheet.dart` has no caller | UI_ONLY_PLACEHOLDER |
| `MenuSurface` MAP route | `MapScreen` is separate | `MenuSurface` returns an empty box for `MenuRoute.map` | UI_ONLY_PLACEHOLDER |
| Classic GEAR/GOLD/SHOP/ESSENCE/MORE | same directors | `PlayShell` when `HomeLayout.classic` | IMPLEMENTED_AND_ACCESSIBLE |

Gates (not bugs): `MenuTabs.showGold` / `showShop` are `GameLogic.showDailyChase`
(first boss or AL > 0) in `lib/core/menu_alerts.dart`. ESSENCE also needs
essence or AL ≥ 1. KEY jargon is `GameLogic.showKeystoneJargon` (party Lv100).
Before those gates the buttons are absent or say they are locked. That is
`IMPLEMENTED_AND_ACCESSIBLE` once the gate opens.
