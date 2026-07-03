/// CapsManager enforces upper bounds on computed values to prevent
/// exponential scaling from breaking game balance.
///
/// Add new caps here without touching individual systems; systems call
/// [apply] to clamp any value before using it.
class CapsManager {
  /// Maximum effective HP an enemy can have after all modifiers.
  double enemyEffectiveHpCap;

  /// Maximum idle reward per tick.
  double idleRewardCap;

  /// Maximum total power (DPS) a single hero can contribute.
  double heroPowerCap;

  // Extend with additional caps as the game grows.

  CapsManager({
    this.enemyEffectiveHpCap = 1e9,
    this.idleRewardCap = 1e6,
    this.heroPowerCap = 1e8,
  });

  /// Clamp an enemy HP value to [enemyEffectiveHpCap].
  double applyEnemyHpCap(double value) =>
      value.clamp(0.0, enemyEffectiveHpCap);

  /// Clamp an idle reward to [idleRewardCap].
  double applyIdleRewardCap(double value) =>
      value.clamp(0.0, idleRewardCap);

  /// Clamp hero power to [heroPowerCap].
  double applyHeroPowerCap(double value) =>
      value.clamp(0.0, heroPowerCap);

  /// Generic named-cap lookup for future extensibility.
  double apply(String capName, double value) {
    switch (capName) {
      case 'enemyEffectiveHp':
        return applyEnemyHpCap(value);
      case 'idleReward':
        return applyIdleRewardCap(value);
      case 'heroPower':
        return applyHeroPowerCap(value);
      default:
        return value; // Unknown caps pass through unmodified.
    }
  }
}
