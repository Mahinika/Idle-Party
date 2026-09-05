import 'package:flutter/material.dart';

import '../../core/blessing_constellation.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/god_hand_mastery.dart';
import '../../core/menu_alerts.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../meta/prestige_shop.dart';

/// Forever essence spends — God Hand, Blessing, permanent buys, REBORN.
class EssenceKeepPanel extends StatelessWidget {
  const EssenceKeepPanel({super.key, required this.director});

  final GameDirector director;

  Widget _label(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: GameTheme.body(size: 12, color: GameTheme.torchHot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final cdMaxed = state.metaDepth.godHandCdLevel >= 8;
    final cdCost = GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel);
    final dmgCost = GameLogic.godHandUpgradeCost(state.godHandLevel);
    final style = state.metaDepth.godHandStyle;

    final masteryOpen = GodHandMastery.milestones
        .where((m) => !state.metaDepth.claimedGodHandMastery.contains(m.$1))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.essence}e · keeps on Ascend',
          style: GameTheme.body(size: 15, color: GameTheme.torchHot),
        ),
        Text(
          state.metaDepth.ascendBlessings <= 0
              ? 'Blessing: none yet (each Ascend stacks power + gold)'
              : 'Blessing ×${state.metaDepth.ascendBlessings}: '
                    '+${state.ascendBlessingAttackBonus} ATK · '
                    '+${state.ascendBlessingDefenseBonus} DEF · '
                    '+${state.ascendBlessingVitalityBonus} STA · '
                    '+${state.ascendBlessingGoldPercent}% gold',
          style: GameTheme.body(size: 12, color: GameTheme.mossLit),
        ),
        if (GameLogic.canAscend(state))
          Text(
            'Ascend is on the hub TODAY card — not a buy here.',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),

        _label('GOD HAND'),
        Text(
          'Lv${state.godHandLevel} · smash ${state.godHandSmashDamage()} · '
          'CD ${state.godHandCooldownSeconds.toStringAsFixed(1)}s',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'Damage · ${dmgCost}e',
                dense: true,
                onPressed: state.essence >= dmgCost
                    ? director.upgradeGodHand
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GameButton(
                label: cdMaxed ? 'CD · MAX' : 'CD · ${cdCost}e',
                dense: true,
                onPressed: cdMaxed
                    ? null
                    : (state.essence >= cdCost
                          ? director.upgradeGodHandCd
                          : null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final entry in <(int, String)>[
              (0, 'BAL'),
              (1, 'FOCUS'),
              (2, 'WIDE'),
            ]) ...[
              if (entry.$1 > 0) const SizedBox(width: 6),
              Expanded(
                child: GameButton(
                  label: entry.$2,
                  dense: true,
                  style: style == entry.$1
                      ? GameButtonStyle.brown
                      : GameButtonStyle.grey,
                  onPressed: () => director.setGodHandStyle(entry.$1),
                ),
              ),
            ],
          ],
        ),
        if (masteryOpen.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final m in masteryOpen)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: GameButton(
                label: GodHandMastery.ready(state, m.$1)
                    ? 'CLAIM · ${m.$2} · ${GodHandMastery.progressLabel(state, m.$1)}'
                    : '${m.$2} · ${GodHandMastery.progressLabel(state, m.$1)}',
                style: GameButtonStyle.grey,
                dense: true,
                onPressed: GodHandMastery.ready(state, m.$1)
                    ? () => director.claimGodHandMastery(m.$1)
                    : null,
              ),
            ),
        ],

        if (MenuTabs.showShop(state)) ...[
          _label('PERMANENT BUYS'),
          Text(
            'AL-gated QoL · not the bottom-tab SHOP',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          PrestigeShopOverlay(director: director, compact: true),
        ],

        if (BlessingConstellation.unlocked(state)) ...[
          _label('CONSTELLATION'),
          Text(
            '${BlessingConstellation.pointsAvailable(state)} pts · '
            '${state.metaDepth.constellationNodes.length}/${BlessingConstellation.maxLit} lit',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          for (final n in BlessingConstellation.nodes)
            if (!BlessingConstellation.isLit(state, n.$1))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: GameButton(
                  label: 'LIGHT ${n.$2} — ${n.$3} · ${n.$4} pts',
                  style: GameButtonStyle.grey,
                  dense: true,
                  onPressed: () => director.lightConstellationNode(n.$1),
                ),
              ),
        ],

        if (state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
            !state.metaDepth.partySlot5Unlocked) ...[
          _label('5TH SLOT'),
          GameButton(
            label: 'UNLOCK · ${GameLogic.partySlot5EssenceCost}e',
            dense: true,
            onPressed: state.essence >= GameLogic.partySlot5EssenceCost
                ? director.unlockPartySlot5
                : null,
          ),
        ],

        if (state.soulboundItem != null) ...[
          _label('HEIRLOOM'),
          Text(
            '${state.soulboundItem!.name}'
            '${state.metaDepth.soulboundRefine > 0 ? ' · refine ${state.metaDepth.soulboundRefine}' : ''}',
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ],

        if (GameLogic.canRebornAtCap(state)) ...[
          const SizedBox(height: 16),
          Divider(
            height: 12,
            color: GameTheme.bloodLit.withValues(alpha: 0.35),
          ),
          _label('REBORN (optional)'),
          GameButton(
            label: 'REBORN',
            style: GameButtonStyle.grey,
            expanded: false,
            dense: true,
            onPressed: () => confirmRebornAtCap(context, director),
          ),
          Text(
            'Empty-bag climb at AL20 — AL and Blessing stay. Not Ascend.',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
