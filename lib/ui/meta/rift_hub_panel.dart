import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../shell/shell_layout.dart';

/// KEY tab: Farm Rift enter (tier picker on ENTER).
class RiftHubPanel extends StatelessWidget {
  const RiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return ShellLayout.hint(
        'FARM RIFT unlocks when every active hero is Lv${GameLogic.maxHeroLevel} — '
        'Stormwake progress bar + Guardian (loot mid-run; not Spire climb).',
        maxLines: 3,
      );
    }
    final best = state.metaDepth.riftBestTier;
    final next = Rift.nextOfferTier(best);
    final gold = Rift.successGold(next);
    final essence = Rift.successEssence(next);
    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellLayout.sectionHeader('FARM RIFT · STORMWAKE'),
        ShellLayout.gap(4),
        ShellLayout.hint(
          'ENTER opens the R picker — any R. Gold + gear mid-run. '
          'Endless after R${Rift.campaignCap}. Best R$best. '
          'Next R$next pays +${gold}g and +${essence}e.',
          maxLines: 4,
        ),
        ShellLayout.gap(8),
        GameButton(
          label: 'ENTER FARM RIFT',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: GameLogic.canEnterRift(state)
              ? () => confirmRiftRun(context, director)
              : null,
        ),
      ],
    ),
    );
  }
}
