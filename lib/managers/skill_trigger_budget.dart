/// SkillTriggerBudget limits how many skill triggers can fire in a single
/// game tick, preventing infinite combo loops and runaway performance spikes.
///
/// Each skill type can optionally declare its own sub-budget so that one
/// overpowered skill cannot consume the entire allowance.
class SkillTriggerBudget {
  final int globalMaxPerTick;

  /// Per-skill-id budget; falls back to globalMaxPerTick when absent.
  final Map<String, int> _perSkillMax;
  final Map<String, int> _perSkillUsed = {};
  int _globalUsed = 0;

  SkillTriggerBudget({
    this.globalMaxPerTick = 20,
    Map<String, int>? perSkillBudgets,
  }) : _perSkillMax = perSkillBudgets ?? {};

  /// Called by GameDirector at the START of every tick (step 6).
  void resetForTick() {
    _globalUsed = 0;
    _perSkillUsed.clear();
  }

  /// Returns true and consumes budget if [skillId] may fire.
  /// Returns false if either the global budget or the per-skill budget is
  /// exhausted – the caller must then skip the trigger.
  bool tryConsume(String skillId) {
    if (_globalUsed >= globalMaxPerTick) return false;

    final max = _perSkillMax[skillId] ?? globalMaxPerTick;
    final used = _perSkillUsed[skillId] ?? 0;
    if (used >= max) return false;

    _globalUsed++;
    _perSkillUsed[skillId] = used + 1;
    return true;
  }

  /// Register a custom per-skill limit (call before first tick).
  void setSkillLimit(String skillId, int maxPerTick) {
    _perSkillMax[skillId] = maxPerTick;
  }

  int get globalUsed => _globalUsed;
  int get globalRemaining => globalMaxPerTick - _globalUsed;

  int usedForSkill(String skillId) => _perSkillUsed[skillId] ?? 0;
}
