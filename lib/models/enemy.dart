import 'stats.dart';
import 'buffable.dart';

class EnemyModel implements Buffable {
  final String id;
  final String name;
  final String element;
  final Stats baseStats;
  final int level;
  final bool isBoss;
  final double goldReward;

  Stats currentStats;
  
  // Storing active buffs/debuffs names/types to their remaining durations/stacks
  final Map<String, double> buffDurations = {};
  final Map<String, int> buffStacks = {};
  final Map<String, double> debuffDurations = {};
  final Map<String, int> debuffStacks = {};

  EnemyModel({
    required this.id,
    required this.name,
    required this.element,
    required this.baseStats,
    this.level = 1,
    this.isBoss = false,
    required this.goldReward,
    Stats? currentStats,
  }) : currentStats = currentStats ?? baseStats {
    scaleForLevel();
  }

  void scaleForLevel() {
    // Scaling: 12% per level for HP and 10% for attack/defense
    final hpMultiplier = 1.0 + (level - 1) * 0.12;
    final otherMultiplier = 1.0 + (level - 1) * 0.10;
    
    // Bosses get extra scaling
    final bossHpMult = isBoss ? 3.0 : 1.0;
    final bossAtkMult = isBoss ? 1.5 : 1.0;

    final scaledMaxHp = baseStats.maxHp * hpMultiplier * bossHpMult;
    final scaledAttack = baseStats.attack * otherMultiplier * bossAtkMult;
    final scaledDefense = baseStats.defense * otherMultiplier;

    currentStats = Stats(
      hp: scaledMaxHp,
      maxHp: scaledMaxHp,
      attack: scaledAttack,
      defense: scaledDefense,
      speed: baseStats.speed,
      critRate: baseStats.critRate,
      critDamage: baseStats.critDamage,
    );
  }

  void takeDamage(double amount) {
    final newHp = (currentStats.hp - amount).clamp(0.0, currentStats.maxHp);
    currentStats = currentStats.copyWith(hp: newHp);
  }

  bool get isDead => currentStats.hp <= 0.0;

  factory EnemyModel.fromJson(Map<String, dynamic> json, {int level = 1}) {
    final base = Stats(
      hp: (json['base_hp'] as num).toDouble(),
      maxHp: (json['base_hp'] as num).toDouble(),
      attack: (json['base_attack'] as num).toDouble(),
      defense: (json['base_defense'] as num).toDouble(),
      speed: (json['base_speed'] as num).toDouble(),
      critRate: 0.05, // default
      critDamage: 1.5, // default
    );

    return EnemyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      element: json['element'] as String,
      baseStats: base,
      level: level,
      isBoss: json['is_boss'] as bool? ?? false,
      goldReward: (json['gold_reward'] as num).toDouble(),
    );
  }
}
