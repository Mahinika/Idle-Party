import 'dart:math';

import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/mission.dart';
import '../models/pet.dart';

class GameState {
  const GameState({
    required this.heroes,
    required this.enemies,
    required this.gold,
    required this.essence,
    required this.bossVictories,
    required this.lastUpdated,
    required this.offlineSecondsRecovered,
    required this.attackBonus,
    required this.defenseBonus,
    required this.vitalityBonus,
    required this.recentLoot,
    required this.unlockedRelics,
    required this.currentRoom,
    required this.dungeonFloor,
    this.ascensionLevel = 0,
    this.equippedWeapon,
    this.equippedArmor,
    this.missions = const <Mission>[],
    this.gearStash = const <EquipmentItem>[],
    this.dungeonMode = DungeonMode.farm,
    this.highestFloorCleared = 0,
    this.activePet,
    this.ownedPets = const <Pet>[],
    this.sanctuaryGoldLevel = 0,
    this.sanctuaryPowerLevel = 0,
    this.sanctuaryVitalityLevel = 0,
  });

  final List<PartyHero> heroes;
  final List<EnemyUnit> enemies;
  final int gold;
  final int essence;
  final int bossVictories;
  final DateTime lastUpdated;
  final int offlineSecondsRecovered;
  final int attackBonus;
  final int defenseBonus;
  final int vitalityBonus;
  final List<LootDrop> recentLoot;
  final List<String> unlockedRelics;
  final DungeonRoom currentRoom;
  final List<DungeonRoom> dungeonFloor;

  /// Persistent meta-progress. Survives Ascend; hard reset clears it.
  final int ascensionLevel;

  /// Run equipment. Cleared on Ascend / hard reset.
  final EquipmentItem? equippedWeapon;
  final EquipmentItem? equippedArmor;

  /// Up to 3 active contracts. Refreshed on Ascend; claimed slots roll anew.
  final List<Mission> missions;

  /// Inventory / Combinator stash. Cleared on Ascend / hard reset.
  final List<EquipmentItem> gearStash;

  /// Farm loops the floor; Push advances after the boss.
  final DungeonMode dungeonMode;

  /// Highest floor whose boss was beaten this run (0 = none yet).
  final int highestFloorCleared;

  /// Active combat pet (meta — survives Ascend).
  final Pet? activePet;

  /// Owned pets (meta — survives Ascend).
  final List<Pet> ownedPets;

  /// Sanctuary meta upgrades (survive Ascend).
  final int sanctuaryGoldLevel;
  final int sanctuaryPowerLevel;
  final int sanctuaryVitalityLevel;

  /// Global room counter derived from the authoritative room position.
  int get battleNumber => currentRoom.globalBattleNumber;

  bool hasRelic(String relicId) => unlockedRelics.contains(relicId);

  int get relicAttackBonus => hasRelic('war_banner') ? 4 : 0;

  int get relicDefenseBonus => hasRelic('iron_ward') ? 2 : 0;

  int get relicVitalityBonus => hasRelic('phoenix_ember') ? 10 : 0;

  /// Flat attack from Ascension Level (+1 ATK per AL).
  int get ascensionAttackBonus => ascensionLevel;

  /// Flat defense from Ascension Level (+1 DEF every 2 AL).
  int get ascensionDefenseBonus => ascensionLevel ~/ 2;

  /// Flat vitality from Ascension Level (+2 HP per AL).
  int get ascensionVitalityBonus => ascensionLevel * 2;

  /// Extra gold percent from Ascension Level (+10% per AL).
  int get ascensionGoldBonusPercent => ascensionLevel * 10;

  /// Sanctuary gold find (+5% per level).
  int get sanctuaryGoldBonusPercent => sanctuaryGoldLevel * 5;

  int get sanctuaryAttackBonus => sanctuaryPowerLevel;

  int get sanctuaryVitalityBonus => sanctuaryVitalityLevel * 2;

  int get petAttackBonus => activePet?.totalAttackBonus ?? 0;

  int get equipmentAttackBonus =>
      (equippedWeapon?.attackBonus ?? 0) + (equippedArmor?.attackBonus ?? 0);

  int get equipmentDefenseBonus =>
      (equippedWeapon?.defenseBonus ?? 0) + (equippedArmor?.defenseBonus ?? 0);

  int get equipmentVitalityBonus =>
      (equippedWeapon?.vitalityBonus ?? 0) +
      (equippedArmor?.vitalityBonus ?? 0);

  int get totalAttackBonus =>
      attackBonus +
      relicAttackBonus +
      ascensionAttackBonus +
      equipmentAttackBonus +
      sanctuaryAttackBonus +
      petAttackBonus;

