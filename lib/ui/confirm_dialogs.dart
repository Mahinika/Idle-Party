import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import 'game_theme.dart';
import 'kenney_button.dart';

Future<void> confirmAscend(BuildContext context, GameDirector director) async {
  final state = director.state;
  if (!GameLogic.canAscend(state)) return;

  final reward = GameLogic.ascendEssenceReward(state.ascensionLevel + 1);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GameTheme.stoneDeep,
      title: Text('Ascend?', style: GameTheme.pixel(size: 8)),
      content: Text(
        'Reset this run (gear, levels, stash, floor).\n'
        'Keep essence, relics, pets, sanctuary, soulbound.\n\n'
        'Reward: +${reward}e · AL → ${state.ascensionLevel + 1}',
        style: GameTheme.body(size: 15, color: GameTheme.parchment),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'CANCEL',
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
        ),
        KenneyButton(
          label: 'ASCEND',
          style: KenneyButtonStyle.red,
          expanded: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    director.ascend();
  }
}

Future<void> confirmLeaveDungeon(
  BuildContext context,
  VoidCallback onLeave,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GameTheme.stoneDeep,
      title: Text('Return to hub?', style: GameTheme.pixel(size: 8)),
      content: Text(
        'Leave the dungeon and return to the hub. '
        'Mid-floor combat progress on this room is lost.',
        style: GameTheme.body(size: 15, color: GameTheme.parchment),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'STAY',
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
        ),
        KenneyButton(
          label: 'HUB',
          style: KenneyButtonStyle.grey,
          expanded: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    onLeave();
  }
}
