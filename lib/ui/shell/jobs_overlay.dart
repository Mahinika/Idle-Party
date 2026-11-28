import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_state.dart';
import '../../core/mission_board.dart';
import '../../models/mission.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'home/director_select.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class JobsOverlay extends StatelessWidget {
  const JobsOverlay({super.key, required this.director});
  final GameDirector director;

  /// One line so the last claim is not pushed under the bottom bar.
  /// The 3rd claim always pays +5 essence.
  static String introLine({required int chainCount}) {
    // Not "in a row": any 3 claims, no days involved (polish7 P019).
    return 'Every 3rd quest claimed adds +5 essence. Progress: $chainCount/3.';
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
    return 'REROLL (ad)';
  }

  static String rerollAdLine() => 'Swap for a new goal after a short ad.';

  static String rerollButtonTip({required int rerollsLeft}) =>
      'Rewarded ad · new Daily or Side goal · $rerollsLeft left today';

  static Key rerollKey(int i) => ValueKey('quest-reroll-$i');
  static Key progressKey(int i) => ValueKey('quest-progress-$i');
  static Key barKey(int i) => ValueKey('quest-bar-$i');

  static Widget _rewardChip(String icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: MenuChrome.cardBox(inset: true),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon.asset(icon, size: 14),
        const SizedBox(width: 3),
        Text(label, style: GameTheme.hint(color: GameTheme.parchment)),
      ],
    ),
  );

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
      builder: (context, state) =>
          SingleChildScrollView(child: _board(context, state)),
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
          // One line at 1.0; at large text it wraps instead of cutting
          // the progress count.
          ShellLayout.hint(
            introLine(chainCount: state.metaDepth.jobChainCount),
            maxLines: 2,
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
              // Claim is the go action: amber face (polish7 P001).
              style: GameButtonStyle.go,
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
            Text('CLAIMED', style: GameTheme.section(color: GameTheme.mossLit)),
          ],
        ),
      );
    }
    final rerollLabel = rerollButtonLabel(
      adFree: director.state.metaDepth.adFree,
      rerollsLeft: rerollsLeft,
    );
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
              // A small swap button in the corner, not a full-width slab
              // on every card (audit F031). The label stays in semantics.
              if (showReroll)
                GameIconButton(
                  key: rerollKey(index),
                  label: rerollLabel,
                  tooltip: rerollButtonTip(rerollsLeft: rerollsLeft),
                  asset: UiIcon.watchAd,
                  size: 18,
                  onPressed: () => director.rerollQuestSlot(index),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // "0/20" on the left, the reward as chips on the right
          // (audit F076); it wraps under at large text.
          Wrap(
            spacing: 6,
            runSpacing: 2,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${mission.progress}/${mission.target}',
                key: progressKey(index),
                style: GameTheme.section(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rewardChip(
                    UiIcon.gold,
                    '+${formatGold(mission.goldReward)}',
                  ),
                  if (mission.essenceReward > 0) ...[
                    const SizedBox(width: 4),
                    _rewardChip(UiIcon.essence, '+${mission.essenceReward}'),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          // A plum bar with a visible track, even at 0 (audit F030).
          ClipRRect(
            key: barKey(index),
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: LinearProgressIndicator(
              value: mission.target <= 0
                  ? 0
                  : (mission.progress / mission.target).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: GameTheme.levelAccentDeep,
              color: mission.canClaim
                  ? GameTheme.mossLit
                  : GameTheme.levelAccent,
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
                style: GameButtonStyle.go,
                primary: true,
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
