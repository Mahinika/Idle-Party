class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.attackBonus,
    this.level = 1,
  });

  final String id;
  final String name;
  final int attackBonus;
  final int level;

  int get totalAttackBonus => attackBonus + (level - 1);

  Pet copyWith({
    String? id,
    String? name,
    int? attackBonus,
    int? level,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      attackBonus: attackBonus ?? this.attackBonus,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'attackBonus': attackBonus,
    'level': level,
  };

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      attackBonus: json['attackBonus'] as int,
      level: (json['level'] as int?) ?? 1,
    );
  }
}
