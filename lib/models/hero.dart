import 'stats.dart';

/// Defines the role/class of a hero, used by AI and skill systems.
enum HeroClass { warrior, mage, ranger, healer, tank }

/// Immutable hero definition loaded from JSON.
/// Runtime mutable state (currentHp, xp, level) lives in a separate
/// HeroState object, keeping the model clean.
class Hero {
  final String id;
  final String name;
  final HeroClass heroClass;
  final Stats baseStats;
  final List<String> skillIds; // References into skills.json
  final int unlockCost;        // Gold required to unlock

  const Hero({
    required this.id,
    required this.name,
    required this.heroClass,
    required this.baseStats,
    required this.skillIds,
    this.unlockCost = 0,
  });

  factory Hero.fromJson(Map<String, dynamic> json) => Hero(
        id: json['id'] as String,
        name: json['name'] as String,
        heroClass: HeroClass.values.firstWhere(
          (c) => c.name == (json['class'] as String? ?? 'warrior'),
          orElse: () => HeroClass.warrior,
        ),
        baseStats: Stats.fromJson(
            (json['baseStats'] as Map<String, dynamic>?) ?? {}),
        skillIds: List<String>.from(json['skillIds'] as List? ?? []),
        unlockCost: (json['unlockCost'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'class': heroClass.name,
        'baseStats': baseStats.toJson(),
        'skillIds': skillIds,
        'unlockCost': unlockCost,
      };
}

/// Mutable runtime state for a hero instance in the party.
class HeroState {
  final Hero definition;
  int level;
  double currentHp;
  double experience;
  bool isAlive;

  HeroState({
    required this.definition,
    this.level = 1,
    double? currentHp,
    this.experience = 0.0,
  })  : currentHp = currentHp ?? definition.baseStats.maxHp,
        isAlive = true;

  Stats get effectiveStats {
    // Base scaling: each level adds 5 % to all stats.
    final scale = 1.0 + (level - 1) * 0.05;
    final base = definition.baseStats;
    return Stats(
      maxHp: base.maxHp * scale,
      attack: base.attack * scale,
      defense: base.defense * scale,
      speed: base.speed,
      critChance: base.critChance,
      critMultiplier: base.critMultiplier,
      accuracy: base.accuracy,
      evasion: base.evasion,
    );
  }

  double get maxHp => effectiveStats.maxHp;

  void takeDamage(double amount) {
    currentHp = (currentHp - amount).clamp(0.0, maxHp);
    if (currentHp <= 0) isAlive = false;
  }

  void heal(double amount) {
    currentHp = (currentHp + amount).clamp(0.0, maxHp);
    if (currentHp > 0) isAlive = true;
  }

  void addExperience(double xp) {
    experience += xp;
    // Simple level-up threshold: level * 100 XP required.
    final threshold = level * 100.0;
    if (experience >= threshold) {
      experience -= threshold;
      level++;
    }
  }
}
