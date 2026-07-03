import '../models/hero.dart';
import 'dungeon_system.dart';
import 'economy_system.dart';
import 'prestige_system.dart';

class AscensionSystem {
  double totalAscensionPoints = 0.0;
  int ascensionCount = 0;

  AscensionSystem();

  /// Calculates pending ascension points for reset (requires zone 20+)
  double calculatePendingAscensionPoints(int currentZone, double prestigePoints) {
    if (currentZone < 20) return 0.0;
    return (currentZone / 20.0).floorToDouble() + (prestigePoints / 1000.0).floorToDouble();
  }

  /// Performs an ascension reset.
  /// Resets prestige points, gold, dungeon zone, and hero levels.
  /// Increases each hero's permanent ascension level by 1, boosting stats by 50%.
  bool performAscension({
    required List<HeroModel> heroes,
    required DungeonSystem dungeonSystem,
    required EconomySystem economySystem,
    required PrestigeSystem prestigeSystem,
  }) {
    final pending = calculatePendingAscensionPoints(dungeonSystem.currentZone, prestigeSystem.totalPrestigePoints);
    if (pending <= 0.0) return false;

    // 1. Award ascension points
    totalAscensionPoints += pending;
    economySystem.addAscensionPoints(pending);
    ascensionCount++;

    // 2. Clear Prestige Points & Count (deeper reset)
    prestigeSystem.totalPrestigePoints = 0.0;
    economySystem.prestigePoints = 0.0;

    // 3. Reset Economy gold
    economySystem.gold = 100.0;

    // 4. Reset dungeon progression
    dungeonSystem.resetToZone(1);

    // 5. Apply Hero Ascension level
    for (var hero in heroes) {
      hero.ascend(); // Sets ascension += 1, level = 1, heals fully
    }

    return true;
  }

  /// Global passive bonus from Ascension points:
  /// +10% overall damage per ascension point.
  double get dpsMultiplierBonus => totalAscensionPoints * 0.10;

  /// +5% overall HP per ascension point.
  double get hpMultiplierBonus => totalAscensionPoints * 0.05;
}
