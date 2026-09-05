import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'income_overlay.dart';
import 'power_upgrade_row.dart';

class SanctuaryOverlay extends StatelessWidget {
  const SanctuaryOverlay({super.key, required this.director});
  final GameDirector director;

  int _prestigeOf(GameState state, String track) => switch (track) {
    'gold' => state.metaDepth.sanctuaryGoldPrestige,
    'power' => state.metaDepth.sanctuaryPowerPrestige,
    'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
    'xp' => state.metaDepth.sanctuaryXpPrestige,
    _ => 0,
  };

  int _levelOf(GameState state, String track) => switch (track) {
    'gold' => state.sanctuaryGoldLevel,
    'power' => state.sanctuaryPowerLevel,
    'vitality' => state.sanctuaryVitalityLevel,
    'xp' => state.metaDepth.sanctuaryXpLevel,
    _ => 0,
  };

  Color _trackAccent(String track) => switch (track) {
    'gold' => GameTheme.torch,
    'power' => GameTheme.hudHpDamage,
    'vitality' => GameTheme.mossLit,
    'xp' => GameTheme.rarityRare,
    _ => GameTheme.parchmentDim,
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final campOpen = MenuTabs.showCamp(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampRatesSection(director: director),
        const SizedBox(height: 8),
        Text(
          '${state.essence}e · survive Ascend · reset at Lv12+',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 8),
        if (campOpen)
          for (final track in <String>['gold', 'power', 'vitality', 'xp'])
            _campTrackCard(context, state, track)
        else
          Text(
            'War Altar, Life Well, and Lore Font appear here once Essence unlocks.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _campTrackCard(BuildContext context, GameState state, String track) {
    final level = _levelOf(state, track);
    final prestige = _prestigeOf(state, track);
    final cost = GameLogic.sanctuaryCost(level);
    final keepShort = GameLogic.sanctuaryPrestigeKeepShort(track);
    final currentBonus = GameLogic.sanctuaryBonusLabel(
      track,
      level,
      prestige: prestige,
    );
    final canPrestige = level >= 12;
    final prestigeGain = GameLogic.sanctuaryPrestigeEssenceGain(level);
    final canAfford = state.essence >= cost;
    final bulk = GameLogic.sanctuaryBulkAffordableLevels(state, track);

    String? detail;
    if (track == 'gold') {
      final hubDelta = GoldIncome.nextGoldFindDeltaPerMinute(state);
      detail = 'Next +${hubDelta}g/min hub';
    }

    // Prefer bulk as the one primary when affordable; single buy otherwise.
    final useBulk = bulk > 1;
    late final Widget trailing;
    if (useBulk) {
      final bulkCost = GameLogic.sanctuaryBulkCost(state, track, bulk);
      final target = level + bulk;
      final label = track == 'gold'
          ? () {
              final hubNow = GoldIncome.hubGoldPerMinute(state);
              final hubAfter =
                  GoldIncome.hubGoldPerMinuteAtGoldLevel(state, target);
              return '+${hubAfter - hubNow}g/min · ${bulkCost}e';
            }()
          : 'Buy $bulk · ${bulkCost}e';
      trailing = GameButton(
        label: label,
        expanded: false,
        dense: true,
        onPressed: () => director.upgradeSanctuaryBulk(track),
      );
    } else {
      trailing = GameButton(
        label: '${cost}e',
        expanded: false,
        dense: true,
        onPressed: canAfford ? () => director.upgradeSanctuary(track) : null,
      );
    }

    return PowerUpgradeRow(
      accent: _trackAccent(track),
      title: GameLogic.sanctuaryNames[track] ?? track,
      subtitle: 'Lv$level · $currentBonus'
          '${prestige > 0 ? ' · P$prestige' : ''}',
      detail: detail,
      selected: canPrestige,
      dense: true,
      trailing: trailing,
      below: canPrestige
          ? GameButton(
              label: 'Reset · keep $keepShort · +${prestigeGain}e',
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierColor: MenuChrome.scrim,
                  builder: (ctx) => MenuChrome.dialog(
                    title: 'Reset this track?',
                    content: Text(
                      'Resets this track to Lv1. Keeps $keepShort forever '
                      'and refunds ${prestigeGain}e.\n\n'
                      'Not Ascend — only this track.',
                      style: GameTheme.body(
                        size: 15,
                        color: GameTheme.parchment,
                      ),
                    ),
                    actions: [
                      GameButton(
                        label: 'CANCEL',
                        style: GameButtonStyle.grey,
                        expanded: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      GameButton(
                        label: 'RESET',
                        style: GameButtonStyle.red,
                        expanded: false,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  director.prestigeSanctuaryTrack(track);
                }
              },
            )
          : null,
    );
  }
}
