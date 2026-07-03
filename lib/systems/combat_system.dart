import '../core/dps_pipeline.dart';
import '../managers/caps_manager.dart';
import '../models/enemy.dart';
import '../models/hero.dart';

/// CombatSystem handles damage calculation, HP tracking, and boss phases.
///
/// It reads the current DPS from the pipeline (which already reflects all
/// weather/event/buff/skill multipliers applied in prior update steps)
/// and applies it to the current enemy.
///
/// Update order: step 8.
class CombatSystem {
  final DpsPipeline dpsPipeline;
  final CapsManager capsManager;

  final List<Enemy> _enemyCatalogue = [];
  final List<HeroState> _party = [];
  EnemyState? _currentEnemy;

  double _combatTimer = 0.0;
  static const double _attackInterval = 1.0; // seconds per auto-attack

  CombatSystem({
    required this.dpsPipeline,
    required this.capsManager,
  });

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _enemyCatalogue
      ..clear()
      ..addAll(data.map(Enemy.fromJson));
  }

  // ── Party management ────────────────────────────────────────────────────

  void setParty(List<HeroState> party) {
    _party
      ..clear()
      ..addAll(party);
  }

  void setEnemy(EnemyState enemy) {
    final cappedHp = capsManager.applyEnemyHpCap(enemy.currentHp);
    enemy.currentHp = cappedHp;
    _currentEnemy = enemy;
  }

  EnemyState? get currentEnemy => _currentEnemy;
  List<HeroState> get party => List.unmodifiable(_party);

  // ── Combat tick ────────────────────────────────────────────────────────

  void update(double deltaTime) {
    if (_currentEnemy == null || !_currentEnemy!.isAlive) return;
    if (_party.isEmpty) return;

    _combatTimer += deltaTime;
    if (_combatTimer < _attackInterval) return;
    _combatTimer -= _attackInterval;

    // Accumulate raw damage from all alive heroes.
    var rawDamage = 0.0;
    for (final hero in _party) {
      if (!hero.isAlive) continue;
      final power = capsManager.applyHeroPowerCap(
        hero.effectiveStats.attack,
      );
      rawDamage += power;
    }

    // Apply pipeline multipliers (weather, events, dungeon, buffs, skills…).
    final finalDamage = dpsPipeline.apply(rawDamage);

    // Reduce by enemy defense.
    final enemy = _currentEnemy!;
    final mitigated =
        (finalDamage - enemy.definition.baseStats.defense).clamp(1.0, double.infinity);
    enemy.takeDamage(mitigated);

    // Distribute XP on kill.
    if (!enemy.isAlive) {
      _distributeXp(enemy.definition.xpReward);
    }
  }

  void _distributeXp(double totalXp) {
    final alive = _party.where((h) => h.isAlive).toList();
    if (alive.isEmpty) return;
    final share = totalXp / alive.length;
    for (final h in alive) {
      h.addExperience(share);
    }
  }

  bool get isCombatActive =>
      _currentEnemy != null && _currentEnemy!.isAlive && _party.isNotEmpty;

  /// Spawn an enemy by id from the catalogue.
  EnemyState? spawnEnemy(String enemyId) {
    try {
      final def = _enemyCatalogue.firstWhere((e) => e.id == enemyId);
      final state = EnemyState(definition: def);
      setEnemy(state);
      return state;
    } catch (_) {
      return null;
    }
  }
}
