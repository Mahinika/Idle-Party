import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/menu_router.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';
import 'home_catalog.dart';

/// MENU grid. A row opens its sheet one level deeper.
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
      padding: const EdgeInsets.all(12),
      children: [
        Text('MENU', style: GameTheme.menuTitle(size: 18)),
        const SizedBox(height: 8),
        for (final entry in entries)
          WebClickScope(
            label: entry.label,
            onPressed: () => entry.open(context, director, router),
            child: Semantics(
              button: true,
              label: entry.label,
              child: InkWell(
                onTap: () => entry.open(context, director, router),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
                  child: Row(
                    children: [
                      GameIcon.asset(entry.icon, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: GameTheme.body(size: 14, color: GameTheme.parchment),
                        ),
                      ),
                      if (entry.badge(state)) const _Dot(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('TIP A FRIEND', style: GameTheme.menuTitle(size: 14)),
        HomeFriendTip(director: director),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: GameTheme.hudHpDamage,
        shape: BoxShape.circle,
      ),
    );
  }
}
