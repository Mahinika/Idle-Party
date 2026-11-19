import 'package:flutter/material.dart';

import '../../core/blessing_constellation.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/god_hand_mastery.dart';
import '../../core/menu_alerts.dart';
import '../confirm_dialogs.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../meta/prestige_shop.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

String _blessingLine(GameState state) {
  final next = 'Next Ascend adds ${ascendBlessingStackPhrase()}.';
  final capped = GameLogic.isMaxAscension(state);
  if (state.metaDepth.ascendBlessings <= 0) {
    return capped
        ? 'Ascend Blessing: none yet.'
        : 'Ascend Blessing: none yet. $next';
  }
  final now =
      'Ascend Blessing ×${state.metaDepth.ascendBlessings}: '
      '+${state.ascendBlessingAttackBonus} AP · '
      '+${state.ascendBlessingDefenseBonus} Armor · '
      '+${state.ascendBlessingVitalityBonus} STA · '
      '+${state.ascendBlessingGoldPercent}% gold.';
  return capped ? now : '$now $next';
}

/// Forever essence spends — God Hand, Blessing, permanent buys, REBORN.
class EssenceKeepPanel extends StatelessWidget {
  /// God Hand smash modes: (style id, label, what it does).
  static const godHandStyles = <(int, String, String)>[
    (0, 'BAL', 'Balanced smash'),
    (1, 'FOCUS', 'Smaller + stronger (~+22% dmg · −18% radius)'),
    (2, 'WIDE', 'Wider + weaker (~−12% dmg · +22% radius)'),
  ];

  const EssenceKeepPanel({super.key, required this.director});

  static const String introLine =
      'God Hand upgrades and lasting buys.';
  static const String aboutTitle = 'About Blessing';
  static const Key blessingLineKey = ValueKey('keep-blessing-line');
  static Key masteryGoalKey(String id) => ValueKey('keep-mastery-$id');

  /// What a God Hand milestone needs, with progress.
  static String masteryNeed(GameState state, String id) => switch (id) {
    'gh_dmg_5' => 'Needs Damage Lv5 · ${GodHandMastery.progressLabel(state, id)}',
    'gh_cd_4' => 'Needs CD Lv4 · ${GodHandMastery.progressLabel(state, id)}',
    'gh_smash_100' =>
      'Smash ${GodHandMastery.smashMilestone} times · ${GodHandMastery.progressLabel(state, id)}',
    _ => GodHandMastery.progressLabel(state, id),
  };

  final GameDirector director;

