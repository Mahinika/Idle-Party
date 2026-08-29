import 'package:flutter/material.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../custom_assets.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../web_click_bridge.dart';

/// Flat tab bottom bar. Hub: GEAR · POWER · (KEY) · QUESTS · MORE.
/// Dungeon: GEAR · POWER · QUESTS · overflow (KEY/MORE) · LEAVE.
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
    MenuRoute.power => 'POWER',
    MenuRoute.quests => 'QUESTS',
    MenuRoute.key => 'KEY',
    MenuRoute.more => 'MORE',
    MenuRoute.none => '',
  };

  static String iconFor(MenuRoute r) => switch (r) {
    MenuRoute.gear => KenneyAssets.helmet,
    MenuRoute.power => CustomAssets.iconAxe,
    MenuRoute.quests => CustomAssets.iconTrophy,
    MenuRoute.key => KenneyAssets.chestClosed,
    MenuRoute.more => CustomAssets.iconBook,
    MenuRoute.none => KenneyAssets.book,
  };

  MenuAlert _alertFor(MenuRoute r) => switch (r) {
    MenuRoute.gear => alerts.gear,
    MenuRoute.power => alerts.power,
    MenuRoute.quests => alerts.quests,
    MenuRoute.key => alerts.key,
    MenuRoute.more => alerts.more,
    MenuRoute.none => MenuAlert.quiet,
  };

  String _reasonLine() {
    if (route != MenuRoute.none) {
      final selected = _alertFor(route).reason;
      if (selected.isNotEmpty) return selected;
    }
    for (final dest in destinations) {
      final r = _alertFor(dest).reason;
      if (r.isNotEmpty) return r;
    }
    for (final dest in overflow) {
      final r = _alertFor(dest).reason;
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  MenuRoute _overflowDisplayRoute() {
    if (overflow.contains(route)) return route;
    if (overflow.contains(MenuRoute.more)) return MenuRoute.more;
    return overflow.first;
  }

  MenuAlert _overflowAlert() {
    if (overflow.contains(route)) return _alertFor(route);
    for (final dest in overflow) {
      final a = _alertFor(dest);
      if (!a.isQuiet) return a;
    }
    return MenuAlert.quiet;
  }

  void _tapOverflow() {
    if (overflow.contains(route)) {
      onSelect(route);
      return;
    }
    onSelect(
      overflow.contains(MenuRoute.more) ? MenuRoute.more : overflow.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotCount =
        destinations.length +
        (overflow.isEmpty ? 0 : 1) +
        (onLeave != null ? 1 : 0);
    final dense = slotCount >= 5;
    final reason = _reasonLine();
    final bar = Material(
      color: Colors.transparent,
      child: Container(
        height: GameTheme.bottomNavHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GameTheme.stone.withValues(alpha: 0.96),
              GameTheme.ink.withValues(alpha: 0.98),
            ],
          ),
          border: Border(
            top: BorderSide(color: GameTheme.borderLit.withValues(alpha: 0.35)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final dest in destinations)
              Expanded(
                child: AppBottomBarItem(
                  label: labelFor(dest),
                  icon: iconFor(dest),
                  badge: _alertFor(dest).badge,
                  selected: route == dest,
                  dense: dense,
                  onTap: () => onSelect(dest),
                ),
              ),
            if (overflow.isNotEmpty)
              Expanded(
                child: AppBottomBarItem(
                  label: labelFor(_overflowDisplayRoute()),
                  icon: iconFor(_overflowDisplayRoute()),
                  badge: _overflowAlert().badge,
                  selected: overflow.contains(route),
                  dense: dense,
                  onTap: _tapOverflow,
                ),
              ),
            if (onLeave != null)
              Expanded(
                flex: destinations.length >= 4 ? 1 : 2,
                child: AppBottomBarItem(
                  label: 'LEAVE',
                  icon: KenneyAssets.iconDoor,
                  selected: false,
                  urgent: true,
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
            padding: const EdgeInsets.only(bottom: 3),
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
    this.urgent = false,
    this.badge = '',
    this.dense = false,
  });

  final String label;
  final String icon;
  final bool selected;
  final bool urgent;
  final String badge;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? GameTheme.accentWarn
        : (selected ? GameTheme.torchHot : GameTheme.parchmentDim);
    final semanticsLabel = badge.isEmpty ? label : '$label $badge waiting';
    final iconSize = dense ? 16.0 : 18.0;
    final labelSize = dense ? 11.0 : 12.0;
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: GameTheme.minTouch + 8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 6 : 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? GameTheme.torch.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  ),
                  child: badge.isEmpty
                      ? KenneySprite(asset: icon, size: iconSize)
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KenneySprite(asset: icon, size: iconSize),
                            Positioned(
                              right: -7,
                              top: -6,
                              child: NavBadge(text: badge),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: labelSize, color: color),
                ),
              ],
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
      constraints: const BoxConstraints(minWidth: 15),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: GameTheme.torchHot,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameTheme.ink, width: 1),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GameTheme.body(size: 10, color: GameTheme.ink),
      ),
    );
  }
}
