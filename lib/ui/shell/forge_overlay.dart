import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/home_layout.dart';
import '../../core/nav_copy.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
  });
  final GameDirector director;

  /// SPLIT home: thin panel under the fight (BEST row + expand).
  final bool inlineUnderFight;

  /// GOLD footer. ESSENCE waits until that tab exists.
  static String resetHint({required bool plain, required bool showCamp}) {
    if (plain) {
      return 'Run gold power resets when you start over. Buy the row tagged BEST when unsure.';
    }
    if (showCamp) {
      return 'GOLD → FORGE + bag gold wipe on Ascend. BLESSING stays on ESSENCE.';
    }
    return 'GOLD → FORGE + bag gold wipe on Ascend. BLESSING stays.';
  }

  /// One-line sheet totals for the FORGE header (fits narrow home panel).
  static String boughtSummary(GameState state, {required bool plain}) {
    if (plain) {
      return 'Bought: AP +${state.forgeAttackSheet} · '
          'Armor +${state.forgeDefenseSheet} · '
          'STA +${state.forgeVitalitySheet}';
    }
    final parts = <String>[
      'AP +${state.forgeAttackSheet}',
      'Armor +${state.forgeDefenseSheet}',
      'STA +${state.forgeVitalitySheet}',
      'MOVE +${GameState.softForgePercent(state.moveSpeedBonus).round()}%',
      'HASTE +${GameState.softForgePercent(state.attackSpeedBonus).round()}%',
      'CRIT +${GameState.softForgePercent(state.critBonus, softAt: 25).round()}%',
      'MASTERY +${state.forgeMasterySheet}',
    ];
    return 'Bought: ${parts.join(' · ')}';
  }

  @override
  State<ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<ForgeOverlay> {
  ForgeGoldSpendMode _spendMode = ForgeGoldSpendMode.one;
  bool _showAllTracks = false;

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
    return PowerUpgradeRow(
      accent: _forgeAccent(type),
      title: _forgeName(type),
      tag: recommended ? 'BEST' : null,
      subtitle:
          '${_forgeBonus(state, type)}${nextDelta == null ? '' : ' · $nextDelta'}',
      selected: recommended,
      dense: true,
      trailing: GameButton(
        label: buyLabel,
        tip: onPressed == null && shortGold > 0
            ? 'Need ${formatGold(shortGold)} more'
            : recommended
            ? 'BEST = cheapest track that still lifts party power'
            : _softTip(state, type),
        expanded: false,
        dense: true,
        onPressed: onPressed,
      ),
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
    if (widget.inlineUnderFight) {
      return _inlineUnderFightBody(plain: plain, canBuyAny: canBuyAny);
    }
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
            ),
          ),
      ],
    );
  }

  Widget _inlineUnderFightBody({
    required bool plain,
    required bool canBuyAny,
  }) {
    final state = director.state;
    final recommended =
        PartyUpgradeType.values[GameLogic.recommendedForgeUpgrade(state)];
    final rows = _showAllTracks
        ? PartyUpgradeType.values
        : <PartyUpgradeType>[recommended];

    Widget rowList() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canBuyAny)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
            child: MenuChrome.segmented(
              dense: true,
              labels: const ['×1', 'Bulk'],
              selectedIndex: _spendMode == ForgeGoldSpendMode.one ? 0 : 1,
              onSelect: (i) {
                if (i == 0) {
                  setState(() => _spendMode = ForgeGoldSpendMode.one);
                  return;
                }
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
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              state.gold <= 0
                  ? 'Earn gold in the dungeon, then buy here.'
                  : 'Need a bit more gold for the next buy.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: WebClickScope(
            label: _showAllTracks ? 'Show best only' : 'All tracks',
            onPressed: () => setState(() => _showAllTracks = !_showAllTracks),
            child: Semantics(
              button: true,
              label: _showAllTracks ? 'Show best only' : 'All tracks',
              child: InkWell(
                onTap: () => setState(() => _showAllTracks = !_showAllTracks),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                  child: Text(
                    _showAllTracks ? 'Show best only' : 'All tracks',
                    style: GameTheme.menuTitle(
                      size: 11,
                      color: GameTheme.torch,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showAllTracks)
          Expanded(
            child: SingleChildScrollView(child: rowList()),
          )
        else
          rowList(),
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
          padding: EdgeInsets.fromLTRB(8, homeFight ? 0 : 0, 8, homeFight ? 2 : 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                ForgeOverlay.boughtSummary(state, plain: plain),
                maxLines: 1,
                softWrap: false,
                style: GameTheme.body(
                  size: homeFight ? 11 : 12,
                  color: homeFight
                      ? GameTheme.parchmentDim
                      : GameTheme.parchment,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            NavCopy.playerText(
              ForgeOverlay.resetHint(
                plain: plain,
                showCamp: MenuTabs.showCamp(state),
              ),
              state.homeLayout,
            ),
            maxLines: homeFight ? 1 : null,
            overflow: homeFight ? TextOverflow.ellipsis : null,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ),
        SizedBox(height: homeFight ? 2 : 4),
        if (canBuyAny) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MenuChrome.segmented(
              dense: homeFight,
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
          ),
          const SizedBox(height: 2),
          if (!homeFight)
            Text(
              _spendMode == ForgeGoldSpendMode.one
                  ? '×1 = one buy · Bulk opens wallet slices'
                  : 'Bulk ${_spendMode.chipLabel} on each tap',
              style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
            ),
          if (!homeFight) const SizedBox(height: 4),
          if (homeFight) const SizedBox(height: 2),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