  Widget _label(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: GameTheme.hint(color: GameTheme.torchHot),
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

    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatCount(state.essence)} essence · keeps on Ascend',
          style: GameTheme.readable(color: GameTheme.torchHot),
        ),
        ShellLayout.gap(4),
        // One short line, then the God Hand buttons; the rest folds
        // (audit F096). Rule text wraps instead of cutting (F040).
        ShellLayout.hint(EssenceKeepPanel.introLine, maxLines: 3),
        MenuChrome.fold(
          title: EssenceKeepPanel.aboutTitle,
          children: [
            Text(
              _blessingLine(state),
              key: EssenceKeepPanel.blessingLineKey,
              style: GameTheme.hint(color: GameTheme.mossLit),
            ),
            ShellLayout.hint(
              'CAMP, Relics, and Pets are on the other ESSENCE tiles.',
              maxLines: 4,
            ),
            if (GameLogic.canAscend(state))
              Text(
                GameLogic.endgameUnlocked(state)
                    ? 'Ascend is optional — today\'s job is KEY / ENDGAME. '
                          'The hub button says ASCEND — not a buy here.'
                    : 'The hub button says ASCEND — not a buy here.',
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
          ],
        ),

        _label('GOD HAND'),
        Text(
          'Lv${state.godHandLevel} · smash ${state.godHandSmashDamage()} · '
          'CD ${state.godHandCooldownSeconds.toStringAsFixed(1)}s',
          style: GameTheme.section(color: GameTheme.parchment),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'Damage · ${formatCount(dmgCost)}',
                icon: UiIcon.essence,
                style: GameButtonStyle.essence,
                tip: state.essence >= dmgCost
                    ? null
                    : 'Need ${formatCount(dmgCost - state.essence)} more essence',
                dense: true,
                onPressed: state.essence >= dmgCost
                    ? director.upgradeGodHand
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GameButton(
                label: cdMaxed ? 'CD · MAX' : 'CD · ${formatCount(cdCost)}',
                icon: cdMaxed ? null : UiIcon.essence,
                style: GameButtonStyle.essence,
                tip: cdMaxed
                    ? 'Cooldown is maxed'
                    : (state.essence >= cdCost
                          ? null
                          : 'Need ${formatCount(cdCost - state.essence)} more essence'),
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
        // Picked smash mode uses the plum segmented toggle (batch 6
        // colour rule: plum = picked, brown/gold = act or buy).
        MenuChrome.segmented(
          dense: true,
          labels: [for (final e in EssenceKeepPanel.godHandStyles) e.$2],
          selectedIndex: style.clamp(0, EssenceKeepPanel.godHandStyles.length - 1),
          onSelect: (i) => director.setGodHandStyle(EssenceKeepPanel.godHandStyles[i].$1),
        ),
        ShellLayout.hint(
          EssenceKeepPanel.godHandStyles[style.clamp(0, EssenceKeepPanel.godHandStyles.length - 1)].$3,
          maxLines: 2,
        ),
        if (masteryOpen.isNotEmpty) ...[
          const SizedBox(height: 6),
          // Goals, not greyed buys: say what each needs (audit F041).
          for (final m in masteryOpen)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: GodHandMastery.ready(state, m.$1)
                  ? GameButton(
                      label:
                          'CLAIM · ${m.$2} · +12 · ${GodHandMastery.progressLabel(state, m.$1)}',
                      icon: UiIcon.essence,
                      style: GameButtonStyle.essence,
                      primary: true,
                      dense: true,
                      onPressed: () => director.claimGodHandMastery(m.$1),
                    )
                  : Container(
                      key: EssenceKeepPanel.masteryGoalKey(m.$1),
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      decoration: MenuChrome.listCard(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.$2,
                                  style: GameTheme.readable(
                                    color: GameTheme.parchment,
                                  ),
                                ),
                                Text(
                                  EssenceKeepPanel.masteryNeed(state, m.$1),
                                  style: GameTheme.hint(
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Icon + number, never an "e" suffix (P003/P055).
                          Semantics(
                            label: '+12 essence',
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+12',
                                  style: GameTheme.readable(
                                    color: GameTheme.torchHot,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                GameIcon.asset(UiIcon.essence, size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
        ],

        if (MenuTabs.showShop(state)) ...[
          _label('PERMANENT BUYS'),
          Text(
            'These stay after Ascend.',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
          PrestigeShopOverlay(director: director, compact: true),
        ],

        if (BlessingConstellation.unlocked(state)) ...[
          _label('STAR NODES'),
          Text(
            'Spend points · not the same as Ascend Blessing stacks\n'
            '${BlessingConstellation.pointsAvailable(state)} pts · '
            '${state.metaDepth.constellationNodes.length}/${BlessingConstellation.maxLit} lit',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          if (BlessingConstellation.pointsAvailable(state) > 0 &&
              state.metaDepth.constellationNodes.length <
                  BlessingConstellation.maxLit)
            Text(
              'Unspent Star points — optional forever nodes (not a hub hunt).',
              style: GameTheme.hint(color: GameTheme.mossLit),
            ),
          for (final n in BlessingConstellation.nodes)
            if (BlessingConstellation.isLit(state, n.$1))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'LIT ${n.$2} — ${BlessingConstellation.effectLabel(n.$1)}',
                  style: GameTheme.hint(color: GameTheme.mossLit),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: GameButton(
                  label:
                      'LIGHT ${n.$2} — ${BlessingConstellation.effectLabel(n.$1)} · '
                      '${n.$3} · ${n.$4} pts',
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
            label: 'UNLOCK · ${GameLogic.partySlot5EssenceCost}',
            icon: UiIcon.essence,
            style: GameButtonStyle.essence,
            dense: true,
            onPressed: state.essence >= GameLogic.partySlot5EssenceCost
                ? director.unlockPartySlot5
                : null,
          ),
        ],

        if (state.soulboundItem != null) ...[
          _label('HEIRLOOM (legacy)'),
          Text(
            'Old-save keep piece · new keep-gear is Apex under Craft',
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
          Text(
            '${state.soulboundItem!.name}'
            '${state.metaDepth.soulboundRefine > 0 ? ' · refine ${state.metaDepth.soulboundRefine} (+${state.soulboundRefineAttackBonus} AP · +${state.soulboundRefineDefenseBonus} Armor)' : ''}',
            style: GameTheme.section(color: GameTheme.mossLit),
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
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
        ],
        ShellLayout.gap(12),
      ],
    ),
    );
  }
}
