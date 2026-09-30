import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'power_upgrade_row.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({super.key, required this.director});
  final GameDirector director;

  /// GOLD footer. ESSENCE waits until that tab exists.
  static String resetHint({required bool plain, required bool showCamp}) {
    if (plain) {
      return 'Run gold power resets when you start over. Buy the row tagged BEST when unsure.';
    }
    if (showCamp) {
      return 'GOLD → FORGE + bag gold wipe on Ascend. Blessing KEEP stays on ESSENCE.';
    }
    return 'GOLD → FORGE + bag gold wipe on Ascend. Blessing KEEP stays.';
  }

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
    PartyUpgradeType.mastery => GameTheme.tooltipEpic,
  };

  String _forgeName(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => 'ATK',
    PartyUpgradeType.defense => 'DEF',
    PartyUpgradeType.vitality => 'STA',
    PartyUpgradeType.moveSpeed => 'MOVE',
    PartyUpgradeType.attackSpeed => 'HASTE',
    PartyUpgradeType.crit => 'CRIT',
    PartyUpgradeType.mastery => 'MASTERY',
  };

  String _forgeBonus(GameState state, PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => '+${state.attackBonus}',
    PartyUpgradeType.defense => '+${state.defenseBonus}',
    PartyUpgradeType.vitality => '+${state.vitalityBonus}',
    PartyUpgradeType.moveSpeed =>
      '+${GameState.softForgePercent(state.moveSpeedBonus).round()}%'
      '${state.moveSpeedBonus >= 40 ? ' · cap' : ''}',
    PartyUpgradeType.attackSpeed =>
      '+${GameState.softForgePercent(state.attackSpeedBonus).round()}%'
      '${state.attackSpeedBonus >= 40 ? ' · cap' : ''}',
    PartyUpgradeType.crit =>
      '+${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%'
      '${state.critBonus >= 25 ? ' · cap' : ''}',
    PartyUpgradeType.mastery => '+${state.masteryBonus}',
  };

  Widget _upgradeRow({
    required GameState state,
    required PartyUpgradeType type,
    required VoidCallback? onPressed,
  }) {
    final recommended = GameLogic.recommendedForgeUpgrade(state) == type.index;
    final cost = GameLogic.upgradeCostFor(state, type);
    final preview = GameLogic.previewForgeGoldSpend(state, type, _spendMode);
    final nextDelta = _nextRankDelta(state, type);
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
      subtitle: '${_forgeBonus(state, type)}${nextDelta == null ? '' : ' · $nextDelta'}',
      selected: recommended,
      dense: true,
      trailing: GameButton(
        label: buyLabel,
        tip: recommended ? 'Recommended BEST track for your gold' : null,
        expanded: false,
        dense: true,
        onPressed: onPressed,
      ),
    );
  }

  String? _nextRankDelta(GameState state, PartyUpgradeType type) {
    if (!GameLogic.canForgeGoldSpend(state, type, ForgeGoldSpendMode.one)) {
      return null;
    }
    return switch (type) {
      PartyUpgradeType.attack =>
        '+${GameLogic.forgeAttackGain} ATK next',
      PartyUpgradeType.defense =>
        '+${GameLogic.forgeDefenseGain} DEF next',
      PartyUpgradeType.vitality =>
        '+${GameLogic.forgeVitalityGain} STA next',
      PartyUpgradeType.moveSpeed => '+5% MOVE next',
      PartyUpgradeType.attackSpeed => '+5% HASTE next',
      PartyUpgradeType.crit => '+5% CRIT next',
      PartyUpgradeType.mastery => '+1 MASTERY next',
    };
  }

  @override
  Widget build(BuildContext context) {
    final plain = GameLogic.plainPlayerChrome(director.state);
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
        Expanded(
          child: SingleChildScrollView(
            child: _classicForgeBody(plain: plain, pinSpendAll: false),
          ),
        ),
        if (canBuyAny)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GameButton(
              label: GameLogic.canForgeGoldSpendEven(state)
                  ? 'SPEND ALL · EVEN'
                  : 'SPEND ALL · EVEN · Need gold',
              tip: 'Splits wallet gold round-robin across every track',
              style: GameButtonStyle.grey,
              dense: true,
              onPressed: GameLogic.canForgeGoldSpendEven(state)
                  ? () {
                      director.upgradeSpendAllEvenly();
                      setState(() {});
                    }
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _classicForgeBody({required bool plain, required bool pinSpendAll}) {
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
                  'CRIT +${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%  '
                  'MASTERY +${state.masteryBonus}',
          maxLines: 3,
          overflow: TextOverflow.visible,
          softWrap: true,
          style: GameTheme.body(size: 12, color: GameTheme.parchment),
        ),
        Text(
          ForgeOverlay.resetHint(
            plain: plain,
            showCamp: MenuTabs.showCamp(state),
          ),
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        if (canBuyAny) ...[
          MenuChrome.segmented(
            dense: true,
            labels: const ['×1', 'Bulk'],
            selectedIndex: _spendMode == ForgeGoldSpendMode.one ? 0 : 1,
            onSelect: (i) {
              if (i == 0) {
                setState(() => _spendMode = ForgeGoldSpendMode.one);
                return;
              }
              // Bulk sheet: pick a wallet slice (#43).
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: GameTheme.ink,
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bulk spend',
                          style: GameTheme.menuTitle(size: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Spend that slice of your wallet on one GOLD track.',
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final mode in [
                          ForgeGoldSpendMode.pct5,
                          ForgeGoldSpendMode.pct25,
                          ForgeGoldSpendMode.pct50,
                          ForgeGoldSpendMode.pct100,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GameButton(
                              label: mode.chipLabel,
                              style: _spendMode == mode
                                  ? GameButtonStyle.brown
                                  : GameButtonStyle.grey,
                              onPressed: () {
                                setState(() => _spendMode = mode);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            _spendMode == ForgeGoldSpendMode.one
                ? '×1 = one buy · Bulk opens wallet slices'
                : 'Bulk ${_spendMode.chipLabel} on each tap',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
        ] else ...[
          Text(
            state.gold <= 0
                ? 'Earn gold in the dungeon, then come back here to buy.'
                : 'Need a bit more gold for the next buy — keep clearing floors.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 4),
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
        if (canBuyAny && pinSpendAll) ...[
          const SizedBox(height: 2),
          GameButton(
            label: GameLogic.canForgeGoldSpendEven(state)
                ? 'SPEND ALL · EVEN'
                : 'SPEND ALL · EVEN · Need gold',
            style: GameButtonStyle.grey,
            dense: true,
            onPressed: GameLogic.canForgeGoldSpendEven(state)
                ? () {
                    director.upgradeSpendAllEvenly();
                    setState(() {});
                  }
                : null,
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
