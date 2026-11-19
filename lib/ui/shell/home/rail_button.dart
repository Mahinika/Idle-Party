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
  /// Count pip on the icon corner (SCROLLS tickets, …).
  static const countKey = ValueKey('rail-count');

  const RailButton({
    super.key,
    required this.entry,
    required this.state,
    required this.director,
    required this.router,
    this.compact = false,
    this.listCard = false,
    this.stacked = false,
  });

  final HomeEntry entry;
  final GameState state;
  final GameDirector director;
  final MenuRouter router;

  /// Horizontal chip on the fight seam — icon + short label, no vertical stack.
  final bool compact;

  /// Inside [ShellLayout.card] on the MENU grid — skip outer fill.
  final bool listCard;

  /// With [compact]: icon above the label, filling the width it is given.
  /// The fight seam uses it when the inline chips do not fit (large text).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (!entry.visible(state, director)) return const SizedBox.shrink();
    final timer = entry.timer?.call(state);
    final badge = entry.badge(state);
    if (compact) {
      // A short count rides the icon corner, so the label never cuts it off
      // at 1.45 ("SCROLLS…", polish7 P029). Longer timers stay inline.
      final bigText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final pip =
          bigText &&
              !listCard &&
              timer != null &&
              timer.isNotEmpty &&
              timer.length <= 3
          ? timer
          : null;
      final label = Text(
        timer != null && timer.isNotEmpty && pip == null
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
              if (pip != null)
                Positioned(
                  right: -8,
                  top: -6,
                  child: ExcludeSemantics(
                    child: Container(
                      key: RailButton.countKey,
                      constraints: const BoxConstraints(
                        minWidth: 13,
                        minHeight: 13,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: GameTheme.torch,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: GameTheme.ink),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pip,
                        maxLines: 1,
                        style: GameTheme.hint(
                          color: GameTheme.ink,
                        ).copyWith(height: 1.0),
                      ),
                    ),
                  ),
                )
              else if (badge)
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
          SizedBox(width: listCard ? 6 : (pip != null ? 8 : 4)),
          if (listCard) Expanded(child: label) else label,
        ],
      );
      if (listCard) {
        final semanticsLabel = badge ? '${entry.label}, ready' : entry.label;
        return WebClickScope(
          label: entry.label,
          onPressed: () => entry.open(context, director, router),
          child: Semantics(
            button: true,
            label: semanticsLabel,
            child: InkWell(
              onTap: () => entry.open(context, director, router),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: GameTheme.minTouch,
                ),
                child: Align(alignment: Alignment.centerLeft, child: row),
              ),
            ),
          ),
        );
      }
      if (stacked) {
        return WebClickScope(
          label: entry.label,
          onPressed: () => entry.open(context, director, router),
          child: Semantics(
            button: true,
            label: pip == null ? entry.label : '${entry.label}, $pip',
            child: Material(
              color: GameTheme.panelInset.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: InkWell(
                onTap: () => entry.open(context, director, router),
                borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: GameTheme.minTouch,
                    minHeight: GameTheme.minTouch,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      row.children.first,
                      const SizedBox(height: 2),
                      label,
                    ],
                  ),
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
          label: pip == null ? entry.label : '${entry.label}, $pip',
          child: Material(
            color: GameTheme.panelInset.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: InkWell(
              onTap: () => entry.open(context, director, router),
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                constraints: const BoxConstraints(
                  minWidth: GameTheme.minTouch,
                  minHeight: GameTheme.minTouch,
                ),
                alignment: Alignment.center,
                child: row,
              ),
            ),
          ),
        ),
      );
    }
    final semanticsLabel = badge ? '${entry.label}, ready' : entry.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: WebClickScope(
        label: entry.label,
        onPressed: () => entry.open(context, director, router),
        child: Semantics(
          button: true,
          label: semanticsLabel,
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
