import 'package:flutter/material.dart';
import '../../core/chase_contract.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/hub_chase.dart';
import '../../core/local_season.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';

class HubMetaPulse extends StatelessWidget {
  const HubMetaPulse({
    super.key,
    required this.state,
    required this.chaseKind,
    this.chaseUrgency = HubChaseUrgency.normal,
  });

  final GameState state;
  final HubChaseKind chaseKind;
  final HubChaseUrgency chaseUrgency;

  /// KEY / Vault / Week crumbs. Empty when first-hour or the hunt is already
  /// KEY / Gauntlet / Ranked GR / Farm Rift / Ashen / soft rest.
  static List<String> crumbsFor({
    required GameState state,
    required HubChaseKind chaseKind,
    HubChaseUrgency chaseUrgency = HubChaseUrgency.normal,
    DateTime? now,
  }) {
    if (!GameLogic.showDailyChase(state)) return const [];
    if (hubChaseOwnsEndgameRow(chaseKind)) return const [];
    if (chaseUrgency == HubChaseUrgency.ready) return const [];

    final bits = <String>[];
    final showKey = GameLogic.showKeystoneJargon(state);
    if (showKey &&
        chaseKind != HubChaseKind.dailyVaultProgress &&
        chaseKind != HubChaseKind.claimDailyVault) {
      bits.add(
        state.hardmodeLevel <= 0
            ? 'KEY +0 · dial on KEY'
            : 'KEY +${state.hardmodeLevel}',
      );
    }

    if (chaseKind != HubChaseKind.claimDailyVault &&
        chaseKind != HubChaseKind.dailyVaultProgress &&
        chaseKind != HubChaseKind.dailyRun &&
        chaseKind != HubChaseKind.claimMissions) {
      final clears = state.metaDepth.dailyVaultClears;
      final target = GameLogic.dailyVaultClearTarget;
      if (!GameLogic.canClaimDailyVault(state)) {
        bits.add(
          GameLogic.showDailyRunOnHub(state)
              ? 'Vault $clears/$target · not Daily Run'
              : 'Vault $clears/$target',
        );
      }
    }

    // When the hunt is already a daily, name the other two so they
    // don't collapse into "the daily" — skip until Daily Run exists.
    if (GameLogic.showDailyRunOnHub(state)) {
      if (chaseKind == HubChaseKind.dailyVaultProgress ||
          chaseKind == HubChaseKind.claimDailyVault) {
        bits.add('≠ Daily Run · ≠ Quests');
      } else if (chaseKind == HubChaseKind.dailyRun) {
        bits.add('≠ Vault · ≠ Quests');
      } else if (chaseKind == HubChaseKind.claimMissions) {
        bits.add('≠ Vault · ≠ Daily Run');
      }
    }

    if (chaseKind != HubChaseKind.weekGoal &&
        chaseUrgency != HubChaseUrgency.ready) {
      final clock = now ?? DateTime.now().toUtc();
      final weekKey = state.metaDepth.weeklyKey.isNotEmpty
          ? state.metaDepth.weeklyKey
          : GameLogic.isoWeekKey(clock);
      final week = LocalSeasonCatalog.forWeekKey(weekKey);
      if (week.hasGoal) {
        if (LocalSeasonCatalog.weekGoalReady(state, week)) {
          bits.add('Week goal READY');
        } else if (!LocalSeasonCatalog.weekGoalClaimed(state, week)) {
          bits.add(
            'Week · ${LocalSeasonCatalog.weekProgressLabel(state, week)}',
          );
        }
      }
    }
    return bits;
  }

  @override
  Widget build(BuildContext context) {
    final bits = crumbsFor(
      state: state,
      chaseKind: chaseKind,
      chaseUrgency: chaseUrgency,
    );

    if (bits.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Semantics(
        label: 'Meta: ${bits.join(', ')}',
        child: Text(
          bits.join(' · '),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
      ),
    );
  }
}

class HubTodayCard extends StatelessWidget {
  const HubTodayCard({
    super.key,
    required this.chase,
    this.compact = false,
    this.hideDetail = false,
    this.actionLabel,
    this.onAction,
  });

