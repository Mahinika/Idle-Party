import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/menu_router.dart';
import '../feedback_toast.dart';
import '../first_session_tips.dart';
import '../hub_screen.dart';
import '../is2_shell.dart';
import 'menu_surface.dart';
import 'play_nav.dart';

/// Single play-phase owner: hub or dungeon scene, one [MenuSurface], toast.
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
    director.addListener(_onDirector);
    router.addListener(_onRouter);
    _syncPause();
  }

  @override
  void dispose() {
    director.removeListener(_onDirector);
    router.removeListener(_onRouter);
    director.setUiPaused(false);
    super.dispose();
  }

  void _onDirector() {
    final now = director.state.inDungeon;
    if (_inDungeon && !now) {
      router.close();
      final nav = director.takePendingHubNav();
      if (nav != null) router.apply(nav);
    }
    _inDungeon = now;
    _syncPause();
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final inDungeon = director.state.inDungeon;
    return PlayNav(
      router: router,
      onEnterDungeon: (id) {
        router.close();
        director.enterDungeon(dungeonId: id);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (inDungeon)
            Is2Shell(
              director: director,
              router: router,
              pulse: 0.5,
              onLeaveDungeon: _leaveDungeon,
            )
          else
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
        ],
      ),
    );
  }
}
