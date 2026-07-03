class CapsManager {
  // Enemy Effective HP Cap (e.g., to prevent overflow of numeric types or extreme values)
  static const double maxEnemyEffectiveHp = 1e300;

  // Idle Reward Cap: Maximum offline progress duration capped at 24 hours (86400 seconds)
  static const double maxIdleTimeSeconds = 86400.0;

  // Hero Power Cap: Caps maximum stat value (e.g., HP, attack, defense to prevent runaway progression)
  static const double maxHeroStat = 1e50;

  /// Applies the Enemy Effective HP Cap.
  double clampEnemyHp(double hp) {
    return hp.clamp(0.0, maxEnemyEffectiveHp);
  }

  /// Applies the Idle Reward duration cap.
  double clampIdleTime(double durationInSeconds) {
    return durationInSeconds.clamp(0.0, maxIdleTimeSeconds);
  }

  /// Applies the Hero Stat Cap to a given stat value.
  double clampHeroStat(double value) {
    return value.clamp(0.0, maxHeroStat);
  }
}
