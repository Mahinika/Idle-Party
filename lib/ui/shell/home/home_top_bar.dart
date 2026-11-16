import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/keystone.dart';
import '../../../core/game_state.dart';
import '../../../core/gold_income.dart';
import '../../../core/home_layout.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_router.dart';
import '../../../core/nav_copy.dart';
import '../../chunky_face.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../hub/hub_header.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_common.dart';
import 'director_select.dart';
import 'hud_pills.dart';

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
                '${s.inDungeon}|${s.currentRoom.floorNumber}|'
                '${GoldIncome.hubGoldPerMinute(s)}';
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final chase = NavCopy.playerText(
      _chaseLine(state),
      HomeLayout.home,
    );
    final third = _third(context, state, route, essencePanel);
    final compactTop =
        state.homeLayout == HomeLayout.home && state.inDungeon;
    final perMin = GoldIncome.hubGoldPerMinute(state);
    final fast = state.combatPace >= 2;
    // Stone fills the cutout. The words start below it.
    final topInset = MenuChrome.systemTopInset(context);
    return Material(
      color: GameTheme.stoneDeep,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 2 + topInset, 8, compactTop ? 2 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HudPill(
                  icon: UiIcon.ascend,
                  text: 'AL ${state.ascensionLevel}',
                  edge: GameTheme.levelAccent,
                ),
                const SizedBox(width: 4),
                HudPill(
                  icon: UiIcon.essence,
                  text: '${state.essence}',
                  edge: GameTheme.levelAccent,
                ),
                if (compactTop && state.keystoneRunActive) ...[
                  const SizedBox(width: 4),
                  Text(
                    Keystone.formatTimer(state.keystoneTimerMs),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
                ],
                const SizedBox(width: 4),
                Expanded(
                  child: _tap(
                    label: 'Gold',
                    onTap: () => _openGold(context, state),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: HudPill(
                        icon: UiIcon.gold,
                        text: formatGold(state.gold),
                        sub: perMin > 0
                            ? '+${GoldIncome.perMinuteLabel(perMin)}'
                            : null,
                        edge: GameTheme.buyGoldBottom,
                      ),
                    ),
                  ),
                ),
                if (third != null && !compactTop) ...[
                  const SizedBox(width: 4),
                  _tap(
                    label: third.$1,
                    onTap: third.$3,
                    child: HudPill(icon: third.$4, text: third.$2),
                  ),
                ],
                const SizedBox(width: 4),
                _tap(
                  label: fast ? 'SPEED 2×' : 'SPEED 1×',
                  onTap: director.cycleCombatPace,
                  child: ChunkyFace(
                    tone: fast ? ChunkyTone.orange : ChunkyTone.stone,
                    minWidth: GameTheme.minTouch,
                    minHeight: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      fast ? '2×' : '1×',
                      maxLines: 1,
                      style: GameTheme.button(
                        size: GameTheme.typeButtonDense,
                        color: fast
                            ? ChunkyFace.textOn(ChunkyTone.orange)
                            : GameTheme.parchment,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _tap(
                  label: 'MENU',
                  onTap: () => router.toggle(MenuRoute.more),
                  child: ChunkyFace(
                    tone: ChunkyTone.stone,
                    minWidth: 38,
                    minHeight: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GameIcon.asset(UiIcon.menu, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (compactTop) ...[
                  HexBadge(
                    label: 'F${state.currentRoom.floorNumber}',
                    semanticLabel: 'Floor ${state.currentRoom.floorNumber}',
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    chase,
                    maxLines: compactTop && textScale <= 1.2 ? 2 : 1,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                ),
                if (state.inDungeon) ...[
                  const SizedBox(width: 4),
                  HudDpsPill(director: director),
                ],
              ],
            ),
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
            constraints: const BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
