import 'package:flutter/material.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../web_click_bridge.dart';

/// TT2-style flat tab bar: equal color blocks with icon + label.
/// Hub: GEAR · GOLD · SHOP · ESSENCE · MORE · (KEY). Dungeon: same five + LEAVE.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.alerts,
    required this.route,
    required this.destinations,
    required this.onSelect,
    this.overflow = const <MenuRoute>[],
    this.onLeave,
    this.showReason = false,
  });

  final MenuAlerts alerts;
  final MenuRoute route;
  final List<MenuRoute> destinations;
  final List<MenuRoute> overflow;
  final void Function(MenuRoute route) onSelect;
  final VoidCallback? onLeave;
  final bool showReason;

  static String labelFor(MenuRoute r) => switch (r) {
    MenuRoute.gear => 'GEAR',
    MenuRoute.gold => 'GOLD',
    MenuRoute.shop => 'SHOP',
    MenuRoute.essence => 'ESSENCE',
    MenuRoute.key => 'KEY',
    MenuRoute.more => 'MORE',
    MenuRoute.none => '',
  };

  static Color slotColorFor(MenuRoute r) => switch (r) {
    MenuRoute.gear => GameTheme.navGear,
    MenuRoute.gold => GameTheme.navGold,
    MenuRoute.shop => GameTheme.navShop,
    MenuRoute.essence => GameTheme.navEssence,
    MenuRoute.key => GameTheme.navKey,
    MenuRoute.more => GameTheme.navMore,
    MenuRoute.none => GameTheme.navMore,
  };

  static Widget iconFor(MenuRoute r, {double size = 18}) => switch (r) {
    MenuRoute.gear => GameIcon.asset(UiIcon.gear, size: size),
    MenuRoute.gold => GameIcon.asset(UiIcon.gold, size: size),
    MenuRoute.shop => GameIcon.asset(UiIcon.star, size: size),
    MenuRoute.essence => GameIcon.asset(UiIcon.essence, size: size),
    MenuRoute.key => GameIcon.asset(UiIcon.key, size: size),
    MenuRoute.more => GameIcon.asset(UiIcon.more, size: size),
    MenuRoute.none => GameIcon.asset(UiIcon.more, size: size),
  };

  MenuAlert _alertFor(MenuRoute r) => switch (r) {
    MenuRoute.gear => alerts.gear,
    MenuRoute.gold => alerts.gold,
    MenuRoute.shop => alerts.shop,
    MenuRoute.essence => alerts.essence,
    MenuRoute.key => alerts.key,
    MenuRoute.more => alerts.more,
    MenuRoute.none => MenuAlert.quiet,
  };

  String _reasonLine() {
    // Already inside a menu: skip that tab's "open X" nudge — the sheet owns
    // status copy. Prefer another destination's alert, else stay quiet so the
    // bar does not stack a second banner under GEAR / GOLD / …
    for (final dest in destinations) {
      if (dest == route) continue;
      final r = _alertFor(dest).reason;
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final slotCount = destinations.length + (onLeave != null ? 1 : 0);
    final dense = slotCount >= 6;
    final reason = _reasonLine();
    final bar = Material(
      color: Colors.transparent,
      child: Container(
        height: dense
            ? GameTheme.bottomNavHeight
            : GameTheme.bottomNavHeight + 4,
        decoration: BoxDecoration(
          color: GameTheme.ink,
          border: Border(
            top: BorderSide(color: GameTheme.borderLit.withValues(alpha: 0.5)),
          ),
          boxShadow: const [
            BoxShadow(
              color: GameTheme.shadowMid,
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(2, dense ? 1 : 2, 2, dense ? 1 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final dest in destinations)
              Expanded(
                child: AppBottomBarItem(
                  label: labelFor(dest),
                  icon: iconFor(dest, size: dense ? 16 : 18),
                  badge: _alertFor(dest).badge,
                  selected: route == dest,
                  fill: slotColorFor(dest),
                  dense: dense,
                  onTap: () => onSelect(dest),
                ),
              ),
            if (onLeave != null)
              Expanded(
                child: AppBottomBarItem(
                  label: 'LEAVE',
                  icon: GameIcon.asset(UiIcon.leave, size: dense ? 16 : 18),
                  selected: false,
                  urgent: true,
                  fill: GameTheme.navLeave,
                  dense: dense,
                  onTap: onLeave!,
                ),
              ),
          ],
        ),
      ),
    );
    final inset = MediaQuery.paddingOf(context).bottom;
    if (!showReason || reason.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: bar,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 3),
            child: Text(
              reason,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 11, color: GameTheme.torchHot),
            ),
          ),
          bar,
        ],
      ),
    );
  }
}

class AppBottomBarItem extends StatelessWidget {
  const AppBottomBarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.fill,
    this.urgent = false,
    this.badge = '',
    this.dense = false,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final bool urgent;
  final String badge;
  final bool dense;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = urgent
        ? GameTheme.accentWarn
        : (selected ? GameTheme.torchHot : GameTheme.parchment);
    final semanticsLabel = badge.isEmpty ? label : '$label $badge waiting';
    final labelSize = dense ? 10.0 : 11.0;
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: selected
                      ? Color.lerp(fill, GameTheme.torch, 0.12)
                      : fill,
                  borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  border: Border.all(
                    color: selected
                        ? GameTheme.torchHot
                        : GameTheme.border.withValues(alpha: 0.45),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: GameTheme.torch.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          SizedBox(height: dense ? 2 : 3),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.body(
                              size: labelSize,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badge.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: NavBadge(text: badge),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavBadge extends StatelessWidget {
  const NavBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: GameTheme.bloodLit,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameTheme.ink, width: 1),
      ),
      child: text == MenuAlert.starMark
          ? GameIcon.asset(UiIcon.star, size: 9, color: GameTheme.parchment)
          : Text(
              text,
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 10, color: GameTheme.parchment),
            ),
    );
  }
}
