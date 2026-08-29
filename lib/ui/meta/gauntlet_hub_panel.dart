
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

/// META → KEY: Infinity Gauntlet enter (party max-level Spire climb).
class GauntletHubPanel extends StatelessWidget {
  const GauntletHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'INFINITY GAUNTLET unlocks at party level ${GameLogic.maxHeroLevel} — '
        'endless Crystal Spire climb (boss every 5 floors).',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.gauntletBestFloor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'INFINITY GAUNTLET',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          best <= 0
              ? 'Endless Crystal Spire — boss every 5 floors. Wipe or leave returns to hub.'
              : 'Best F$best — floors escalate forever; wipe or leave returns to hub.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'ENTER GAUNTLET',
          style: KenneyButtonStyle.red,
          onPressed: GameLogic.canEnterGauntlet(state)
              ? () => confirmGauntletRun(context, director)
              : null,
        ),
      ],
    );
  }
}