  final HubChase chase;
  final bool compact;
  final bool hideDetail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ready = chase.urgency == HubChaseUrgency.ready;
    final almost = chase.urgency == HubChaseUrgency.almost;
    final accent = ready
        ? GameTheme.torchHot
        : almost
        ? GameTheme.accentWarn
        : GameTheme.parchmentDim;
    final chip = ready
        ? 'READY'
        : almost
        ? 'ALMOST'
        : null;
    final showDetail = !hideDetail && chase.detail.isNotEmpty;
    final why = ChaseContract(chase: chase).whyLine;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final titleMaxLines = textScale > 1.2 ? 1 : 2;
    // Text strip only — no fill box under ENTER.
    return Semantics(
      label: 'Next job: ${chase.title}. ${chase.detail}. $why',
      button:
          chase.urgency == HubChaseUrgency.ready ||
          chase.urgency == HubChaseUrgency.almost,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Semantics(
                  label: 'Next job',
                  excludeSemantics: true,
                  child: GameIcon.asset(UiIcon.star, size: 16),
                ),
                if (chip != null) ...[
                  const SizedBox(width: 8),
                  Text(chip, style: GameTheme.body(size: 13, color: accent)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _todayHeadline(chase, ready: ready),
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 16, color: GameTheme.parchment),
            ),
            if (showDetail) ...[
              const SizedBox(height: 6),
              Text(
                chase.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 4),
              Text(
                why,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GameButton(
                  label: actionLabel!,
                  style: GameButtonStyle.grey,
                  expanded: false,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// TODAY title line — skip progress when READY chip already marks payoff.
String _todayHeadline(HubChase chase, {required bool ready}) {
  final prog = chase.progressLabel;
  if (ready) return chase.title;
  if (prog == null || prog.isEmpty) return chase.title;
  if (chase.title.contains(prog)) return chase.title;
  final keyInTitle = RegExp(r'KEY \+\d+').firstMatch(chase.title);
  final keyInProg = RegExp(r'KEY \+\d+').firstMatch(prog);
  if (keyInTitle != null &&
      keyInProg != null &&
      keyInTitle.group(0) == keyInProg.group(0)) {
    return chase.title;
  }
  // Never echo urgency words next to an ALMOST chip either.
  final lower = prog.toLowerCase();
  if (lower == 'ready' || lower.endsWith(' ready')) return chase.title;
  return '${chase.title} · $prog';
}

class HubUrgentRow extends StatelessWidget {
  const HubUrgentRow({
    super.key,
    required this.claimable,
    required this.canAscend,
    required this.ascendLabel,
    required this.onContracts,
    required this.onAscend,
    required this.dailyClaimed,
    required this.onDaily,
    required this.weeklyReady,
    required this.weeklyProgress,
    required this.weeklyClaimed,
    required this.weeklyBestTimedKey,
    required this.vaultClaimEssence,
    required this.onClaimDailyVault,
    this.hideAscend = false,
    this.hideVaultClaim = false,
    this.hideVaultProgress = false,
    this.hideMissionClaim = false,
    this.hideDaily = false,
  });

  final int claimable;
  final bool canAscend;
  final String? ascendLabel;
  final VoidCallback onContracts;
  final VoidCallback onAscend;
  final bool dailyClaimed;
  final VoidCallback onDaily;
  final bool weeklyReady;
  final int weeklyProgress;
  final bool weeklyClaimed;
  final int weeklyBestTimedKey;
  final int vaultClaimEssence;
  final VoidCallback onClaimDailyVault;
  final bool hideAscend;
  final bool hideVaultClaim;
  final bool hideVaultProgress;
  final bool hideMissionClaim;
  final bool hideDaily;

  @override
  Widget build(BuildContext context) {
    final showVaultProgress =
        !hideVaultProgress &&
        !weeklyClaimed &&
        weeklyProgress > 0 &&
        weeklyProgress < GameLogic.dailyVaultClearTarget &&
        weeklyBestTimedKey < 2;
    final showAscend = canAscend && ascendLabel != null && !hideAscend;
    final showVault = weeklyReady && !hideVaultClaim;
    final showMissions = claimable > 0 && !hideMissionClaim;
    final showDaily = !hideDaily && !dailyClaimed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAscend) ...[
          GameButton(
            label: ascendLabel!,
            style: GameButtonStyle.red,
            primary: true,
            onPressed: onAscend,
          ),
          const SizedBox(height: 4),
        ],
        if (showVault) ...[
          GameButton(
            label: 'CLAIM VAULT  +${vaultClaimEssence}e',
            style: GameButtonStyle.brown,
            primary: true,
            onPressed: onClaimDailyVault,
          ),
          const SizedBox(height: 4),
        ] else if (showVaultProgress) ...[
          Text(
            'Daily Vault · $weeklyProgress/${GameLogic.dailyVaultClearTarget}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
        ],
        if (showMissions || showDaily)
          Row(
            children: [
              if (showMissions) ...[
                Expanded(
                  child: GameButton(
                    label: claimable == 1
                        ? 'CLAIM QUESTS'
                        : 'CLAIM QUESTS ($claimable)',
                    style: showVault
                        ? GameButtonStyle.grey
                        : GameButtonStyle.brown,
                    onPressed: onContracts,
                  ),
                ),
                if (showDaily) const SizedBox(width: 6),
              ],
              if (showDaily)
                Expanded(
                  child: GameButton(
                    label: dailyClaimed ? 'DAILY RUN · done' : 'DAILY RUN',
                    style: GameButtonStyle.grey,
                    onPressed: dailyClaimed ? null : onDaily,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
