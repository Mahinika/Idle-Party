# Technical debt (home shell)

Noted **2026-11-05** while reading the shell. Not a cleanup list to do in
this pass. Fixes that belong to the wiring pass are in `MISSING_UI_REPORT.md`.

## Two shells, one save

`PlayShell` branches on `HomeLayout`. Classic still owns `DungeonTopHud`,
`WispGiftOverlay`, and `AppBottomBar`. Home reimplemented the bar, the seam,
and the gold panel, then turned the old HUD off with `homeChrome`. Anything
added only to `DungeonTopHud` is invisible on a new game. That is how floor
jump, farm intensity, the rift bar, HOLD, and the vault chip went missing.

## Three defaults for the same field

- `GameState` field default is `HomeLayout.classic` (`game_state.dart`).
- `HomeLayout.fromJson` treats a missing JSON value as `home`.
- `startNewGame` forces `home` only when `_phoneHadNoSaveAtBoot`, and forces
  `homePanelFull: true` in that case.

A test that builds `createInitialState` without `copyWith(homeLayout: home)`
is on the classic shell. A new phone install is not.

## Gold route is a lie on home

`MenuRouter` still has `MenuRoute.gold` and `GoldDock`. `HomeShell` closes
that route in the listener. Intents keep targeting it (`nav_intent.dart`).
The under-fight panel does not read `router.goldPanel`.

## String rewrite instead of two copies

`NavCopy.playerText` replaces `GOLD →`, `GEAR →`, `the hub`, and similar
substrings. A new sentence that contains those pieces changes by accident.
Guides go through it (`home_shell_test.dart`).

## FULL is the default and it hides the rail

`hideRails: full` plus `homePanelFull: true` on a new game means the rail
catalog is dead until the player taps SPLIT or goes to camp. The MENU grid
was not given those entries.

## Empty and unused UI

- `showFeatureSheet` (`feature_sheet.dart`) — comment says QUESTS is the
  caller. Nothing calls it. QUESTS uses `JobsOverlay`.
- `MenuSurface` `MenuRoute.map` returns `SizedBox.shrink()`.
- LOADOUTS tab stays hidden. Save fields remain on purpose (`AGENTS.md`).

## Vault button

`HomeCatalog` vault `open` returns without feedback when the claim is not
ready. The badge is the only signal, and the rail is hidden in FULL.

## Endgame wipe label

`WipeAdvice.hubCtaLabelFor` returns `OPEN ENDGAME` when `hubNavFor` is null.
The button still calls `hubAfterWipe(openMenu: null)`.

## File size

`game_logic.dart`, `spatial_combat.dart`, and `dungeon_top_hud.dart` are
already large. This pass should not add systems to them. New home glue stays
under `lib/ui/shell/home/`.
