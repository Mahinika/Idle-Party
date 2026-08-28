import 'package:flutter/material.dart';
import '../../core/menu_alerts.dart';
import '../../core/menu_router.dart';
import '../custom_assets.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../web_click_bridge.dart';

/// The one nav row. Hub and dungeon show the same pillars in the same order;
/// the dungeon adds LEAVE (back to hub), the hub does not.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.alerts,
    required this.route,
    required this.onParty,
    required this.onPower,
    required this.onMeta,
    this.onHubClose,
    this.showReason = false,
  });

  /// Shared "something waits here" marks (see [MenuAlerts]).
  final MenuAlerts alerts;
  final MenuRoute route;
  final VoidCallback onParty;
  final VoidCallback onPower;
  final VoidCallback onMeta;

  /// Dungeon only: leaving back to the hub.
  final VoidCallback? onHubClose;

  /// Hub: one plain line saying what is waiting behind a marked button.
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    // FEEL 329: four dungeon pillars (PARTY/POWER/META/LEAVE) need denser labels.
    final dense = onHubClose != null;
    final reason = alerts.party.isQuiet
        ? alerts.meta.reason
        : alerts.party.reason;
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
            Expanded(
              child: AppBottomBarItem(
                label: 'PARTY',
                icon: KenneyAssets.helmet,
                badge: alerts.party.badge,
                selected: route == MenuRoute.party,
                dense: dense,
                onTap: onParty,
              ),
            ),
            Expanded(
              child: AppBottomBarItem(
                label: 'POWER',
                icon: CustomAssets.iconAxe,
                badge: alerts.power.badge,
                selected: route == MenuRoute.power,
                dense: dense,
                onTap: onPower,
              ),
            ),
            Expanded(
              child: AppBottomBarItem(
                label: 'META',
                icon: KenneyAssets.book,
                badge: alerts.meta.badge,
                selected:
                    route == MenuRoute.meta ||
                    route == MenuRoute.settings ||
                    route == MenuRoute.jobs,
                dense: dense,
                onTap: onMeta,
              ),
            ),
            if (onHubClose != null)
              Expanded(
                flex: 2,
                child: AppBottomBarItem(
                  label: 'LEAVE',
                  icon: KenneyAssets.iconDoor,
                  selected: false,
                  urgent: true,
                  dense: dense,
                  onTap: onHubClose!,
                ),
              ),
          ],
        ),
      ),
    );
    if (!showReason || reason.isEmpty) return bar;
    return Column(
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

  /// Small count / star drawn on the icon when something waits inside.
  final String badge;

  /// Tighter icon/label when four dungeon pillars share ~360px.
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
