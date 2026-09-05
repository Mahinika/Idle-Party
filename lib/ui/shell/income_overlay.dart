import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../core/gold_income.dart';
import '../game_theme.dart';

/// Compact Hub / Run rates at the top of ESSENCE → TRACKS.
class CampRatesSection extends StatelessWidget {
  const CampRatesSection({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final run = director.runGoldPerMinute;
    final hub = GoldIncome.hubGoldPerMinute(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          run > 0
              ? 'Hub ${GoldIncome.perMinuteLabel(hub)} · Run ${GoldIncome.perMinuteLabel(run)}'
              : 'Hub ${GoldIncome.perMinuteLabel(hub)} · Run — enter a dungeon',
          style: GameTheme.body(size: 14, color: GameTheme.mossLit),
        ),
        Text(
          GoldIncome.multiplierLine(state),
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!MenuTabs.showCamp(state)) ...[
          const SizedBox(height: 6),
          Text(
            'Tracks unlock after Ascend or when you earn essence.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}
