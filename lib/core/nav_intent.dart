import 'menu_router.dart';

/// One navigation request: destination plus optional inner segment.
class NavIntent {
  const NavIntent({
    required this.route,
    this.gear,
    this.goldPanel,
    this.essencePanel,
    this.more,
    this.mapEndgame = false,
  });

  final MenuRoute route;
  final GearPanel? gear;
  final GoldPanel? goldPanel;
  final EssencePanel? essencePanel;
  final MoreSection? more;

  /// Home MAP opens on ENDGAME instead of PATH.
  final bool mapEndgame;

  static const NavIntent gold = NavIntent(route: MenuRoute.gold);

  /// Gold market (flasks / listings) — under GOLD.
  static const NavIntent market = NavIntent(
    route: MenuRoute.gold,
    goldPanel: GoldPanel.market,
  );

  static const NavIntent quests = NavIntent(
    route: MenuRoute.more,
    more: MoreSection.quests,
  );

  /// Hub ENDGAME hunts (Gauntlet, Farm Rift, Ranked GR, Ashen).
  static const NavIntent endgame = NavIntent(
    route: MenuRoute.map,
    mapEndgame: true,
  );
}