  int get totalDefenseBonus =>
      defenseBonus +
      relicDefenseBonus +
      ascensionDefenseBonus +
      equipmentDefenseBonus;

  int get totalVitalityBonus =>
      vitalityBonus +
      relicVitalityBonus +
      ascensionVitalityBonus +
      equipmentVitalityBonus +
      sanctuaryVitalityBonus;

  int get totalAttack => heroes
      .where((hero) => hero.isAlive)
      .fold<int>(0, (sum, hero) => sum + effectiveHeroAttack(hero));

  int get aliveHeroes => heroes.where((hero) => hero.isAlive).length;

  List<EnemyUnit> get aliveEnemies =>
      enemies.where((enemy) => !enemy.isDefeated).toList();

  bool get areEnemiesDefeated => enemies.every((enemy) => enemy.isDefeated);

  int get partyDefenseBonus => totalDefenseBonus;

  int get partyVitalityBonus => totalVitalityBonus;

  bool get isPartyDefeated => aliveHeroes == 0;

  bool get hasLivingMage =>
      heroes.any((hero) => hero.isAlive && hero.role == HeroRole.mage);

  bool get hasLivingHealer =>
      heroes.any((hero) => hero.isAlive && hero.role == HeroRole.healer);

  bool get hasLivingWarrior =>
      heroes.any((hero) => hero.isAlive && hero.role == HeroRole.warrior);

  /// Max floor the party may enter (cleared + frontier).
  int get maxReachableFloor => max(1, highestFloorCleared + 1);

  /// Mage aura: +15% of base hero attack (min +2) while a mage lives.
  int mageAuraBonusFor(PartyHero hero) {
    if (!hasLivingMage) {
      return 0;
    }
    return max(2, (hero.attack * 15) ~/ 100);
  }

  /// Warrior guard: +2 flat defense while tanking.
  int warriorGuardBonusFor(PartyHero hero) =>
      hero.role == HeroRole.warrior && hero.isAlive ? 2 : 0;

  /// Healer mend amount per tick (scales lightly with healer level).
  int get healerMendAmount {
    for (final hero in heroes) {
      if (hero.isAlive && hero.role == HeroRole.healer) {
        return 2 + (hero.level ~/ 2);
      }
    }
    return 0;
  }

  EquipmentItem? equippedFor(EquipmentSlot slot) => switch (slot) {
    EquipmentSlot.weapon => equippedWeapon,
    EquipmentSlot.armor => equippedArmor,
  };

  int effectiveHeroAttack(PartyHero hero) =>
      hero.attack + totalAttackBonus + mageAuraBonusFor(hero);

  int effectiveHeroDefense(PartyHero hero) =>
      hero.defense + totalDefenseBonus + warriorGuardBonusFor(hero);

  int effectiveHeroMaxHp(PartyHero hero) => hero.maxHp + totalVitalityBonus;

