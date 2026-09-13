import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/greater_rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: Greater Rift next-rank enter (no KEY stepper).
class GreaterRiftHubPanel extends StatelessWidget {
  const GreaterRiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'GREATER RIFT unlocks at party level ${GameLogic.maxHeroLevel} — '
        'ranked Mothveil kill ladder (no mid-run gear; not Spire climb).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.grBestTier;
    final next = GreaterRift.nextOfferTier(best);
    final kills = GreaterRift.killTarget(next);
    final par = GreaterRift.formatTimer(GreaterRift.parTimeMs(next));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GREATER RIFT · RANKED',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Next rank after your best — hub ENDGAME shows it. No KEY dial. '
          'Mothveil · gold OK, no gear mid-run. Local PB (Play GR board waits on a Console ID). '
          'Endless after GR${GreaterRift.campaignCap}. '
          'Best GR$best · next GR$next · kill $kills before $par · '
          '+${GreaterRift.successEssence(next)}e / +${GreaterRift.successGold(next)}g',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER RANK GR$next',
          style: GameButtonStyle.red,
          onPressed: GameLogic.canEnterGreaterRift(state)
              ? () => confirmGreaterRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
