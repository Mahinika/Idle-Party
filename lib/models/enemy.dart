import 'stats.dart';

class EnemyUnit {
  const EnemyUnit({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    required this.rewardGold,
  });

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final int rewardGold;

  int get attack => stats.attack + ((level - 1) * 2);

  int get defense => stats.defense + (level - 1);

  int get maxHp => stats.maxHp + ((level - 1) * 8);

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
  }) {
    return EnemyUnit(
      name: name ?? this.name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      rewardGold: rewardGold ?? this.rewardGold,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
    'rewardGold': rewardGold,
  };

  factory EnemyUnit.fromJson(Map<String, dynamic> json) {
    return EnemyUnit(
      name: json['name'] as String,
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
      rewardGold: json['rewardGold'] as int,
    );
  }
}
