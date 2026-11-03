import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import 'home_catalog.dart';
import 'rail_button.dart';

/// SCROLLS and the rest, painted over the fight. They do not shrink it.
class FightRails extends StatelessWidget {
  const FightRails({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    return Stack(
      children: [
        Positioned(
          left: 2,
          top: 4,
          bottom: 4,
          child: _rail(HomePlace.leftRail, state),
        ),
        Positioned(
          right: 2,
          top: 4,
          bottom: 4,
          child: _rail(HomePlace.rightRail, state),
        ),
      ],
    );
  }

  Widget _rail(HomePlace place, GameState state) {
    final entries = HomeCatalog.of(place);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries)
            RailButton(
              entry: entry,
              state: state,
              director: director,
              router: router,
            ),
        ],
      ),
    );
  }
}
