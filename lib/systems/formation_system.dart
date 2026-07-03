enum FormationPosition {
  frontline,
  backline,
}

class FormationSystem {
  final Map<String, FormationPosition> _heroPositions = {};

  FormationSystem();

  void assignPosition(String heroId, FormationPosition position) {
    _heroPositions[heroId] = position;
  }

  FormationPosition getPosition(String heroId) {
    return _heroPositions[heroId] ?? FormationPosition.frontline; // default frontline
  }

  /// Returns attack bonus/multiplier for a hero depending on their formation position.
  double getAttackMultiplierBonus(String heroId) {
    final pos = getPosition(heroId);
    if (pos == FormationPosition.backline) {
      return 0.25; // +25% Attack for Backliners
    } else {
      return -0.10; // -10% Attack for Frontliners (tank penalty)
    }
  }

  /// Returns defense bonus/multiplier for a hero depending on their formation position.
  double getDefenseMultiplierBonus(String heroId) {
    final pos = getPosition(heroId);
    if (pos == FormationPosition.frontline) {
      return 0.25; // +25% Defense for Frontliners (tank bonus)
    } else {
      return -0.20; // -20% Defense for Backliners (squishy penalty)
    }
  }
}
