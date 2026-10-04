import 'menu_router.dart';

/// One navigation request: destination plus optional inner segment.
class NavIntent {
  const NavIntent({
    required this.route,
    this.gear,
    this.goldPanel,
    this.essencePanel,
    this.more,
  });

  final MenuRoute route;
  final GearPanel? gear;
  final GoldPanel? goldPanel;
  final EssencePanel? essencePanel;
  final MoreSection? more;

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
}
