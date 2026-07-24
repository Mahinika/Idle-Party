import 'stats.dart';

/// Visual/combat role of an enemy within a room group.
enum EnemyRole { normal, elite, boss }

class EnemyUnit {
  const EnemyUnit({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    required this.rewardGold,
    this.role = EnemyRole.normal,
  });

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final int rewardGold;
  final EnemyRole role;

  // All stat scaling is baked into [stats] by `GameLogic.createEnemyGroup`
  // (single source of truth — avoids double level scaling).
  int get attack => stats.attack;

  int get defense => stats.defense;

  int get maxHp => stats.maxHp;

  bool get isDefeated => currentHp <= 0;

  EnemyUnit takeDamage(int damage) {
    final nextHp = currentHp - damage;
    return copyWith(currentHp: nextHp.clamp(0, maxHp));
  }

  EnemyUnit healToFull() => copyWith(currentHp: maxHp);

  EnemyUnit copyWith({
    int? level,
    int? currentHp,
    Stats? stats,
    int? rewardGold,
    String? name,
    EnemyRole? role,
  }) {
    return EnemyUnit(
      name: name ?? this.name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      rewardGold: rewardGold ?? this.rewardGold,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
    'rewardGold': rewardGold,
    'role': role.name,
  };

  factory EnemyUnit.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String?;
    return EnemyUnit(
      name: json['name'] as String,
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
      rewardGold: json['rewardGold'] as int,
      role: roleName == null
          ? EnemyRole.normal
          : EnemyRole.values.byName(roleName),
    );
  }
}
