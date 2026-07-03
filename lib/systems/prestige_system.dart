import '../models/hero.dart';
import 'dungeon_system.dart';
import 'economy_system.dart';

class PrestigeSystem {
  double totalPrestigePoints = 0.0;
  int prestigeCount = 0;

  PrestigeSystem();

  /// Calculates how many prestige points are pending for reset.
  double calculatePendingPrestigePoints(int maxZoneReached, double currentGold) {
    if (maxZoneReached < 5) return 0.0; // Prestige unlocked at zone 5
    return (maxZoneReached * 5.0) + (currentGold / 5000.0);
  }

  /// Performs a prestige reset. 
  /// Resets heroes levels, gold, current wave, and current zone.
  /// Awards prestige points to economy and prestige systems.
  bool performPrestige({
    required List<HeroModel> heroes,
    required DungeonSystem dungeonSystem,
    required EconomySystem economySystem,
  }) {
    final pending = calculatePendingPrestigePoints(dungeonSystem.currentZone, economySystem.gold);
    if (pending <= 0.0) return false;

    // 1. Award prestige currency
    totalPrestigePoints += pending;
    economySystem.addPrestigePoints(pending);
    prestigeCount++;

    // 2. Reset economy
    economySystem.gold = 100.0;

    // 3. Reset dungeon progression
    dungeonSystem.resetToZone(1);

    // 4. Reset hero progression
    for (var hero in heroes) {
      hero.level = 1;
      hero.xp = 0.0;
      hero.skillCooldowns.clear();
      hero.recalculateStats();
      hero.healFully();
    }

    return true;
  }

  /// Global passive multiplier from Prestige points:
  /// +2% damage bonus per prestige point.
  double get dpsMultiplierBonus => totalPrestigePoints * 0.02;

  /// +1% hp bonus per prestige point.
  double get hpMultiplierBonus => totalPrestigePoints * 0.01;
}
