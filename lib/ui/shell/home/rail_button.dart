import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_router.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';
import 'home_catalog.dart';

/// One rail or menu icon: picture, label, optional timer, optional red dot.
class RailButton extends StatelessWidget {
  const RailButton({
    super.key,
    required this.entry,
    required this.state,
    required this.director,
    required this.router,
    this.compact = false,
  });

  final HomeEntry entry;
  final GameState state;
  final GameDirector director;
  final MenuRouter router;

  /// Horizontal chip on the fight seam — icon + short label, no vertical stack.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!entry.visible(state, director)) return const SizedBox.shrink();
    final timer = entry.timer?.call(state);
    final badge = entry.badge(state);
    if (compact) {
      return WebClickScope(
        label: entry.label,
        onPressed: () => entry.open(context, director, router),
        child: Semantics(
          button: true,
          label: entry.label,
          child: Material(
            color: GameTheme.panelInset.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: InkWell(
              onTap: () => entry.open(context, director, router),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GameIcon.asset(entry.icon, size: 18),
                        if (badge)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: GameTheme.hudHpDamage,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timer != null && timer.isNotEmpty
                          ? '${entry.label} $timer'
                          : entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: 7,
                        color: GameTheme.parchment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: WebClickScope(
        label: entry.label,
        onPressed: () => entry.open(context, director, router),
        child: Semantics(
          button: true,
          label: entry.label,
          child: InkWell(
            onTap: () => entry.open(context, director, router),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: GameTheme.minTouch,
                minHeight: GameTheme.minTouch,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GameIcon.asset(entry.icon, size: 22),
                      if (badge)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: GameTheme.hudHpDamage,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.pixel(
                      size: 8,
                      color: GameTheme.parchment,
                    ),
                  ),
                  if (timer != null && timer.isNotEmpty)
                    Text(
                      timer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: 7,
                        color: GameTheme.torchHot,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
