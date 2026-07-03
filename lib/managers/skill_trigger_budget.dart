class SkillTriggerBudget {
  final int maxTriggersPerTick;
  int _currentTriggers = 0;

  SkillTriggerBudget({this.maxTriggersPerTick = 10});

  /// Resets the trigger count. Should be called at the beginning of each game tick.
  void reset() {
    _currentTriggers = 0;
  }

  /// Attempts to consume 1 trigger from the budget. 
  /// Returns true if successful, false if the budget is exhausted (infinite loop prevented).
  bool tryTrigger() {
    if (_currentTriggers < maxTriggersPerTick) {
      _currentTriggers++;
      return true;
    }
    return false;
  }

  int get currentTriggers => _currentTriggers;
  bool get isExhausted => _currentTriggers >= maxTriggersPerTick;
}
