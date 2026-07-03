/// PrestigeSystem allows players to reset progress in exchange for permanent
/// multiplier bonuses.
///
/// Update order: step 11.
class PrestigeSystem {
  int _prestigeLevel = 0;
  double _bonusMultiplier = 1.0;

  int get prestigeLevel => _prestigeLevel;
  double get bonusMultiplier => _bonusMultiplier;

  void update(double deltaTime) {
    // Placeholder: auto-prestige logic or cooldown could go here.
  }

  /// Attempt a prestige reset. Returns true if eligible.
  bool tryPrestige({required double currentGold, double threshold = 1e6}) {
    if (currentGold < threshold) return false;
    _prestigeLevel++;
    _bonusMultiplier = 1.0 + _prestigeLevel * 0.1; // +10% per prestige
    return true;
  }
}
