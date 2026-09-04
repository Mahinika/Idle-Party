import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/game_state.dart';
import '../../core/blessing_constellation.dart';
import '../../core/god_hand_mastery.dart';
import '../confirm_dialogs.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'power_upgrade_row.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<ForgeOverlay> {
  ForgeGoldSpendMode _spendMode = ForgeGoldSpendMode.one;

  GameDirector get director => widget.director;

  Color _forgeAccent(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => GameTheme.hudHpDamage,
    PartyUpgradeType.defense => GameTheme.rarityRare,
    PartyUpgradeType.vitality => GameTheme.mossLit,
    PartyUpgradeType.moveSpeed => GameTheme.torchHot,
    PartyUpgradeType.attackSpeed => GameTheme.torch,
    PartyUpgradeType.crit => GameTheme.bloodLit,
  };

  String _forgeName(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => 'ATK',
    PartyUpgradeType.defense => 'DEF',
    PartyUpgradeType.vitality => 'STA',
    PartyUpgradeType.moveSpeed => 'MOVE',
    PartyUpgradeType.attackSpeed => 'HASTE',
    PartyUpgradeType.crit => 'CRIT',
  };

  String _forgeBonus(GameState state, PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => '+${state.attackBonus}',
    PartyUpgradeType.defense => '+${state.defenseBonus}',
    PartyUpgradeType.vitality => '+${state.vitalityBonus}',
    PartyUpgradeType.moveSpeed =>
      '+${GameState.softForgePercent(state.moveSpeedBonus).round()}%',
    PartyUpgradeType.attackSpeed =>
      '+${GameState.softForgePercent(state.attackSpeedBonus).round()}%',
    PartyUpgradeType.crit =>
      '+${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%',
  };

  Widget _upgradeRow({
    required GameState state,
    required PartyUpgradeType type,
    required VoidCallback? onPressed,
  }) {
    final recommended = GameLogic.recommendedForgeUpgrade(state) == type.index;
    final cost = GameLogic.upgradeCostFor(state, type);
    final preview = GameLogic.previewForgeGoldSpend(state, type, _spendMode);
    final String buyLabel;
    if (onPressed == null) {
      buyLabel = '${cost}g';
    } else if (_spendMode == ForgeGoldSpendMode.one) {
      buyLabel = '${cost}g';
    } else {
      buyLabel = '${preview.buys}× · ${preview.spent}g';
    }
    return PowerUpgradeRow(
      accent: _forgeAccent(type),
      title: _forgeName(type),
      tag: recommended ? 'BEST' : null,
      subtitle: _forgeBonus(state, type),
      selected: recommended,
      trailing: KenneyButton(
        label: buyLabel,
        expanded: false,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plain = GameLogic.plainPlayerChrome(director.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _classicForgeBody(plain: plain),
                if (!plain) ...[
                  const SizedBox(height: 12),
                  Text(
                    'KEEP',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: GameTheme.torchHot,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _metaForgeBody(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _classicForgeBody({required bool plain}) {
    final state = director.state;
    final canBuyAny = !(plain &&
        state.gold <
            GameLogic.upgradeCostFor(
              state,
              PartyUpgradeType.values[
                  GameLogic.recommendedForgeUpgrade(state)],
            ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plain
              ? 'Bought: ATK +${state.attackBonus} · DEF +${state.defenseBonus} · '
                  'STA +${state.vitalityBonus}'
              : 'Bought: ATK +${state.attackBonus}  DEF +${state.defenseBonus}  '
                  'STA +${state.vitalityBonus}  '
                  'MOVE +${GameState.softForgePercent(state.moveSpeedBonus).round()}%  '
                  'HASTE +${GameState.softForgePercent(state.attackSpeedBonus).round()}%  '
                  'CRIT +${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%',
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          plain
              ? 'Resets when you start over. Tap BEST when unsure.'
              : 'Wallet gold · resets on Ascend.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        if (canBuyAny) ...[
          MenuChrome.segmented(
            labels: [
              for (final mode in ForgeGoldSpendMode.values) mode.chipLabel,
            ],
            selectedIndex: _spendMode.index,
            onSelect: (i) => setState(
              () => _spendMode = ForgeGoldSpendMode.values[i],
            ),
          ),
          const SizedBox(height: 6),
        ] else ...[
          Text(
            state.gold <= 0
                ? 'Earn gold in the dungeon, then come back here to buy.'
                : 'Need a bit more gold for the next buy — keep clearing floors.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
        ],
        for (final type in PartyUpgradeType.values)
          _upgradeRow(
            state: state,
            type: type,
            onPressed: GameLogic.canForgeGoldSpend(state, type, _spendMode)
                ? () {
                    director.upgradePartyTrack(type, mode: _spendMode);
                    setState(() {});
                  }
                : null,
          ),
        if (canBuyAny) ...[
          const SizedBox(height: 4),
          KenneyButton(
            label: GameLogic.canForgeGoldSpendEven(state)
                ? 'SPEND ALL · EVEN'
                : 'SPEND ALL · EVEN · Need gold',
            style: KenneyButtonStyle.grey,
            onPressed: GameLogic.canForgeGoldSpendEven(state)
                ? () {
                    director.upgradeSpendAllEvenly();
                    setState(() {});
                  }
                : null,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _metaForgeBody() {
    final state = director.state;
    final cdMaxed = state.metaDepth.godHandCdLevel >= 8;
    final cdLabel = cdMaxed
        ? 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · MAX'
        : 'Cooldown ${state.godHandCooldownSeconds.toStringAsFixed(2)}s · '
              '${GameLogic.godHandCdUpgradeCost(state.metaDepth.godHandCdLevel)}e';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keep forever — essence spends survive Ascend. '
          'Relics are on the Relics tab. Gold buys are at the top of this page.',
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
              child: KenneyButton(
                label:
                    '${BlessingConstellation.isLit(state, n.$1) ? 'LIT' : 'LIGHT'} '
                    '${n.$2} — ${n.$3} · ${n.$4} pts',
                style: BlessingConstellation.isLit(state, n.$1)
                    ? KenneyButtonStyle.red
                    : KenneyButtonStyle.grey,
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
        const SizedBox(height: 6),
        KenneyButton(
          label:
              'Damage Lv${state.godHandLevel} · '
              '${GameLogic.godHandUpgradeCost(state.godHandLevel)}e',
          onPressed:
              state.essence >= GameLogic.godHandUpgradeCost(state.godHandLevel)
              ? director.upgradeGodHand
              : null,
        ),
        const SizedBox(height: 6),
        KenneyButton(
          label: cdLabel,
          onPressed: cdMaxed
              ? null
              : (state.essence >=
                        GameLogic.godHandCdUpgradeCost(
                          state.metaDepth.godHandCdLevel,
                        )
                    ? director.upgradeGodHandCd
                    : null),
        ),
        const SizedBox(height: 8),
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
                child: KenneyButton(
                  label: state.metaDepth.godHandStyle == entry.$1
                      ? '${entry.$2} ✓'
                      : entry.$2,
                  style: state.metaDepth.godHandStyle == entry.$1
                      ? KenneyButtonStyle.brown
                      : KenneyButtonStyle.grey,
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
            child: KenneyButton(
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
              style: KenneyButtonStyle.grey,
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
          KenneyButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  '
                'AL${GameLogic.partySlot5MinAscension}+',
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
          KenneyButton(
            label: 'REBORN',
            style: KenneyButtonStyle.grey,
            expanded: false,
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
