import 'package:flutter/material.dart';
import '../../core/menu_alerts.dart';
import '../custom_assets.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../web_click_bridge.dart';

enum BottomNavTab { none, gear, bag, more, party, power, meta }

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, 
    required this.stashCount,
    required this.active,
    required this.onGear,
    required this.onBag,
    required this.onMore,
    this.stashCap,
    this.hubPillars = false,
    this.alerts = MenuAlerts.none,
    this.onParty,
    this.onPower,
    this.onMeta,
    this.onHubClose,
  });

  final int stashCount;
  final int? stashCap;

  /// Shared "something waits here" marks (see [MenuAlerts]).
  final MenuAlerts alerts;
  final BottomNavTab active;
  final VoidCallback onGear;
  final VoidCallback onBag;
  final VoidCallback onMore;
  /// Unified pillars: PARTY / POWER / META / HUB (hub shell + dungeon).
  final bool hubPillars;
  final VoidCallback? onParty;
  final VoidCallback? onPower;
  final VoidCallback? onMeta;
  final VoidCallback? onHubClose;

  @override
  Widget build(BuildContext context) {
    final full = stashCap != null && stashCount >= stashCap!;
    final nearlyFull = !full &&
        stashCap != null &&
        stashCount >= (stashCap! * 0.9).ceil();
    final bagLabel = stashCap == null
        ? 'BAG $stashCount'
        : full
            ? 'BAG FULL $stashCount/$stashCap'
            : nearlyFull
                ? 'BAG $stashCount/$stashCap!'
                : 'BAG $stashCount/$stashCap';
    return Material(
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
            top: BorderSide(
              color: GameTheme.borderLit.withValues(alpha: 0.35),
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: hubPillars
            ? Row(
                children: [
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'PARTY',
                      icon: KenneyAssets.helmet,
                      badge: alerts.party.badge,
                      selected: active == BottomNavTab.party ||
                          active == BottomNavTab.gear ||
                          active == BottomNavTab.bag,
                      onTap: onParty ?? onGear,
                    ),
                  ),
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'POWER',
                      icon: CustomAssets.iconAxe,
                      badge: alerts.power.badge,
                      selected: active == BottomNavTab.power,
                      onTap: onPower ?? onMore,
                    ),
                  ),
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'META',
                      icon: KenneyAssets.book,
                      badge: alerts.meta.badge,
                      selected: active == BottomNavTab.meta,
                      onTap: onMeta ?? onMore,
                    ),
                  ),
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'HUB',
                      icon: KenneyAssets.iconDoor,
                      selected: false,
                      onTap: onHubClose ?? onMore,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'GEAR',
                      icon: KenneyAssets.iconSword,
                      selected: active == BottomNavTab.gear,
                      onTap: onGear,
                    ),
                  ),
                  Expanded(
                    child: AppBottomBarItem(
                      label: bagLabel,
                      icon: KenneyAssets.chestClosed,
                      selected: active == BottomNavTab.bag,
                      urgent: full || nearlyFull,
                      onTap: onBag,
                    ),
                  ),
                  Expanded(
                    child: AppBottomBarItem(
                      label: 'MORE',
                      icon: KenneyAssets.iconDoor,
                      selected: active == BottomNavTab.more,
                      onTap: onMore,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppBottomBarItem extends StatelessWidget {
  const AppBottomBarItem({super.key, 
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.urgent = false,
    this.badge = '',
  });

  final String label;
  final String icon;
  final bool selected;
  final bool urgent;

  /// Small count / star drawn on the icon when something waits inside.
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? GameTheme.accentWarn
        : (selected ? GameTheme.torchHot : GameTheme.parchmentDim);
    final semanticsLabel = badge.isEmpty ? label : '$label $badge waiting';
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
            height: GameTheme.minTouch + 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? GameTheme.torch.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                  ),
                  child: badge.isEmpty
                      ? KenneySprite(asset: icon, size: 18)
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KenneySprite(asset: icon, size: 18),
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
                  style: GameTheme.body(size: 13, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab controller whose length can grow as menus unlock (progressive tabs).

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
