/// Classic primary attributes (Str/Agi/Sta/Int/Spi).
///
/// Heroes derive combat from these via CombatRatings.
/// Enemies use [Stats.enemy] flat overrides (no primary combat model in v1).
class Stats {
  const Stats({
    required this.strength,
    required this.agility,
    required this.stamina,
    required this.intellect,
    required this.spirit,
    this.flatAttack,
    this.flatDefense,
    this.flatMaxHp,
  });

  /// Flat combat sheet for enemies (baked ATK/DEF/HP).
  factory Stats.enemy({
    required int attack,
    required int defense,
    required int maxHp,
  }) {
    return Stats(
      strength: 1,
      agility: 1,
      stamina: maxHp > 0 ? (maxHp / 10).ceil().clamp(1, 9999) : 1,
      intellect: 1,
      spirit: 1,
      flatAttack: attack,
      flatDefense: defense,
      flatMaxHp: maxHp,
    );
  }

  final int strength;
  final int agility;
  final int stamina;
  final int intellect;
  final int spirit;

  /// Enemy-only baked combat values.
  final int? flatAttack;
  final int? flatDefense;
  final int? flatMaxHp;

  bool get isEnemySheet => flatAttack != null;

  /// Enemy passthrough (heroes should use CombatRatings / PartyHero getters).
  int get attack => flatAttack ?? strength;
  int get defense => flatDefense ?? agility;
  int get maxHp => flatMaxHp ?? (10 * stamina);

  Stats copyWith({
    int? strength,
    int? agility,
    int? stamina,
    int? intellect,
    int? spirit,
    int? flatAttack,
    int? flatDefense,
    int? flatMaxHp,
  }) {
    return Stats(
      strength: strength ?? this.strength,
      agility: agility ?? this.agility,
      stamina: stamina ?? this.stamina,
      intellect: intellect ?? this.intellect,
      spirit: spirit ?? this.spirit,
      flatAttack: flatAttack ?? this.flatAttack,
      flatDefense: flatDefense ?? this.flatDefense,
      flatMaxHp: flatMaxHp ?? this.flatMaxHp,
    );
  }

  Map<String, dynamic> toJson() {
    if (isEnemySheet) {
      return <String, dynamic>{
        'attack': flatAttack,
        'defense': flatDefense,
        'maxHp': flatMaxHp,
        'strength': strength,
        'agility': agility,
        'stamina': stamina,
        'intellect': intellect,
        'spirit': spirit,
      };
    }
    return <String, dynamic>{
      'strength': strength,
      'agility': agility,
      'stamina': stamina,
      'intellect': intellect,
      'spirit': spirit,
    };
  }

  /// Parses v5 primaries or legacy `{attack,defense,maxHp}` as enemy flat sheet.
  /// Hero legacy migration is done in [PartyHero.fromJson].
  factory Stats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('strength')) {
      return Stats(
        strength: json['strength'] as int,
        agility: json['agility'] as int,
        stamina: json['stamina'] as int,
        intellect: json['intellect'] as int,
        spirit: json['spirit'] as int,
        flatAttack: json['attack'] as int?,
        flatDefense: json['defense'] as int?,
        flatMaxHp: json['maxHp'] as int?,
      );
    }

    return Stats.enemy(
      attack: (json['attack'] as int?) ?? 1,
      defense: (json['defense'] as int?) ?? 1,
      maxHp: (json['maxHp'] as int?) ?? 10,
    );
  }
}
