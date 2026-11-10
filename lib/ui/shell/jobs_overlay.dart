import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_state.dart';
import '../../core/mission_board.dart';
import '../../models/mission.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import 'home/director_select.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  /// One line so the last claim is not pushed under the bottom bar.
  /// The 3rd claim always pays +5 essence.
  static String introLine({required int chainCount}) {
    return 'Claim 3 in a row for +5 essence. Progress: $chainCount/3.';
  }

  static String rewardLine({required int gold, required int essence}) {
    if (essence <= 0) return '+${formatGold(gold)}';
    return '+${formatGold(gold)} · +$essence essence';
  }

  static String chainClaimLabel() => 'Claim · chain +5 essence';

  static String rerollButtonLabel({
    required bool adFree,
    required int rerollsLeft,
  }) {
    if (adFree) return 'REROLL · FREE ($rerollsLeft left)';
    return 'NEW GOAL';
  }

  static String rerollAdLine() =>
      'Swap for a new goal after a short ad.';

  static String rerollButtonTip({required int rerollsLeft}) =>
      'Rewarded ad · new Daily or Side goal · $rerollsLeft left today (UTC)';

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

  static String _missionDigest(GameState state) {
    final b = StringBuffer();
    for (final m in state.missions) {
      b
        ..write(m.id)
        ..write(':')
        ..write(m.progress)
        ..write('/')
        ..write(m.target)
        ..write(':')
        ..write(m.claimed)
        ..write(';');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DirectorSelect<String>(
      director: director,
      select: (s) => _missionDigest(s),
      builder: (context, state) => SingleChildScrollView(
        child: _board(context, state),
      ),
    );
  }

  Widget _board(BuildContext context, GameState state) {
    final claimable = state.missions.where((m) => m.canClaim).length;
    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellLayout.hint(
            introLine(chainCount: state.metaDepth.jobChainCount),
            maxLines: 1,
          ),
          if (claimable == 0) ...[
            ShellLayout.gap(4),
            ShellLayout.hint(
              'Clear floors to fill these. Progress survives wipes.',
              maxLines: 2,
            ),
          ],
          if (claimable > 0) ...[
            ShellLayout.gap(4),
            GameButton(
              label: claimable == 1
                  ? 'CLAIM QUESTS'
                  : 'CLAIM QUESTS ($claimable)',
              onPressed: () => director.claimAllReadyMissions(),
              style: GameButtonStyle.brown,
              primary: true,
            ),
          ],
          ShellLayout.gap(2),
          for (var i = 0; i < state.missions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _questCard(director, state.missions[i], i),
            ),
        ],
      ),
    );
  }

  Widget _questCard(GameDirector director, Mission mission, int index) {
    final rerollsLeft = MissionBoard.questRerollsRemaining(director.state);
    final showReroll =
        (index == MissionBoard.dailySlot || index == MissionBoard.sideSlot) &&
        MissionBoard.canRerollMission(mission, index) &&
        rerollsLeft > 0;
    final titleStyle = GameTheme.readable(
      color: switch (mission.tier) {
        2 => GameTheme.bloodLit,
        1 => GameTheme.torchHot,
        _ => GameTheme.parchment,
      },
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: GameTheme.panelInset,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        _slotBadge(index),
        style: GameTheme.hint(color: GameTheme.torchHot),
      ),
    );
    if (mission.claimed) {
      return ShellLayout.card(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayTitle(mission, index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            Text(
              'CLAIMED',
              style: GameTheme.section(color: GameTheme.mossLit),
            ),
          ],
        ),
      );
    }
    return ShellLayout.card(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              badge,
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayTitle(mission, index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Progress ${mission.progress}/${mission.target} · '
            '${rewardLine(gold: mission.goldReward, essence: mission.essenceReward)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.section(),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: LinearProgressIndicator(
              value: mission.target <= 0
                  ? 0
                  : (mission.progress / mission.target).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: GameTheme.panelInset,
              color: mission.canClaim ? GameTheme.mossLit : GameTheme.torchHot,
            ),
          ),
          if (mission.canClaim) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: GameButton(
                label: director.state.metaDepth.jobChainCount == 2
                    ? chainClaimLabel()
                    : 'CLAIM',
                onPressed: () => director.claimMission(mission.id),
                style: GameButtonStyle.brown,
                primary: true,
                dense: true,
                expanded: false,
              ),
            ),
          ],
          if (showReroll) ...[
            if (!director.state.metaDepth.adFree) ...[
              const SizedBox(height: 2),
              Text(
                rerollAdLine(),
                textAlign: TextAlign.right,
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: GameButton(
                label: rerollButtonLabel(
                  adFree: director.state.metaDepth.adFree,
                  rerollsLeft: rerollsLeft,
                ),
                tip: rerollButtonTip(rerollsLeft: rerollsLeft),
                onPressed: () => director.rerollQuestSlot(index),
                style: GameButtonStyle.grey,
                dense: true,
                expanded: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
