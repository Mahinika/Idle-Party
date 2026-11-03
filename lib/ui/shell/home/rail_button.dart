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
  });

  final HomeEntry entry;
  final GameState state;
  final GameDirector director;
  final MenuRouter router;

  @override
  Widget build(BuildContext context) {
    if (!entry.visible(state, director)) return const SizedBox.shrink();
    final timer = entry.timer?.call(state);
    final badge = entry.badge(state);
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
