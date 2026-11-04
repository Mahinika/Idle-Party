import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../game_theme.dart';
import 'home_catalog.dart';
import 'rail_button.dart';

/// SCROLLS, QUESTS, and the rest — under the party row, not over the cave.
class FightSeamRails extends StatelessWidget {
  const FightSeamRails({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  static List<HomeEntry> visibleEntries(
    GameState state,
    GameDirector director,
  ) {
    final out = <HomeEntry>[
      ...HomeCatalog.of(HomePlace.leftRail),
      ...HomeCatalog.of(HomePlace.rightRail),
    ];
    out.retainWhere((e) => e.visible(state, director));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final entries = visibleEntries(state, director);
    if (entries.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: GameTheme.border.withValues(alpha: 0.45)),
        ),
      ),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(width: 4),
          itemBuilder: (context, i) => RailButton(
            entry: entries[i],
            state: state,
            director: director,
            router: router,
            compact: true,
          ),
        ),
      ),
    );
  }
}
