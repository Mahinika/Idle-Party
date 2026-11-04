import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../game_theme.dart';
import 'home_catalog.dart';
import 'rail_button.dart';

/// MENU grid. Compact chips match the fight seam rail family.
class HomeMenuGrid extends StatelessWidget {
  const HomeMenuGrid({
    super.key,
    required this.director,
    required this.router,
  });

  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final entries = HomeCatalog.of(HomePlace.menuGrid)
        .where((e) => e.visible(state, director))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'MENU',
            style: GameTheme.menuTitle(size: 14, color: GameTheme.parchmentDim),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.6,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => RailButton(
            entry: entries[i],
            state: state,
            director: director,
            router: router,
            compact: true,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: GameTheme.border.withValues(alpha: 0.45)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TIP A FRIEND',
                  style: GameTheme.menuTitle(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 6),
                HomeFriendTip(director: director),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
