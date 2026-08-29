import 'menu_router.dart';

/// One navigation request: destination plus optional inner segment.
class NavIntent {
  const NavIntent({
    required this.route,
    this.gear,
    this.power,
    this.more,
    this.scrollBagFilters = false,
  });

  final MenuRoute route;
  final GearPanel? gear;
  final PowerSegment? power;
  final MoreSection? more;
  final bool scrollBagFilters;

  static const NavIntent bagFilters = NavIntent(
    route: MenuRoute.more,
    more: MoreSection.settings,
    scrollBagFilters: true,
  );

  static const NavIntent shop = NavIntent(
    route: MenuRoute.power,
    power: PowerSegment.market,
  );
}
