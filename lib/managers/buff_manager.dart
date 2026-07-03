/// A single active buff on a target.
class BuffInstance {
  final String id;
  final String sourceId; // Hero/skill that applied the buff
  double remainingDuration; // seconds; -1 = permanent
  final double magnitude;   // e.g. 0.2 = +20%
  final String stat;        // which stat this buff affects
  int stackCount;

  BuffInstance({
    required this.id,
    required this.sourceId,
    required this.remainingDuration,
    required this.magnitude,
    required this.stat,
    this.stackCount = 1,
  });
}

/// Stacking strategy for a buff type.
enum StackRule {
  /// Refresh duration; do not add stacks.
  refresh,
  /// Add a new stack (capped by [maxStacks]).
  addStack,
  /// Replace old instance with new one.
  replace,
}

/// BuffManager tracks all active buffs and enforces stacking rules.
///
/// Systems should call [apply] to add buffs and read [totalMagnitude] or
/// [getBuffsForStat] to query them.  GameDirector calls [tick] each frame
/// to advance durations and expire buffs.
class BuffManager {
  final Map<String, List<BuffInstance>> _buffs = {};
  final Map<String, StackRule> _stackRules = {};
  final Map<String, int> _maxStacks = {};

  /// Register stacking rules for a buff type before applying it.
  void registerStackRule(
    String buffId, {
    StackRule rule = StackRule.refresh,
    int maxStacks = 1,
  }) {
    _stackRules[buffId] = rule;
    _maxStacks[buffId] = maxStacks;
  }

  /// Apply a buff to [targetId].
  void apply(String targetId, BuffInstance buff) {
    final rule = _stackRules[buff.id] ?? StackRule.refresh;
    final maxStacks = _maxStacks[buff.id] ?? 1;
    final list = _buffs.putIfAbsent(targetId, () => []);

    final existing = list.where((b) => b.id == buff.id).toList();

    switch (rule) {
      case StackRule.refresh:
        if (existing.isNotEmpty) {
          existing.first.remainingDuration = buff.remainingDuration;
        } else {
          list.add(buff);
        }
        break;

      case StackRule.addStack:
        if (existing.isNotEmpty &&
            existing.first.stackCount < maxStacks) {
          existing.first.stackCount++;
          existing.first.remainingDuration = buff.remainingDuration;
        } else if (existing.isEmpty) {
          list.add(buff);
        }
        break;

      case StackRule.replace:
        list.removeWhere((b) => b.id == buff.id);
        list.add(buff);
        break;
    }
  }

  /// Tick durations; remove expired buffs.
  void tick(double deltaTime) {
    for (final list in _buffs.values) {
      list.removeWhere((b) {
        if (b.remainingDuration < 0) return false; // permanent
        b.remainingDuration -= deltaTime;
        return b.remainingDuration <= 0;
      });
    }
    _buffs.removeWhere((_, list) => list.isEmpty);
  }

  /// Sum of all buff magnitudes for [stat] on [targetId].
  double totalMagnitude(String targetId, String stat) {
    final list = _buffs[targetId] ?? [];
    return list
        .where((b) => b.stat == stat)
        .fold(0.0, (sum, b) => sum + b.magnitude * b.stackCount);
  }

  /// All active buffs for a target.
  List<BuffInstance> getBuffs(String targetId) =>
      List.unmodifiable(_buffs[targetId] ?? []);

  /// Remove all buffs for a target (e.g. on death/reset).
  void clearTarget(String targetId) => _buffs.remove(targetId);

  /// Remove all buffs everywhere.
  void clearAll() => _buffs.clear();
}
