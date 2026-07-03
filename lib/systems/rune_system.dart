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

  /// Fuses two identical or same-type runes to unlock higher power synergy.
  Rune? fuseRunes(Rune rune1, Rune rune2) {
    if (rune1.type != rune2.type) return null;

    final newPower = (rune1.power + rune2.power) * 1.25; // 25% synergy bonus
    return Rune(
      id: '${rune1.id}_fused',
      name: 'Greater ${rune1.name}',
      type: rune1.type,
      power: double.parse(newPower.toStringAsFixed(4)), // Avoid precision float issues
    );
  }

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
