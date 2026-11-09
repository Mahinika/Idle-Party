import 'package:flutter/material.dart';
import '../../core/farm_intensity.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/home_layout.dart';
import '../../core/nav_copy.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
    this.expandedTrackList = false,
  });
  final GameDirector director;

  /// SPLIT home: thin panel under the fight.
  final bool inlineUnderFight;

  /// FORGE/CAMP/MARKET sheet under bounded height.
  final bool expandedTrackList;

  /// GOLD footer. ESSENCE waits until that tab exists.
  static String resetHint({required bool plain, required bool showCamp}) {
    if (plain) {
      return 'Run gold power resets when you start over. Buy the row tagged BEST when unsure.';
    }
    if (showCamp) {
      return 'Forge gold and bag gold reset when you Ascend. Blessing on Essence does not.';
    }
    return 'Forge gold and bag gold reset when you Ascend. Blessing does not.';
  }

  /// One-line sheet totals for the FORGE header (fits narrow home panel).
  static String boughtSummary(GameState state, {required bool plain}) {
    if (plain) {
      return 'Bought: AP +${state.forgeAttackSheet} · '
          'Armor +${state.forgeDefenseSheet} · '
          'STA +${state.forgeVitalitySheet}';
    }
    final move = GameState.softForgePercent(state.moveSpeedBonus).round();
    final haste = GameState.softForgePercent(state.attackSpeedBonus).round();
    final crit = GameState.softForgePercent(state.critBonus, softAt: 25).round();
    final parts = <String>[
      'AP +${state.forgeAttackSheet}',
      'Armor +${state.forgeDefenseSheet}',
      'STA +${state.forgeVitalitySheet}',
      if (move > 0) 'MOVE +$move%',
      if (haste > 0) 'HASTE +$haste%',
      if (crit > 0) 'CRIT +$crit%',
      'MASTERY +${state.forgeMasterySheet}',
    ];
    return 'Bought: ${parts.join(' · ')}';
  }

  @override
  State<ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<ForgeOverlay> {
  ForgeGoldSpendMode _spendMode = ForgeGoldSpendMode.one;

  GameDirector get director => widget.director;

  bool get _compactPrice =>
      widget.inlineUnderFight || widget.expandedTrackList;

  bool get _scrollAllTracks =>
      widget.inlineUnderFight || widget.expandedTrackList;

  Color _forgeAccent(PartyUpgradeType type) {
    if (director.state.colorblindMode) {
      return switch (type) {
        PartyUpgradeType.attack => GameTheme.parchment,
        PartyUpgradeType.defense => GameTheme.parchmentDim,
        PartyUpgradeType.vitality => GameTheme.borderLit,
        PartyUpgradeType.moveSpeed => GameTheme.stoneRaised,
        PartyUpgradeType.attackSpeed => GameTheme.ink,
        PartyUpgradeType.crit => GameTheme.panelInset,
        PartyUpgradeType.mastery => GameTheme.clear,
      };
    }
    return switch (type) {
      PartyUpgradeType.attack => GameTheme.hudHpDamage,
      PartyUpgradeType.defense => GameTheme.rarityRare,
      PartyUpgradeType.vitality => GameTheme.mossLit,
      PartyUpgradeType.moveSpeed => GameTheme.torchHot,
      PartyUpgradeType.attackSpeed => GameTheme.torch,
      PartyUpgradeType.crit => GameTheme.bloodLit,
      PartyUpgradeType.mastery => GameTheme.tooltipEpic,
    };
  }

  String _forgeName(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => 'AP',
    PartyUpgradeType.defense => 'Armor',
    PartyUpgradeType.vitality => 'STA',
    PartyUpgradeType.moveSpeed => 'MOVE',
    PartyUpgradeType.attackSpeed => 'HASTE',
    PartyUpgradeType.crit => 'CRIT',
    PartyUpgradeType.mastery => 'MASTERY',
  };

  String _forgeBonus(GameState state, PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => _flatSheet(
      state.forgeAttackSheet,
      soft: state.attackBonus >= GameLogic.forgeAttackSoftAt,
    ),
    PartyUpgradeType.defense => _flatSheet(
      state.forgeDefenseSheet,
      soft: state.defenseBonus >= GameLogic.forgeDefenseSoftAt,
    ),
    PartyUpgradeType.vitality => _flatSheet(
      state.forgeVitalitySheet,
      soft: state.vitalityBonus >= GameLogic.forgeVitalitySoftAt,
    ),
    PartyUpgradeType.moveSpeed =>
      '+${GameState.softForgePercent(state.moveSpeedBonus).round()}%'
          '${state.moveSpeedBonus >= 40 ? ' · SOFT' : ''}',
    PartyUpgradeType.attackSpeed =>
      '+${GameState.softForgePercent(state.attackSpeedBonus).round()}%'
          '${state.attackSpeedBonus >= 40 ? ' · SOFT' : ''}',
    PartyUpgradeType.crit =>
      '+${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%'
          '${state.critBonus >= 25 ? ' · SOFT' : ''}',
    PartyUpgradeType.mastery => _flatSheet(
      state.forgeMasterySheet,
      soft: state.masteryBonus >= GameLogic.forgeMasterySoftAt,
    ),
  };

  String _flatSheet(int sheet, {required bool soft}) =>
      '+$sheet${soft ? ' · SOFT' : ''}';

  static String _fmtSoftNextPct(double gain) {
    if (gain <= 0) return '+0%';
    if ((gain - gain.round()).abs() < 0.05) return '+${gain.round()}%';
    return '+${gain.toStringAsFixed(1)}%';
  }

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
      buyLabel = formatGold(cost);
    } else if (_spendMode == ForgeGoldSpendMode.one) {
      buyLabel = formatGold(cost);
    } else {
      buyLabel = '${preview.buys}× · ${formatGold(preview.spent)}';
    }
    final shortGold = cost > state.gold ? cost - state.gold : 0;
    final primaryBuy = recommended && onPressed != null;
    final trailing = _compactPrice
        ? PowerUpgradePriceChip(
            label: buyLabel,
            primary: primaryBuy,
            onPressed: onPressed,
          )
        : GameButton(
            label: buyLabel,
            tip: onPressed == null && shortGold > 0
                ? 'Need ${formatGold(shortGold)} more'
                : recommended
                ? 'BEST = cheapest track that still lifts party power'
                : _softTip(state, type),
            style: primaryBuy ? GameButtonStyle.brown : GameButtonStyle.grey,
            primary: primaryBuy,
            expanded: false,
            dense: true,
            onPressed: onPressed,
          );
    return PowerUpgradeRow(
      accent: _forgeAccent(type),
      title: _forgeName(type),
      tag: recommended ? 'BEST' : null,
      subtitle: onPressed == null && shortGold > 0
          ? 'Need ${formatGold(shortGold)} more'
          : '${_forgeBonus(state, type)}${nextDelta == null ? '' : ' · $nextDelta'}',
      selected: recommended,
      dense: true,
      trailing: trailing,
    );
  }

  void _openBulkSpendSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(ctx).bottom,
        ),
        child: Material(
          color: GameTheme.sheet,
          borderRadius: MenuChrome.sheetRadius,
          child: Padding(
            padding: ShellLayout.sheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bulk spend', style: GameTheme.section()),
                ShellLayout.gap(4),
                ShellLayout.hint(
                  'Spend that slice of your wallet on one GOLD track.',
                  maxLines: 2,
                ),
                ShellLayout.gap(8),
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
                      primary: _spendMode == mode,
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
      ),
    );
  }

  Widget _spendModeSegmented({required bool dense}) {
    if (_compactPrice) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          MenuChrome.chip(
            label: '×1',
            selected: _spendMode == ForgeGoldSpendMode.one,
            onTap: () => setState(() => _spendMode = ForgeGoldSpendMode.one),
          ),
          MenuChrome.chip(
            label: 'Bulk',
            selected: _spendMode != ForgeGoldSpendMode.one,
            onTap: _openBulkSpendSheet,
          ),
        ],
      );
    }
    return MenuChrome.segmented(
      dense: dense,
      labels: const ['×1', 'Bulk'],
      selectedIndex: _spendMode == ForgeGoldSpendMode.one ? 0 : 1,
      onSelect: (i) {
        if (i == 0) {
          setState(() => _spendMode = ForgeGoldSpendMode.one);
          return;
        }
        _openBulkSpendSheet();
      },
    );
  }

  Widget _spendAllButton(GameState state) {
    return GameButton(
      label: GameLogic.canForgeGoldSpendEven(state)
          ? 'SPEND ALL · EVEN'
          : 'SPEND ALL · EVEN · Need gold',
      tip:
          'Splits wallet gold round-robin across every track. '
          'AP, Armor, STA, and MASTERY soften past 40 buys. '
          'MOVE and HASTE soften past 40. CRIT softens past 25.',
      style: GameButtonStyle.grey,
      dense: true,
      onPressed: GameLogic.canForgeGoldSpendEven(state)
          ? () {
              director.upgradeSpendAllEvenly();
              setState(() {});
            }
          : null,
    );
  }

  String? _softTip(GameState state, PartyUpgradeType type) {
    return switch (type) {
      PartyUpgradeType.attack
          when state.attackBonus >= GameLogic.forgeAttackSoftAt =>
        'AP soft-caps past ${GameLogic.forgeAttackSoftAt.round()} — each buy adds less',
      PartyUpgradeType.defense
          when state.defenseBonus >= GameLogic.forgeDefenseSoftAt =>
        'Armor soft-caps past ${GameLogic.forgeDefenseSoftAt.round()} — each buy adds less',
      PartyUpgradeType.vitality
          when state.vitalityBonus >= GameLogic.forgeVitalitySoftAt =>
        'STA soft-caps past ${GameLogic.forgeVitalitySoftAt.round()} — each buy adds less',
      PartyUpgradeType.crit when state.critBonus >= 25 =>
        'CRIT soft-caps past 25 — each buy adds less sheet %',
      PartyUpgradeType.mastery
          when state.masteryBonus >= GameLogic.forgeMasterySoftAt =>
        'MASTERY soft-caps past ${GameLogic.forgeMasterySoftAt.round()} — each buy adds less',
      _ => null,
    };
  }

  String _fmtSoftNextFlat(double gain, String stat) {
    if (gain <= 0) return '+0 $stat next';
    if ((gain - gain.round()).abs() < 0.05) {
      return '+${gain.round()} $stat next';
    }
    return '+${gain.toStringAsFixed(1)} $stat next';
  }

  String? _nextRankDelta(GameState state, PartyUpgradeType type) {
    if (!GameLogic.canForgeGoldSpend(state, type, ForgeGoldSpendMode.one)) {
      return null;
    }
    return switch (type) {
      PartyUpgradeType.attack => _fmtSoftNextFlat(
        GameState.softForgeNextGain(
          state.attackBonus,
          GameLogic.forgeAttackGain,
          softAt: GameLogic.forgeAttackSoftAt,
        ),
        'AP',
      ),
      PartyUpgradeType.defense => _fmtSoftNextFlat(
        GameState.softForgeNextGain(
          state.defenseBonus,
          GameLogic.forgeDefenseGain,
          softAt: GameLogic.forgeDefenseSoftAt,
        ),
        'Armor',
      ),
      PartyUpgradeType.vitality => _fmtSoftNextFlat(
        GameState.softForgeNextGain(
          state.vitalityBonus,
          GameLogic.forgeVitalityGain,
          softAt: GameLogic.forgeVitalitySoftAt,
        ),
        'STA',
      ),
      PartyUpgradeType.moveSpeed =>
        '${_fmtSoftNextPct(GameState.softForgeNextGain(state.moveSpeedBonus, GameLogic.forgeMoveGain))} MOVE next',
      PartyUpgradeType.attackSpeed =>
        '${_fmtSoftNextPct(GameState.softForgeNextGain(state.attackSpeedBonus, GameLogic.forgeHasteGain))} HASTE next',
      PartyUpgradeType.crit =>
        '${_fmtSoftNextPct(GameState.softForgeNextGain(state.critBonus, GameLogic.forgeCritGain, softAt: 25))} CRIT next',
      PartyUpgradeType.mastery => _fmtSoftNextFlat(
        GameState.softForgeNextGain(
          state.masteryBonus,
          GameLogic.forgeMasteryGain,
          softAt: GameLogic.forgeMasterySoftAt,
        ),
        'MASTERY',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final plain = GameLogic.plainPlayerChrome(director.state);
    final state = director.state;
    final canBuyAny =
        !(plain &&
            state.gold <
                GameLogic.upgradeCostFor(
                  state,
                  PartyUpgradeType.values[GameLogic.recommendedForgeUpgrade(
                    state,
                  )],
                ));
    final body = _scrollAllTracks
        ? _inlineUnderFightBody(plain: plain, canBuyAny: canBuyAny)
        : Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: _classicForgeBody(plain: plain, pinSpendAll: false),
          ),
        ),
        if (canBuyAny)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: _spendAllButton(state),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _farmIntensityRow(state),
        Expanded(child: body),
      ],
    );
  }

  Widget _farmIntensityRow(GameState state) {
    if (!FarmIntensity.applies(state)) return const SizedBox.shrink();
    final current = FarmIntensity.effectiveMult(state);
    final index = FarmIntensity.allowed.indexOf(current);
    return Padding(
      padding: ShellLayout.seamPadding.copyWith(bottom: 2),
      child: MenuChrome.segmented(
        dense: true,
        labels: [for (final mult in FarmIntensity.allowed) '$mult×'],
        selectedIndex: index < 0 ? 0 : index,
        onSelect: (i) {
          final mult = FarmIntensity.allowed[i];
          if (FarmIntensity.canPick(state, mult)) {
            director.setFarmIntensity(mult);
          } else if (FarmIntensity.canTry(state, mult)) {
            director.tryFarmIntensity(mult);
          }
        },
      ),
    );
  }

  Widget _inlineUnderFightBody({
    required bool plain,
    required bool canBuyAny,
  }) {
    final state = director.state;

    // The home fight gives this panel whatever height is left. A short
    // phone at text scale 1.45 can be shorter than the spend row, so the
    // row scrolls with the tracks instead of painting a stripe.
    return ListView(
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (canBuyAny)
          Padding(
            padding: ShellLayout.seamPadding.copyWith(bottom: 2),
            child: _spendModeSegmented(dense: true),
          )
        else
          Padding(
            padding: ShellLayout.listPadding,
            child: ShellLayout.hint(
              state.gold <= 0
                  ? 'Earn gold in the dungeon, then buy here.'
                  : 'Need a bit more gold for the next buy.',
              maxLines: 1,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ShellLayout.sheetHorizontal,
            4,
            ShellLayout.sheetHorizontal,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final type in PartyUpgradeType.values)
                _upgradeRow(
                  state: state,
                  type: type,
                  onPressed:
                      GameLogic.canForgeGoldSpend(state, type, _spendMode)
                      ? () {
                          director.upgradePartyTrack(type, mode: _spendMode);
                          setState(() {});
                        }
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classicForgeBody({required bool plain, required bool pinSpendAll}) {
    final state = director.state;
    final homeFight =
        state.homeLayout == HomeLayout.home && !widget.inlineUnderFight;
    final canBuyAny =
        !(plain &&
            state.gold <
                GameLogic.upgradeCostFor(
                  state,
                  PartyUpgradeType.values[GameLogic.recommendedForgeUpgrade(
                    state,
                  )],
                ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: ShellLayout.listPadding.copyWith(bottom: homeFight ? 2 : 6),
          child: Text(
            ForgeOverlay.boughtSummary(state, plain: plain),
            maxLines: 2,
            softWrap: true,
            style: GameTheme.readable(color: homeFight
                  ? GameTheme.parchmentDim
                  : GameTheme.parchment),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
          child: ShellLayout.hint(
            NavCopy.playerText(
              ForgeOverlay.resetHint(
                plain: plain,
                showCamp: MenuTabs.showCamp(state),
              ),
              state.homeLayout,
            ),
            maxLines: homeFight ? 2 : 4,
          ),
        ),
        ShellLayout.gap(homeFight ? 2 : 4),
        if (canBuyAny) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
            child: _spendModeSegmented(dense: homeFight),
          ),
          ShellLayout.gap(2),
          if (!homeFight)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
              child: ShellLayout.hint(
                _spendMode == ForgeGoldSpendMode.one
                    ? '×1 = one buy · Bulk opens wallet slices'
                    : 'Bulk ${_spendMode.chipLabel} on each tap',
                maxLines: 2,
              ),
            ),
          if (!homeFight) ShellLayout.gap(4),
        ] else ...[
          Padding(
            padding: ShellLayout.listPadding,
            child: ShellLayout.hint(
              state.gold <= 0
                  ? 'Earn gold in the dungeon, then come back here to buy.'
                  : 'Need a bit more gold for the next buy — keep clearing floors.',
              maxLines: 2,
            ),
          ),
          ShellLayout.gap(4),
        ],
        for (final type in PartyUpgradeType.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
            child: _upgradeRow(
              state: state,
              type: type,
              onPressed: GameLogic.canForgeGoldSpend(state, type, _spendMode)
                  ? () {
                      director.upgradePartyTrack(type, mode: _spendMode);
                      setState(() {});
                    }
                  : null,
            ),
          ),
        if (canBuyAny && pinSpendAll) ...[
          ShellLayout.gap(2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ShellLayout.sheetHorizontal),
            child: _spendAllButton(state),
          ),
        ],
        ShellLayout.gap(4),
      ],
    );
  }
}
