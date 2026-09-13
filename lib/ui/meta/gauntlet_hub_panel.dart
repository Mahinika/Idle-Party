import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// KEY tab: Infinity Gauntlet enter (party max-level Spire climb).
class GauntletHubPanel extends StatelessWidget {
  const GauntletHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'INFINITY GAUNTLET unlocks at party level ${GameLogic.maxHeroLevel} — '
        'endless Spire climb, not a 16th cave (boss every 5 floors).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.gauntletBestFloor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'INFINITY GAUNTLET · CLIMB',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          best <= 0
              ? 'Endless Spire floors — not a 16th cave, not a timed Rift. '
                  'Boss every 5. Wipe or leave → hub. Best floor is your PB.'
              : 'Spire climb · best F$best. Not a 16th cave. Floors escalate forever — '
                  'boss every 5. Not a Rift timer.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER GAUNTLET',
          style: GameButtonStyle.red,
          onPressed: GameLogic.canEnterGauntlet(state)
              ? () => confirmGauntletRun(context, director)
              : null,
        ),
      ],
    );
  }
}
