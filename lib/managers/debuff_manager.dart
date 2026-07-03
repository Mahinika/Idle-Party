/// A single active debuff on a target.
class DebuffInstance {
  final String id;
  final String sourceId;
  double remainingDuration; // seconds; -1 = permanent
  final double magnitude;   // e.g. 0.15 = -15%
  final String stat;
  int stackCount;

  DebuffInstance({
    required this.id,
    required this.sourceId,
    required this.remainingDuration,
    required this.magnitude,
    required this.stat,
    this.stackCount = 1,
  });
}

/// Stacking strategy for debuff types.
enum DebuffStackRule { refresh, addStack, replace }

/// DebuffManager mirrors BuffManager but for negative effects.
///
/// Intentionally kept as a separate class so that buff and debuff pipelines
/// can diverge independently without coupling.
class DebuffManager {
  final Map<String, List<DebuffInstance>> _debuffs = {};
  final Map<String, DebuffStackRule> _stackRules = {};
  final Map<String, int> _maxStacks = {};

  void registerStackRule(
    String debuffId, {
    DebuffStackRule rule = DebuffStackRule.refresh,
    int maxStacks = 1,
  }) {
    _stackRules[debuffId] = rule;
    _maxStacks[debuffId] = maxStacks;
  }

  void apply(String targetId, DebuffInstance debuff) {
    final rule = _stackRules[debuff.id] ?? DebuffStackRule.refresh;
    final maxStacks = _maxStacks[debuff.id] ?? 1;
    final list = _debuffs.putIfAbsent(targetId, () => []);

    final existing = list.where((d) => d.id == debuff.id).toList();

    switch (rule) {
      case DebuffStackRule.refresh:
        if (existing.isNotEmpty) {
          existing.first.remainingDuration = debuff.remainingDuration;
        } else {
          list.add(debuff);
        }
        break;

      case DebuffStackRule.addStack:
        if (existing.isNotEmpty &&
            existing.first.stackCount < maxStacks) {
          existing.first.stackCount++;
          existing.first.remainingDuration = debuff.remainingDuration;
        } else if (existing.isEmpty) {
          list.add(debuff);
        }
        break;

      case DebuffStackRule.replace:
        list.removeWhere((d) => d.id == debuff.id);
        list.add(debuff);
        break;
    }
  }

  void tick(double deltaTime) {
    for (final list in _debuffs.values) {
      list.removeWhere((d) {
        if (d.remainingDuration < 0) return false;
        d.remainingDuration -= deltaTime;
        return d.remainingDuration <= 0;
      });
    }
    _debuffs.removeWhere((_, list) => list.isEmpty);
  }

  /// Total magnitude reduction for [stat] on [targetId].
  double totalMagnitude(String targetId, String stat) {
    final list = _debuffs[targetId] ?? [];
    return list
        .where((d) => d.stat == stat)
        .fold(0.0, (sum, d) => sum + d.magnitude * d.stackCount);
  }

  List<DebuffInstance> getDebuffs(String targetId) =>
      List.unmodifiable(_debuffs[targetId] ?? []);

  void clearTarget(String targetId) => _debuffs.remove(targetId);
  void clearAll() => _debuffs.clear();
}
