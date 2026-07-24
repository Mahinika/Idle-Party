import 'stats.dart';

enum HeroRole { warrior, healer, mage, rogue }

class PartyHero {
  const PartyHero({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    this.role = HeroRole.rogue,
  });

  factory PartyHero.starting({
    required String name,
    required Stats stats,
    HeroRole? role,
  }) {
    return PartyHero(
      name: name,
      level: 1,
      currentHp: stats.maxHp,
      stats: stats,
      role: role ?? roleForName(name),
    );
  }

  /// Maps legacy saves / known starters to roles.
  static HeroRole roleForName(String name) => switch (name) {
    'Aegis' => HeroRole.warrior,
    'Vale' => HeroRole.healer,
    'Ember' => HeroRole.mage,
    _ => HeroRole.rogue,
  };

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final HeroRole role;

  int get attack => stats.attack + ((level - 1) * 2);

  int get defense => stats.defense + (level - 1);

  int get maxHp => stats.maxHp + ((level - 1) * 5);

  bool get isAlive => currentHp > 0;

  String get roleLabel => switch (role) {
    HeroRole.warrior => 'WARRIOR',
    HeroRole.healer => 'HEALER',
    HeroRole.mage => 'MAGE',
    HeroRole.rogue => 'ROGUE',
  };

  String get passiveLabel => switch (role) {
    HeroRole.warrior => 'Taunt + guard',
    HeroRole.healer => 'Party mend',
    HeroRole.mage => 'Arcane aura',
    HeroRole.rogue => 'Opportunist',
  };

  PartyHero takeDamage(int damage) {
    final nextHp = currentHp - damage;
    return copyWith(currentHp: nextHp.clamp(0, maxHp));
  }

  PartyHero healToFull() => copyWith(currentHp: maxHp);

  PartyHero levelUp() => copyWith(level: level + 1, currentHp: maxHp + 5);

  PartyHero train() => levelUp();

  PartyHero copyWith({
    int? level,
    int? currentHp,
    Stats? stats,
    HeroRole? role,
  }) {
    return PartyHero(
      name: name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
    'role': role.name,
  };

  factory PartyHero.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role'] as String?;
    return PartyHero(
      name: json['name'] as String,
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
      role: roleRaw == null
          ? roleForName(json['name'] as String)
          : HeroRole.values.byName(roleRaw),
    );
  }
}