  GameState copyWith({
    List<PartyHero>? heroes,
    List<EnemyUnit>? enemies,
    int? gold,
    int? essence,
    int? bossVictories,
    DateTime? lastUpdated,
    int? offlineSecondsRecovered,
    int? attackBonus,
    int? defenseBonus,
    int? vitalityBonus,
    List<LootDrop>? recentLoot,
    List<String>? unlockedRelics,
    DungeonRoom? currentRoom,
    List<DungeonRoom>? dungeonFloor,
    int? ascensionLevel,
    EquipmentItem? equippedWeapon,
    EquipmentItem? equippedArmor,
    List<Mission>? missions,
    List<EquipmentItem>? gearStash,
    DungeonMode? dungeonMode,
    int? highestFloorCleared,
    Pet? activePet,
    List<Pet>? ownedPets,
    int? sanctuaryGoldLevel,
    int? sanctuaryPowerLevel,
    int? sanctuaryVitalityLevel,
    bool clearEquippedWeapon = false,
    bool clearEquippedArmor = false,
    bool clearActivePet = false,
  }) {
    return GameState(
      heroes: heroes ?? this.heroes,
      enemies: enemies ?? this.enemies,
      gold: gold ?? this.gold,
      essence: essence ?? this.essence,
      bossVictories: bossVictories ?? this.bossVictories,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      offlineSecondsRecovered:
          offlineSecondsRecovered ?? this.offlineSecondsRecovered,
      attackBonus: attackBonus ?? this.attackBonus,
      defenseBonus: defenseBonus ?? this.defenseBonus,
      vitalityBonus: vitalityBonus ?? this.vitalityBonus,
      recentLoot: recentLoot ?? this.recentLoot,
      unlockedRelics: unlockedRelics ?? this.unlockedRelics,
      currentRoom: currentRoom ?? this.currentRoom,
      dungeonFloor: dungeonFloor ?? this.dungeonFloor,
      ascensionLevel: ascensionLevel ?? this.ascensionLevel,
      equippedWeapon: clearEquippedWeapon
          ? null
          : (equippedWeapon ?? this.equippedWeapon),
      equippedArmor: clearEquippedArmor
          ? null
          : (equippedArmor ?? this.equippedArmor),
      missions: missions ?? this.missions,
      gearStash: gearStash ?? this.gearStash,
      dungeonMode: dungeonMode ?? this.dungeonMode,
      highestFloorCleared: highestFloorCleared ?? this.highestFloorCleared,
      activePet: clearActivePet ? null : (activePet ?? this.activePet),
      ownedPets: ownedPets ?? this.ownedPets,
      sanctuaryGoldLevel: sanctuaryGoldLevel ?? this.sanctuaryGoldLevel,
      sanctuaryPowerLevel: sanctuaryPowerLevel ?? this.sanctuaryPowerLevel,
      sanctuaryVitalityLevel:
          sanctuaryVitalityLevel ?? this.sanctuaryVitalityLevel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 2,
    'heroes': heroes.map((hero) => hero.toJson()).toList(),
    'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
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
    'currentRoom': currentRoom.toJson(),
    'dungeonFloor': dungeonFloor.map((room) => room.toJson()).toList(),
    'ascensionLevel': ascensionLevel,
    if (equippedWeapon != null) 'equippedWeapon': equippedWeapon!.toJson(),
    if (equippedArmor != null) 'equippedArmor': equippedArmor!.toJson(),
    'missions': missions.map((mission) => mission.toJson()).toList(),
    'gearStash': gearStash.map((item) => item.toJson()).toList(),
    'dungeonMode': dungeonMode.name,
    'highestFloorCleared': highestFloorCleared,
    if (activePet != null) 'activePet': activePet!.toJson(),
    'ownedPets': ownedPets.map((pet) => pet.toJson()).toList(),
    'sanctuaryGoldLevel': sanctuaryGoldLevel,
    'sanctuaryPowerLevel': sanctuaryPowerLevel,
    'sanctuaryVitalityLevel': sanctuaryVitalityLevel,
  };

  /// Parses a v2 save. Legacy v1 saves are migrated in
  /// `GameLogic.stateFromJson` before reaching this factory.
  factory GameState.fromJson(Map<String, dynamic> json) {
    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;
    final weaponJson = json['equippedWeapon'] as Map<String, dynamic>?;
    final armorJson = json['equippedArmor'] as Map<String, dynamic>?;
    final missionsJson = json['missions'] as List<dynamic>?;
    final stashJson = json['gearStash'] as List<dynamic>?;
    final petsJson = json['ownedPets'] as List<dynamic>?;
    final activePetJson = json['activePet'] as Map<String, dynamic>?;
    final modeRaw = json['dungeonMode'] as String?;

    return GameState(
      heroes: (json['heroes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PartyHero.fromJson)
          .toList(),
      enemies: (json['enemies'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(EnemyUnit.fromJson)
          .toList(),
      gold: json['gold'] as int,
      essence: (json['essence'] as int?) ?? 0,
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
      currentRoom: DungeonRoom.fromJson(
        json['currentRoom'] as Map<String, dynamic>,
      ),
      dungeonFloor: (json['dungeonFloor'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DungeonRoom.fromJson)
          .toList(),
      ascensionLevel: (json['ascensionLevel'] as int?) ?? 0,
      equippedWeapon: weaponJson == null
          ? null
          : EquipmentItem.fromJson(weaponJson),
      equippedArmor: armorJson == null
          ? null
          : EquipmentItem.fromJson(armorJson),
      missions: missionsJson == null
          ? <Mission>[]
          : missionsJson
                .cast<Map<String, dynamic>>()
                .map(Mission.fromJson)
                .toList(),
      gearStash: stashJson == null
          ? <EquipmentItem>[]
          : stashJson
                .cast<Map<String, dynamic>>()
                .map(EquipmentItem.fromJson)
                .toList(),
      dungeonMode: modeRaw == null
          ? DungeonMode.farm
          : DungeonMode.values.byName(modeRaw),
      highestFloorCleared: (json['highestFloorCleared'] as int?) ?? 0,
      activePet: activePetJson == null ? null : Pet.fromJson(activePetJson),
      ownedPets: petsJson == null
          ? <Pet>[]
          : petsJson.cast<Map<String, dynamic>>().map(Pet.fromJson).toList(),
      sanctuaryGoldLevel: (json['sanctuaryGoldLevel'] as int?) ?? 0,
      sanctuaryPowerLevel: (json['sanctuaryPowerLevel'] as int?) ?? 0,
      sanctuaryVitalityLevel: (json['sanctuaryVitalityLevel'] as int?) ?? 0,
    );
  }
}
