import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_layout.dart';

/// Empty FLOORS sheet: why there is nothing to jump to yet (F006).
const floorJumpEmptyKey = ValueKey('floor_jump_empty');

String floorJumpEmptyLine(int here) =>
    'No other floor yet. Clear F$here to open F${here + 1} here.';

/// Floors below [here] the party can jump back to.
List<int> floorJumpCleared(GameState state) {
  final here = state.currentRoom.floorNumber;
  return [
    for (var f = 1; f < here; f++)
      if (GameLogic.canTravelToFloor(state, f)) f,
  ];
}

/// Top line. The KEY clock note waits until KEY is in play (polish7 P047).
String floorJumpHint(GameState state) {
  final here = state.currentRoom.floorNumber;
  final keyOn = state.hardmodeLevel > 0;
  return keyOn
      ? 'Now F$here. A jump keeps the KEY clock running.'
      : 'Now F$here. Tap a floor to go there.';
}

/// Chevron: these rows are taps, not a list to read.
const Widget _go = GameIcon.glyph(UiGlyph.next, size: 14);

/// Same floor list the classic HUD menu used. Calls [GameDirector.travelToFloor].
Future<void> showFloorJumpSheet(
  BuildContext context,
  GameDirector director,
) async {
  final state = director.state;
  if (!state.inDungeon ||
      state.inGauntlet ||
      state.inAnyRiftMode ||
      state.inWorldBoss) {
    director.showToast('No floor jump in this hunt', life: 1.8);
    return;
  }
  final here = state.currentRoom.floorNumber;
  final maxFloor = state.maxReachableFloor;
  // Below this floor only: a higher floor sits under Higher, never in both
  // lists (polish7 P047).
  final clearedFloors = floorJumpCleared(state);
  final noJumps = clearedFloors.isEmpty &&
      ![
        for (var f = here + 1; f <= maxFloor; f++)
          GameLogic.canTravelToFloor(state, f),
      ].contains(true);
  final picked = await showDialog<int>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'FLOORS',
      // Sized to its rows, capped at 45 % of the screen: a fixed 45 % box
      // left 250 px of dark under one row (audit F006).
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 280,
          minWidth: 280,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ShellLayout.hint(floorJumpHint(state), maxLines: 2),
            if (noJumps) ...[
              ShellLayout.gap(6),
              Text(
                floorJumpEmptyLine(here),
                key: floorJumpEmptyKey,
                style: GameTheme.readable(color: GameTheme.parchmentDim),
              ),
            ],
            ShellLayout.gap(6),
            WebClickScope(
              label: 'This floor',
              onPressed: null,
              child: Semantics(
                label: 'This floor · F$here',
                child: ListTile(
                  dense: true,
                  minVerticalPadding: 12,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    'This floor · F$here',
                    style: GameTheme.readable(color: GameTheme.torchHot),
                  ),
                ),
              ),
            ),
            if (clearedFloors.isNotEmpty) ...[
              ShellLayout.gap(4),
              Text(
                'Cleared',
                style: GameTheme.section(color: GameTheme.parchmentDim),
              ),
              ShellLayout.gap(2),
              for (final f in clearedFloors)
                WebClickScope(
                  label: 'Floor $f',
                  onPressed: () => Navigator.pop(ctx, f),
                  child: Semantics(
                    button: true,
                    label: 'Floor $f',
                    child: ListTile(
                      dense: true,
                      minVerticalPadding: 12,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        'F$f',
                        style: GameTheme.readable(color: GameTheme.parchment),
                      ),
                      trailing: _go,
                      onTap: () => Navigator.pop(ctx, f),
                    ),
                  ),
                ),
            ],
            if (maxFloor > here) ...[
              ShellLayout.gap(4),
              Text(
                'Higher',
                style: GameTheme.section(color: GameTheme.parchmentDim),
              ),
              ShellLayout.gap(2),
              for (var f = here + 1; f <= maxFloor; f++)
                WebClickScope(
                  label: 'Floor $f',
                  onPressed: GameLogic.canTravelToFloor(state, f)
                      ? () => Navigator.pop(ctx, f)
                      : null,
                  child: Semantics(
                    button: GameLogic.canTravelToFloor(state, f),
                    label: GameLogic.canTravelToFloor(state, f)
                        ? 'Floor $f'
                        : 'Floor $f, locked',
                    child: ListTile(
                      dense: true,
                      minVerticalPadding: 12,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        GameLogic.canTravelToFloor(state, f)
                            ? 'F$f'
                            : 'F$f · locked',
                        style: GameTheme.readable(
                          color: GameLogic.canTravelToFloor(state, f)
                              ? GameTheme.parchment
                              : GameTheme.parchmentDim,
                        ),
                      ),
                      trailing: GameLogic.canTravelToFloor(state, f)
                          ? _go
                          : null,
                      onTap: GameLogic.canTravelToFloor(state, f)
                          ? () => Navigator.pop(ctx, f)
                          : null,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        GameButton(
          label: 'CANCEL',
          style: GameButtonStyle.grey,
          expanded: false,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final world = director.spatial;
  final alive = world?.enemies.any((e) => e.isAlive) ?? false;
  final midFloor =
      world != null &&
      (alive ||
          world.combatElapsed > 1.0 ||
          world.groundLoot.isNotEmpty ||
          world.enemies.any((e) => e.hp < e.maxHp));
  if (!midFloor) {
    director.travelToFloor(picked);
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Leave this floor?',
      content: Text(
        alive
            ? 'Enemies are still alive. Jump to F$picked anyway? '
                'Loot on the ground is lost.'
            : 'This floor is mid-run. Jump to F$picked anyway? '
                'Loot on the ground is lost.',
        style: GameTheme.readable(color: GameTheme.parchment),
      ),
      actions: [
        GameButton(
          label: 'CANCEL',
          style: GameButtonStyle.grey,
          expanded: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        GameButton(
          label: 'JUMP',
          expanded: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok == true) director.travelToFloor(picked);
}
