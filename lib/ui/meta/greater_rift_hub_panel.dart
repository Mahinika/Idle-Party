import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/greater_rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: Greater Rift enter (tier picker on ENTER).
class GreaterRiftHubPanel extends StatelessWidget {
  const GreaterRiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'GREATER RIFT unlocks at party level ${GameLogic.maxHeroLevel} — '
        'ranked Mothveil progress + Guardian under the timer (no mid-run gear).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.grBestTier;
    final maxSel = GreaterRift.maxSelectableTier(best);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GREATER RIFT · RANKED',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'ENTER opens the GR picker (1–GR$maxSel) — lower or next after best. '
          'Clock · no gear mid-run. Endless after GR${GreaterRift.campaignCap}. '
          'Best GR$best.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER RANKED GR',
          style: GameButtonStyle.red,
          onPressed: GameLogic.canEnterGreaterRift(state)
              ? () => confirmGreaterRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
