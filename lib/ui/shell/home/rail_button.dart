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
    this.listCard = false,
  });

  final HomeEntry entry;
  final GameState state;
  final GameDirector director;
  final MenuRouter router;

  /// Horizontal chip on the fight seam — icon + short label, no vertical stack.
  final bool compact;

  /// Inside [ShellLayout.card] on the MENU grid — skip outer fill.
  final bool listCard;

  @override
  Widget build(BuildContext context) {
    if (!entry.visible(state, director)) return const SizedBox.shrink();
    final timer = entry.timer?.call(state);
    final badge = entry.badge(state);
    if (compact) {
      final label = Text(
        timer != null && timer.isNotEmpty
            ? '${entry.label} $timer'
            : entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.readable(color: GameTheme.parchment),
      );
      final row = Row(
        mainAxisSize: listCard ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GameIcon.asset(
                entry.icon,
                size: listCard ? GameTheme.iconNav : GameTheme.iconList,
              ),
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
          SizedBox(width: listCard ? 6 : 4),
          if (listCard) Expanded(child: label) else label,
        ],
      );
      if (listCard) {
        return WebClickScope(
          label: entry.label,
          onPressed: () => entry.open(context, director, router),
          child: Semantics(
            button: true,
            label: entry.label,
            child: InkWell(
              onTap: () => entry.open(context, director, router),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: row,
                ),
              ),
            ),
          ),
        );
      }
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                child: row,
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
                    style: GameTheme.hint(color: GameTheme.parchment),
                  ),
                  if (timer != null && timer.isNotEmpty)
                    Text(
                      timer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.hint(color: GameTheme.torchHot),
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
