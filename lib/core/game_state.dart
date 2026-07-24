import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';

class GameState {
  const GameState({
    required this.heroes,
    required this.enemy,
    required this.gold,
    required this.essence,
    required this.battleNumber,
    required this.bossVictories,
    required this.lastUpdated,
    required this.offlineSecondsRecovered,
    required this.attackBonus,
    required this.defenseBonus,
    required this.vitalityBonus,
    required this.recentLoot,
    required this.unlockedRelics,
  });

  final List<PartyHero> heroes;
  final EnemyUnit enemy;
  final int gold;
  final int essence;
  final int battleNumber;
  final int bossVictories;
  final DateTime lastUpdated;
  final int offlineSecondsRecovered;
  final int attackBonus;
  final int defenseBonus;
  final int vitalityBonus;
  final List<LootDrop> recentLoot;
  final List<String> unlockedRelics;

  bool hasRelic(String relicId) => unlockedRelics.contains(relicId);

  int get relicAttackBonus => hasRelic('war_banner') ? 4 : 0;

  int get relicDefenseBonus => hasRelic('iron_ward') ? 2 : 0;

  int get relicVitalityBonus => hasRelic('phoenix_ember') ? 10 : 0;

  int get totalAttackBonus => attackBonus + relicAttackBonus;

  int get totalDefenseBonus => defenseBonus + relicDefenseBonus;

  int get totalVitalityBonus => vitalityBonus + relicVitalityBonus;

  int get totalAttack =>
      heroes
          .where((hero) => hero.isAlive)
          .fold<int>(0, (sum, hero) => sum + hero.attack) +
      totalAttackBonus;

  int get aliveHeroes => heroes.where((hero) => hero.isAlive).length;

  int get partyDefenseBonus => totalDefenseBonus;

  int get partyVitalityBonus => totalVitalityBonus;

  bool get isPartyDefeated => aliveHeroes == 0;

  int effectiveHeroAttack(PartyHero hero) => hero.attack + totalAttackBonus;

  int effectiveHeroDefense(PartyHero hero) => hero.defense + totalDefenseBonus;

  int effectiveHeroMaxHp(PartyHero hero) => hero.maxHp + totalVitalityBonus;

  GameState copyWith({
    List<PartyHero>? heroes,
    EnemyUnit? enemy,
    int? gold,
    int? essence,
    int? battleNumber,
    int? bossVictories,
    DateTime? lastUpdated,
    int? offlineSecondsRecovered,
    int? attackBonus,
    int? defenseBonus,
    int? vitalityBonus,
    List<LootDrop>? recentLoot,
    List<String>? unlockedRelics,
  }) {
    return GameState(
      heroes: heroes ?? this.heroes,
      enemy: enemy ?? this.enemy,
      gold: gold ?? this.gold,
      essence: essence ?? this.essence,
      battleNumber: battleNumber ?? this.battleNumber,
      bossVictories: bossVictories ?? this.bossVictories,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      offlineSecondsRecovered:
          offlineSecondsRecovered ?? this.offlineSecondsRecovered,
      attackBonus: attackBonus ?? this.attackBonus,
      defenseBonus: defenseBonus ?? this.defenseBonus,
      vitalityBonus: vitalityBonus ?? this.vitalityBonus,
      recentLoot: recentLoot ?? this.recentLoot,
      unlockedRelics: unlockedRelics ?? this.unlockedRelics,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'heroes': heroes.map((hero) => hero.toJson()).toList(),
    'enemy': enemy.toJson(),
    'gold': gold,
    'essence': essence,
    'battleNumber': battleNumber,
    'bossVictories': bossVictories,
    'lastUpdated': lastUpdated.toIso8601String(),
    'offlineSecondsRecovered': offlineSecondsRecovered,
    'attackBonus': attackBonus,
    'defenseBonus': defenseBonus,
    'vitalityBonus': vitalityBonus,
    'recentLoot': recentLoot.map((loot) => loot.toJson()).toList(),
    'unlockedRelics': unlockedRelics,
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;
    return GameState(
      heroes: (json['heroes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PartyHero.fromJson)
          .toList(),
      enemy: EnemyUnit.fromJson(json['enemy'] as Map<String, dynamic>),
      gold: json['gold'] as int,
      essence: (json['essence'] as int?) ?? 0,
      battleNumber: json['battleNumber'] as int,
      bossVictories: (json['bossVictories'] as int?) ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      offlineSecondsRecovered: json['offlineSecondsRecovered'] as int,
      attackBonus: (json['attackBonus'] as int?) ?? 0,
      defenseBonus: (json['defenseBonus'] as int?) ?? 0,
      vitalityBonus: (json['vitalityBonus'] as int?) ?? 0,
      recentLoot: recentLootJson == null
          ? <LootDrop>[]
          : recentLootJson
                .cast<Map<String, dynamic>>()
                .map(LootDrop.fromJson)
                .toList(),
      unlockedRelics: unlockedRelicsJson == null
          ? <String>[]
          : unlockedRelicsJson.cast<String>(),
    );
  }
}
