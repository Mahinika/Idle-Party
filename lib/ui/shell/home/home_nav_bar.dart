import 'package:flutter/material.dart';

import '../../../core/ashen_crown.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../menu_chrome.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';

/// HEROES · ESSENCE · FIGHT · MAP · SHOP. The open tab shows icon_close_tab.
class HomeNavBar extends StatelessWidget {
  const HomeNavBar({
    super.key,
    required this.state,
    required this.router,
    this.alerts,
  });

  final GameState state;
  final MenuRouter router;
  final MenuAlerts? alerts;

  @override
  Widget build(BuildContext context) {
    final tabs = MenuRouter.visibleHomeTabs(state);
    final essence = tabs.contains(MenuRoute.essence);
    final map = tabs.contains(MenuRoute.map);
    final shop = tabs.contains(MenuRoute.shop);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final inset = MenuChrome.systemBottomInset(context);
    final grown = GameTheme.navBarExtent(scale);
    // Keep the labels above the gesture inset without stacking a full extra
    // bar on a short phone. A tall bar already has room for the inset.
    final labelH = grown - inset > 40 ? grown - inset : 40.0;
    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
        height: labelH,
        child: Row(
          children: [
            Expanded(child: _tab(MenuRoute.gear, 'HEROES', UiIcon.gear)),
            Expanded(
              child: essence
                  ? _tab(MenuRoute.essence, 'ESSENCE', UiIcon.essence)
                  : const SizedBox.shrink(),
            ),
            Expanded(child: _fight()),
            Expanded(
              child: map
                  ? _tab(
                      MenuRoute.map,
                      'MAP',
                      UiIcon.map,
                      timer: _mapTimer(),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: shop
                  ? _tab(MenuRoute.shop, 'SHOP', UiIcon.shop)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
          ),
          SizedBox(height: inset),
        ],
      ),
    );
  }

  String? _mapTimer() {
    if (!AshenCrown.canEnter(state)) return null;
    final left = state.metaDepth.worldBossTickets;
    if (left <= 0) return null;
    return '$left';
  }

  Widget _fight() {
    final open = router.route != MenuRoute.none;
    return _button(
      label: 'FIGHT',
      semantics: 'FIGHT',
      selected: !open,
      onTap: router.close,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GameIcon.asset(UiIcon.sword, size: 24),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              'FIGHT',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.readable(color: open ? GameTheme.parchment : GameTheme.torchHot),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(MenuRoute route, String label, String icon, {String? timer}) {
    final selected = router.route == route;
    final alert = _alert(route);
    return _button(
      label: selected ? 'Close $label' : label,
      semantics: selected ? 'Close $label' : label,
      selected: selected,
      onTap: () {
        if (selected) {
          router.close();
        } else {
          router.open(route);
        }
      },
      child: selected
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameIcon.asset(UiIcon.closeTab, size: 24),
                const SizedBox(height: 2),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      'CLOSE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.readable(color: GameTheme.torchHot),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GameIcon.asset(icon, size: GameTheme.iconNav),
                    if (alert)
                      const Positioned(
                        right: -3,
                        top: -3,
                        child: _Dot(),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.readable(color: GameTheme.parchment),
                  ),
                ),
                if (timer != null)
                  Text(
                    timer,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
              ],
            ),
    );
  }

  bool _alert(MenuRoute route) {
    final alerts = this.alerts;
    if (alerts == null) return false;
    final mark = switch (route) {
      MenuRoute.gear => alerts.gear,
      MenuRoute.shop => alerts.shop,
      MenuRoute.essence => alerts.essence,
      MenuRoute.map => alerts.more,
      _ => MenuAlert.quiet,
    };
    return !mark.isQuiet;
  }

  Widget _button({
    required String label,
    required String semantics,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: selected
                  ? GameTheme.torch.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border(
                top: BorderSide(
                  color: selected
                      ? GameTheme.torchHot
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: child,
              ),
            ),
          ),
        ),
      ),
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
