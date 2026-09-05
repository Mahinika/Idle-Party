import '../../models/loot.dart';
import '../game_state.dart';
import '../loot_pipeline.dart';

/// Bag capacity, stash mutations, and gear lookup.
abstract final class GearStash {
  static const int maxGearStash = 50;

  static int maxGearStashFor(GameState state) =>
      maxGearStash +
      state.metaDepth.stashBonusSlots +
      state.metaDepth.shopBagBonusSlots;

  /// When the bag counts as "filling up" — the badge and the hint use this.
  static const double bagWarnFraction = 0.85;

  /// When the bag is jammed enough that cleaning may drop kept-tier gear.
  static const double bagJamFraction = 0.90;

  static int bagWarnAt(int cap) => (cap * bagWarnFraction).ceil();

  static int bagJamAt(int cap) => (cap * bagJamFraction).ceil();

  static bool isBagWarning(GameState state) =>
      state.gearStash.length >= bagWarnAt(maxGearStashFor(state));

  static bool isBagJammed(GameState state) =>
      state.gearStash.length >= bagJamAt(maxGearStashFor(state));

  /// Puts gear into the inventory stash. Overflow salvages the oldest piece.
  static GameState stashEquipment(GameState state, EquipmentItem item) {
    return stashEquipmentDetailed(state, item).state;
  }

  /// Salvage oldest bag pieces until length ≤ cap (bad saves / illegal unequip).
  static GameState clampStashToCap(GameState state) {
    final cap = maxGearStashFor(state);
    if (state.gearStash.length <= cap) return state;
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    final vault = List<EquipmentItem>.from(state.apexVault);
    while (stash.length > cap) {
      final overflow = stash.removeAt(0);
      if (overflow.isApex) {
        vault.add(overflow);
      } else {
        essence += LootPipeline.equipmentEssenceValue(overflow);
      }
    }
    return state.copyWith(
      gearStash: stash,
      apexVault: vault,
      essence: essence,
      lastUpdated: DateTime.now(),
    );
  }

  /// Like [stashEquipment], also reporting overflow salvage for UI feedback.
  static ({GameState state, int overflowEssence, String? overflowName})
  stashEquipmentDetailed(GameState state, EquipmentItem item) {
    if (item.isApex) {
      return (
        state: state.copyWith(apexVault: [...state.apexVault, item]),
        overflowEssence: 0,
        overflowName: null,
      );
    }
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    var overflowEssence = 0;
    String? overflowName;
    final cap = maxGearStashFor(state);
    if (stash.length >= cap) {
      final overflow = stash.removeAt(0);
      if (overflow.isApex) {
        return (
          state: state.copyWith(
            gearStash: stash,
            apexVault: [...state.apexVault, overflow, item],
            essence: essence,
          ),
          overflowEssence: 0,
          overflowName: null,
        );
      }
      overflowEssence = LootPipeline.equipmentEssenceValue(overflow);
      overflowName = overflow.name;
      essence += overflowEssence;
    }
    stash.add(item);
    return (
      state: state.copyWith(gearStash: stash, essence: essence),
      overflowEssence: overflowEssence,
      overflowName: overflowName,
    );
  }

  static EquipmentItem? findGear(GameState state, String id) {
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        if (item.id == id) return item;
      }
    }
    return findStashGear(state, id);
  }

  /// Bag-only lookup — combinator / merge never touches equipped gear.
  static EquipmentItem? findStashGear(GameState state, String id) {
    for (final item in state.gearStash) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) {
    for (var i = 0; i < state.heroes.length; i++) {
      for (final entry in state.heroes[i].equipped.entries) {
        if (entry.value.id == id) {
          return (heroIndex: i, slot: entry.key);
        }
      }
    }
    return null;
  }

  static GameState removeGear(GameState state, String id) {
    final location = findEquippedLocation(state, id);
    if (location != null) {
      final hero = state.heroes[location.heroIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(location.slot);
      final heroes = [...state.heroes];
      heroes[location.heroIndex] = hero.copyWith(equipped: nextGear);
      return state.copyWith(heroes: heroes);
    }
    return state.copyWith(
      gearStash: state.gearStash.where((item) => item.id != id).toList(),
    );
  }
}
