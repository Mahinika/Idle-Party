import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/greater_rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// KEY tab: Greater Rift tier dial (party max-level prestige + boards).
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
    final maxSel = GreaterRift.maxSelectableTier(best);
    final pref = GreaterRift.clampTier(
      state.metaDepth.grPreferredTier.clamp(GreaterRift.minTier, maxSel),
    );
    final kills = GreaterRift.killTarget(pref);
    final par = GreaterRift.formatTimer(GreaterRift.parTimeMs(pref));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GREATER RIFT · RANKED',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Mothveil prestige timer — harder packs, no mid-run gear, board score. '
          'Not Gauntlet floors · not farm Rift loot. '
          'Best GR$best · kill $kills before $par · '
          '+${GreaterRift.successEssence(pref)}e / +${GreaterRift.successGold(pref)}g',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            MenuChrome.stepperButton(
              label: 'GR -',
              sign: '-',
              onPressed: pref > GreaterRift.minTier
                  ? () => director.setGrPreferredTier(pref - 1)
                  : null,
            ),
            Expanded(
              child: Text(
                'GR$pref',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
            ),
            MenuChrome.stepperButton(
              label: 'GR +',
              sign: '+',
              onPressed: pref < maxSel
                  ? () => director.setGrPreferredTier(pref + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'ENTER RANK GR$pref',
          style: GameButtonStyle.red,
          onPressed: GameLogic.canEnterGreaterRift(state)
              ? () => confirmGreaterRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
