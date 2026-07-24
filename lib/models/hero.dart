import 'stats.dart';

class PartyHero {
  const PartyHero({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
  });

  factory PartyHero.starting({required String name, required Stats stats}) {
    return PartyHero(
      name: name,
      level: 1,
      currentHp: stats.maxHp,
      stats: stats,
    );
  }

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;

  int get attack => stats.attack + ((level - 1) * 2);

  int get defense => stats.defense + (level - 1);

  int get maxHp => stats.maxHp + ((level - 1) * 5);

  bool get isAlive => currentHp > 0;

  PartyHero takeDamage(int damage) {
    final nextHp = currentHp - damage;
    return copyWith(currentHp: nextHp.clamp(0, maxHp));
  }

  PartyHero healToFull() => copyWith(currentHp: maxHp);

  PartyHero levelUp() => copyWith(level: level + 1, currentHp: maxHp + 5);

  PartyHero train() => levelUp();

  PartyHero copyWith({int? level, int? currentHp, Stats? stats}) {
    return PartyHero(
      name: name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
  };

  factory PartyHero.fromJson(Map<String, dynamic> json) {
    return PartyHero(
      name: json['name'] as String,
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }
}
