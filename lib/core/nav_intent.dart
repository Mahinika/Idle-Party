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

  /// Real-money store tab (catalog live; billing soon).
  static const NavIntent shop = NavIntent(route: MenuRoute.shop);

  static const NavIntent gold = NavIntent(route: MenuRoute.gold);

  /// Gold market (flasks / listings) — under GOLD.
  static const NavIntent market = NavIntent(
    route: MenuRoute.gold,
    goldPanel: GoldPanel.market,
  );

  static const NavIntent essence = NavIntent(route: MenuRoute.essence);

  /// KEEP (Blessing / God Hand / REBORN) — under ESSENCE.
  static const NavIntent essenceKeep = NavIntent(
    route: MenuRoute.essence,
    essencePanel: EssencePanel.keep,
  );

  /// Permanent essence buys — under ESSENCE → KEEP (prestige section).
  static const NavIntent essenceShop = NavIntent(
    route: MenuRoute.essence,
    essencePanel: EssencePanel.keep,
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
