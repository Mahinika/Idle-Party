import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/hub_chase.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../confirm_dialogs.dart';
import '../feedback_toast.dart';
import '../first_session_tips.dart';
import '../hub_screen.dart';
import '../is2_shell.dart';
import 'app_bottom_bar.dart';
import 'menu_surface.dart';
import 'play_nav.dart';

/// Single play-phase owner: hub or dungeon scene, one [MenuSurface], toast,
/// and one shared bottom nav (TT2-style — bar always visible above home).
class PlayShell extends StatefulWidget {
  const PlayShell({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  State<PlayShell> createState() => _PlayShellState();
}

class _PlayShellState extends State<PlayShell> {
  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;
  late bool _inDungeon;

  @override
  void initState() {
    super.initState();
    _inDungeon = director.state.inDungeon;
    router.addListener(_onRouter);
    _syncPause();
  }

  @override
  void didUpdateWidget(covariant PlayShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != router) {
      oldWidget.router.removeListener(_onRouter);
      router.addListener(_onRouter);
    }
    final now = director.state.inDungeon;
    if (_inDungeon && !now) {
      router.close();
      final nav = director.takePendingHubNav();
      if (nav != null) router.apply(nav);
    }
    if (_inDungeon != now) {
      _inDungeon = now;
      _syncPause();
    }
  }

  @override
  void dispose() {
    router.removeListener(_onRouter);
    director.setUiPaused(false);
    super.dispose();
  }

  void _onRouter() {
    _syncPause();
    if (mounted) setState(() {});
  }

  void _syncPause() {
    director.setUiPaused(router.isOpen && director.state.inDungeon);
  }

  void _leaveDungeon() {
    router.close();
    director.leaveDungeon();
  }

  void _openMenuFeel(VoidCallback open) {
    final state = director.state;
    final wasOpen = router.isOpen;
    open();
    if (!wasOpen &&
        router.isOpen &&
        state.inDungeon &&
        !state.isPartyDefeated) {
      director.showToast(
        'Fight paused in menu — close to resume',
        life: 1.6,
      );
    }
  }

  Widget _bottomBar() {
    final state = director.state;
    if (state.inDungeon) {
      final graph = DestinationGraph.dungeon(state);
      return AppBottomBar(
        alerts: MenuAlerts.forDungeon(state),
        route: router.route,
        destinations: graph.destinations,
        showReason: true,
        onSelect: (dest) => _openMenuFeel(() => router.toggle(dest)),
        onLeave: () {
          if (state.isPartyDefeated) {
            director.hubAfterWipe();
            return;
          }
          confirmLeaveDungeon(
            context,
            _leaveDungeon,
            state: state,
          );
        },
      );
    }
    final chase = HubChase.forState(state);
    return AppBottomBar(
      alerts: MenuAlerts.forHub(
        state,
        chaseKind: chase.kind,
        urgency: chase.urgency,
      ),
      route: router.route,
      destinations: DestinationGraph.hub(state).destinations,
      // Reason line self-hides when empty; READY chase quiets non-chase alerts.
      showReason: true,
      onSelect: router.toggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inDungeon = director.state.inDungeon;
    final tipsAndMenus = <Widget>[
      if (!router.isOpen || inDungeon) FirstSessionTips(director: director),
      MenuSurface(director: director, router: router),
      if (director.toast != null)
        Positioned.fill(
          child: FeedbackToast(
            message: director.toast!,
            maxLines: inDungeon ? 2 : 3,
            alignment: inDungeon
                ? (router.isOpen
                      ? const Alignment(0, -0.82)
                      : const Alignment(0, -0.42))
                : const Alignment(0, -0.55),
          ),
        ),
    ];

    return PopScope(
      canPop: !router.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (router.isOpen) router.close();
      },
      child: PlayNav(
        router: router,
        onEnterDungeon: (id) {
          router.close();
          director.enterDungeon(dungeonId: id);
        },
        // Dungeon: map full-bleed under the bottom bar; menus stay above it.
        // Hub: bar sits below the scene (World Path must not hide under tabs).
        child: inDungeon
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Is2Shell(
                    director: director,
                    router: router,
                    pulse: 0.5,
                    onLeaveDungeon: _leaveDungeon,
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: tipsAndMenus,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: router,
                        builder: (context, _) => _bottomBar(),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: router.isOpen,
                          child: HubScreen(
                            director: director,
                            router: router,
                            onEnterDungeon: (id) {
                              router.close();
                              director.enterDungeon(dungeonId: id);
                            },
                          ),
                        ),
                        ...tipsAndMenus,
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: router,
                    builder: (context, _) => _bottomBar(),
                  ),
                ],
              ),
      ),
    );
  }
}
