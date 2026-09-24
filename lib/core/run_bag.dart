import '../models/gear_loadout.dart';
import '../models/loot.dart';
import '../models/market_listing.dart';

/// This-run wallet, forge, bag, and floor progress.
///
/// [GameState.toJson] still writes these as flat keys. Ascend zeros the bag.
class RunBag {
  const RunBag({
    required this.gold,
    required this.attackBonus,
    required this.defenseBonus,
    required this.vitalityBonus,
    this.moveSpeedBonus = 0,
    this.attackSpeedBonus = 0,
    this.critBonus = 0,
    this.masteryBonus = 0,
    required this.recentLoot,
    this.equipped = const <EquipmentSlot, EquipmentItem>{},
    this.gearStash = const <EquipmentItem>[],
    this.marketListings = const <MarketListing>[],
    this.loadouts = const <GearLoadout>[],
    this.highestFloorCleared = 0,
    this.lastFloorClearSec = 0,
  });

  final int gold;
  final int attackBonus;
  final int defenseBonus;
  final int vitalityBonus;
  final int moveSpeedBonus;
  final int attackSpeedBonus;
  final int critBonus;
  final int masteryBonus;
  final List<LootDrop> recentLoot;
  final Map<EquipmentSlot, EquipmentItem> equipped;
  final List<EquipmentItem> gearStash;
  final List<MarketListing> marketListings;
  final List<GearLoadout> loadouts;
  final int highestFloorCleared;
  final int lastFloorClearSec;
}
