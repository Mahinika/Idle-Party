import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/gear/gear_upgrade_copy.dart';
import '../../core/game_state.dart';
import '../../core/menu_alerts.dart';
import '../../core/home_layout.dart';
import '../../core/nav_copy.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import 'buy_qty_toggle.dart';
import 'home/nav_clearance.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class ForgeOverlay extends StatefulWidget {
  const ForgeOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
    this.expandedTrackList = false,
    this.spendMode,
  });
  final GameDirector director;

  /// Set when the home panel header owns ×1 / ×10 / MAX. The body then
  /// skips its own selector and buys with this mode.
  final ForgeGoldSpendMode? spendMode;

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
    final crit = GameState.softForgePercent(
      state.critBonus,
      softAt: 25,
    ).round();
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
  /// "Lv3 · " before a FORGE row's value line, like CAMP rows.
  static String levelPrefix(GameState state, PartyUpgradeType type) =>
      'Lv${GameLogic.forgeTrackTier(state, type)} · ';

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
        flat(
          state.attackBonus,
          GameLogic.forgeAttackGain,
          GameLogic.forgeAttackSoftAt,
          'AP',
        ),
        state.attackBonus >= GameLogic.forgeAttackSoftAt,
      ),
      PartyUpgradeType.defense => (
        flat(
          state.defenseBonus,
          GameLogic.forgeDefenseGain,
          GameLogic.forgeDefenseSoftAt,
          'Armor',
        ),
        state.defenseBonus >= GameLogic.forgeDefenseSoftAt,
      ),
      PartyUpgradeType.vitality => (
        flat(
          state.vitalityBonus,
          GameLogic.forgeVitalityGain,
          GameLogic.forgeVitalitySoftAt,
          'STA',
        ),
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
        flat(
          state.masteryBonus,
          GameLogic.forgeMasteryGain,
          GameLogic.forgeMasterySoftAt,
          'MASTERY',
        ),
        state.masteryBonus >= GameLogic.forgeMasterySoftAt,
      ),
    };
    final parts = line.split('|');
    return (parts[0], parts[1], soft);
  }

  /// Share of the way to the track's soft-cap knee (same knees as
  /// [forgeGainLine]). 1.0 once soft-capped.
  static double forgeSoftProgress(GameState state, PartyUpgradeType type) {
    final (points, softAt) = switch (type) {
      PartyUpgradeType.attack => (
        state.attackBonus,
        GameLogic.forgeAttackSoftAt,
      ),
      PartyUpgradeType.defense => (
        state.defenseBonus,
        GameLogic.forgeDefenseSoftAt,
      ),
      PartyUpgradeType.vitality => (
        state.vitalityBonus,
        GameLogic.forgeVitalitySoftAt,
      ),
      PartyUpgradeType.moveSpeed => (state.moveSpeedBonus, 40.0),
      PartyUpgradeType.attackSpeed => (state.attackSpeedBonus, 40.0),
      PartyUpgradeType.crit => (state.critBonus, 25.0),
      PartyUpgradeType.mastery => (
        state.masteryBonus,
        GameLogic.forgeMasterySoftAt,
      ),
    };
    if (softAt <= 0) return 1;
    return (points / softAt).clamp(0.0, 1.0);
  }

  /// Long-press MAX: 5 / 25 / 50 / 100% of the wallet per tap.
  static Future<ForgeGoldSpendMode?> pickWalletSlice(
    BuildContext context,
    ForgeGoldSpendMode current, {
    int? gold,
  }) {
    return showModalBottomSheet<ForgeGoldSpendMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(ctx).bottom),
        child: Material(
          color: GameTheme.sheet,
          borderRadius: MenuChrome.sheetRadius,
          child: Padding(
            padding: ShellLayout.sheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuChrome.sheetHandle(),
                MenuChrome.sheetTitleRow(ctx, sliceTitle),
                ShellLayout.gap(4),
                ShellLayout.hint(sliceHint, maxLines: 2),
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
                      label: sliceLabel(mode, gold),
                      style: current == mode
                          ? GameButtonStyle.brown
                          : GameButtonStyle.grey,
                      primary: current == mode,
                      onPressed: () => Navigator.pop(ctx, mode),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// MAX sheet title and hint (audit F025 / F070: no "GOLD track" jargon).
  static const sliceTitle = 'MAX · share of gold';
  static const sliceHint =
      'Each MAX tap spends this share of your gold on the upgrade you tap.';

  /// "25% · 3.0Kg": the share and what it is worth now (F025).
  static String sliceLabel(ForgeGoldSpendMode mode, int? gold) {
    if (gold == null) return mode.chipLabel;
    final pct = switch (mode) {
      ForgeGoldSpendMode.pct5 => 5,
      ForgeGoldSpendMode.pct25 => 25,
      ForgeGoldSpendMode.pct50 => 50,
      _ => 100,
    };
    return '${mode.chipLabel} · ${formatGold((gold * pct) ~/ 100)}';
  }

  /// MAX face for a spend mode: plain MAX for the wallet, else the slice.
  static String maxLabelFor(ForgeGoldSpendMode mode) => switch (mode) {
    ForgeGoldSpendMode.pct5 ||
    ForgeGoldSpendMode.pct25 ||
    ForgeGoldSpendMode.pct50 => mode.chipLabel,
    _ => 'MAX',
  };

  @override
  State<ForgeOverlay> createState() => _ForgeOverlayState();
}

class _ForgeOverlayState extends State<ForgeOverlay> {
  ForgeGoldSpendMode _ownMode = ForgeGoldSpendMode.one;

  /// Header-owned mode wins; otherwise this body's own selector.
  ForgeGoldSpendMode get _spendMode => widget.spendMode ?? _ownMode;
  set _spendMode(ForgeGoldSpendMode mode) => _ownMode = mode;

  bool get _headerOwnsQty => widget.spendMode != null;

  GameDirector get director => widget.director;

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
      PartyUpgradeType.attack => GameTheme.statAttack,
      PartyUpgradeType.defense => GameTheme.statArmor,
      PartyUpgradeType.vitality => GameTheme.statVitality,
      PartyUpgradeType.moveSpeed => GameTheme.statMove,
      PartyUpgradeType.attackSpeed => GameTheme.statSpeed,
      PartyUpgradeType.crit => GameTheme.statCrit,
      PartyUpgradeType.mastery => GameTheme.statMastery,
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
    final (now, next, soft) = ForgeOverlay.forgeGainLine(
      state,
      type,
      buys: buys,
    );
    return PowerUpgradeRow(
      accent: _forgeAccent(type),
      leading: UpgradeIconTile(
        icon: _forgeIcon(type),
        accent: _forgeAccent(type),
      ),
      title: _forgeName(type),
      tag: recommended ? 'BEST' : null,
      // Same "Lv · now › next" line as CAMP (audit F060).
      subtitle: '${ForgeOverlay.levelPrefix(state, type)}$now',
      gainNext: next,
      gainNote: soft ? 'SOFT' : null,
      progress: ForgeOverlay.forgeSoftProgress(state, type),
      detail: shortGold > 0
          ? null
          : onPressed != null
          ? GearUpgradeCopy.forgeNextFloorLine(state, type)
          : null,
      selected: recommended,
      dense: true,
      trailing: PowerUpgradePriceChip(
        label: buyLabel,
        primary: primaryBuy,
        quantity: onPressed == null ? null : buys,
        onPressed: onPressed,
        caption: shortGold > 0 ? 'Need ${formatGold(shortGold)} more' : null,
        footnote: shortGold > 0 && director.runGoldPerMinute > 0
            ? '+${GoldIncome.perMinuteLabel(director.runGoldPerMinute)}'
            : null,
      ),
    );
  }

  void _openBulkSpendSheet() {
    ForgeOverlay.pickWalletSlice(
      context,
      _spendMode,
      gold: director.state.gold,
    ).then((mode) {
      if (mode != null && mounted) setState(() => _spendMode = mode);
    });
  }

  BuyQty get _qty => switch (_spendMode) {
    ForgeGoldSpendMode.one => BuyQty.one,
    ForgeGoldSpendMode.x10 => BuyQty.ten,
    _ => BuyQty.max,
  };

  /// MAX face: plain MAX for the whole wallet, else the picked slice.
  String get _maxLabel => ForgeOverlay.maxLabelFor(_spendMode);

  Widget _spendModeSegmented({required bool dense}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: BuyQtyToggle(
        value: _qty,
        maxLabel: _maxLabel,
        onChanged: (q) => setState(
          () => _spendMode = switch (q) {
            BuyQty.one => ForgeGoldSpendMode.one,
            BuyQty.ten => ForgeGoldSpendMode.x10,
            BuyQty.max => ForgeGoldSpendMode.pct100,
          },
        ),
        onMaxLongPress: _openBulkSpendSheet,
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: body)],
    );
  }

  Widget _inlineUnderFightBody({required bool plain, required bool canBuyAny}) {
    final state = director.state;

    // The home fight gives this panel whatever height is left. A short
    // phone at text scale 1.45 can be shorter than the spend row, so the
    // row scrolls with the tracks instead of painting a stripe.
    // FARM strength moved to the KEY / ENTER flow and the seam chip.
    return ListView(
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (canBuyAny && !_headerOwnsQty)
          Padding(
            padding: ShellLayout.seamPadding.copyWith(bottom: 2),
            child: _spendModeSegmented(dense: true),
          )
        else if (!canBuyAny)
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
          padding: EdgeInsets.fromLTRB(
            ShellLayout.sheetHorizontal,
            4,
            ShellLayout.sheetHorizontal,
            8 + NavClearance.of(context),
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
            style: GameTheme.readable(
              color: homeFight ? GameTheme.parchmentDim : GameTheme.parchment,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ShellLayout.sheetHorizontal,
          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: ShellLayout.sheetHorizontal,
            ),
            child: _spendModeSegmented(dense: homeFight),
          ),
          ShellLayout.gap(2),
          if (!homeFight)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShellLayout.sheetHorizontal,
              ),
              child: ShellLayout.hint(switch (_spendMode) {
                ForgeGoldSpendMode.one || ForgeGoldSpendMode.x10 =>
                  '×1 / ×10 buys per tap · MAX spends the wallet · hold MAX for 5–50%',
                _ => 'MAX ${_spendMode.chipLabel} of the wallet on each tap',
              }, maxLines: 2),
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
            padding: const EdgeInsets.symmetric(
              horizontal: ShellLayout.sheetHorizontal,
            ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: ShellLayout.sheetHorizontal,
            ),
            child: _spendAllButton(state),
          ),
        ],
        ShellLayout.gap(4),
      ],
    );
  }
}
