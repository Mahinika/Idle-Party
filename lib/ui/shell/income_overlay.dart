import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/gold_income.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'shell_layout.dart';

/// Compact Hub / Run rates at the top of ESSENCE → CAMP.
class CampRatesSection extends StatelessWidget {
  const CampRatesSection({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final run = director.runGoldPerMinute;
    final hub = GoldIncome.hubGoldPerMinute(state);

    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hub ${GoldIncome.perMinuteLabel(hub)}',
          style: GameTheme.readable(color: GameTheme.mossLit),
        ),
        ShellLayout.gap(4),
        ShellLayout.hint(
          run > 0
              ? 'Essence ~1 per 12 min after 10 min. Run ${GoldIncome.perMinuteLabel(run)}.'
              : 'Essence ~1 per 12 min after 10 min. Run — enter a dungeon.',
          maxLines: 2,
        ),
        ShellLayout.gap(6),
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
    ),
    );
  }
}
