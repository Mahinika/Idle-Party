import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../is2_shell.dart';
import '../dungeon_top_hud.dart';
import 'floor_jump_sheet.dart';
import 'home_fight_tools.dart';

/// The cave picture. The seam sits under it, outside this flex.
class FightViewport extends StatelessWidget {
  const FightViewport({
    super.key,
    required this.director,
    required this.router,
    required this.onLeave,
  });

  final GameDirector director;
  final MenuRouter router;
  final VoidCallback onLeave;

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
        ),
        Positioned(
          left: 8,
          top: 2,
          right: 78,
          child: ListenableBuilder(
            listenable: director,
            builder: (context, _) => DungeonTopHud(
              state: director.state,
              director: director,
              placeLineOnly: true,
              onOpenSettings: () {},
              onOpenContracts: () {},
              onFloorLineTap: (ctx) => showFloorJumpSheet(ctx, director),
            ),
          ),
        ),
        HomeFightTools(director: director, seamClearance: 108),
      ],
    );
  }
}
