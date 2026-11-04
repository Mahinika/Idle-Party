import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/greater_rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../shell/shell_layout.dart';

/// KEY tab: Greater Rift enter (tier picker on ENTER).
class GreaterRiftHubPanel extends StatelessWidget {
  const GreaterRiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return ShellLayout.hint(
        'Ranked GR unlocks when every active hero is Lv${GameLogic.maxHeroLevel} — '
        'ranked Mothveil progress + Guardian under the timer (no mid-run gear).',
        maxLines: 3,
      );
    }
    final month = state.metaDepth.leaderboardSeasonKey;
    final seasonTier = state.metaDepth.seasonBestGrTier;
    final bestMs = state.metaDepth.seasonBestGrClearMs;
    final bestTime = bestMs > 0
        ? GreaterRift.formatTimer(bestMs)
        : 'no time yet';
    final monthBit = month.isEmpty ? '' : ' · $month';
    final bestBit = bestMs > 0 && seasonTier > 0
        ? 'Best GR$seasonTier · $bestTime$monthBit.'
        : 'Best $bestTime$monthBit.';
    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellLayout.sectionHeader('Ranked GR'),
        ShellLayout.gap(4),
        ShellLayout.hint(
          'Clock · no gear mid-run. Endless after GR${GreaterRift.campaignCap}.',
          maxLines: 2,
        ),
        ShellLayout.gap(4),
        ShellLayout.hint(bestBit, maxLines: 2),
        ShellLayout.gap(8),
        GameButton(
          label: 'ENTER RANKED GR',
          style: GameButtonStyle.brown,
          primary: true,
          onPressed: GameLogic.canEnterGreaterRift(state)
              ? () => confirmGreaterRiftRun(context, director)
              : null,
        ),
      ],
    ),
    );
  }
}
