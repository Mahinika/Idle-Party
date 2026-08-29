import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_bar.dart';
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
    final relicLine = GameLogic.relicKeepSummary(state);
    final campOpen = MenuTabs.showCamp(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampRatesSection(director: director),
        const SizedBox(height: 8),
        Text(
          'Tracks survive Ascend · reset from Lv12',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (state.metaDepth.ascendBlessings > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Ascend Blessing ×${state.metaDepth.ascendBlessings} · '
            'see Gold → KEEP',
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
        ],
        if (relicLine != null) ...[
          const SizedBox(height: 4),
          Text(
            relicLine,
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        if (campOpen)
          for (final track in <String>['gold', 'power', 'vitality', 'xp'])
            _campTrackCard(context, state, track)
        else
          Text(
            'War Altar, Life Well, and Lore Font appear here once Essence unlocks.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
      ],
    );
  }

  Widget _campTrackCard(BuildContext context, GameState state, String track) {
    final level = _levelOf(state, track);
    final prestige = _prestigeOf(state, track);
    final nextLevel = level + 1;
    final cost = GameLogic.sanctuaryCost(level);
    final keepShort = GameLogic.sanctuaryPrestigeKeepShort(track);
    final nextBonus = GameLogic.sanctuaryBonusLabel(
      track,
      nextLevel,
      prestige: prestige,
    );
    final currentBonus = GameLogic.sanctuaryBonusLabel(
      track,
      level,
      prestige: prestige,
    );
    final cycleStep = level <= 0 ? 0 : ((level - 1) % 12 + 1);
    final canPrestige = level >= 12;
    final prestigeGain = GameLogic.sanctuaryPrestigeEssenceGain(level);
    final canAfford = state.essence >= cost;
    final bulk = GameLogic.sanctuaryBulkAffordableLevels(state, track);

    String? detail;
    if (track == 'gold') {
      final hubDelta = GoldIncome.nextGoldFindDeltaPerMinute(state);
      detail = 'Next $nextBonus · Hub +${hubDelta}g/min';
    } else {
      detail = 'Next $nextBonus';
    }

    final barColor = track == 'vitality'
        ? KenneyBarColor.red
        : track == 'power'
            ? KenneyBarColor.yellow
            : KenneyBarColor.green;

    String? bulkLabel;
    if (bulk > 1) {
      final target = level + bulk;
      if (track == 'gold') {
        final hubNow = GoldIncome.hubGoldPerMinute(state);
        final hubAfter = GoldIncome.hubGoldPerMinuteAtGoldLevel(state, target);
        bulkLabel = 'Buy $bulk · +${hubAfter - hubNow} g/min';
      } else {
        bulkLabel = 'Buy $bulk · Lv$target';
      }
    }

    return PowerUpgradeRow(
      accent: _trackAccent(track),
      title: GameLogic.sanctuaryNames[track] ?? track,
      subtitle: 'Lv$level · $currentBonus'
          '${prestige > 0 ? ' · P$prestige' : ''}'
          ' · $cycleStep/12',
      detail: detail,
      selected: canPrestige || (track == 'gold' && canAfford),
      trailing: KenneyButton(
        label: '${cost}e',
        expanded: false,
        onPressed: canAfford ? () => director.upgradeSanctuary(track) : null,
      ),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KenneyProgressBar(
            value: (cycleStep / 12.0).clamp(0.0, 1.0),
            height: 8,
            color: barColor,
          ),
          if (bulkLabel != null) ...[
            const SizedBox(height: 4),
            KenneyButton(
              label: bulkLabel,
              style: KenneyButtonStyle.grey,
              onPressed: () => director.upgradeSanctuaryBulk(track),
            ),
          ],
          if (canPrestige) ...[
            const SizedBox(height: 4),
            KenneyButton(
              label: 'Reset · keep $keepShort · +${prestigeGain}e',
              style: KenneyButtonStyle.grey,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierColor: MenuChrome.scrim,
                  builder: (ctx) => MenuChrome.dialog(
                    title: 'Reset this track?',
                    content: Text(
                      'Resets this Essence track to Lv1. Keeps $keepShort forever '
                      'and refunds ${prestigeGain}e.\n\n'
                      'This is not Ascend — only this track. '
                      'Ascend (hub claim) resets the run bag and raises AL.',
                      style: GameTheme.body(
                        size: 15,
                        color: GameTheme.parchment,
                      ),
                    ),
                    actions: [
                      KenneyButton(
                        label: 'CANCEL',
                        style: KenneyButtonStyle.grey,
                        expanded: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      KenneyButton(
                        label: 'RESET',
                        style: KenneyButtonStyle.red,
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
            ),
          ],
        ],
      ),
    );
  }
}
