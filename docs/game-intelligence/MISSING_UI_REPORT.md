# Missing UI report

## Connected in this change

The P0 and P1 rows below were the gap. The wiring uses the methods
already named there:

- `HomeShell._onRouter` opens `showHomeGoldSheet` (FULL and camp) or moves
  `UpgradePanel.focusPanel` (SPLIT).
- Camp draws `HomeGoldDock`.
- MENU grid entries `menu_scrolls`, `menu_watch`, `menu_vault`, `menu_daily`,
  `menu_wisp`, `menu_pouch`, `menu_update`, `menu_floors` in `HomeCatalog`.
- Vault calls `claimDailyVault` or toasts the count and opens QUESTS.
- `ForgeOverlay._farmIntensityRow` calls `setFarmIntensity` / `tryFarmIntensity`.
- `showFloorJumpSheet` calls `travelToFloor`.
- `FightSeam` shows HOLD → `startExitHold` while the stairs wait.
- `HomeFightTools` mounts `RiftProgressHud`, `ScrollBuffStack`, `BoostAdButton`,
  `WispGiftOverlay`, and `DungeonLootLog` on the cave.
- `HomeTopBar` shows `Keystone.formatTimer` during a KEY run.
- `WipeAdvice.hubNavFor` returns `NavIntent.endgame` (`MenuRoute.map`).

P2 (chase line, DPS meter, empty `showFeatureSheet`, empty `MenuSurface` map)
stays as written.

Priority is what a home-layout player cannot reach even though the method
exists. Gates (first boss, Lv100) are listed last. They are working locks,
not missing buttons.

## P0 — the shell drops a real destination

1. **GOLD and MARKET intents do nothing.**  
   `HomeShell._onRouter` closes `MenuRoute.gold`. Callers:
   `WipeAdvice.hubNavFor` (flask, MARKET, AP/Armor/STA),
   `InventoryDock.onOpenMarket` → `NavIntent.market`,
   `ChaseDispatcher` market chase → `runChasePlan` → `NavIntent.market`,
   `DungeonTopHud.onOpenForge` (classic only).  
   **Wire:** after close, focus `UpgradePanel` (SPLIT, in a cave) or open
   `HomeGoldSheet` (FULL, or out of the cave) on FORGE vs MARKET.

2. **No FORGE / CAMP / MARKET at camp.**  
   `showPanel` requires `state.inDungeon`. Leaving the cave removes the dock.
   **Wire:** show `HomeGoldDock` under `CampViewport`.

3. **FULL hides the only SCROLLS / WATCH / VAULT / DAILY / WISP / POUCH row.**  
   `startNewGame` sets `homePanelFull: true`. `FightSeam.hideRails` is that
   flag. Those `HomeCatalog` entries are not on the MENU grid.  
   **Wire:** same entries on `HomePlace.menuGrid`, still using their `open`
   callbacks. Do not draw a second rail over the cave.

4. **VAULT tap is a no-op until the bar is full.**  
   `HomeCatalog` id `vault` calls `claimDailyVault` only when clears ≥ target.
   **Wire:** otherwise toast the count and open QUESTS.

## P1 — fight tools that lived only on `DungeonTopHud`

`Is2Shell` replaces that HUD with an empty box when `homeChrome` is true.
Do not put the old HUD back. Mount the existing widgets, or a menu row that
calls the same method.

5. **FARM 1× / 2× / 4×** — `FarmIntensity` + `setFarmIntensity`.  
   **Wire:** a row on `ForgeOverlay` while `FarmIntensity.applies`.

6. **Floor jump** — `travelToFloor`.  
   **Wire:** MENU → FLOORS while in a normal cave.

7. **HOLD** — `startExitHold`.  
   **Wire:** seam text button only while `spatial.awaitingExit`.

8. **Farm Rift / Ranked GR bar** — `RiftProgressHud`.  
   **Wire:** top of `FightViewport` during those runs.

9. **KEY clock** — `Keystone.formatTimer`.  
   **Wire:** `HomeTopBar` chip while `keystoneRunActive`.

10. **Active scroll icons** — `ScrollBuffStack`.  
    **Wire:** corner of `FightViewport` (same widget as classic).

11. **Between-fight ticket button** — `BoostAdButton` → `watchPowerupAd`.  
    **Wire:** same corner. No change to ad code.

12. **Wisp lantern** — `WispGiftOverlay` is not in `HomeShell`.  
    `tapWispGift` has no other button.  
    **Wire:** mount the overlay on the fight viewport.

13. **Wipe OPEN ENDGAME** — label without a route  
    (`WipeAdvice.hubNavFor` returns null).  
    **Wire:** `NavIntent` to `MenuRoute.map` with the ENDGAME segment selected.

## P2 — visible, not blocking

14. Loot history `DungeonLootLog` — floaters still show names. Mount the log
    at the bottom of the viewport so it does not cover the seam.
15. Fight chase line is not tappable. Camp ENTER already runs `runChasePlan`.
    Leave the line as text so the top bar Robert liked stays one row.
16. DPS meter is hidden in a home fight (`HomeTopBar` compact row and
    `Is2Shell`). Leave it off the fight picture.
17. `showFeatureSheet` has no caller. Do not build a feature on it.
18. `MenuSurface` MAP child is an empty box. Home uses `MapScreen`. Leave the
    empty branch so classic never shows a second map.

## Not missing

HEROES, God Hand smash, flask drink, SHOP, ESSENCE tiles, MAP enter, hunt
confirms, KEY sheet once MAP is open, Ascend, offline dialog, wipe revive,
settings, quests from MENU, forge/camp/market **while inside a cave** via the
dock or the split panel. Those call the real directors today.
