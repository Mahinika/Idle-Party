import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../shell_layout.dart';
import 'rail_button.dart';
import 'home_catalog.dart';

/// MENU grid. List cards match sheet rows ([ShellLayout.card]).
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
      padding: ShellLayout.listPadding,
      children: [
        ShellLayout.sectionHeader('MENU'),
        ShellLayout.gap(4),
        ShellLayout.hint(
          'Settings, guides, and the rest.',
          maxLines: 2,
        ),
        ShellLayout.gap(8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: ShellLayout.sectionGap,
            crossAxisSpacing: ShellLayout.sectionGap,
            childAspectRatio: 3.2,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => ShellLayout.card(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: RailButton(
              entry: entries[i],
              state: state,
              director: director,
              router: router,
              compact: true,
              listCard: true,
            ),
          ),
        ),
      ],
    );
  }
}
