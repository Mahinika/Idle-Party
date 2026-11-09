import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../game_theme.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_layout.dart';

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
  final clearedFloors = <int>[
    for (var f = 1; f <= maxFloor; f++)
      if (f != here && GameLogic.canTravelToFloor(state, f)) f,
  ];
  final picked = await showDialog<int>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'FLOORS',
      content: SizedBox(
        width: 280,
        height: MediaQuery.sizeOf(ctx).height * 0.45,
        child: ListView(
          children: [
            ShellLayout.hint('Now F$here. Jump keeps the KEY clock running.', maxLines: 2),
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
