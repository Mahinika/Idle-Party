import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
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
      dense: true,
      trailing: GameButton(
        label: buyLabel,
        expanded: false,
        dense: true,
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
            child: _classicForgeBody(plain: plain),
          ),
        ),
      ],
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
          style: GameTheme.body(size: 12, color: GameTheme.parchment),
        ),
        Text(
          plain
              ? 'Resets when you start over. Tap BEST when unsure.'
              : 'Wallet gold · resets on Ascend. God Hand & Blessing live on ESSENCE.',
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 4),
        if (canBuyAny) ...[
          MenuChrome.segmented(
            dense: true,
            labels: [
              for (final mode in ForgeGoldSpendMode.values) mode.chipLabel,
            ],
            selectedIndex: _spendMode.index,
            onSelect: (i) => setState(
              () => _spendMode = ForgeGoldSpendMode.values[i],
            ),
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
        if (canBuyAny) ...[
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
