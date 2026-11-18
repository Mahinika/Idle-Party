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
  const HomeTopBar({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  /// AL and essence pills wait until either means something: first ascend,
  /// first essence, or first boss. A new save does not open on two zeros.
  static bool showsMetaPills(GameState s) =>
      s.ascensionLevel > 0 || s.essence > 0 || s.bossVictories > 0;

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
                '${s.bossVictories}|'
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
    final chase = NavCopy.playerText(_chaseLine(state), HomeLayout.home);
    final third = _third(context, state, route, essencePanel);
    final compactTop = state.homeLayout == HomeLayout.home && state.inDungeon;
    final perMin = GoldIncome.hubGoldPerMinute(state);
    final fast = state.combatPace >= 2;
    final goldHasSub = perMin > 0;
    final showMeta = HomeTopBar.showsMetaPills(state);
    final menuCaption = textScale <= 1.1;
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
                if (showMeta) ...[
                  HudPill(
                    icon: UiIcon.ascend,
                    text: 'AL ${state.ascensionLevel}',
                    edge: GameTheme.levelAccent,
                    reserveSub: goldHasSub,
                  ),
                  const SizedBox(width: 4),
                  HudPill(
                    icon: UiIcon.essence,
                    text: formatCount(state.essence),
                    edge: GameTheme.levelAccent,
                    reserveSub: goldHasSub,
                  ),
                ],
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
                    child: HudPill(
                      icon: third.$4,
                      text: third.$2,
                      reserveSub: goldHasSub,
                    ),
                  ),
                ],
                if (state.inDungeon) ...[
                  const SizedBox(width: 4),
                  _tap(
                    label: fast ? 'SPEED 2×' : 'SPEED 1×',
                    onTap: director.cycleCombatPace,
                    child: ChunkyFace(
                      tone: fast ? ChunkyTone.orange : ChunkyTone.stone,
                      minWidth: 40,
                      minHeight: GameTheme.chunkyFaceDense,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              '▸',
                              maxLines: 1,
                              style: GameTheme.button(
                                size: GameTheme.typeButtonDense,
                                color: fast
                                    ? ChunkyFace.textOn(ChunkyTone.orange)
                                    : GameTheme.parchmentDim,
                              ),
                            ),
                          ),
                          Text(
                            fast ? '2×' : '1×',
                            maxLines: 1,
                            style: GameTheme.button(
                              size: GameTheme.typeButtonDense,
                              color: fast
                                  ? ChunkyFace.textOn(ChunkyTone.orange)
                                  : GameTheme.parchment,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                _tap(
                  label: 'MENU',
                  onTap: () => router.toggle(MenuRoute.more),
                  child: ChunkyFace(
                    tone: ChunkyTone.stone,
                    minWidth: 36,
                    minHeight: GameTheme.chunkyFaceDense,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: menuCaption
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GameIcon.asset(UiIcon.menu, size: 14),
                              // Fixed width: the caption never widens
                              // the face past its 36 dp minimum.
                              ExcludeSemantics(
                                child: SizedBox(
                                  width: 28,
                                  child: Text(
                                    'MENU',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    textAlign: TextAlign.center,
                                    style: GameTheme.hint(
                                      color: GameTheme.parchment,
                                    ).copyWith(height: 1),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GameIcon.asset(UiIcon.menu, size: 20),
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
        formatCount(state.metaDepth.adTickets),
        () => router.open(MenuRoute.shop),
        UiIcon.ticket,
      );
    }
    if (route == MenuRoute.essence) {
      final embers = essencePanel == EssencePanel.keep;
      return (
        embers ? 'Embers' : 'Cinders',
        formatCount(embers ? state.metaDepth.embers : state.metaDepth.cinders),
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
