import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/meta_systems.dart';
import '../core/story_lore.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'menu_chrome.dart';

Future<void> confirmAscend(BuildContext context, GameDirector director) async {
  final state = director.state;
  if (!GameLogic.canAscend(state)) return;

  final nextAl = state.ascensionLevel + 1;
  final baseReward = GameLogic.ascendEssenceReward(nextAl);
  final milestone = MetaSystems.ascendMilestoneReward(
    state.ascensionLevel,
    nextAl,
  );
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Ascend?',
      content: Text(
        StoryLore.ascendConfirmBody(
          rewardEssence: baseReward + milestone,
          nextAl: nextAl,
          milestoneBonus: milestone,
          godHandLevel: state.godHandLevel,
          soulboundFragments: state.soulboundFragments,
        ),
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
    barrierColor: MenuChrome.scrim,
    builder: (ctx) => MenuChrome.dialog(
      title: 'Return to hub?',
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
          label: 'RETURN',
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
