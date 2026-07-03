class Stats {
  final double hp;
  final double maxHp;
  final double attack;
  final double defense;
  final double speed;
  final double critRate;
  final double critDamage;

  const Stats({
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.speed,
    required this.critRate,
    required this.critDamage,
  });

  factory Stats.empty() {
    return const Stats(
      hp: 0.0,
      maxHp: 0.0,
      attack: 0.0,
      defense: 0.0,
      speed: 0.0,
      critRate: 0.0,
      critDamage: 0.0,
    );
  }

  Stats copyWith({
    double? hp,
    double? maxHp,
    double? attack,
    double? defense,
    double? speed,
    double? critRate,
    double? critDamage,
  }) {
    return Stats(
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      speed: speed ?? this.speed,
      critRate: critRate ?? this.critRate,
      critDamage: critDamage ?? this.critDamage,
    );
  }

  Stats operator +(Stats other) {
    return Stats(
      hp: hp + other.hp,
      maxHp: maxHp + other.maxHp,
      attack: attack + other.attack,
      defense: defense + other.defense,
      speed: speed + other.speed,
      critRate: critRate + other.critRate,
      critDamage: critDamage + other.critDamage,
    );
  }

  Stats multiply(double multiplier) {
    return Stats(
      hp: hp * multiplier,
      maxHp: maxHp * multiplier,
      attack: attack * multiplier,
      defense: defense * multiplier,
      speed: speed * multiplier,
      critRate: critRate, // Crit rate typically doesn't scale linearly with level
      critDamage: critDamage, // Crit damage typically doesn't scale linearly with level
    );
  }

  @override
  String toString() {
    return 'Stats(hp: ${hp.toStringAsFixed(1)}/${maxHp.toStringAsFixed(1)}, atk: ${attack.toStringAsFixed(1)}, def: ${defense.toStringAsFixed(1)}, spd: ${speed.toStringAsFixed(2)})';
  }
}
