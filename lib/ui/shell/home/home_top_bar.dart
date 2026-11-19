import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/party_meter.dart';
import '../../../core/hub_chase.dart';
import '../../../core/keystone.dart';
import '../../../core/game_state.dart';
import '../../../core/gold_income.dart';
import '../../../core/home_layout.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/nav_copy.dart';
import '../../../core/nav_intent.dart';
import '../dungeon_target_hud.dart';
import '../dungeon_top_hud.dart';
import '../../chunky_face.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../hub/hub_header.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../shell_common.dart';
import 'director_select.dart';
import 'home_catalog.dart';
import 'al_ascension_sheet.dart';
import 'floor_jump_sheet.dart';
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

  /// AL 0 stays hidden; essence visibility follows [showsMetaPills].
  static bool showsAlPill(GameState s) => s.ascensionLevel >= 1;

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
                '${GoldIncome.hubGoldPerMinute(s)}|'
                '${HomeCatalog.townMenuBadge(s, director)}';
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
    final chaseHub = HubChase.forState(state);
    final questReady = chaseHub.kind == HubChaseKind.claimMissions;
    final chaseTitle = questReady ? '' : chaseHub.title;
    final chase = chaseTitle.isEmpty
        ? ''
        : NavCopy.playerText(chaseTitle, HomeLayout.home);
    final third = _third(context, state, route, essencePanel);
    final compactTop = state.homeLayout == HomeLayout.home && state.inDungeon;
    final perMin = GoldIncome.hubGoldPerMinute(state);
    final fast = state.combatPace >= 2;
    final goldHasSub = perMin > 0;
    final alSub = alPillSubLine(state);
    final showMeta = HomeTopBar.showsMetaPills(state);
    final menuCaption = textScale <= 1.1;
    final tightChrome = compactTop && textScale > 1.9;
    // Town has no quick rail (F100): SCROLLS / POUCH / UPDATE wait in MENU,
    // so their red dot moves onto the MENU button.
    final menuDot = HomeCatalog.townMenuBadge(state, director);
    // Stone fills the cutout. The words start below it.
    final topInset = MenuChrome.systemTopInset(context);
    return Material(
      color: GameTheme.stoneDeep,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          2 + topInset,
          8,
          tightChrome ? 0 : (compactTop ? 2 : 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (showMeta) ...[
                  if (HomeTopBar.showsAlPill(state)) ...[
                    Flexible(
                      flex: 0,
                      fit: FlexFit.loose,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: _tap(
                          label: 'Ascension Level ${state.ascensionLevel}',
                          onTap: () => showAlAscensionSheet(
                            context,
                            director: director,
                            router: router,
                          ),
                          child: ExcludeSemantics(
                            child: HudPill(
                              icon: UiIcon.ascend,
                              text: 'AL ${state.ascensionLevel}',
                              sub: alSub,
                              edge: GameTheme.levelAccent,
                              reserveSub: goldHasSub && alSub == null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _essencePill(context, state, goldHasSub),
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
                  label: menuDot ? 'MENU, ready' : 'MENU',
                  onTap: () => router.toggle(MenuRoute.more),
                  child: _withDot(
                    menuDot,
                    ChunkyFace(
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
                ),
              ],
            ),
            if (compactTop) ...[
              SizedBox(height: textScale > 1.4 ? 0 : 2),
              _DungeonTargetRow(
                director: director,
                router: router,
                state: state,
                questReady: questReady,
                questCount: state.missions.where((m) => m.canClaim).length,
                textScale: textScale,
                onFloorTap: () => showFloorJumpSheet(context, director),
              ),
              if (chase.isNotEmpty) ...[
                SizedBox(height: textScale > 1.4 ? 0 : 1),
                Text(
                  chase,
                  maxLines: textScale <= 1.2 ? 2 : 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.parchmentDim),
                ),
              ],
            ] else ...[
              SizedBox(height: textScale > 1.4 ? 0 : 2),
              Row(
                children: [
                  Expanded(
                    child: chase.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            chase,
                            maxLines: textScale <= 1.2 ? 2 : 1,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.hint(color: GameTheme.parchmentDim),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openGold(BuildContext context, GameState state) {
    final perMin = GoldIncome.hubGoldPerMinute(state);
    showHubIncomeSheet(
      context,
      incomeLine: GoldIncome.perMinuteLabel(perMin),
      // What makes up the rate, not a bare " · Gold" (polish7 P034).
      multiplierLine: GoldIncome.multiplierLine(state),
      displayTitle: '',
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

  /// Red dot on the MENU button while a moved rail cell has something ready.
  static const Key menuDotKey = ValueKey('home-top-menu-dot');

  Widget _withDot(bool on, Widget child) {
    if (!on) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            key: menuDotKey,
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: GameTheme.hudHpDamage,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _essencePill(BuildContext context, GameState state, bool goldHasSub) {
    final unlocked = MenuTabs.showCamp(state);
    final count = formatCount(state.essence);
    final pill = HudPill(
      icon: UiIcon.essence,
      text: count,
      edge: GameTheme.levelAccent,
      reserveSub: goldHasSub,
    );
    final label = 'Essence, $count';
    if (unlocked) {
      return _tap(
        label: label,
        onTap: () => router.open(MenuRoute.essence),
        child: ExcludeSemantics(child: pill),
      );
    }
    return Tooltip(
      message: 'ESSENCE opens at 1st essence',
      child: Semantics(
        label: '$label · locked',
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: GameTheme.minTouch,
            minHeight: GameTheme.minTouch,
          ),
          child: Center(child: pill),
        ),
      ),
    );
  }

  static double _hexBadgeLayoutWidth(
    BuildContext context,
    String floorLabel,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: floorLabel,
        style: GameTheme.hint(color: GameTheme.parchment),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width + 18;
  }

  static double _dpsPillLayoutWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: '999 dps',
        style: GameTheme.combat(color: GameTheme.parchment, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width + 12;
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

class _DungeonTargetRow extends StatelessWidget {
  const _DungeonTargetRow({
    required this.director,
    required this.router,
    required this.state,
    required this.questReady,
    required this.questCount,
    required this.textScale,
    required this.onFloorTap,
  });

  final GameDirector director;
  final MenuRouter router;
  final GameState state;
  final bool questReady;
  final int questCount;
  final double textScale;
  final VoidCallback onFloorTap;

  @override
  Widget build(BuildContext context) {
    final floorLabel = 'F${state.currentRoom.floorNumber}';
    final chip = MissionClaimChip(
      count: questCount,
      dense: true,
      onTap: director.claimAllReadyMissions,
      onLongPress: () => router.apply(NavIntent.quests),
    );
    return ListenableBuilder(
      listenable: director.combatFrame,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
        const gap = 4.0;
        final hexW = HomeTopBar._hexBadgeLayoutWidth(context, floorLabel);
        final chipW = questReady
            ? MissionClaimChip.layoutWidth(context, questCount, dense: true)
            : 0.0;
        final world = director.spatial;
        final dpsLive =
            world != null &&
            world.combatElapsed > 0.05 &&
            PartyMeter.fromHeroes(
              world.heroes,
              elapsed: world.combatElapsed,
            ).chipLabel !=
                '0 DPS';
        final dpsW = dpsLive ? HomeTopBar._dpsPillLayoutWidth(context) : 0.0;
        final trailingWithChip = hexW +
            gap +
            dpsW +
            (dpsW > 0 ? gap : 0) +
            (questReady ? gap + chipW : 0);
        final minStrip = TargetCornerHud.minLayoutWidth(context);
        const stripSlack = 4.0;
        final inlineQuest = questReady &&
            constraints.maxWidth - trailingWithChip >= minStrip - stripSlack;

        final targetRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: director.combatFrame,
                builder: (context, _) => TargetCornerHud(
                  director: director,
                  edgeInset: false,
                ),
              ),
            ),
            const SizedBox(width: gap),
            _floorBadge(context, floorLabel),
            const SizedBox(width: gap),
            HudDpsPill(director: director),
            if (inlineQuest) ...[
              const SizedBox(width: gap),
              chip,
            ],
          ],
        );

        if (questReady && !inlineQuest) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              targetRow,
              SizedBox(height: textScale > 1.4 ? 0 : 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [chip],
              ),
            ],
          );
        }
        return targetRow;
        },
      ),
    );
  }

  Widget _floorBadge(BuildContext context, String floorLabel) {
    return WebClickScope(
      label: 'Floor ${state.currentRoom.floorNumber}, open floor list',
      onPressed: onFloorTap,
      child: Semantics(
        button: true,
        label: 'Floor ${state.currentRoom.floorNumber}, open floor list',
        child: InkWell(
          onTap: onFloorTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: GameTheme.minTouch,
              minHeight: GameTheme.minTouch,
            ),
            child: Center(
              child: ExcludeSemantics(
                child: HexBadge(
                  label: floorLabel,
                  semanticLabel: 'Floor ${state.currentRoom.floorNumber}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
