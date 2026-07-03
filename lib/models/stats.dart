/// Stats holds all numeric attributes for heroes and enemies.
/// Using nullable doubles so JSON fields can be absent (defaults applied in factory).
class Stats {
  final double maxHp;
  final double attack;
  final double defense;
  final double speed;
  final double critChance;   // 0.0 – 1.0
  final double critMultiplier;
  final double accuracy;
  final double evasion;

  const Stats({
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.speed,
    this.critChance = 0.05,
    this.critMultiplier = 1.5,
    this.accuracy = 1.0,
    this.evasion = 0.0,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        maxHp: (json['maxHp'] as num?)?.toDouble() ?? 100.0,
        attack: (json['attack'] as num?)?.toDouble() ?? 10.0,
        defense: (json['defense'] as num?)?.toDouble() ?? 5.0,
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        critChance: (json['critChance'] as num?)?.toDouble() ?? 0.05,
        critMultiplier: (json['critMultiplier'] as num?)?.toDouble() ?? 1.5,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 1.0,
        evasion: (json['evasion'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'maxHp': maxHp,
        'attack': attack,
        'defense': defense,
        'speed': speed,
        'critChance': critChance,
        'critMultiplier': critMultiplier,
        'accuracy': accuracy,
        'evasion': evasion,
      };

  /// Returns a copy with selected fields overridden.
  Stats copyWith({
    double? maxHp,
    double? attack,
    double? defense,
    double? speed,
    double? critChance,
    double? critMultiplier,
    double? accuracy,
    double? evasion,
  }) =>
      Stats(
        maxHp: maxHp ?? this.maxHp,
        attack: attack ?? this.attack,
        defense: defense ?? this.defense,
        speed: speed ?? this.speed,
        critChance: critChance ?? this.critChance,
        critMultiplier: critMultiplier ?? this.critMultiplier,
        accuracy: accuracy ?? this.accuracy,
        evasion: evasion ?? this.evasion,
      );
}
