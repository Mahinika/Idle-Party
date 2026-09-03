import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/gold_income.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';

/// Hub / Run gold rates — embedded at the top of POWER → Essence.
class CampRatesSection extends StatelessWidget {
  const CampRatesSection({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final run = director.runGoldPerMinute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.sectionLabelScoped('RATES', scope: MenuScope.account),
        Text(
          GoldIncome.hubRateLine(state),
          style: GameTheme.body(size: 15, color: GameTheme.mossLit),
        ),
        Text(
          run > 0
              ? 'Run ${GoldIncome.perMinuteLabel(run)}'
              : 'Run — fight in a dungeon to see combat gold/min',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        const SizedBox(height: 4),
        Text(
          GoldIncome.multiplierLine(state),
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (!MenuTabs.showCamp(state)) ...[
          const SizedBox(height: 8),
          Text(
            'Gold Find and sanctuary tracks unlock after Ascend or when you '
            'earn essence.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}
