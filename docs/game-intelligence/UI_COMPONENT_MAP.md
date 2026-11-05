# UI component map (home shell)

Owner: `HomeShell` `lib/ui/shell/home/home_shell.dart`.
Chosen by `PlayShell.build` when `state.homeLayout == HomeLayout.home`.

## Column, top to bottom

| Piece | Widget | Route / action |
|---|---|---|
| Top bar | `HomeTopBar` | AL, essence, chase text, gold → income sheet, SPEED, MENU (`MenuRoute.more`) |
| First-hour line | `FirstSessionTips` | Only while out of a cave and no sheet |
| Cave | `FightViewport` → `Is2Shell(homeChrome: true)` | Fight picture, target card, boss banner, wipe panel. Skips `DungeonTopHud`, DPS, scene party strip, loot log, `BoostAdButton`, `ScrollBuffStack` |
| Camp | `CampViewport` | Party dolls, chase `GameButton`, `FightSeamRails` |
| Seam | `FightSeam` | Repeat/Next, God Hand, LEAVE, SPLIT/FULL, `PartyCornerHud(homeRow: true)`, rails unless FULL |
| Split body | `UpgradePanel` | FORGE / CAMP / MARKET inline. Only when in a cave and not FULL |
| Full dock | `HomeGoldDock` | Thin FORGE / CAMP / MARKET. Opens `HomeGoldSheet`. Only when in a cave and FULL |
| Sheet | `_sheet` | ESSENCE → `EssenceTilesScreen`. MAP → `MapScreen`. Anything else → `MenuSurface(home: true)` |
| Back | `_backRow` | `router.back` when `homeAtSub` or KEY |
| HEROES tabs | `_gearThumb` | GEAR / BAG / MERGE / ROSTER |
| Bar | `HomeNavBar` | HEROES, ESSENCE if camp gate, FIGHT (closes the sheet), MAP if gold gate, SHOP if shop gate |

`HomeShell._onRouter` forces `MenuRoute.gold` closed. GOLD is supposed to be
the under-fight panel, but nothing then moves that panel.

## MENU grid (`HomeCatalog` place `menuGrid`)

QUESTS, PATCH NOTES, SETTINGS, INFO, GUIDES, CRAFT (after plain chrome ends),
REDEEM, then `HomeFriendTip`.

## Fight rails (`HomePlace.leftRail` / `rightRail`)

SCROLLS, WATCH, POUCH, UPDATE, QUESTS, VAULT, DAILY, WISP.
`FightSeam(hideRails: full)` drops this row in FULL. New games start FULL
(`director_save.dart`). Camp still shows the rails under `CampViewport`.

## `MenuSurface` children (`home: true`)

| `MenuRoute` | Child |
|---|---|
| gear | `InventoryDock` (`showTabRail: false`; thumb is outside) |
| gold | `GoldDock` — never seen, because the shell closes the route |
| shop | `ShopDock` |
| essence | Not used. `HomeShell` swaps in `EssenceTilesScreen` |
| key | `KeystoneSheet` |
| map | Empty `SizedBox`. Real map is `MapScreen` in `HomeShell` |
| more, depth 0 | `HomeMenuGrid` |
| more, quests | `JobsOverlay` |
| more, sub screen | `MoreList` (settings, info, craft, credits) |

## Prompts

`HomePromptHost` (zero-size host): offline dialog, patch notes, Discord,
notify opt-in, Play review. It does not mount `WispGiftOverlay`.

## Classic-only chrome still in the tree

`AppBottomBar`, `HubScreen`, `DungeonTopHud`, and `WispGiftOverlay` inside
`PlayShell` run only when `HomeLayout.classic`.
