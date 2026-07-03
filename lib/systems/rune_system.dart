enum RuneType {
  fire,
  speed,
  focus,
}

class Rune {
  final String id;
  final String name;
  final RuneType type;
  final double power; // e.g. 0.05 for 5% boost

  Rune({
    required this.id,
    required this.name,
    required this.type,
    required this.power,
  });
}

class RuneSystem {
  final Map<String, List<Rune>> _heroRunes = {};

  RuneSystem();

  void socketRune(String heroId, Rune rune) {
    _heroRunes.putIfAbsent(heroId, () => []).add(rune);
  }

  void unsocketAllRunes(String heroId) {
    _heroRunes.remove(heroId);
  }

  List<Rune> getSocketedRunes(String heroId) {
    return _heroRunes[heroId] ?? [];
  }

  /// Calculates speed boost from socketed speed runes on a specific hero.
  double getSpeedBonus(String heroId) {
    final runes = getSocketedRunes(heroId);
    return runes
        .where((r) => r.type == RuneType.speed)
        .fold(0.0, (sum, rune) => sum + rune.power);
  }

  /// Calculates crit rate boost from socketed focus runes on a specific hero.
  double getCritRateBonus(String heroId) {
    final runes = getSocketedRunes(heroId);
    return runes
        .where((r) => r.type == RuneType.focus)
        .fold(0.0, (sum, rune) => sum + rune.power);
  }

  /// Calculates fire elemental multiplier bonus on a specific hero.
  double getFireDamageBonus(String heroId) {
    final runes = getSocketedRunes(heroId);
    return runes
        .where((r) => r.type == RuneType.fire)
        .fold(0.0, (sum, rune) => sum + rune.power);
  }
}
