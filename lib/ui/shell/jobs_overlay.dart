
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../models/mission.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  static String _slotBadge(int index) => switch (index) {
    0 => 'DAILY · easy',
    1 => 'BOUNTY · climb',
    _ => 'SIDE · variety',
  };

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final claimable = state.missions.where((m) => m.canClaim).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUESTS — clear goals while you dungeon. Claim for gold + essence.\n'
          'Chain ${state.metaDepth.jobChainCount}/3 · the 3rd claim in a row pays +5e extra.',
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (claimable > 0) ...[
          const SizedBox(height: 8),
          KenneyButton(
            label: claimable == 1
                ? 'CLAIM QUESTS'
                : 'CLAIM QUESTS ($claimable)',
            onPressed: () => director.claimAllReadyMissions(),
            style: KenneyButtonStyle.brown,
            primary: true,
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < state.missions.length; i++)
          _questCard(state.missions[i], i, hideClaim: claimable > 0),
      ],
    );
  }

  Widget _questCard(Mission mission, int index, {bool hideClaim = false}) {
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
                  '+${mission.goldReward}g +${mission.essenceReward}e',
                  style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
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
          if (!hideClaim && (mission.canClaim || mission.claimed))
            KenneyButton(
              label: mission.claimed
                  ? 'CLAIMED'
                  : (director.state.metaDepth.jobChainCount == 2
                      ? 'CLAIM · chain +5e'
                      : 'CLAIM'),
              onPressed: mission.canClaim
                  ? () => director.claimMission(mission.id)
                  : null,
              style: KenneyButtonStyle.grey,
              expanded: false,
            ),
        ],
      ),
    );
  }
}
