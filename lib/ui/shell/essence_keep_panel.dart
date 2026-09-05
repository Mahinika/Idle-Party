import 'package:flutter/material.dart';

import '../../core/blessing_constellation.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/god_hand_mastery.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Essence spends that survive Ascend — Blessing, God Hand, REBORN, 5th slot.
/// Lives on the ESSENCE tab (moved off GOLD → KEEP).
class EssenceKeepPanel extends StatelessWidget {
  const EssenceKeepPanel({super.key, required this.director});

  final GameDirector director;

  Widget _sectionTitle(String title, String blurb) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuChrome.sectionLabelScoped(title),
          Text(
            blurb,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final cdMaxed = state.metaDepth.godHandCdLevel >= 8;
    final cdLabel = cdMaxed
        ? 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · MAX'
        : 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · '
              '${GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel)}e';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChrome.sectionLabelScoped('KEEP', scope: MenuScope.account),
        const SizedBox(height: 6),
        Text(
          'Keep forever — survives Ascend. Gold buys stay on GOLD.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.essence} essence',
          style: GameTheme.body(size: 15, color: GameTheme.torchHot),
        ),
        Text(
          state.metaDepth.ascendBlessings <= 0
              ? 'Ascend Blessing: none yet — each Ascend stacks '
                    '+${GameLogic.ascendBlessingAtk} ATK · '
                    '+${GameLogic.ascendBlessingDef} DEF · '
                    '+${GameLogic.ascendBlessingVit} STA · '
                    '+${GameLogic.ascendBlessingGoldPct}% gold'
              : 'Ascend Blessing ×${state.metaDepth.ascendBlessings}: '
                    '+${state.ascendBlessingAttackBonus} ATK · '
                    '+${state.ascendBlessingDefenseBonus} DEF · '
                    '+${state.ascendBlessingVitalityBonus} STA · '
                    '+${state.ascendBlessingGoldPercent}% gold',
          style: GameTheme.body(size: 13, color: GameTheme.mossLit),
        ),
        if (GameLogic.canAscend(state))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ascend is the hub ASCEND button (TODAY READY) — not a buy here.',
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
        Builder(
          builder: (_) {
            if (GameLogic.isMaxAscension(state)) {
              return const SizedBox.shrink();
            }
            final hub = GoldIncome.hubGoldPerMinute(state);
            final run = director.runGoldPerMinute;
            final oldP = GoldIncome.goldFindPercent(state);
            final newP = oldP + GameLogic.ascendBlessingGoldPct;
            final hubGain = GoldIncome.goldFindDeltaOnRate(hub, oldP, newP);
            final runGain = GoldIncome.goldFindDeltaOnRate(run, oldP, newP);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Next Blessing +${GameLogic.ascendBlessingGoldPct}% gold'
                ' · Hub +${hubGain}g/min'
                '${run > 0 ? ' · Run +${runGain}g/min' : ''}',
                style: GameTheme.body(
                  size: 12,
                  color: GameTheme.parchmentDim,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (BlessingConstellation.unlocked(state)) ...[
          _sectionTitle(
            'CONSTELLATION',
            'AL20 perk tree — light nodes with constellation points.',
          ),
          Text(
            '${BlessingConstellation.pointsAvailable(state)} pts · '
            '${state.metaDepth.constellationNodes.length}/${BlessingConstellation.maxLit} lit',
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          for (final n in BlessingConstellation.nodes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GameButton(
                label:
                    '${BlessingConstellation.isLit(state, n.$1) ? 'LIT' : 'LIGHT'} '
                    '${n.$2} — ${n.$3} · ${n.$4} pts',
                style: BlessingConstellation.isLit(state, n.$1)
                    ? GameButtonStyle.red
                    : GameButtonStyle.grey,
                dense: true,
                onPressed: BlessingConstellation.isLit(state, n.$1)
                    ? null
                    : () => director.lightConstellationNode(n.$1),
              ),
            ),
          const SizedBox(height: 8),
        ],
        _sectionTitle(
          'GOD HAND',
          'Tap in the dungeon to steer + smash. Soft knobs: damage, CD, style.',
        ),
        Text(
          'Lv${state.godHandLevel} · smash ${state.godHandSmashDamage()} · '
          'blast ${state.godHandSmashRadius.toStringAsFixed(1)} · '
          'CD ${state.godHandCooldownSeconds.toStringAsFixed(2)}s',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        const SizedBox(height: 4),
        GameButton(
          label:
              'Damage Lv${state.godHandLevel} · '
              '${GameLogic.godHandUpgradeCost(state.godHandLevel)}e',
          dense: true,
          onPressed:
              state.essence >= GameLogic.godHandUpgradeCost(state.godHandLevel)
              ? director.upgradeGodHand
              : null,
        ),
        const SizedBox(height: 4),
        GameButton(
          label: cdLabel,
          dense: true,
          onPressed: cdMaxed
              ? null
              : (state.essence >=
                        GameLogic.godHandCdUpgradeCost(
                          state.metaDepth.godHandCdLevel,
                        )
                    ? director.upgradeGodHandCd
                    : null),
        ),
        const SizedBox(height: 6),
        Text(
          'BAL · r${state.godHandRadius.toStringAsFixed(1)} · '
          'FOCUS · r${(state.godHandRadius * 0.82).toStringAsFixed(1)} (+dmg) · '
          'WIDE · r${(state.godHandRadius * 1.22).toStringAsFixed(1)} (−dmg)',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final entry in <(int, String)>[
              (0, 'BAL · r${state.godHandRadius.toStringAsFixed(1)}'),
              (
                1,
                'FOCUS · r${(state.godHandRadius * 0.82).toStringAsFixed(1)}',
              ),
              (
                2,
                'WIDE · r${(state.godHandRadius * 1.22).toStringAsFixed(1)}',
              ),
            ]) ...[
              if (entry.$1 > 0) const SizedBox(width: 6),
              Expanded(
                child: GameButton(
                  label: entry.$2,
                  dense: true,
                  style: state.metaDepth.godHandStyle == entry.$1
                      ? GameButtonStyle.brown
                      : GameButtonStyle.grey,
                  onPressed: () => director.setGodHandStyle(entry.$1),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _sectionTitle(
          'GOD HAND MASTERY',
          'Milestones from Hand level, CD upgrades, and smash count.',
        ),
        for (final m in GodHandMastery.milestones)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GameButton(
              label: () {
                final claimed =
                    state.metaDepth.claimedGodHandMastery.contains(m.$1);
                final progress = GodHandMastery.progressLabel(state, m.$1);
                if (claimed) return 'DONE · ${m.$2} · $progress';
                if (GodHandMastery.ready(state, m.$1)) {
                  return 'CLAIM · ${m.$2} · $progress';
                }
                return '${m.$2} · $progress';
              }(),
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: GodHandMastery.ready(state, m.$1)
                  ? () => director.claimGodHandMastery(m.$1)
                  : null,
            ),
          ),
        if (state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
            !state.metaDepth.partySlot5Unlocked) ...[
          const SizedBox(height: 8),
          _sectionTitle(
            '5TH SLOT',
            'Extra fighter · survives Ascend. Also on GEAR → ROSTER.',
          ),
          GameButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  '
                'AL${GameLogic.partySlot5MinAscension}+',
            dense: true,
            onPressed: state.essence >= GameLogic.partySlot5EssenceCost
                ? director.unlockPartySlot5
                : null,
          ),
        ],
        Divider(
          height: 16,
          color: GameTheme.rarityCommon.withValues(alpha: 0.4),
        ),
        if (state.soulboundItem != null) ...[
          _sectionTitle(
            'HEIRLOOM',
            'Older save. Craft gear is the keep path now — this still adds party power.',
          ),
          Text(
            '${state.soulboundItem!.name}'
            '${state.metaDepth.soulboundRefine > 0 ? ' · refine ${state.metaDepth.soulboundRefine}' : ''}',
            style: GameTheme.body(size: 14, color: GameTheme.mossLit),
          ),
        ],
        if (GameLogic.canRebornAtCap(state)) ...[
          const SizedBox(height: 20),
          Divider(
            height: 16,
            color: GameTheme.bloodLit.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 4),
          _sectionTitle(
            'REBORN (optional)',
            'Empty-bag climb at AL20 — not Ascend. Confirm before pressing.',
          ),
          GameButton(
            label: 'REBORN',
            style: GameButtonStyle.grey,
            expanded: false,
            dense: true,
            onPressed: () => confirmRebornAtCap(context, director),
          ),
          const SizedBox(height: 4),
          Text(
            'AL stays 20 — no extra Blessing. Apex stays. '
            'TODAY will not nag you to press this.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
