import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../first_session_tips.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../menu_chrome.dart';
import '../../web_click_bridge.dart';
import '../menu_surface.dart';
import 'camp_viewport.dart';
import 'director_select.dart';
import 'essence_tiles_screen.dart';
import 'fight_seam.dart';
import 'fight_viewport.dart';
import 'home_gold_dock.dart';
import 'home_nav_bar.dart';
import 'home_prompts.dart';
import 'home_top_bar.dart';
import 'map_screen.dart';
import 'upgrade_panel.dart';

/// Fight-first shell. The hub is the camp viewport when the party is out.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;
  HomeGoldPanel _goldFocus = HomeGoldPanel.forge;
  int _goldFocusGen = 0;

  @override
  void initState() {
    super.initState();
    router.addListener(_onRouter);
  }

  @override
  void dispose() {
    router.removeListener(_onRouter);
    super.dispose();
  }

  void _onRouter() {
    if (router.route == MenuRoute.gold) {
      final panel = router.goldPanel == GoldPanel.market
          ? HomeGoldPanel.market
          : HomeGoldPanel.forge;
      _goldFocus = panel;
      _goldFocusGen++;
      router.close();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = director.state;
        final split = state.inDungeon && !state.homePanelFull;
        if (split || router.route != MenuRoute.none) return;
        showHomeGoldSheet(
          context,
          director: director,
          router: router,
          initialPanel: panel,
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final route = router.route;
    final sheet = route != MenuRoute.none && route != MenuRoute.gold;
    final showPanel = !sheet && state.inDungeon;
    final full = state.homePanelFull;
    final alerts = MenuAlerts.forHub(
      state,
      chaseKind: HubChase.forState(state).kind,
    );
    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
      children: [
        HomeTopBar(director: director, router: router),
        if (!sheet && !state.inDungeon)
          if (FirstSessionTips.active(state, inDungeon: false)
              case final hint?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              FirstSessionTips.displayLine(hint, state),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            ),
          ),
        Expanded(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    flex: showPanel ? (full ? 1 : 4) : 5,
                    child: RepaintBoundary(
                      child: state.inDungeon
                          ? FightViewport(
                              director: director,
                              router: router,
                              onLeave: widget.onLeave,
                            )
                          : CampViewport(director: director, router: router),
                    ),
                  ),
                  if (showPanel)
                    FightSeam(
                      director: director,
                      router: router,
                      onLeave: widget.onLeave,
                      hideRails: full,
                    ),
                  if (showPanel && !full)
                    Expanded(
                      flex: 2,
                      child: RepaintBoundary(
                        child: DirectorSelect<int>(
                          director: director,
                          select: (s) => s.gold + s.essence,
                          builder: (context, _) => UpgradePanel(
                            director: director,
                            router: router,
                            focusPanel: _goldFocus,
                            focusGeneration: _goldFocusGen,
                          ),
                        ),
                      ),
                    ),
                  if (showPanel && full)
                    HomeGoldDock(director: director, router: router),
                  if (!sheet && !state.inDungeon)
                    HomeGoldDock(director: director, router: router),
                ],
              ),
              if (sheet) _sheet(),
              const IgnorePointer(child: SizedBox.shrink()),
              HomePromptHost(director: director, router: router),
            ],
          ),
          ),
        ),
        if (_showBack)
          _backRow(),
        if (route == MenuRoute.gear) _gearThumb(state),
        HomeNavBar(state: state, router: router, alerts: alerts),
      ],
      ),
    );
  }

  bool get _showBack =>
      router.homeAtSub || router.route == MenuRoute.key;

  Widget _backRow() {
    return Material(
      color: GameTheme.panel,
      child: WebClickScope(
        label: 'Back',
        onPressed: router.back,
        child: Semantics(
          button: true,
          label: 'Back',
          child: InkWell(
            onTap: router.back,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon.glyph(UiGlyph.prev, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'BACK',
                      style: GameTheme.menuTitle(
                        size: 12,
                        color: GameTheme.parchment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gearThumb(GameState state) {
    final panels = MenuRouter.visibleGearPanels(state);
    if (panels.isEmpty) return const SizedBox.shrink();
    final labels = panels.map(_gearLabel).toList();
    final selected = panels.indexOf(router.gearPanel).clamp(0, panels.length - 1);
    return Material(
      color: GameTheme.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: MenuChrome.segmented(
          dense: true,
          labels: labels,
          selectedIndex: selected,
          onSelect: (i) => router.gearPanel = panels[i],
        ),
      ),
    );
  }

  String _gearLabel(GearPanel panel) => switch (panel) {
        GearPanel.gear => 'GEAR',
        GearPanel.bag => 'BAG',
        GearPanel.merge => 'MERGE',
        GearPanel.roster => 'ROSTER',
      };

  Widget _sheet() {
    if (router.route == MenuRoute.essence) {
      return Positioned.fill(
        child: ColoredBox(
          color: GameTheme.panel,
          child: EssenceTilesScreen(director: director, router: router),
        ),
      );
    }
    if (router.route == MenuRoute.map) {
      return Positioned.fill(
        child: ColoredBox(
          color: GameTheme.panel,
          child: MapScreen(director: director, router: router),
        ),
      );
    }
    return MenuSurface(director: director, router: router, home: true);
  }
}
