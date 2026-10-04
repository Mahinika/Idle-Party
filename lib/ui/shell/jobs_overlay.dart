import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../models/mission.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  /// One line so the last claim is not pushed under the bottom bar.
  /// The 3rd claim always pays +5 essence.
  static String introLine({required int chainCount}) {
    return 'Claim here or in the dungeon. Chain $chainCount/3 · +5e';
  }

  static String rewardLine({required int gold, required int essence}) {
    if (essence <= 0) return '+${gold}g';
    return '+${gold}g +${essence}e';
  }

  static String chainClaimLabel() => 'CLAIM · chain +5e';

  static String _slotBadge(int index) => switch (index) {
    0 => 'DAILY',
    1 => 'BOUNTY',
    2 => 'SIDE',
    3 => 'WEEK',
    _ => 'CONTRACT',
  };

  /// Badge already names the slot — drop Daily:/Week:/Contract: from the line.
  static String displayTitle(Mission mission, int index) {
    final raw = mission.title;
    return switch (index) {
      0 => raw.startsWith('Daily: ') ? raw.substring(7) : raw,
      1 => raw.replaceFirst(RegExp(r'^Bounty \d+: '), ''),
      3 => raw.startsWith('Week: ') ? raw.substring(6) : raw,
      4 => raw.startsWith('Contract: ') ? raw.substring(10) : raw,
      _ => raw,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final claimable = state.missions.where((m) => m.canClaim).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          introLine(chainCount: state.metaDepth.jobChainCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          _questCard(state.missions[i], i),
      ],
    );
  }

  Widget _questCard(Mission mission, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: MenuChrome.listCard(
        borderColor: switch (mission.tier) {
          2 => GameTheme.bloodLit,
          1 => GameTheme.torchHot,
          _ => GameTheme.border.withValues(alpha: 0.9),
        },
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        displayTitle(mission, index),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  'Progress ${mission.progress}/${mission.target}'
                  ' · ${rewardLine(gold: mission.goldReward, essence: mission.essenceReward)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 14),
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
                        ? chainClaimLabel()
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
