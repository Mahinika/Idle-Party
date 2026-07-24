class Stats {
  const Stats({
    required this.attack,
    required this.defense,
    required this.maxHp,
  });

  final int attack;
  final int defense;
  final int maxHp;

  Stats copyWith({int? attack, int? defense, int? maxHp}) {
    return Stats(
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      maxHp: maxHp ?? this.maxHp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'attack': attack,
    'defense': defense,
    'maxHp': maxHp,
  };

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      maxHp: json['maxHp'] as int,
    );
  }
}
