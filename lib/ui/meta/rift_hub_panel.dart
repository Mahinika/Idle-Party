import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: Farm Rift enter (tier picker on ENTER).
class RiftHubPanel extends StatelessWidget {
  const RiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'FARM RIFT unlocks at party level ${GameLogic.maxHeroLevel} — '
        'Stormwake progress bar + Guardian (loot mid-run; not Spire climb).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.riftBestTier;
    final maxSel = Rift.maxSelectableTier(best);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FARM RIFT · STORMWAKE',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'ENTER opens the R picker (1–R$maxSel). Gold + gear mid-run. '
          'Endless after R${Rift.campaignCap}. Best R$best.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER FARM RIFT',
          style: GameButtonStyle.brown,
          onPressed: GameLogic.canEnterRift(state)
              ? () => confirmRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
