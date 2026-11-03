import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../is2_shell.dart';
import 'fight_rails.dart';
import 'fight_seam.dart';

/// The fight, with home chrome hidden and the seam under the picture.
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
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Is2Shell(
                director: director,
                router: router,
                pulse: 0.5,
                onLeaveDungeon: onLeave,
                homeChrome: true,
              ),
              FightRails(director: director, router: router),
            ],
          ),
        ),
        FightSeam(director: director, router: router, onLeave: onLeave),
      ],
    );
  }
}
