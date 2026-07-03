import '../core/dps_pipeline.dart';
import '../models/enemy.dart';
import '../systems/economy_system.dart';

/// A dungeon zone definition loaded from JSON.
class DungeonZone {
  final String id;
  final String name;
  final int wavesPerZone;
  final List<String> enemyPool;
  final String? bossId;

  const DungeonZone({
    required this.id,
    required this.name,
    required this.wavesPerZone,
    required this.enemyPool,
    this.bossId,
  });

  factory DungeonZone.fromJson(Map<String, dynamic> json) => DungeonZone(
        id: json['id'] as String,
        name: json['name'] as String,
        wavesPerZone: (json['wavesPerZone'] as num?)?.toInt() ?? 10,
        enemyPool: List<String>.from(json['enemyPool'] as List? ?? []),
        bossId: json['bossId'] as String?,
      );
}

/// A dungeon modifier that tweaks the DPS pipeline for a zone/wave.
class DungeonModifier {
  final String id;
  final String name;
  final double dpsMult;
  final double enemyHpMult;

  const DungeonModifier({
    required this.id,
    required this.name,
    required this.dpsMult,
    required this.enemyHpMult,
  });

  factory DungeonModifier.fromJson(Map<String, dynamic> json) =>
      DungeonModifier(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        enemyHpMult: (json['enemyHpMult'] as num?)?.toDouble() ?? 1.0,
      );
}

/// DungeonSystem manages zone progression, wave logic, and modifiers.
///
/// Update order: step 3 (modifiers) and step 14 (loot).
class DungeonSystem {
  final List<DungeonZone> _zones = [];
  final List<DungeonModifier> _modifiers = [];
  int _currentZoneIndex = 0;
  int _currentWave = 0;
  EnemyState? _currentEnemy;

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _modifiers
      ..clear()
      ..addAll(data.map(DungeonModifier.fromJson));
  }

  void loadZones(List<Map<String, dynamic>> data) {
    _zones
      ..clear()
      ..addAll(data.map(DungeonZone.fromJson));
  }

  DungeonZone? get currentZone =>
      _zones.isNotEmpty ? _zones[_currentZoneIndex % _zones.length] : null;

  int get currentWave => _currentWave;
  EnemyState? get currentEnemy => _currentEnemy;

  /// Called at step 3: apply dungeon modifiers to the DPS pipeline.
  void updateModifiers(double deltaTime, DpsPipeline pipeline) {
    pipeline.clearCategory('dungeon');
    for (final mod in _modifiers) {
      pipeline.addMultiplier('dungeon', mod.dpsMult);
    }
  }

  /// Set the current enemy (called by CombatSystem after a kill).
  void setCurrentEnemy(EnemyState? enemy) {
    _currentEnemy = enemy;
  }

  /// Step 14: resolve loot and advance wave after enemy death.
  void resolveLoot(double deltaTime, EconomySystem economy) {
    if (_currentEnemy == null) return;
    if (_currentEnemy!.isAlive) return;

    final reward = _currentEnemy!.definition.goldReward;
    economy.addGold(reward);
    _advanceWave();
    _currentEnemy = null;
  }

  void _advanceWave() {
    if (_zones.isEmpty) return;
    final zone = _zones[_currentZoneIndex % _zones.length];
    _currentWave++;
    if (_currentWave >= zone.wavesPerZone) {
      _currentWave = 0;
      _currentZoneIndex++;
    }
  }
}
