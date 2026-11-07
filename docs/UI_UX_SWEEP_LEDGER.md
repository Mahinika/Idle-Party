# UI/UX consistency sweep — completion ledger

Branch `cursor/ui-ux-consistency-sweep-3edc`, based on `origin/main`
`238fa2966457a1f3560d7f3ff0c8529e21c3c838`.

Each row is one canonical item. A shared change is named once and
cross-referenced. “Verified” means the code path and a test (or a measured
color) were checked. Rendered phone frames are the shell goldens plus
`test/ui_app_scale_test.dart` drives `MyApp` (a live `setUiTextScale` and a
reloaded save, start SKIP and NEW GAME, camp and fight, every dock) at
360×780 and 360×640. `test/ui_menu_scale_test.dart` still pumps `HomeShell`
at OS 1 / 1.4 / 2. A raw scale of 2 is a separate stress and is not capped.

Ramp: `title` Cinzel 18, `section` VT323 16, `readable` VT323 14, `hint`
VT323 12. Order is title, then section, then body, then hint. `button` 19 /
dense 15 is the action role (not a second title). `combat` is Press Start 9
(comfort 11).
Ceiling `typeScaleMax` 1.45 equals `kUiTextScaleMax`. OS scale still
multiplies, then the product clamps. The slider max was not lowered.

