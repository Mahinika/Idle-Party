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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      children: [
        Text('MENU', style: GameTheme.menuTitle(size: 18)),
        const SizedBox(height: 4),
        for (final entry in entries)
          WebClickScope(
            label: entry.label,
            onPressed: () => entry.open(context, director, router),
            child: Semantics(
              button: true,
              label: entry.label,
              child: InkWell(
                onTap: () => entry.open(context, director, router),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: GameTheme.borderLit.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: GameTheme.minTouch,
                    ),
                    child: Row(
                      children: [
                        GameIcon.asset(entry.icon, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.label,
                            style: GameTheme.body(
                              size: 15,
                              color: GameTheme.parchment,
                            ),
                          ),
                        ),
                        if (entry.badge(state)) const _Dot(),
                        const SizedBox(width: 4),
                        Text(
                          '›',
                          style: GameTheme.body(
                            size: 18,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'TIP A FRIEND',
          style: GameTheme.menuTitle(size: 14, color: GameTheme.parchmentDim),
        ),
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
