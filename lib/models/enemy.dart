import 'stats.dart';

/// Phase of a boss encounter.
enum BossPhase { normal, enraged, desperate }

/// Immutable enemy definition loaded from JSON.
class Enemy {
  final String id;
  final String name;
  final Stats baseStats;
  final bool isBoss;
  final List<String> skillIds;
  final double xpReward;
  final double goldReward;

  const Enemy({
    required this.id,
    required this.name,
    required this.baseStats,
    this.isBoss = false,
    required this.skillIds,
    this.xpReward = 10.0,
    this.goldReward = 5.0,
  });

  factory Enemy.fromJson(Map<String, dynamic> json) => Enemy(
        id: json['id'] as String,
        name: json['name'] as String,
        baseStats: Stats.fromJson(
            (json['baseStats'] as Map<String, dynamic>?) ?? {}),
        isBoss: (json['isBoss'] as bool?) ?? false,
        skillIds: List<String>.from(json['skillIds'] as List? ?? []),
        xpReward: (json['xpReward'] as num?)?.toDouble() ?? 10.0,
        goldReward: (json['goldReward'] as num?)?.toDouble() ?? 5.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseStats': baseStats.toJson(),
        'isBoss': isBoss,
        'skillIds': skillIds,
        'xpReward': xpReward,
        'goldReward': goldReward,
      };
}

/// Mutable runtime state for an active enemy encounter.
class EnemyState {
  final Enemy definition;
  double currentHp;
  BossPhase phase;
  bool isAlive;

  EnemyState({required this.definition})
      : currentHp = definition.baseStats.maxHp,
        phase = BossPhase.normal,
        isAlive = true;

  double get maxHp => definition.baseStats.maxHp;

  void takeDamage(double amount) {
    currentHp = (currentHp - amount).clamp(0.0, maxHp);
    if (currentHp <= 0) {
      isAlive = false;
    } else {
      _updateBossPhase();
    }
  }

  void _updateBossPhase() {
    if (!definition.isBoss) return;
    final ratio = currentHp / maxHp;
    if (ratio <= 0.25) {
      phase = BossPhase.desperate;
    } else if (ratio <= 0.50) {
      phase = BossPhase.enraged;
    } else {
      phase = BossPhase.normal;
    }
  }
}