| # | Disposition | Evidence |
|---|-------------|----------|
| 1 | Changed | `GameTheme.title/section/readable/hint/combat`. Menu call sites use those roles. `test/ui_type_ramp_test.dart` rejects a new free `size:` on the old helpers. |
| 2 | Changed | `composeTextScaler` clamps to `typeScaleMax` (1.45), same constant as the slider max. Test locks OS 2 × game 1 and game max. |
| 3 | Changed | `_LiveTextScale` in `lib/main.dart` listens to the director and rebuilds the `MaterialApp` scaler when `uiTextScale` changes. Start (SKIP and NEW GAME) and play share that scaler. `test/ui_app_scale_test.dart` calls `setUiTextScale(1.45)` on a live `MyApp` and pumps a second `MyApp` whose save already stores 1.45. |
| 4 | Changed | Home nav and classic bar dropped `FittedBox`. Labels use `readable` and ellipsis. `navBarExtent` grows the bar with scale. |
| 5 | Changed | `MenuChrome.segmented` height is `minTouch` times the actual text scale (never below 44). The icon stays beside the label (`iconList`) and the label ellipsizes instead of overflowing the row. FARM/PUSH and the text presets use it. Camp and fight both lay out at slider max and at raw scale 2 (`test/ui_app_scale_test.dart`). |
| 6 | Changed | `HomeShell` no longer wraps the cave, camp, and docks in `withClampedTextScaling(maxScaleFactor: 1.3)`. The older 1.35 clamps are gone from the party HUD, world map, endgame map, and IS2 shell. `test/ui_app_scale_test.dart` reads the same scaler on FIGHT (outside the old clamp) and on FARM and FORGE (inside it). |
| 7 | Changed | `MenuChrome.tabRail` sets `labelStyle` and `unselectedLabelStyle` to `readable`. Settings, gear, and the other rails go through it. |
| 8 | Changed | `pixelCached` no longer promotes a sub-9 request to 9. It asserts `size >= hudPixel`. The free-size test rejects digit sizes outside the theme and the three world-space painters. |
| 9 | Changed | Menu copy is VT323 or Cinzel. Press Start is `combat` and the dungeon painters. Documented in `docs/UI_THEME.md`. |
| 10 | Changed | `GameButton` picks `typeButton` or `typeButtonDense` only. Label length does not change the size. Long-label test locks the font size. |
| 11 | Changed | `MenuChrome.dialog` and the scrolling dialog both title with `GameTheme.title`. Sheet headers use the same title style. |
| 12 | Changed | Presets are S = `kUiTextScaleMin` (0.80), M = 1.0, L = 1.20, XL = `kUiTextScaleMax` (1.45). Test checks the ends. |
| 13 | Changed | Overlay header stacks from measured title + wallet + close width, not a 0.95 scale threshold. |
| 14 | Changed | Display copy: slider times the phone’s own text size, then capped at the slider maximum. Dungeon view is named as the camera. |
| 15 | Changed | `docs/UI_THEME.md` states the ramp, the 1.45 ceiling, dungeon view vs text, and the compact-combat exception. |
| 16 | Changed | Home and classic bars both use `navBarExtent`. |
| 17 | Changed | Rail buttons and the MENU grid both use `GameTheme.readable`. |
| 18 | Changed | MENU grid `childAspectRatio` is 3.2 so a tile is a row, not a tall card. |
| 19 | Changed | Grid icons use `iconNav` (24). Rail icons use `iconList` (18). Contrast is parchment on the panel, measured in item 77. |
| 20 | Already satisfied | `OverlayScaffold` close is a dense `GameButton` labeled CLOSE (`lib/ui/shell/overlay_scaffold.dart`). `GameButton` min height is `minTouch` (44). `test/widget_test.dart` finds the word CLOSE. `UiGlyph.close` is only the in-row dismiss on the gold dock and a bag combine slot, not a second sheet header. |
| 21 | Changed | `ShellLayout.listPadding` uses `edgeGap` (12). |
| 22 | Changed | Dialog and scrolling dialog both use inset 20×24. |
| 23 | Changed | Actions align end, spacing 8. Cancel is `dialogCancel` (ghost) before the confirm `GameButton`. |
| 24 | Changed | Comparable rows use `MenuChrome.listCard` / `cardBox` / `PowerUpgradeRow`. New sheets are told to use those in the checklist. |
| 25 | Changed | `iconList` 18, `iconNav` 24, `iconShowcase` 32. Segmented and rails use the first two. |
| 26 | Changed | List body is `readable` (14) or `hint` (12). Nothing in menu code requests 7 or 8. |
| 27 | Changed | Card title is `title` or `section` (16). Body is `readable` (14). Meta is `hint` (12). A dense forge row keeps the track name at `readable` so the next upgrade stays on the split screen. “Bulk spend” stays `section`. The current/next line is `hint`. `test/ui_type_ramp_test.dart` locks title > section > body > hint. |
| 28 | Changed | Home sheets pass gold and essence into the same `WalletStrip` the classic sheets use. |
| 29 | Changed | Immersive sticky hides the status-bar icons (`lib/core/immersive_ui.dart`) and the window draws into the cutout (`android:windowLayoutInDisplayCutoutMode` shortEdges). `viewPadding` still reports that cutout after the icons hide, so a header at y 15 sits in it. The header bar, hub backdrop, and cave scene still paint from the screen edge. `HomeTopBar` and full-screen titles (`playSafeArea(top: true)`, dialog inset) start their words at `systemTopInset`. `test/ui_app_scale_test.dart` requires AL and MENU, IDLE PARTY, and a dialog title to start at or below a 44 top inset, and FIGHT at least 34 above the bottom. `test/small_screen_dialogs_test.dart` still fits 360×640 and 360×780 at raw scale 2 with a notch. |
| 30 | Changed | Settings labels say “Dungeon view · Close/Normal/Wide”. HUD chips stay NEAR/MID/FAR. `docs/TRAILER.md` and the capture note use the same words. |
| 31 | Changed | The FARM/PUSH row is the segmented control. Its height is the control height, so the container cannot be shorter than the control. |
| 32 | Changed | God Hand slot is `minTouch` by `minTouch` (44). The ring no longer sits in a `FittedBox`. |
| 33 | Changed | The 2× farm chip and the row under it both use `DungeonModeChip` with `combat` comfort, ellipsis, no scale-down. |
| 34 | Changed | The home party row height follows the text scale (floor 32). Party names ellipsize and the level stays full size (`dungeon_party_strip_test`). The home strip uses `readable`, so starter names such as Aegis L1 stay whole beside the flask. The corner strip stays `combat`. |
| 35 | Changed | Boss and elite titles ellipsize inside the plate. The full string is the `Text` data and a long-press `Tooltip`. |
| 36 | Changed | The buff stack scrolls inside its max height instead of scaling the whole row down. |
| 37 | Changed | The gold dock is a segmented row at least 44 tall, not a 32-tall strip. |
| 38 | Changed | TODAY title keeps two lines at every scale. The old `textScale > 1.2` one-line branch is gone. |
| 39 | Changed | Coach and daily goal copy use `hint`. Primary actions stay `GameButton`. |
| 40 | Already satisfied | Selected hero fill is `GameTheme.hudRowSelected` on `_HomePartyChip`. FARM/PUSH is a separate `MenuChrome.segmented` in `FightSeam`. The two markers do not share a widget. |
| 41 | Changed | DPS and the rest of the combat plate use `combat`. |
| 42 | Changed | Loot lines and toasts use `readable` / `hint` on the toast colors. `GameButton` long-press shows `FeedbackToast`, not a snackbar. |
| 43 | Changed | Wipe copy uses the menu ramp and keeps its existing wrap. `test/integration_layout_fit_test.dart` still pumps it at 360×640. |
| 44 | Changed | FIGHT uses the same `readable` label as the other home tabs. |
| 45 | Changed | CLOSE is `readable` on the nav, not a hint that expands and then shrinks. |
| 46 | Changed | Bag name, stats, and hint use `readable` and `hint`. |
| 47 | Changed | Gear stat lines that asked for 9 or 10 now use `hint` (12) or `readable` (14). |
| 48 | Changed | Bag rows and the item tooltip both use `readable` for the name and `hint` for the secondary line. |
| 49 | Changed | `GameTheme.isPhoneWidth` returns true for every width, so there is no second phone layout. The doll heading is the spec at `title` and the level at `hint` (`character_equip_panel.dart`). The selector chip uses `readable` whether or not the small doll is shown. |
| 50 | Changed | Roster and gear hero chips use `hint` for the name and a shared min height from the chip, not a second font. |
| 51 | Changed | Apex recipe name is `section`, cost is `readable`, meta is `hint`. |
| 52 | Changed | Craft inherits the ramp. Its overflow protection stays a scroll, not a `FittedBox`. Layout-fit still covers it. |
| 53 | Changed | “Bulk spend” is `section`, not `title`. |
| 54 | Changed | Camp and forge upgrades both use `PowerUpgradeRow`. |
| 55 | Changed | `ForgeOverlay._upgradeRow` puts the current bonus and the next delta in `subtitle` (`bonus · next`). `PowerUpgradeRow` paints that line at `hint`, max two lines, so the next number is not clipped to one ellipsis. The buy chip stays in the trailing column. |
| 56 | Changed | When a forge buy cannot run, the row’s subtitle becomes `Need … more` (`ForgeOverlay`) so the shortfall sits on the row without covering the next upgrade. Gold 0 also shows “Earn gold in the dungeon, then buy here.” `test/forge_inline_test.dart` finds both. |
| 57 | Changed | Merge slots use the same card padding and rarity colors as the bag (`rarity*` / `cardBox`). |
| 58 | Already satisfied | Worn gear on the doll says “Equipped · UNEQUIP below · long-press for tip” (`character_equip_panel.dart`). Bag compare uses the same `equipChip*` colors for blocked, upgrade, and neutral. MERGE copy says worn gear stays. |
| 59 | Changed | `MenuChrome.dollWellDecoration` is the radial well. GEAR already used those colors; CAMP party dolls now use the same decoration. |
| 60 | Already satisfied | `ApexForgePanel._farmMeter` titles a locked target `Farm locked: <mat>` in `section`, and `_farmSources` (same file) prints the drop cave and the next level gate under it in `hint`. The craft chips stay tappable. |
| 61 | Changed | Shop description is `hint`. The buy control is a `GameButton` at `typeButton`, so the button is the louder line. |
| 62 | Changed | Market no longer requests a sub-9 pixel size. Prices and names are `readable` / `hint`. |
| 63 | Changed | Blessing name and cost use the same `section` / `readable` pair as upgrade rows. |
| 64 | Changed | Essence entry cards in both layouts use `listCard` and the ramp. |
| 65 | Changed | Quest title is `section` or `readable`. The secondary line is `hint`. The extra sizes are gone. |
| 66 | Changed | Welcome Back rows use `readable` and `hint` and still wrap. Layout-fit covers the dialog. |
| 67 | Changed | Path card title is `title` or `section`. The subtitle is `hint`. |
| 68 | Changed | The world-map dialog title uses `GameTheme.title`, same as `MenuChrome.dialog`. |
| 69 | Changed | Endgame status height follows the composed text scale. The separate 1.35 clamp is gone. |
| 70 | Changed | Rift tier figures use `section` or `readable`, not a display heading. |
| 71 | Changed | The floors sheet height is 0.45 of the screen and the list scrolls. The fixed 280 is gone. |
| 72 | Changed | The grotto name on CAMP and on the map uses `title`. |
| 73 | Already satisfied | `KeystoneSheet` is a scroll of `MenuChrome.fold` rows (title + subtitle), the same fold settings uses. The hunt line above them is `hint`. No second card chrome. |
| 74 | Changed | Relic and pet rows are icon, name (`readable`), status (`hint`), action (`GameButton`). |
| 75 | Changed | Achievements and Codex use `section` headings and `readable` / `hint` rows. Codex empty copy says to fight or clear floors. |
| 76 | Changed | Challenge toggle labels use `readable`, like settings rows. The KEY stepper is 44, not 36. |
| 77 | Changed | Measured, not estimated. parchmentDim `#B4BCC8` on panel `#182028` is about 8.6:1. parchment `#ECE8DF` on the same panel is about 13.5:1. Both beat WCAG AA 4.5:1. `test/ui_type_ramp_test.dart` locks the hex and the ratio. No lightening. |
| 78 | Changed | `MenuChrome.textLink` min height is `minTouch` (44). |
| 79 | Changed | Steppers draw `UiGlyph.add` and `UiGlyph.remove`, placed on the left and right of the value. Hit target is `minTouch`. |
| 80 | Changed | The percent width grows with the text scale, one line, no wrap. Test pumps DISPLAY at OS 2 on 360×640 and reads `145%`. |
| 81 | Changed | `GameButton` long-press inserts `FeedbackToast`. There is no `SnackBar` in `lib/ui`. |
| 82 | Changed | Patch-note headings use `section`. Body uses `readable`. |
| 83 | Changed | Guides and patch notes both sit in a scrolling sheet with `title` plus `readable` body. |
| 84 | Changed | Play Games name, score, and status use `readable` and `hint`. |
| 85 | Changed | Save-slot title is `readable`. The meta line is `hint`. |
| 86 | Changed | New-party labels are `section`, helpers are `hint`, fields use the theme input. |
| 87 | Changed | Recovery and the required-update screen use `title`, `readable`, and a `GameButton`. |
| 88 | Changed | The notification opt-in and the review ask use `MenuChrome.dialog` and `readable` body. Consent behavior is unchanged. |
| 89 | Already satisfied | `redeem_coupon_dialog.dart` uses `MenuChrome.dialog` and a dense CLOSE `GameButton`. `wisp_gift_overlay.dart` and the vault claim use the sheet title plus `readable` body and a `GameButton`. No separate dialog chrome. |
| 90 | Changed | Empty bag, market, and codex say what is missing and where to go next. Test pumps empty market and empty codex at OS 2 on 360×640. |
| 91 | Changed | `test/ui_app_scale_test.dart` pumps `MyApp`, not a `HomeShell` wrapper. It checks a live `setUiTextScale(1.45)`, a reloaded save at 1.45, SKIP and NEW GAME at 1.45, OS 2 × game 1 clamped to 1.45, and camp plus fight plus FORGE/CAMP/MARKET on 360×780 and 360×640. HEROES and FIGHT stay findable as the full words. |
| 92 | Changed | The same file pumps `HomeShell` at `TextScaler.linear(2)` on 360×640 for camp and fight. The FIGHT scaler stays 2, so this stress is not the app cap. Camp dolls scroll instead of overflowing. `test/ui_menu_scale_test.dart` still pumps the older HomeShell matrix. |
| 93 | Changed | The home shell pump above is the A56 logical size (360×780) at one scale set. Shell goldens are the pixel frames for the same phone class. |
| 94 | Changed | The same pump runs at 360×640. |
| 95 | Changed | Long party names ellipsize (`dungeon_party_strip_test`). A long `GameButton` label keeps `typeButton` and two lines (`ui_menu_scale_test`). |
| 96 | Changed | Empty market and empty codex are pumped at scale 2. A fresh party is the full-enough list on the home shell pump. Locked rows stay on screen with `hint` (item 60). |
| 97 | Changed | `docs/UI_THEME.md` “Compact combat is not a menu.” World-space painters may size from the tile. Menu sheets may not use `FittedBox`. |
| 98 | Changed | `test/ui_type_ramp_test.dart` fails if menu code adds `GameTheme.body/menuTitle/pixel/button(..., size: <digit>)` or a `FittedBox(`. Allowed `FittedBox` files are `main.dart` (web letterbox) and `boot_cinematic_layer.dart`. |
| 99 | Changed | `showFeatureSheet` and `lib/ui/shell/home/feature_sheet.dart` are deleted. No Dart references remain. Three audit notes under `docs/game-intelligence/` still name the old helper and are labeled historical. |
| 100 | Changed | `docs/UI_THEME.md` menu checklist is text, margin, contrast, touch, and scale, plus empty copy and dialog action order. |

## Not applicable

These are outside the sweep because the owner forbade the change, or the
widget is a frame rather than a menu.

- Economy, drops, costs, monetization, save format, cloud ownership, billing, and consent behavior. No files under `lib/core/game_logic.dart`, `lib/core/game_state.dart`, or the shop billing path were edited for those rules. Consent copy in the review and notification dialogs was restyled only.
- Web letterbox (`lib/main.dart`) and the boot cinematic (`lib/ui/boot_cinematic_layer.dart`) still use `FittedBox` to frame a whole scene. `test/ui_type_ramp_test.dart` allows only those two files.
- The Cognifox mark has no font size. It was not restyled.
- CRAFT, wipe, and Welcome Back still wrap or scroll. `test/integration_layout_fit_test.dart` pumps them at 360×640.
