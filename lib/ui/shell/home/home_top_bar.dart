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
import '../../web_click_bridge.dart';
import '../dungeon_party_hud.dart';
import '../shell_common.dart';
import 'director_select.dart';

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
                '${s.keystoneRunActive}|${s.keystoneTimerMs}';
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
    final chase = NavCopy.playerText(
      _chaseLine(state),
      HomeLayout.home,
    );
    final third = _third(context, state, route, essencePanel);
    final compactTop =
        state.homeLayout == HomeLayout.home && state.inDungeon;
    return Material(
      color: GameTheme.stoneDeep,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, compactTop ? 2 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _chip('AL ${state.ascensionLevel}', UiIcon.ascend),
                const SizedBox(width: 6),
                _chip('${state.essence}', UiIcon.essence),
                if (compactTop && state.keystoneRunActive) ...[
                  const SizedBox(width: 6),
                  Text(
                    Keystone.formatTimer(state.keystoneTimerMs),
                    style: GameTheme.pixel(size: 10, color: GameTheme.torchHot),
                  ),
                ],
                if (compactTop) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      chase,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                if (compactTop)
                  _tap(
                    label: 'Gold',
                    onTap: () => _openGold(context, state),
                    child: _chip(formatGold(state.gold), UiIcon.gold),
                  )
                else
                  Expanded(
                    child: _tap(
                      label: 'Gold',
                      onTap: () => _openGold(context, state),
                      child: _chip(
                        '${formatGold(state.gold)}  ${GoldIncome.perMinuteLabel(GoldIncome.hubGoldPerMinute(state))}',
                        UiIcon.gold,
                      ),
                    ),
                  ),
                if (third != null && !compactTop) ...[
                  const SizedBox(width: 6),
                  _tap(
                    label: third.$1,
                    onTap: third.$3,
                    child: _chip(third.$2, third.$4),
                  ),
                ],
                const SizedBox(width: 6),
                _tap(
                  label: state.combatPace >= 2 ? 'SPEED 2×' : 'SPEED 1×',
                  onTap: director.cycleCombatPace,
                  child: Text(
                    state.combatPace >= 2 ? '2×' : '1×',
                    style: GameTheme.menuTitle(size: 14),
                  ),
                ),
                const SizedBox(width: 6),
                _tap(
                  label: 'MENU',
                  onTap: () => router.toggle(MenuRoute.more),
                  child: GameIcon.asset(UiIcon.menu, size: 22),
                ),
              ],
            ),
            if (!compactTop) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chase,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ),
                  if (wide) DpsMeter(director: director, onOpenChanged: (_) {}),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _chaseLine(GameState state) => HubChase.forState(state).title;

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
            style: GameTheme.body(size: 12, color: GameTheme.parchment),
          ),
        ),
      ],
    );
  }

  Widget _tap({
    required String label,
    required VoidCallback onTap,
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
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
