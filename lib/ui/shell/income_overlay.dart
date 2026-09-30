import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/gold_income.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';

/// Compact Hub / Run rates at the top of ESSENCE → CAMP.
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
              ? 'Hub ${GoldIncome.perMinuteLabel(hub)} · essence about 1 per 12 min after 10 min · Run ${GoldIncome.perMinuteLabel(run)}'
              : 'Hub ${GoldIncome.perMinuteLabel(hub)} · essence about 1 per 12 min after 10 min · Run — enter a dungeon',
          style: GameTheme.body(size: 14, color: GameTheme.mossLit),
        ),
        // Two chips only — full multiplier dump lived in one dense line (#55).
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in GoldIncome.multiplierParts(state).take(2))
              MenuChrome.chip(
                label: '${p.$1} +${p.$2}%',
                tone: GameTheme.parchmentDim,
              ),
          ],
        ),
      ],
    );
  }
}
