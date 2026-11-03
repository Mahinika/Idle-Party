import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../first_session_tips.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';
import '../menu_surface.dart';
import 'camp_viewport.dart';
import 'director_select.dart';
import 'essence_tiles_screen.dart';
import 'fight_viewport.dart';
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
      router.close();
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
        if (FirstSessionTips.active(state, inDungeon: state.inDungeon)
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    flex: showPanel && !full ? 1 : 5,
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
                    Expanded(
                      flex: full ? 1 : 1,
                      child: RepaintBoundary(
                        child: DirectorSelect<int>(
                          director: director,
                          select: (s) => s.gold + s.essence,
                          builder: (context, _) => UpgradePanel(
                            director: director,
                            router: router,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (sheet) _sheet(),
              const IgnorePointer(child: SizedBox.shrink()),
              HomePromptHost(director: director, router: router),
            ],
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
    return Align(
      alignment: Alignment.centerLeft,
      child: WebClickScope(
        label: 'Back',
        onPressed: () {
          router.back();
        },
        child: Semantics(
          button: true,
          label: 'Back',
          child: InkWell(
            onTap: () {
              router.back();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon.glyph(UiGlyph.prev, size: 16),
                  SizedBox(width: 4),
                  Text('Back'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gearThumb(GameState state) {
    final panels = MenuRouter.visibleGearPanels(state);
    return Material(
      color: GameTheme.stone,
      child: SizedBox(
      height: GameTheme.minTouch,
      child: Row(
        children: [
          for (final panel in panels)
            Expanded(
              child: WebClickScope(
                label: _gearLabel(panel),
                onPressed: () => router.gearPanel = panel,
                child: InkWell(
                  onTap: () => router.gearPanel = panel,
                  child: Center(
                    child: Text(
                      _gearLabel(panel),
                      style: GameTheme.menuTitle(
                        size: 11,
                        color: router.gearPanel == panel
                            ? GameTheme.torchHot
                            : GameTheme.parchment,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
