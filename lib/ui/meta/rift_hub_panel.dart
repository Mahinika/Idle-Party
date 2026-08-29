
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// META → KEY: farm Rift tier dial (gold + gear mid-run).
class RiftHubPanel extends StatelessWidget {
  const RiftHubPanel({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.endgameUnlocked(state)) {
      return Text(
        'RIFT unlocks at party level ${GameLogic.maxHeroLevel} — timed kill challenges with escalating tiers.',
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
      );
    }
    final best = state.metaDepth.riftBestTier;
    final maxSel = Rift.maxSelectableTier(best);
    final pref = Rift.clampTier(
      state.metaDepth.riftPreferredTier.clamp(Rift.minTier, maxSel),
    );
    final kills = Rift.killTarget(pref);
    final par = Rift.formatTimer(Rift.parTimeMs(pref));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RIFT',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Farm Rift — gold and gear mid-run. Best R$best · kill $kills before $par · '
          '+${Rift.successEssence(pref)}e / +${Rift.successGold(pref)}g',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            MenuChrome.stepperButton(
              label: 'RIFT -',
              sign: '-',
              onPressed: pref > Rift.minTier
                  ? () => director.setRiftPreferredTier(pref - 1)
                  : null,
            ),
            Expanded(
              child: Text(
                'R$pref',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 16, color: GameTheme.parchment),
              ),
            ),
            MenuChrome.stepperButton(
              label: 'RIFT +',
              sign: '+',
              onPressed: pref < maxSel
                  ? () => director.setRiftPreferredTier(pref + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        KenneyButton(
          label: 'ENTER RIFT R$pref',
          style: KenneyButtonStyle.brown,
          onPressed: GameLogic.canEnterRift(state)
              ? () => confirmRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
