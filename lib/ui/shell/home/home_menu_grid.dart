import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../game_theme.dart';
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

  /// Width / height of one half-row tile.
  static const double tileAspect = 3.2;

  /// Shortest row: a 44 dp tap target plus the card padding and rim.
  static const double minRowHeight = GameTheme.minTouch + 14;

  /// Row of an odd last tile that spans the full width.
  static const Key lastWideKey = ValueKey('home_menu_grid_last_wide');

  /// Sheet subtitle under the MENU title.
  static const String hint = 'Settings, guides, and the rest.';

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final entries = HomeCatalog.of(HomePlace.menuGrid)
        .where((e) => e.visible(state, director))
        .toList();
    Widget cell(int i) => ShellLayout.card(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: RailButton(
            entry: entries[i],
            state: state,
            director: director,
            router: router,
            compact: true,
            listCard: true,
          ),
        );
    // The sheet header carries the MENU title (audit F078). Tiles go in pairs;
    // an odd last tile spans the full row instead of leaving a hole (F079).
    return ListView(
      padding: ShellLayout.listPadding,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            const gap = ShellLayout.sectionGap;
            final cellW = (c.maxWidth - gap) / 2;
            // Never below a 44 dp tap inside the card's 6 dp padding.
            final h = math.max(cellW / tileAspect, minRowHeight);
            final rows = <Widget>[];
            for (var i = 0; i < entries.length; i += 2) {
              if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
              final pair = i + 1 < entries.length;
              rows.add(
                SizedBox(
                  key: pair ? null : lastWideKey,
                  height: h,
                  child: pair
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cell(i)),
                            const SizedBox(width: gap),
                            Expanded(child: cell(i + 1)),
                          ],
                        )
                      : cell(i),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            );
          },
        ),
      ],
    );
  }
}
