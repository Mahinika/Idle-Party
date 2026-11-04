import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../is2_shell.dart';

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
    return Is2Shell(
      director: director,
      router: router,
      pulse: 0.5,
      onLeaveDungeon: onLeave,
      homeChrome: true,
    );
  }
}
