import 'package:flutter/material.dart';

import '../../../core/ashen_crown.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../menu_chrome.dart';
import '../../chunky_face.dart';
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
    // Keep the labels above the gesture inset without stacking a full extra
    // bar on a short phone. A tall bar already has room for the inset.
    final labelH = HomeNavBar.labelHeight(context);
    final fightD = HomeNavBar.fightDiameter(scale);
    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: labelH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: GameTheme.buyGreyEdge),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _tab(MenuRoute.gear, 'HEROES', UiIcon.gear),
                        ),
                        Expanded(
                          child: essence
                              ? _tab(
                                  MenuRoute.essence,
                                  'ESSENCE',
                                  UiIcon.essence,
                                )
                              : _locked('ESSENCE', _essenceHint()),
                        ),
                        // The round FIGHT sits over this slot.
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(
                          child: map
                              ? _tab(
                                  MenuRoute.map,
                                  'MAP',
                                  UiIcon.map,
                                  timer: _mapTimer(),
                                )
                              : _locked('MAP', _bossHint),
                        ),
                        Expanded(
                          child: shop
                              ? _tab(MenuRoute.shop, 'SHOP', UiIcon.shop)
                              : _locked('SHOP', _bossHint),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  // Rise over the bar. The rim may dip into the gesture
                  // inset a little; the FIGHT label stays above it.
                  top: -HomeNavBar.fightOverhang(context),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: fightD,
                      height: fightD,
                      child: _fight(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: inset),
        ],
      ),
    );
  }

  /// FIGHT rises this far above the bar.
  static const double fightLift = 8;

  /// About 68 dp; grows only past the in-app text ceiling (raw OS scale).
  static double labelHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final inset = MenuChrome.systemBottomInset(context);
    final grown = GameTheme.navBarExtent(scale);
    return grown - inset > 40 ? grown - inset : 40.0;
  }

  /// How far the round FIGHT reaches above the bar. Lists that end at the
  /// bar pad their last row by this much ([NavClearance]).
  static double fightOverhang(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final rise = fightDiameter(scale) - labelHeight(context) - 10;
    return rise > fightLift ? rise : fightLift;
  }

  static double fightDiameter(double textScale) {
    const base = 56.0;
    if (textScale <= GameTheme.typeScaleMax) return base;
    return base * textScale / GameTheme.typeScaleMax;
  }

  static const String _bossHint = 'Boss F2';

  String _essenceHint() =>
      MenuTabs.showGold(state) ? '1st essence' : _bossHint;

  /// A padlock and what opens it, so the slot is never blank.
  Widget _locked(String label, String hint) {
    return Semantics(
      label: '$label locked · $hint',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
        child: Opacity(
          opacity: 0.75,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GameIcon.glyph(
                UiGlyph.lock,
                size: 18,
                color: GameTheme.buyGreyText,
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  hint,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.buyGreyText),
                ),
              ),
            ],
          ),
        ),
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
    final tone = open ? ChunkyTone.stone : ChunkyTone.gold;
    final (top, bottom, shine, edge) = ChunkyFace.colorsFor(tone);
    final ink = open ? GameTheme.parchment : ChunkyFace.textOn(tone);
    return WebClickScope(
      label: 'FIGHT',
      onPressed: router.close,
      child: Semantics(
        button: true,
        selected: !open,
        label: 'FIGHT',
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: router.close,
            customBorder: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [shine, top, bottom],
                  stops: const [0, 0.18, 1],
                ),
                border: Border.all(
                  color: open ? edge : GameTheme.torchHot,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GameIcon.asset(UiIcon.sword, size: 20),
                  Text(
                    'FIGHT',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(size: GameTheme.typeHint, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Screen-reader label of a nav tab. The open tab keeps its name and says
  /// how to close it (audit F045: the label used to swap to CLOSE).
  static String tabSemantics(String label, {required bool selected}) =>
      selected ? '$label, selected. Tap to close' : label;

  Widget _tab(MenuRoute route, String label, String icon, {String? timer}) {
    final selected = router.route == route;
    final alert = !selected && _alert(route);
    return _button(
      label: selected ? 'Close $label' : label,
      semantics: tabSemantics(label, selected: selected),
      selected: selected,
      onTap: () {
        if (selected) {
          router.close();
        } else {
          router.open(route);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GameIcon.asset(icon, size: 20),
              if (alert)
                const Positioned(
                  right: -3,
                  top: -3,
                  child: _Dot(),
                ),
              // Small close mark on the lit tab: tap again closes.
              if (selected)
                Positioned(
                  right: -6,
                  top: -5,
                  child: ExcludeSemantics(
                    child: GameIcon.asset(UiIcon.closeTab, size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Flexible(
            child: ExcludeSemantics(
              excluding: selected,
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GameTheme.body(
                  size: GameTheme.typeHint,
                  color: selected
                      ? GameTheme.toggleOnText
                      : GameTheme.parchment,
                ),
              ),
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
        explicitChildNodes: selected,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            // The frame paints over the slot so the label keeps its width.
            decoration: BoxDecoration(
              // Lit plum face on the open tab (dusk palette, F045).
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        GameTheme.toggleOnShine,
                        GameTheme.toggleOnTop,
                        GameTheme.toggleOnBottom,
                      ],
                      stops: [0, 0.08, 1],
                    )
                  : null,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              border: Border.all(
                color: selected ? GameTheme.toggleOnAccent : Colors.transparent,
                width: 1,
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
