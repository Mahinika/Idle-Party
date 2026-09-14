import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/rift.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// KEY tab: farm Rift tier dial (gold + gear mid-run).
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
    final pref = Rift.clampTier(
      state.metaDepth.riftPreferredTier.clamp(Rift.minTier, maxSel),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FARM RIFT · STORMWAKE',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Progress bar → Rift Guardian — no fail timer. Gold + gear mid-run. '
          'Endless after R${Rift.campaignCap}. '
          'Best R$best · +${Rift.successEssence(pref)}e / +${Rift.successGold(pref)}g',
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
        GameButton(
          label: 'ENTER FARM R$pref',
          style: GameButtonStyle.brown,
          onPressed: GameLogic.canEnterRift(state)
              ? () => confirmRiftRun(context, director)
              : null,
        ),
      ],
    );
  }
}
