import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../is2_shell.dart';
import 'fight_seam.dart';
import 'home_fight_tools.dart';

/// The cave picture. The seam sits under it, outside this flex.
class FightViewport extends StatelessWidget {
  const FightViewport({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
    this.controls = false,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

  /// FARM / PUSH, fist, LEAVE on the bottom edge (home panel open).
  final bool controls;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Is2Shell(
          director: director,
          router: router,
          pulse: 0.5,
          onLeaveDungeon: onLeave,
          homeChrome: true,
          extraBottomInset: controls ? FightFieldControls.cameraReserve : 0,
        ),
        HomeFightTools(
          director: director,
          seamClearance: controls ? FightFieldControls.cameraReserve + 24 : 108,
        ),
        if (controls)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: director,
              builder: (context, _) => FightFieldControls(
                director: director,
                router: router,
                onLeave: onLeave,
              ),
            ),
          ),
      ],
    );
  }
}
