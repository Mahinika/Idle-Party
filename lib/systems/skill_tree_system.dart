import '../models/hero.dart';

class SkillTreeSystem {
  // Map of hero ID to their allocated skill nodes (nodeId -> currentLevel)
  final Map<String, Map<String, int>> _allocations = {};

  SkillTreeSystem();

  int getNodeLevel(String heroId, String nodeId) {
    return _allocations[heroId]?[nodeId] ?? 0;
  }

  /// Attempts to spend a hero's skill points to upgrade a node in their skill tree.
  bool tryUpgradeNode(HeroModel hero, String nodeId) {
    if (hero.skillPoints <= 0) return false;

    final currentLvl = getNodeLevel(hero.id, nodeId);
    if (currentLvl >= 5) return false; // Max level 5 per node

    _allocations.putIfAbsent(hero.id, () => {})[nodeId] = currentLvl + 1;
    hero.skillPoints--;
    return true;
  }

  /// Resets the skill tree for a hero, refunding all spent skill points.
  void resetTree(HeroModel hero) {
    final nodes = _allocations[hero.id];
    if (nodes != null) {
      int refunded = 0;
      nodes.forEach((_, lvl) => refunded += lvl);
      hero.skillPoints += refunded;
      nodes.clear();
    }
  }

  /// Clears all allocations for a hero.
  void clearAll(String heroId) {
    _allocations.remove(heroId);
  }

  double getCritRateBonus(String heroId) {
    return getNodeLevel(heroId, 'crit_rate_boost') * 0.02;
  }

  double getCooldownReductionMultiplier(String heroId) {
    return 1.0 - (getNodeLevel(heroId, 'cooldown_reduction') * 0.05);
  }

  double getPoisonChance(String heroId) {
    return getNodeLevel(heroId, 'poison_on_attack') * 0.15; // 15% per level
  }
}
