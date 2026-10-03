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
        'GAUNTLET unlocks when every active hero is Lv${GameLogic.maxHeroLevel}. '
        'Boss every 5 floors.',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.gauntletBestFloor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GAUNTLET · CLIMB',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          best <= 0
              ? 'Boss every 5 floors. Picture stays Crystal Warden; the tell word cycles.'
              : 'Best clear F$best. Picture stays Crystal Warden; the tell word cycles.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER GAUNTLET',
          style: GameButtonStyle.brown,
          onPressed: GameLogic.canEnterGauntlet(state)
              ? () => confirmGauntletRun(context, director)
              : null,
        ),
      ],
    );
  }
}
