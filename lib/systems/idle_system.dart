import '../managers/caps_manager.dart';

/// IdleSystem accumulates offline/idle progress rewards over time.
///
/// Update order: step 10.
class IdleSystem {
  final CapsManager capsManager;
  double _rewardPerSecond = 1.0;
  double _accumulatedReward = 0.0;

  IdleSystem({required this.capsManager});

  double get rewardPerSecond => _rewardPerSecond;
  double get accumulatedReward => _accumulatedReward;

  void update(double deltaTime) {
    final raw = _rewardPerSecond * deltaTime;
    _accumulatedReward += capsManager.applyIdleRewardCap(raw);
  }

  /// Collect (drain) all accumulated rewards; returns the amount collected.
  double collect() {
    final amount = _accumulatedReward;
    _accumulatedReward = 0.0;
    return amount;
  }

  /// Scale the idle reward rate, e.g. after prestige.
  void setRewardPerSecond(double value) {
    _rewardPerSecond = value.clamp(0.0, capsManager.idleRewardCap);
  }
}
