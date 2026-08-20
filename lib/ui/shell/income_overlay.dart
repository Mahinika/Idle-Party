import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Hub / Run gold rates and the Gold Find generator (CAMP track).
class IncomeOverlay extends StatelessWidget {
  const IncomeOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final run = director.runGoldPerMinute;
    final campOpen = MenuTabs.showCamp(state);
    final goldLevel = state.sanctuaryGoldLevel;
    final hub = GoldIncome.hubGoldPerMinute(state);
    final nextCost = GameLogic.sanctuaryCost(goldLevel);
    final nextDelta = GoldIncome.nextGoldFindDeltaPerMinute(state);
    final bulk = GoldIncome.goldFindBulkAffordableLevels(state);
    final bulkTarget = goldLevel + bulk;
    final bulkHub = bulk > 0
        ? GoldIncome.hubGoldPerMinuteAtGoldLevel(state, bulkTarget)
        : hub;
    final bulkGain = bulkHub - hub;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabel('RATES'),
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
          const SizedBox(height: 12),
          MenuChrome.sectionLabel('GOLD FIND'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: MenuChrome.listCard(
              selected: campOpen && state.essence >= nextCost,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  campOpen
                      ? 'Your keep generator — Lv$goldLevel · '
                          '${GoldIncome.perMinuteLabel(hub)} at the hub'
                      : 'Unlocks in POWER → CAMP after Ascend or when you '
                          'earn essence. Hub still ticks at '
                          '${GoldIncome.perMinuteLabel(hub)}.',
                  style: GameTheme.body(size: 13, color: GameTheme.parchment),
                ),
                if (campOpen) ...[
                  Text(
                    'Next level: +${nextDelta}g/min · ${nextCost}e',
                    style: GameTheme.body(size: 12, color: GameTheme.mossLit),
                  ),
                  const SizedBox(height: 6),
                  KenneyButton(
                    label: state.essence >= nextCost
                        ? 'Upgrade Gold Find · ${nextCost}e'
                        : 'Upgrade Gold Find · Need ${nextCost}e',
                    onPressed: state.essence >= nextCost
                        ? () => director.upgradeSanctuary('gold')
                        : null,
                  ),
                  if (bulk > 1) ...[
                    const SizedBox(height: 4),
                    KenneyButton(
                      label:
                          'Buy $bulk levels · Lv$bulkTarget · '
                          '+$bulkGain g/min',
                      style: KenneyButtonStyle.brown,
                      onPressed: () => director.upgradeSanctuaryGoldBulk(),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'War Altar, Life Well, and Lore Font live on CAMP. '
            'Run gold and forge buys live on FORGE.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ),
    );
  }
}
