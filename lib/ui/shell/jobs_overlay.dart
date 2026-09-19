import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_alerts.dart';
import '../../models/mission.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  /// Header + chain line. Essence waits for the ESSENCE tab.
  static String introLine({required bool showEssence, required int chainCount}) {
    final chain = showEssence
        ? 'Chain $chainCount/3 · 3rd pays +5e.'
        : 'Chain $chainCount/3 · 3rd pays extra.';
    return 'QUESTS — claim while you dungeon.\n$chain';
  }

  static String rewardLine({
    required int gold,
    required int essence,
    required bool showEssence,
  }) {
    if (!showEssence || essence <= 0) return '+${gold}g';
    return '+${gold}g +${essence}e';
  }

  static String chainClaimLabel({required bool showEssence}) =>
      showEssence ? 'CLAIM · chain +5e' : 'CLAIM · chain bonus';

  static String _slotBadge(int index) => switch (index) {
    0 => 'DAILY',
    1 => 'BOUNTY',
    2 => 'SIDE',
    3 => 'WEEK',
    _ => 'CONTRACT',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final showEssence = MenuTabs.showCamp(state);
    final claimable = state.missions.where((m) => m.canClaim).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          introLine(
            showEssence: showEssence,
            chainCount: state.metaDepth.jobChainCount,
          ),
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (claimable > 0) ...[
          const SizedBox(height: 8),
          GameButton(
            label: claimable == 1
                ? 'CLAIM QUESTS'
                : 'CLAIM QUESTS ($claimable)',
            onPressed: () => director.claimAllReadyMissions(),
            style: GameButtonStyle.brown,
            primary: true,
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < state.missions.length; i++)
          _questCard(
            state.missions[i],
            i,
            showEssence: showEssence,
          ),
      ],
    );
  }

  Widget _questCard(
    Mission mission,
    int index, {
    required bool showEssence,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: MenuChrome.listCard(
        borderColor: switch (mission.tier) {
          2 => GameTheme.bloodLit,
          1 => GameTheme.torchHot,
          _ => GameTheme.border.withValues(alpha: 0.9),
        },
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GameTheme.panelInset,
                        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                        border: Border.all(
                          color: GameTheme.border.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Text(
                        _slotBadge(index),
                        style: GameTheme.pixel(
                          size: 9,
                          color: GameTheme.torchHot,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mission.title,
                        style: GameTheme.body(
                          size: 16,
                          color: switch (mission.tier) {
                            2 => GameTheme.bloodLit,
                            1 => GameTheme.torchHot,
                            _ => GameTheme.parchment,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Progress ${mission.progress}/${mission.target}',
                  style: GameTheme.body(size: 14),
                ),
                Text(
                  rewardLine(
                    gold: mission.goldReward,
                    essence: mission.essenceReward,
                    showEssence: showEssence,
                  ),
                  style: GameTheme.body(
                    size: 13,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  child: LinearProgressIndicator(
                    value: mission.target <= 0
                        ? 0
                        : (mission.progress / mission.target).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: GameTheme.panelInset,
                    color: mission.canClaim || mission.claimed
                        ? GameTheme.mossLit
                        : GameTheme.torchHot,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (mission.canClaim || mission.claimed)
            GameButton(
              label: mission.claimed
                  ? 'CLAIMED'
                  : (director.state.metaDepth.jobChainCount == 2
                        ? chainClaimLabel(showEssence: showEssence)
                        : 'CLAIM'),
              onPressed: mission.canClaim
                  ? () => director.claimMission(mission.id)
                  : null,
              style: GameButtonStyle.grey,
              expanded: false,
            ),
        ],
      ),
    );
  }
}
