import 'stats.dart';

/// Visual/combat role of an enemy within a room group.
enum EnemyRole { normal, elite, boss }

/// Combat identity — drives stats skew, AI, and sprite.
enum EnemyArchetype {
  /// Many weak melee bodies.
  swarm,

  /// Balanced frontliner.
  brute,

  /// High HP / DEF, slow melee.
  tank,

  /// Keeps distance, moderate HP.
  ranged,

  /// High ATK, low HP, fast.
  glass,

  /// Soft support caster (ranged, low HP).
  support,
}

class EnemyUnit {
  const EnemyUnit({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    required this.rewardGold,
    this.role = EnemyRole.normal,
    this.archetype = EnemyArchetype.brute,
  });

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final int rewardGold;
  final EnemyRole role;
  final EnemyArchetype archetype;

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
    EnemyArchetype? archetype,
  }) {
    return EnemyUnit(
      name: name ?? this.name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      rewardGold: rewardGold ?? this.rewardGold,
      role: role ?? this.role,
      archetype: archetype ?? this.archetype,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
    'rewardGold': rewardGold,
    'role': role.name,
    'archetype': archetype.name,
  };

  factory EnemyUnit.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    T enumOr<T extends Enum>(List<T> values, String? name, T fallback) {
      if (name == null || name.isEmpty) return fallback;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final roleName = json['role'] as String?;
    final archName = json['archetype'] as String?;
    final statsJson = json['stats'];
    return EnemyUnit(
      name: '${json['name'] ?? 'Enemy'}',
      level: asInt(json['level'], 1).clamp(1, 9999),
      currentHp: asInt(json['currentHp']),
      stats: statsJson is Map<String, dynamic>
          ? Stats.fromJson(statsJson)
          : Stats.enemy(attack: 1, defense: 0, maxHp: 1),
      rewardGold: asInt(json['rewardGold']),
      role: enumOr(EnemyRole.values, roleName, EnemyRole.normal),
      archetype: enumOr(EnemyArchetype.values, archName, EnemyArchetype.brute),
    );
  }
}
