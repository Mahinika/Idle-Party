/// AscensionSystem provides a deeper progression layer beyond prestige,
/// unlocking new systems and permanent stat upgrades.
///
/// Update order: step 12.
class AscensionSystem {
  int _ascensionLevel = 0;
  final List<String> _unlockedFeatures = [];

  int get ascensionLevel => _ascensionLevel;
  List<String> get unlockedFeatures =>
      List.unmodifiable(_unlockedFeatures);

  void update(double deltaTime) {
    // Placeholder: check conditions for auto-ascension or cooldown.
  }

  /// Attempt to ascend. Returns true if eligible.
  bool tryAscend({required int prestigeLevel, int required = 5}) {
    if (prestigeLevel < required) return false;
    _ascensionLevel++;
    _unlockFeaturesForLevel(_ascensionLevel);
    return true;
  }

  void _unlockFeaturesForLevel(int level) {
    const featureMap = {
      1: 'runes',
      2: 'artifacts',
      3: 'pets',
      4: 'relics',
      5: 'formations',
    };
    final feature = featureMap[level];
    if (feature != null && !_unlockedFeatures.contains(feature)) {
      _unlockedFeatures.add(feature);
    }
  }
}
