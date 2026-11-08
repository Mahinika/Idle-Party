import '../assets/custom_assets.dart';

/// Town building identifiers for the out-of-dungeon hub.
enum TownBuildingId { guild, forge, market, inn, vault }

/// Cosmetic town look from Ascend. No extra save field.
///
/// Three painted facades (timber / stone / banners). Pennants at AL10 and
/// lantern arcade at AL20 are Flutter overlays on the same sprites — extra
/// full art passes would repeat the same silhouettes.
abstract final class TownTier {
  static int fromAscension(int ascensionLevel) {
    if (ascensionLevel >= 5) return 2;
    if (ascensionLevel >= 1) return 1;
    return 0;
  }

  static const int paintedTiers = 3;

  static bool showPennants(int ascensionLevel) => ascensionLevel >= 10;

  static bool showArcade(int ascensionLevel) => ascensionLevel >= 20;

  static String progressLine(int ascensionLevel) {
    if (ascensionLevel >= 20) return 'Grand town';
    if (ascensionLevel >= 10) return 'Banner town · arcade at Ascend 20';
    if (ascensionLevel >= 5) return 'Banner town · pennants at Ascend 10';
    if (ascensionLevel >= 1) return 'Stone town · banners at Ascend 5';
    return 'Timber town · stone at first Ascend';
  }

  static int paintedIndex(int ascensionLevel) =>
      fromAscension(ascensionLevel).clamp(0, paintedTiers - 1);
}

/// Town building: art + existing player job.
class TownBuilding {
  const TownBuilding({
    required this.id,
    required this.label,
    required this.description,
  });

  final TownBuildingId id;
  final String label;
  final String description;

  String assetPath(int paintedTier) => switch (id) {
        TownBuildingId.forge => CustomAssets.townForge(paintedTier),
        TownBuildingId.market => CustomAssets.townMarket(paintedTier),
        TownBuildingId.inn => CustomAssets.townInn(paintedTier),
        TownBuildingId.guild => CustomAssets.townGuild(paintedTier),
        TownBuildingId.vault => CustomAssets.townVaultShut,
      };

  static const List<TownBuilding> all = [
    TownBuilding(
      id: TownBuildingId.guild,
      label: 'GUILD',
      description: 'Claim jobs that are already done',
    ),
    TownBuilding(
      id: TownBuildingId.forge,
      label: 'FORGE',
      description: 'Craft and upgrade Apex gear',
    ),
    TownBuilding(
      id: TownBuildingId.market,
      label: 'MARKET',
      description: 'Buy flasks and listed upgrades',
    ),
    TownBuilding(
      id: TownBuildingId.inn,
      label: 'INN',
      description: 'Choose who walks in the active party',
    ),
    TownBuilding(
      id: TownBuildingId.vault,
      label: 'VAULT',
      description: 'Daily Vault claim',
    ),
  ];

  static const List<TownBuilding> backRow = [
    TownBuilding(
      id: TownBuildingId.guild,
      label: 'GUILD',
      description: 'Claim jobs that are already done',
    ),
    TownBuilding(
      id: TownBuildingId.vault,
      label: 'VAULT',
      description: 'Daily Vault claim',
    ),
  ];

  static const List<TownBuilding> frontRow = [
    TownBuilding(
      id: TownBuildingId.forge,
      label: 'FORGE',
      description: 'Craft and upgrade Apex gear',
    ),
    TownBuilding(
      id: TownBuildingId.market,
      label: 'MARKET',
      description: 'Buy flasks and listed upgrades',
    ),
    TownBuilding(
      id: TownBuildingId.inn,
      label: 'INN',
      description: 'Choose who walks in the active party',
    ),
  ];

  static TownBuilding byId(TownBuildingId id) =>
      all.firstWhere((b) => b.id == id);
}
