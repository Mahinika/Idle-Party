import '../models/enemy.dart';

/// AI behaviour tag for an enemy.
enum AiBehaviour { idle, aggressive, defensive, fleeing }

/// AiSystem determines enemy behaviour based on HP/phase and updates
/// enemy state flags used by CombatSystem.
///
/// Update order: step 7.
class AiSystem {
  AiBehaviour _currentBehaviour = AiBehaviour.idle;

  AiBehaviour get behaviour => _currentBehaviour;

  void update(double deltaTime, EnemyState? enemy) {
    if (enemy == null || !enemy.isAlive) {
      _currentBehaviour = AiBehaviour.idle;
      return;
    }

    final ratio = enemy.currentHp / enemy.maxHp;

    if (enemy.definition.isBoss) {
      _currentBehaviour = switch (enemy.phase) {
        BossPhase.normal => AiBehaviour.aggressive,
        BossPhase.enraged => AiBehaviour.aggressive,
        BossPhase.desperate => AiBehaviour.fleeing,
      };
    } else {
      _currentBehaviour =
          ratio < 0.3 ? AiBehaviour.defensive : AiBehaviour.aggressive;
    }
  }
}
