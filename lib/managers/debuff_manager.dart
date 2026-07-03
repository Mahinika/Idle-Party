import '../models/buffable.dart';

class DebuffManager {
  final Map<String, int> _debuffMaxStacks = {};

  DebuffManager() {
    // Default max stacks configuration
    _debuffMaxStacks['burn'] = 5;
    _debuffMaxStacks['poison'] = 5;
    _debuffMaxStacks['scorch_vulnerability'] = 3;
    _debuffMaxStacks['freeze'] = 1;
  }

  void setMaxStacks(String debuffId, int maxStacks) {
    _debuffMaxStacks[debuffId] = maxStacks;
  }

  int getMaxStacks(String debuffId) {
    return _debuffMaxStacks[debuffId] ?? 5; // Default to 5 stacks if not configured
  }

  /// Applies a debuff to a target, conforming to stacking and duration rules.
  void applyDebuff(Buffable target, String debuffId, double duration) {
    final maxStacks = getMaxStacks(debuffId);
    
    if (target.debuffDurations.containsKey(debuffId)) {
      // Existing debuff: increment stack count (up to maxStacks) and refresh duration
      final currentStacks = target.debuffStacks[debuffId] ?? 1;
      target.debuffStacks[debuffId] = (currentStacks + 1).clamp(1, maxStacks);
      target.debuffDurations[debuffId] = duration; // Refresh duration
    } else {
      // New debuff: set initial stack count and duration
      target.debuffStacks[debuffId] = 1;
      target.debuffDurations[debuffId] = duration;
    }
  }

  /// Ticks down all active debuffs. Returns a list of expired debuff IDs.
  List<String> tickDebuffs(Buffable target, double deltaTime) {
    final expiredDebuffs = <String>[];
    
    final keys = List<String>.from(target.debuffDurations.keys);
    for (var key in keys) {
      final remaining = (target.debuffDurations[key] ?? 0.0) - deltaTime;
      if (remaining <= 0) {
        target.debuffDurations.remove(key);
        target.debuffStacks.remove(key);
        expiredDebuffs.add(key);
      } else {
        target.debuffDurations[key] = remaining;
      }
    }
    
    return expiredDebuffs;
  }

  bool hasDebuff(Buffable target, String debuffId) {
    return target.debuffDurations.containsKey(debuffId);
  }

  int getStacks(Buffable target, String debuffId) {
    return target.debuffStacks[debuffId] ?? 0;
  }

  /// Helper to check multiplier bonus or penalty (e.g., 5% damage increase/decrease per stack)
  double getMultiplierBonus(Buffable target, String debuffId, double perStackValue) {
    final stacks = getStacks(target, debuffId);
    return stacks * perStackValue;
  }
}
