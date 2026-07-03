import 'stats.dart';
import 'buffable.dart';

class HeroModel implements Buffable {
  final String id;
  final String name;
  final String element;
  final Stats baseStats;
  
  int level;
  double xp;
  int ascension;
  
  Stats currentStats;
  List<String> skills;
  Map<String, double> skillCooldowns;
  
  // Storing active buffs/debuffs names/types to their remaining durations
  final Map<String, double> buffDurations = {};
  final Map<String, int> buffStacks = {};
  final Map<String, double> debuffDurations = {};
  final Map<String, int> debuffStacks = {};

  HeroModel({
    required this.id,
    required this.name,
    required this.element,
    required this.baseStats,
    this.level = 1,
    this.xp = 0.0,
    this.ascension = 0,
    List<String>? skills,
    Stats? currentStats,
  })  : skills = skills ?? [],
        currentStats = currentStats ?? baseStats,
        skillCooldowns = {} {
    recalculateStats();
  }

  double get xpToNextLevel => level * 100.0;

  void recalculateStats() {
    // Level scaling: each level increases maxHp, attack, and defense by 10%
    final levelMultiplier = 1.0 + (level - 1) * 0.10;
    // Ascension scaling: each ascension increases stats by 50%
    final ascensionMultiplier = 1.0 + ascension * 0.50;
    
    final scaled = baseStats.multiply(levelMultiplier * ascensionMultiplier);
    
    // We preserve current HP fraction if possible
    double hpFraction = 1.0;
    if (currentStats.maxHp > 0) {
      hpFraction = currentStats.hp / currentStats.maxHp;
    }
    
    currentStats = scaled.copyWith(
      hp: scaled.maxHp * hpFraction,
    );
  }

  void gainXp(double amount) {
    xp += amount;
    while (xp >= xpToNextLevel) {
      xp -= xpToNextLevel;
      levelUp();
    }
  }

  void levelUp() {
    level++;
    recalculateStats();
    // Heal to full on level up
    healFully();
  }

  void ascend() {
    ascension++;
    level = 1;
    xp = 0.0;
    recalculateStats();
    healFully();
  }

  void healFully() {
    currentStats = currentStats.copyWith(hp: currentStats.maxHp);
  }

  void takeDamage(double amount) {
    final newHp = (currentStats.hp - amount).clamp(0.0, currentStats.maxHp);
    currentStats = currentStats.copyWith(hp: newHp);
  }

  bool get isDead => currentStats.hp <= 0.0;

  factory HeroModel.fromJson(Map<String, dynamic> json) {
    final base = Stats(
      hp: (json['base_hp'] as num).toDouble(),
      maxHp: (json['base_hp'] as num).toDouble(),
      attack: (json['base_attack'] as num).toDouble(),
      defense: (json['base_defense'] as num).toDouble(),
      speed: (json['base_speed'] as num).toDouble(),
      critRate: (json['base_crit_rate'] as num).toDouble(),
      critDamage: (json['base_crit_damage'] as num).toDouble(),
    );

    return HeroModel(
      id: json['id'] as String,
      name: json['name'] as String,
      element: json['element'] as String,
      baseStats: base,
      skills: List<String>.from(json['skills'] as List),
    );
  }
}
