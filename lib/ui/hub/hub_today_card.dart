import 'package:flutter/material.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/hub_chase.dart';
import '../../core/local_season.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';

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

  @override
  Widget build(BuildContext context) {
    if (!GameLogic.showDailyChase(state)) {
      return const SizedBox(height: 4);
    }
    // READY / ALMOST already owns the strip — skip competing KEY/vault crumbs.
    if (chaseUrgency == HubChaseUrgency.ready ||
        chaseUrgency == HubChaseUrgency.almost) {
      return const SizedBox(height: 4);
    }
    final bits = <String>[];
    final showKey = GameLogic.showKeystoneJargon(state);
    if (showKey &&
        chaseKind != HubChaseKind.keystone &&
        chaseKind != HubChaseKind.dailyVaultProgress &&
        chaseKind != HubChaseKind.claimDailyVault) {
      bits.add(
        state.hardmodeLevel <= 0 ? 'KEY off' : 'KEY +${state.hardmodeLevel}',
      );
    }

    if (chaseKind != HubChaseKind.claimDailyVault &&
        chaseKind != HubChaseKind.dailyVaultProgress) {
      final clears = state.metaDepth.dailyVaultClears;
      final target = GameLogic.dailyVaultClearTarget;
      if (GameLogic.canClaimDailyVault(state)) {
        bits.add('Vault READY');
      } else {
        bits.add('Vault $clears/$target');
      }
    }

    if (chaseKind != HubChaseKind.weekGoal) {
      final weekKey = state.metaDepth.weeklyKey.isNotEmpty
          ? state.metaDepth.weeklyKey
          : GameLogic.isoWeekKey(DateTime.now().toUtc());
      final week = LocalSeasonCatalog.forWeekKey(weekKey);
      if (week.hasGoal) {
        if (LocalSeasonCatalog.weekGoalReady(state, week)) {
          bits.add('Week READY');
        } else if (!LocalSeasonCatalog.weekGoalClaimed(state, week)) {
          bits.add(LocalSeasonCatalog.weekProgressLabel(state, week));
        }
      }
    }

    if (bits.isEmpty) return const SizedBox(height: 4);

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
    this.actionLabel,
    this.onAction,
  });

  final HubChase chase;
  final bool compact;
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
    // Text strip only — no fill box under ENTER.
    return Semantics(
      label: 'TODAY chase: ${chase.title}. ${chase.detail}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            KenneySprite(asset: KenneyAssets.iconStar, size: 14),
            const SizedBox(width: 6),
            Text('TODAY', style: GameTheme.body(size: 12, color: accent)),
            if (chip != null) ...[
              const SizedBox(width: 6),
              Text(chip, style: GameTheme.body(size: 12, color: accent)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chase.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(size: 13, color: GameTheme.parchment),
              ),
            ),
            if (chase.progressLabel != null) ...[
              const SizedBox(width: 6),
              // Flexible so a 360 px phone keeps title + CTA on one line.
              Flexible(
                child: Text(
                  chase.progressLabel!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 12,
                    color: ready || almost ? accent : GameTheme.mossLit,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              KenneyButton(
                label: actionLabel!,
                style: KenneyButtonStyle.grey,
                expanded: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
    required this.showGauntlet,
    required this.gauntletBest,
    required this.onGauntlet,
    required this.showAshenCrown,
    required this.ashenCrownTickets,
    required this.onAshenCrown,
    this.onAshenCrownPractice,
    required this.showRift,
    required this.riftBest,
    required this.onRift,
    required this.showGreaterRift,
    required this.grBest,
    required this.onGreaterRift,
    required this.weeklyReady,
    required this.weeklyProgress,
    required this.weeklyClaimed,
    required this.weeklyBestTimedKey,
    required this.vaultClaimEssence,
    required this.onClaimDailyVault,
    this.hideAscend = false,
    this.hideVaultClaim = false,
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
  final bool showGauntlet;
  final int gauntletBest;
  final VoidCallback onGauntlet;
  final bool showAshenCrown;
  final int ashenCrownTickets;
  final VoidCallback onAshenCrown;
  final VoidCallback? onAshenCrownPractice;
  final bool showRift;
  final int riftBest;
  final VoidCallback onRift;
  final bool showGreaterRift;
  final int grBest;
  final VoidCallback onGreaterRift;
  final bool weeklyReady;
  final int weeklyProgress;
  final bool weeklyClaimed;
  final int weeklyBestTimedKey;
  final int vaultClaimEssence;
  final VoidCallback onClaimDailyVault;
  final bool hideAscend;
  final bool hideVaultClaim;
  final bool hideMissionClaim;
  final bool hideDaily;

  @override
  Widget build(BuildContext context) {
    final showVaultProgress =
        !weeklyClaimed &&
        weeklyProgress > 0 &&
        weeklyProgress < GameLogic.dailyVaultClearTarget &&
        weeklyBestTimedKey < 2;
    final showAscend = canAscend && ascendLabel != null && !hideAscend;
    final showVault = weeklyReady && !hideVaultClaim;
    final showMissions = claimable > 0 && !hideMissionClaim;
    final showDaily = !hideDaily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAscend) ...[
          KenneyButton(
            label: ascendLabel!,
            style: KenneyButtonStyle.red,
            primary: true,
            onPressed: onAscend,
          ),
          const SizedBox(height: 4),
        ],
        if (showVault) ...[
          KenneyButton(
            label:
                'CLAIM VAULT  +${vaultClaimEssence}e',
            style: KenneyButtonStyle.brown,
            primary: true,
            onPressed: onClaimDailyVault,
          ),
          const SizedBox(height: 4),
        ] else if (showVaultProgress) ...[
          Text(
            'Daily vault · $weeklyProgress/${GameLogic.dailyVaultClearTarget}',
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
                  child: KenneyButton(
                    label: 'CLAIM ($claimable)',
                    style: showVault
                        ? KenneyButtonStyle.grey
                        : KenneyButtonStyle.brown,
                    onPressed: onContracts,
                  ),
                ),
                if (showDaily) const SizedBox(width: 6),
              ],
              if (showDaily)
                Expanded(
                  child: KenneyButton(
                    label: dailyClaimed ? 'DAILY · done' : 'DAILY RUN',
                    style: KenneyButtonStyle.grey,
                    onPressed: dailyClaimed ? null : onDaily,
                  ),
                ),
            ],
          ),
        if (showGauntlet) ...[
          const SizedBox(height: 6),
          KenneyButton(
            label: gauntletBest > 0
                ? 'GAUNTLET  ·  best F$gauntletBest'
                : 'INFINITY GAUNTLET',
            style: KenneyButtonStyle.red,
            onPressed: onGauntlet,
          ),
        ],
        if (showAshenCrown) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: KenneyButton(
                  label: 'ASHEN CROWN  ·  $ashenCrownTickets tix',
                  style: KenneyButtonStyle.brown,
                  onPressed: onAshenCrown,
                ),
              ),
              if (onAshenCrownPractice != null) ...[
                const SizedBox(width: 6),
                KenneyButton(
                  label: 'PRACTICE',
                  style: KenneyButtonStyle.grey,
                  expanded: false,
                  onPressed: onAshenCrownPractice,
                ),
              ],
            ],
          ),
        ],
        if (showRift) ...[
          const SizedBox(height: 6),
          KenneyButton(
            label: riftBest > 0
                ? 'RIFT  ·  best R$riftBest'
                : 'RIFT',
            style: KenneyButtonStyle.brown,
            onPressed: onRift,
          ),
        ],
        if (showGreaterRift) ...[
          const SizedBox(height: 6),
          KenneyButton(
            label: grBest > 0
                ? 'GREATER  ·  best GR$grBest'
                : 'GREATER RIFT',
            style: KenneyButtonStyle.red,
            onPressed: onGreaterRift,
          ),
        ],
      ],
    );
  }
}
