import '../assets/custom_assets.dart';
import '../core/menu_router.dart';

/// Town building identifiers for the out-of-dungeon hub.
enum TownBuildingId { forge, market, inn }

/// Cosmetic town look, derived from Ascend. No extra save field.
abstract final class TownTier {
  static int fromAscension(int ascensionLevel) {
    if (ascensionLevel >= 20) return 4;
    if (ascensionLevel >= 10) return 3;
    if (ascensionLevel >= 5) return 2;
    if (ascensionLevel >= 1) return 1;
    return 0;
  }

  /// v1 ships one art pass (tier 0). Higher tiers are proposed looks.
  static const int shippedArtTier = 0;
}

/// Town building: art + which existing menu it opens.
class TownBuilding {
  const TownBuilding({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.route,
    required this.description,
    this.goldPanel,
    this.gearPanel,
  });

  final TownBuildingId id;
  final String label;
  final String assetPath;
  final MenuRoute route;
  final String description;
  final GoldPanel? goldPanel;
  final GearPanel? gearPanel;

  static const List<TownBuilding> all = [
    TownBuilding(
      id: TownBuildingId.forge,
      label: 'FORGE',
      assetPath: CustomAssets.townBuildingForge,
      route: MenuRoute.gold,
      goldPanel: GoldPanel.tracks,
      description: 'Upgrade party power',
    ),
    TownBuilding(
      id: TownBuildingId.market,
      label: 'MARKET',
      assetPath: CustomAssets.townBuildingMarket,
      route: MenuRoute.gold,
      goldPanel: GoldPanel.market,
      description: 'Buy flasks and gear',
    ),
    TownBuilding(
      id: TownBuildingId.inn,
      label: 'INN',
      assetPath: CustomAssets.townBuildingInn,
      route: MenuRoute.gear,
      gearPanel: GearPanel.roster,
      description: 'Choose party composition',
    ),
  ];

  static TownBuilding byId(TownBuildingId id) =>
      all.firstWhere((b) => b.id == id);
}
