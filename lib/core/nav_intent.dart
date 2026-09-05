import 'menu_router.dart';

/// One navigation request: destination plus optional inner segment.
class NavIntent {
  const NavIntent({
    required this.route,
    this.gear,
    this.goldPanel,
    this.essencePanel,
    this.more,
    this.scrollBagFilters = false,
  });

  final MenuRoute route;
  final GearPanel? gear;
  final GoldPanel? goldPanel;
  final EssencePanel? essencePanel;
  final MoreSection? more;
  final bool scrollBagFilters;

  static const NavIntent bagFilters = NavIntent(
    route: MenuRoute.more,
    more: MoreSection.settings,
    scrollBagFilters: true,
  );

  /// Real-money store tab (coming soon).
  static const NavIntent shop = NavIntent(route: MenuRoute.shop);

  static const NavIntent gold = NavIntent(route: MenuRoute.gold);

  /// Gold market (flasks / listings) — under GOLD.
  static const NavIntent market = NavIntent(
    route: MenuRoute.gold,
    goldPanel: GoldPanel.market,
  );

  static const NavIntent essence = NavIntent(route: MenuRoute.essence);

  /// Prestige essence shop — under ESSENCE.
  static const NavIntent essenceShop = NavIntent(
    route: MenuRoute.essence,
    essencePanel: EssencePanel.shop,
  );

  static const NavIntent relics = NavIntent(
    route: MenuRoute.essence,
    essencePanel: EssencePanel.relics,
  );

  static const NavIntent quests = NavIntent(
    route: MenuRoute.more,
    more: MoreSection.quests,
  );
}
