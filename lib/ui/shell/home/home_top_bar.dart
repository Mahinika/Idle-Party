import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/keystone.dart';
import '../../../core/game_state.dart';
import '../../../core/gold_income.dart';
import '../../../core/home_layout.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_router.dart';
import '../../../core/nav_copy.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../hub/hub_header.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../dungeon_party_hud.dart';
import '../shell_common.dart';
import 'director_select.dart';
import 'home_claim_row.dart';

/// AL, essence, gold, a context currency, speed, and MENU.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: router,
      builder: (context, _) {
        return DirectorSelect<String>(
          director: director,
          select: (s) {
            final chase = HubChase.forState(s).title;
            return '${s.ascensionLevel}|${s.essence}|${s.gold}|${s.combatPace}|'
                '${s.metaDepth.adTickets}|${s.metaDepth.cinders}|'
                '${s.metaDepth.embers}|${s.hardmodeLevel}|$chase|'
                '${s.keystoneRunActive}|${s.keystoneTimerMs}|'
                '${HomeClaimRow.showChip(s)}|${HomeClaimRow.vaultLine(s)}|'
                '${HomeClaimRow.showChip(s) ? HomeClaimRow.chipHint(s) : ''}';
          },
          builder: (context, state) =>
              _bar(context, state, router.route, router.essencePanel),
        );
      },
    );
  }

  Widget _bar(
    BuildContext context,
    GameState state,
    MenuRoute route,
    EssencePanel essencePanel,
  ) {
    final wide = MediaQuery.sizeOf(context).width >= 400;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final chase = NavCopy.playerText(
      _chaseLine(state),
      HomeLayout.home,
    );
    final third = _third(context, state, route, essencePanel);
    final compactTop =
        state.homeLayout == HomeLayout.home && state.inDungeon;
    final showClaim = HomeClaimRow.showChip(state);
    // CLAIM next to gold already says it.
    final claimOwnsChase =
        compactTop && HomeClaimRow.vaultLine(state) != null;
    // Stone fills the cutout. Buttons, icons, and words all start below it.
    // The row keeps 44 px hit areas, but its art sits at the top of them and
    // the chase line slides up under their lower half, so the bar is short.
    final topInset = MenuChrome.systemTopInset(context);
    final artH = _artHeight(context);
    final chaseTop = _artTop + artH + 2;
    final overlapChase = compactTop || !wide;
    Widget slot(Widget child) => SizedBox(
          height: GameTheme.minTouch,
          child: Align(
            alignment: Alignment.topCenter,
            child: _art(child, artH),
          ),
        );
    final row = Row(
      children: [
        slot(_chip('AL ${state.ascensionLevel}', UiIcon.ascend)),
        const SizedBox(width: 6),
        slot(_chip('${state.essence}', UiIcon.essence)),
        if (compactTop && state.keystoneRunActive) ...[
          const SizedBox(width: 6),
          slot(
            Text(
              Keystone.formatTimer(state.keystoneTimerMs),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.torchHot),
            ),
          ),
        ],
        const SizedBox(width: 6),
        if (compactTop)
          _tap(
            label: 'Gold',
            onTap: () => _openGold(context, state),
            artH: artH,
            child: _chip(formatGold(state.gold), UiIcon.gold),
          )
        else
          Expanded(
            child: _tap(
              label: 'Gold',
              onTap: () => _openGold(context, state),
              artH: artH,
              child: _chip(
                '${formatGold(state.gold)}  ${GoldIncome.perMinuteLabel(GoldIncome.hubGoldPerMinute(state))}',
                UiIcon.gold,
              ),
            ),
          ),
        if (showClaim) ...[
          const SizedBox(width: 4),
          _claimChip(state, artH),
        ],
        if (third != null && !compactTop) ...[
          const SizedBox(width: 6),
          _tap(
            label: third.$1,
            onTap: third.$3,
            artH: artH,
            child: _chip(third.$2, third.$4),
          ),
        ],
        const SizedBox(width: 6),
        _tap(
          label: state.combatPace >= 2 ? 'SPEED 2×' : 'SPEED 1×',
          onTap: director.cycleCombatPace,
          artH: artH,
          child: _chip(
            state.combatPace >= 2 ? '2×' : '1×',
            UiIcon.sword,
          ),
        ),
        const SizedBox(width: 6),
        _tap(
          label: 'MENU',
          onTap: () => router.toggle(MenuRoute.more),
          artH: artH,
          child: GameIcon.asset(UiIcon.menu, size: 22),
        ),
      ],
    );
    final Widget? chaseLine = compactTop && claimOwnsChase
        ? null
        : compactTop
        ? Text(
            chase,
            maxLines: textScale > 1.2 ? 1 : 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  chase,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.parchmentDim),
                ),
              ),
              if (wide) DpsMeter(director: director, onOpenChanged: (_) {}),
            ],
          );
    final Widget body;
    if (chaseLine == null) {
      body = row;
    } else if (overlapChase) {
      // Chase first, row on top: taps in the overlap still reach the
      // buttons, and the plain line under them has nothing to tap.
      body = Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(
            padding: EdgeInsets.only(top: chaseTop),
            child: chaseLine,
          ),
          row,
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [row, const SizedBox(height: 2), chaseLine],
      );
    }
    return Material(
      color: GameTheme.stoneDeep,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, topInset, 8, compactTop ? 2 : 4),
        child: body,
      ),
    );
  }

  String _chaseLine(GameState state) => HubChase.forState(state).title;

  /// Gap above the row's art, inside the 44 px hit areas.
  static const double _artTop = 4;

  /// One art line: text at the current scale, the 22 px MENU icon, or the
  /// CLAIM chip, whichever is tallest.
  static double _artHeight(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: '0g 1×', style: GameTheme.hint()),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final chip = tp.height + 6; // CLAIM: 2 + 2 pad, 1 + 1 border
    tp.dispose();
    return chip > 22 ? chip : 22.0;
  }

  Widget _art(Widget child, double artH) => Padding(
        padding: const EdgeInsets.only(top: _artTop),
        child: SizedBox(height: artH, child: Center(child: child)),
      );

  /// Daily vault CLAIM: small gold chip, full 44 px hit area.
  Widget _claimChip(GameState state, double artH) {
    final hint = HomeClaimRow.chipHint(state);
    return WebClickScope(
      label: 'CLAIM',
      onPressed: director.claimDailyVault,
      child: Tooltip(
        message: 'Claim $hint',
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: 'Claim the daily vault. $hint',
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('home-top-claim'),
            onTap: director.claimDailyVault,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: _art(DecoratedBox(
                  decoration: BoxDecoration(
                    color: GameTheme.hudFarmGreen,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: GameTheme.clear),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      'CLAIM',
                      maxLines: 1,
                      softWrap: false,
                      style: GameTheme.hint(color: GameTheme.clear),
                    ),
                  ),
                ), artH),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openGold(BuildContext context, GameState state) {
    final perMin = GoldIncome.hubGoldPerMinute(state);
    showHubIncomeSheet(
      context,
      incomeLine: GoldIncome.perMinuteLabel(perMin),
      multiplierLine: '',
      displayTitle: 'Gold',
      willRank: '',
      collectionScore: 0,
    );
  }

  /// Label, value, tap, icon.
  (String, String, VoidCallback, String)? _third(
    BuildContext context,
    GameState state,
    MenuRoute route,
    EssencePanel essencePanel,
  ) {
    if (route == MenuRoute.shop) {
      return (
        'Tickets',
        '${state.metaDepth.adTickets}',
        () => router.open(MenuRoute.shop),
        UiIcon.ticket,
      );
    }
    if (route == MenuRoute.essence) {
      final embers = essencePanel == EssencePanel.keep;
      return (
        embers ? 'Embers' : 'Cinders',
        '${embers ? state.metaDepth.embers : state.metaDepth.cinders}',
        () {
          router.essencePanel = embers
              ? EssencePanel.keep
              : EssencePanel.relics;
          if (!router.homeAtSub) router.pushSub();
        },
        embers ? UiIcon.embers : UiIcon.cinders,
      );
    }
    if (route == MenuRoute.map) {
      return (
        'Keystones',
        '+${state.hardmodeLevel}',
        () => router.open(MenuRoute.key),
        UiIcon.key,
      );
    }
    return null;
  }

  Widget _chip(String text, String icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GameIcon.asset(icon, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.hint(color: GameTheme.parchment),
          ),
        ),
      ],
    );
  }

  Widget _tap({
    required String label,
    required VoidCallback onTap,
    required double artH,
    required Widget child,
  }) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: _art(child, artH),
            ),
          ),
        ),
      ),
    );
  }
}
