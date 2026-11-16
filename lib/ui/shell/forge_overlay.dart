import 'package:flutter/material.dart';
import '../../core/farm_intensity.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/home_layout.dart';
import '../../core/nav_copy.dart';
import '../game_icon.dart';
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

  /// Sheet value now and after [buys] more buys on [type], as shown on
  /// the card ("+12 AP" → "+14"). Same soft knees as the hero sheet.
  static (String, String, bool) forgeGainLine(
    GameState state,
    PartyUpgradeType type, {
    int buys = 1,
  }) {
    String flat(int points, int gain, double softAt, String stat) {
      final now = GameState.softForgePercent(points, softAt: softAt).round();
      final next = GameState.softForgePercent(
        points + gain * buys,
        softAt: softAt,
      ).round();
      return '+$now $stat|+$next';
    }

    String pct(int points, int gain, double softAt) {
      final now = GameState.softForgePercent(points, softAt: softAt).round();
      final next = GameState.softForgePercent(
        points + gain * buys,
        softAt: softAt,
      ).round();
      return '+$now%|+$next%';
    }

    final (line, soft) = switch (type) {
      PartyUpgradeType.attack => (
        flat(state.attackBonus, GameLogic.forgeAttackGain,
            GameLogic.forgeAttackSoftAt, 'AP'),
        state.attackBonus >= GameLogic.forgeAttackSoftAt,
      ),
      PartyUpgradeType.defense => (
        flat(state.defenseBonus, GameLogic.forgeDefenseGain,
            GameLogic.forgeDefenseSoftAt, 'Armor'),
        state.defenseBonus >= GameLogic.forgeDefenseSoftAt,
      ),
      PartyUpgradeType.vitality => (
        flat(state.vitalityBonus, GameLogic.forgeVitalityGain,
            GameLogic.forgeVitalitySoftAt, 'STA'),
        state.vitalityBonus >= GameLogic.forgeVitalitySoftAt,
      ),
      PartyUpgradeType.moveSpeed => (
        pct(state.moveSpeedBonus, GameLogic.forgeMoveGain, 40),
        state.moveSpeedBonus >= 40,
      ),
      PartyUpgradeType.attackSpeed => (
        pct(state.attackSpeedBonus, GameLogic.forgeHasteGain, 40),
        state.attackSpeedBonus >= 40,
      ),
      PartyUpgradeType.crit => (
        pct(state.critBonus, GameLogic.forgeCritGain, 25),
        state.critBonus >= 25,
      ),
      PartyUpgradeType.mastery => (
        flat(state.masteryBonus, GameLogic.forgeMasteryGain,
            GameLogic.forgeMasterySoftAt, 'MASTERY'),
        state.masteryBonus >= GameLogic.forgeMasterySoftAt,
      ),
    };
    final parts = line.split('|');
    return (parts[0], parts[1], soft);
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

  String _forgeIcon(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => UiIcon.sword,
    PartyUpgradeType.defense => UiIcon.shieldRound,
    PartyUpgradeType.vitality => UiIcon.heart,
    PartyUpgradeType.moveSpeed => UiIcon.boots,
    PartyUpgradeType.attackSpeed => UiIcon.wand,
    PartyUpgradeType.crit => UiIcon.star,
    PartyUpgradeType.mastery => UiIcon.tome,
  };

  Widget _upgradeRow({
    required GameState state,
    required PartyUpgradeType type,
    required VoidCallback? onPressed,
  }) {
    final recommended = GameLogic.recommendedForgeUpgrade(state) == type.index;
    final cost = GameLogic.upgradeCostFor(state, type);
    final preview = GameLogic.previewForgeGoldSpend(state, type, _spendMode);
    // The ×N badge carries the count; the face is the total.
    final buyLabel = onPressed == null || _spendMode == ForgeGoldSpendMode.one
        ? formatGold(cost)
        : formatGold(preview.spent);
    final shortGold = cost > state.gold ? cost - state.gold : 0;
    final primaryBuy = recommended && onPressed != null;
    final buys = onPressed == null ? 1 : (preview.buys < 1 ? 1 : preview.buys);
    final (now, next, soft) = ForgeOverlay.forgeGainLine(state, type, buys: buys);
    return PowerUpgradeRow(
      accent: _forgeAccent(type),
      leading: UpgradeIconTile(
        icon: _forgeIcon(type),
        accent: _forgeAccent(type),
      ),
      title: _forgeName(type),
      tag: recommended ? 'BEST' : null,
      subtitle: now,
      gainNext: next,
      gainNote: soft ? 'SOFT' : null,
      detail: onPressed == null && shortGold > 0
          ? 'Need ${formatGold(shortGold)} more'
          : null,
      selected: recommended,
      dense: true,
      trailing: PowerUpgradePriceChip(
        label: buyLabel,
        primary: primaryBuy,
        quantity: onPressed == null ? null : buys,
        onPressed: onPressed,
      ),
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
  return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameButton(
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
        const SizedBox(height: 2),
        Text(
          'Buys the cheapest track.',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.hint(color: GameTheme.parchmentDim),
        ),
      ],
    );
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
    final inline = _scrollAllTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inline) _farmIntensityRow(state),
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
    final farmInline = FarmIntensity.applies(state) ? _farmIntensityRow(state) : null;
    return ListView(
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (farmInline != null || canBuyAny)
          Padding(
            padding: ShellLayout.seamPadding.copyWith(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (farmInline != null) Expanded(child: farmInline),
                if (farmInline != null && canBuyAny) const SizedBox(width: 6),
                if (canBuyAny) Expanded(child: _spendModeSegmented(dense: true)),
              ],
            ),
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
