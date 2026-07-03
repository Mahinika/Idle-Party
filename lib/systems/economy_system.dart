import '../models/hero.dart';

class EconomySystem {
  double gold = 100.0;
  double prestigePoints = 0.0;
  double ascensionPoints = 0.0;

  EconomySystem();

  void addGold(double amount) {
    if (amount > 0) {
      gold += amount;
    }
  }

  bool spendGold(double amount) {
    if (amount <= gold) {
      gold -= amount;
      return true;
    }
    return false;
  }

  void addPrestigePoints(double amount) {
    if (amount > 0) {
      prestigePoints += amount;
    }
  }

  void addAscensionPoints(double amount) {
    if (amount > 0) {
      ascensionPoints += amount;
    }
  }

  /// Calculates the gold cost to upgrade a hero.
  double getUpgradeCost(HeroModel hero) {
    return hero.level * 50.0;
  }

  /// Attempts to level up a hero by spending gold.
  bool tryUpgradeHero(HeroModel hero) {
    final cost = getUpgradeCost(hero);
    if (spendGold(cost)) {
      hero.levelUp();
      return true;
    }
    return false;
  }

  /// Updates economic state (e.g. processing passive income if any).
  void update(double deltaTime, double teamDps) {
    // Passive gold income: 10% of team DPS per second
    final passiveGold = teamDps * 0.10 * deltaTime;
    addGold(passiveGold);
  }
}
