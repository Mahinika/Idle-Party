class RelicDefinition {
  final String id;
  final String name;
  final String description;
  final double bonusPerLevel;
  final String bonusType; // "gold", "attack", "defense"

  RelicDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.bonusPerLevel,
    required this.bonusType,
  });
}

class RelicSystem {
  final Map<String, RelicDefinition> _relics = {};
  final Map<String, int> _relicLevels = {};

  RelicSystem() {
    _registerRelics();
  }

  void _registerRelics() {
    _relics['relic_gold'] = RelicDefinition(
      id: 'relic_gold',
      name: 'Golden Chalice',
      description: 'Increases gold gains by +10% per level.',
      bonusPerLevel: 0.10,
      bonusType: 'gold',
    );
    _relics['relic_attack'] = RelicDefinition(
      id: 'relic_attack',
      name: 'Ancient Sword',
      description: 'Increases all heroes attack by +5% per level.',
      bonusPerLevel: 0.05,
      bonusType: 'attack',
    );
    _relics['relic_defense'] = RelicDefinition(
      id: 'relic_defense',
      name: 'Aegis Shield',
      description: 'Increases all heroes defense by +5% per level.',
      bonusPerLevel: 0.05,
      bonusType: 'defense',
    );
    
    // Set levels to 0
    for (var key in _relics.keys) {
      _relicLevels[key] = 0;
    }
  }

  int getRelicLevel(String relicId) {
    return _relicLevels[relicId] ?? 0;
  }

  double getUpgradeCost(String relicId) {
    final lvl = getRelicLevel(relicId);
    return (lvl + 1) * 10.0; // Costs prestige points
  }

  bool tryUpgradeRelic(String relicId, double availablePrestigePoints, Function(double cost) onDeduct) {
    final cost = getUpgradeCost(relicId);
    if (availablePrestigePoints >= cost) {
      _relicLevels[relicId] = getRelicLevel(relicId) + 1;
      onDeduct(cost);
      return true;
    }
    return false;
  }

  double getGoldBonusMultiplier() {
    final lvl = getRelicLevel('relic_gold');
    return lvl * 0.10;
  }

  double getAttackBonusMultiplier() {
    final lvl = getRelicLevel('relic_attack');
    return lvl * 0.05;
  }

  double getDefenseBonusMultiplier() {
    final lvl = getRelicLevel('relic_defense');
    return lvl * 0.05;
  }

  List<RelicDefinition> get allRelics => _relics.values.toList();
}
