import '../models/buffable.dart';

class BuffManager {
  final Map<String, int> _buffMaxStacks = {};

  BuffManager() {
    // Default max stacks configuration
    _buffMaxStacks['defense_boost'] = 3;
    _buffMaxStacks['attack_boost'] = 5;
    _buffMaxStacks['speed_boost'] = 3;
  }

  void setMaxStacks(String buffId, int maxStacks) {
    _buffMaxStacks[buffId] = maxStacks;
  }

  int getMaxStacks(String buffId) {
    return _buffMaxStacks[buffId] ?? 5; // Default to 5 stacks if not configured
  }

  /// Applies a buff to a target, conforming to stacking and duration rules.
  void applyBuff(Buffable target, String buffId, double duration) {
    final maxStacks = getMaxStacks(buffId);
    
    if (target.buffDurations.containsKey(buffId)) {
      // Existing buff: increment stack count (up to maxStacks) and refresh duration
      final currentStacks = target.buffStacks[buffId] ?? 1;
      target.buffStacks[buffId] = (currentStacks + 1).clamp(1, maxStacks);
      target.buffDurations[buffId] = duration; // Refresh duration
    } else {
      // New buff: set initial stack count and duration
      target.buffStacks[buffId] = 1;
      target.buffDurations[buffId] = duration;
    }
  }

  /// Ticks down all active buffs. Returns a list of expired buff IDs.
  List<String> tickBuffs(Buffable target, double deltaTime) {
    final expiredBuffs = <String>[];
    
    final keys = List<String>.from(target.buffDurations.keys);
    for (var key in keys) {
      final remaining = (target.buffDurations[key] ?? 0.0) - deltaTime;
      if (remaining <= 0) {
        target.buffDurations.remove(key);
        target.buffStacks.remove(key);
        expiredBuffs.add(key);
      } else {
        target.buffDurations[key] = remaining;
      }
    }
    
    return expiredBuffs;
  }

  bool hasBuff(Buffable target, String buffId) {
    return target.buffDurations.containsKey(buffId);
  }

  int getStacks(Buffable target, String buffId) {
    return target.buffStacks[buffId] ?? 0;
  }

  /// Helper to check multiplier bonus (e.g., 5% per stack)
  double getMultiplierBonus(Buffable target, String buffId, double perStackBonus) {
    final stacks = getStacks(target, buffId);
    return stacks * perStackBonus;
  }
}
