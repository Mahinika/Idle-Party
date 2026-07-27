import 'dart:math';

import '../models/combat_ratings.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/mission.dart';
import '../models/pet.dart';

class GameState {
  const GameState({
    required this.heroes,
    required this.enemies,
    required this.gold,
    this.lifetimeGoldEarned = 0,
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
    this.equipped = const <EquipmentSlot, EquipmentItem>{},
    this.missions = const <Mission>[],
    this.gearStash = const <EquipmentItem>[],
    this.dungeonMode = DungeonMode.push,
    this.highestFloorCleared = 0,
    this.highestDungeonCleared = -1,
    this.activePet,
    this.ownedPets = const <Pet>[],
    this.sanctuaryGoldLevel = 0,
    this.sanctuaryPowerLevel = 0,
    this.sanctuaryVitalityLevel = 0,
    this.inDungeon = false,
    this.dungeonId = 'sandy',
    this.soulboundFragments = 0,
    this.soulboundItem,
    this.godHandLevel = 0,
    this.layoutSeed = 0,
    this.soundMuted = false,
    this.reducedVfx = false,
    this.autoSellMaxPower = 24,
    this.rogueUnlocked = false,
    this.seenTips = const <String>[],
    this.loadouts = const <GearLoadout>[],
    this.achievements = const <String>[],
    this.codexEnemies = const <String>[],
    this.codexItems = const <String>[],
    this.challengeBossRush = false,
    this.challengeNoFlask = false,
    this.colorblindMode = false,
    this.uiTextScale = 1.0,
    this.lastDailyDate,
    this.dailyClaimed = false,
    this.seenChangelogVersion = '',
  });

  final List<PartyHero> heroes;
  final List<EnemyUnit> enemies;
  final int gold;

  /// Total gold awarded across all runs. Survives Ascend; hard reset clears it.
  final int lifetimeGoldEarned;

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

  /// Legacy party loadout field (pre per-hero gear). Kept for save migration only.
  /// Prefer [PartyHero.equipped]. Cleared after migrate / Ascend.
  final Map<EquipmentSlot, EquipmentItem> equipped;

  /// Up to 3 active contracts. Refreshed on Ascend; claimed slots roll anew.
  final List<Mission> missions;

  /// Inventory / Combinator stash. Cleared on Ascend / hard reset.
  final List<EquipmentItem> gearStash;

  /// Farm loops the floor; Push advances after clear.
  final DungeonMode dungeonMode;

  /// Highest floor whose wave was cleared this run (0 = none yet).
  final int highestFloorCleared;

  /// Highest dungeon catalog index cleared (meta — survives Ascend). -1 = none.
  final int highestDungeonCleared;

  /// Active combat pet (meta — survives Ascend).
  final Pet? activePet;

  /// Owned pets (meta — survives Ascend).
  final List<Pet> ownedPets;

  /// Sanctuary meta upgrades (survive Ascend).
  final int sanctuaryGoldLevel;
  final int sanctuaryPowerLevel;
  final int sanctuaryVitalityLevel;

  /// Hub vs dungeon: combat loop only runs while in dungeon.
  final bool inDungeon;

  /// Named dungeon id (e.g. sandy).
  final String dungeonId;

  /// Soulbound prestige currency (survives Ascend).
  final int soulboundFragments;

  /// Optional permanent soulbound gear piece (survives Ascend).
  final EquipmentItem? soulboundItem;

  /// God Hand upgrade level (survives Ascend).
  final int godHandLevel;

  /// Salt for procedural floor layout / encounter rolls (changes each visit).
  final int layoutSeed;

  /// Settings — survive Ascend.
  final bool soundMuted;
  final bool reducedVfx;

  /// Auto-sell *drops on pickup* when itemLevel ≤ this (0 = off).
  /// Bag AUTO SELL button ignores this and sells all non-upgrades.
  final int autoSellMaxPower;

  /// Fourth hero (Rogue) unlocked after first Ascend.
  final bool rogueUnlocked;

  /// Dismissed first-run tip ids (survives Ascend).
  final List<String> seenTips;

  /// Up to 3 saved gear presets (survives Ascend).
  final List<GearLoadout> loadouts;

  /// Unlocked local achievement ids (survives Ascend / hard reset persists
  /// only via save — no server, purely cosmetic).
  final List<String> achievements;

  /// Discovered enemy display names for the Codex (survives Ascend).
  final List<String> codexEnemies;

  /// Discovered equipment display names for the Codex (survives Ascend).
  final List<String> codexItems;

  /// Challenge toggle: packs skew to elite/boss-heavy mixes. Chosen before
  /// entering a dungeon; survives Ascend as a standing preference.
  final bool challengeBossRush;

  /// Challenge toggle: flasks are disabled entirely.
  final bool challengeNoFlask;

  /// Accessibility: colorblind-friendly combat floater palette.
  final bool colorblindMode;

  /// Accessibility: UI text scale multiplier.
  final double uiTextScale;

  /// Last UTC calendar date (`yyyy-mm-dd`) the Daily Run was entered.
  final String? lastDailyDate;

  /// Whether today's Daily Run reward has already been claimed.
  final bool dailyClaimed;

  /// Highest changelog version the player has seen in Settings → What's New.
  final String seenChangelogVersion;

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

  /// Loot Sprite (and upgrades) grant gold find; other pets stay ATK-focused.
  int get petGoldFindPercent {
    final pet = activePet;
    if (pet == null) return 0;
    if (pet.id.startsWith('loot_sprite')) {
      return 8 + pet.level * 2;
    }
    return 0;
  }

  /// Mild drop-rate help from Loot Sprite.
  int get petLootFindPercent {
    final pet = activePet;
    if (pet == null) return 0;
    if (pet.id.startsWith('loot_sprite')) {
      return 6 + pet.level;
    }
    return 0;
  }

  int get soulboundAttackBonus => soulboundItem?.attackBonus ?? 0;

  int get soulboundDefenseBonus => soulboundItem?.defenseBonus ?? 0;

  int get soulboundVitalityBonus => soulboundItem?.vitalityBonus ?? 0;

  /// Sum of all heroes' gear attack (UI / power checks).
  int get equipmentAttackBonus => heroes.fold<int>(
        0,
        (s, h) => s + h.gearAttackBonus,
      ) +
      soulboundAttackBonus;

  int get equipmentDefenseBonus => heroes.fold<int>(
        0,
        (s, h) => s + h.gearDefenseBonus,
      ) +
      soulboundDefenseBonus;

  int get equipmentVitalityBonus => heroes.fold<int>(
        0,
        (s, h) => s + h.gearVitalityBonus,
      ) +
      soulboundVitalityBonus;

  int get gearGoldFindPercent {
    var pct = heroes.fold<int>(0, (s, h) => s + h.gearGoldFindPercent);
    if (soulboundItem?.effectId == GearEffectId.goldFind) {
      pct += soulboundItem!.effectValue;
    }
    return pct;
  }

  /// Party-wide average-ish lifesteal for legacy UI; prefer per-hero.
  int get gearLifestealPercent {
    if (heroes.isEmpty) return 0;
    final total = heroes.fold<int>(0, (s, h) => s + h.gearLifestealPercent);
    return (total / heroes.length).round();
  }

  bool get gearHasPierce =>
      heroes.any((h) => h.gearHasPierce) ||
      soulboundItem?.effectId == GearEffectId.pierce;

  ProjectilePattern get weaponPattern =>
      heroes.isEmpty ? ProjectilePattern.single : heroes.first.weaponPattern;

  /// Forge / relics / AL / sanctuary / pet / soulbound — not personal gear.
  int get metaAttackBonus =>
      attackBonus +
      relicAttackBonus +
      ascensionAttackBonus +
      sanctuaryAttackBonus +
      petAttackBonus +
      soulboundAttackBonus;

  int get metaDefenseBonus =>
      defenseBonus +
      relicDefenseBonus +
      ascensionDefenseBonus +
      soulboundDefenseBonus;

  int get metaVitalityBonus =>
      vitalityBonus +
      relicVitalityBonus +
      ascensionVitalityBonus +
      sanctuaryVitalityBonus +
      soulboundVitalityBonus;

  int get totalAttackBonus => metaAttackBonus +
      heroes.fold<int>(0, (s, h) => s + h.gearAttackBonus);

  int get totalDefenseBonus => metaDefenseBonus +
      heroes.fold<int>(0, (s, h) => s + h.gearDefenseBonus);

  int get totalVitalityBonus => metaVitalityBonus +
      heroes.fold<int>(0, (s, h) => s + h.gearVitalityBonus);

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

  /// Mage aura: +15% of mage spell power (min +2) while a mage lives.
  int mageAuraBonusFor(PartyHero hero) {
    if (!hasLivingMage) {
      return 0;
    }
    PartyHero? mage;
    for (final h in heroes) {
      if (h.isAlive && h.role == HeroRole.mage) {
        mage = h;
        break;
      }
    }
    if (mage == null) return 0;
    final mageSp = mage.grownPrimaries.intel + mage.gearSpellPowerBonus;
    return max(2, (mageSp * 15) ~/ 100);
  }

  /// Warrior Defensive Stance: base guard DEF, scales lightly with level.
  int warriorGuardBonusFor(PartyHero hero) {
    if (hero.role != HeroRole.warrior || !hero.isAlive) return 0;
    return 2 + (hero.level ~/ 5);
  }

  /// Healer mend amount per tick (scales lightly with healer level).
  int get healerMendAmount {
    for (final hero in heroes) {
      if (hero.isAlive && hero.role == HeroRole.healer) {
        return 2 + (hero.level ~/ 2);
      }
    }
    return 0;
  }

  EquipmentItem? equippedFor(EquipmentSlot slot) {
    for (final hero in heroes) {
      final item = hero.itemIn(slot);
      if (item != null) return item;
    }
    return equipped[slot];
  }

  EquipmentItem? equippedOn(int heroIndex, EquipmentSlot slot) {
    if (heroIndex < 0 || heroIndex >= heroes.length) return null;
    return heroes[heroIndex].itemIn(slot);
  }

  CombatRatings ratingsFor(PartyHero hero) {
    return CombatRatings.fromHeroSheet(
      hero: hero,
      gearStrength: hero.gearStrengthBonus,
      gearAgility: hero.gearAgilityBonus,
      gearStamina: hero.gearStaminaBonus,
      gearIntellect: hero.gearIntellectBonus,
      gearSpirit: hero.gearSpiritBonus,
      gearSpellPower: hero.gearSpellPowerBonus,
      gearArmor: hero.gearArmorBonus,
      gearCrit: hero.gearCritChance,
      gearFlatAttack: hero.gearAttackBonus,
      metaAttack: metaAttackBonus,
      metaDefense: metaDefenseBonus,
      metaVitality: metaVitalityBonus,
      guardBonus: warriorGuardBonusFor(hero),
      auraBonus: mageAuraBonusFor(hero),
    );
  }

  int effectiveHeroAttack(PartyHero hero) => ratingsFor(hero).effectiveAttack;

  int effectiveHeroDefense(PartyHero hero) => ratingsFor(hero).defense;

  int effectiveHeroMaxHp(PartyHero hero) => ratingsFor(hero).maxHp;

  int effectiveHeroCrit(PartyHero hero) => ratingsFor(hero).critChance;

  int effectiveHeroSpirit(PartyHero hero) => ratingsFor(hero).spirit;

  int effectiveHeroStrength(PartyHero hero) => ratingsFor(hero).strength;

  double effectiveHeroAttackSpeed(PartyHero hero) {
    final base = switch (hero.role) {
      HeroRole.mage => 1.82,
      HeroRole.rogue => 1.55,
      HeroRole.healer => 1.43,
      HeroRole.warrior => 1.35,
    };
    return base * (1 + hero.gearAttackSpeedBonus / 100);
  }

  double effectiveHeroMoveSpeed(PartyHero hero) {
    final base = switch (hero.role) {
      HeroRole.rogue => 3.6,
      HeroRole.healer => 3.2,
      HeroRole.warrior => 3.1,
      HeroRole.mage => 3.0,
    };
    return base * (1 + hero.gearMoveSpeedBonus / 100);
  }

  /// God Hand AOE radius in tiles.
  double get godHandRadius => 1.8 + (godHandLevel * 0.15);

  /// God Hand base damage before AL/ATK scaling.
  int get godHandBaseDamage => 8 + godHandLevel * 3;

  GameState copyWith({
    List<PartyHero>? heroes,
    List<EnemyUnit>? enemies,
    int? gold,
    int? lifetimeGoldEarned,
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
    Map<EquipmentSlot, EquipmentItem>? equipped,
    List<Mission>? missions,
    List<EquipmentItem>? gearStash,
    DungeonMode? dungeonMode,
    int? highestFloorCleared,
    int? highestDungeonCleared,
    Pet? activePet,
    List<Pet>? ownedPets,
    int? sanctuaryGoldLevel,
    int? sanctuaryPowerLevel,
    int? sanctuaryVitalityLevel,
    bool? inDungeon,
    String? dungeonId,
    int? soulboundFragments,
    EquipmentItem? soulboundItem,
    int? godHandLevel,
    int? layoutSeed,
    bool? soundMuted,
    bool? reducedVfx,
    int? autoSellMaxPower,
    bool? rogueUnlocked,
    List<String>? seenTips,
    List<GearLoadout>? loadouts,
    List<String>? achievements,
    List<String>? codexEnemies,
    List<String>? codexItems,
    bool? challengeBossRush,
    bool? challengeNoFlask,
    bool? colorblindMode,
    double? uiTextScale,
    String? lastDailyDate,
    bool? dailyClaimed,
    String? seenChangelogVersion,
    bool clearEquipped = false,
    bool clearActivePet = false,
    bool clearSoulboundItem = false,
  }) {
    return GameState(
      heroes: heroes ?? this.heroes,
      enemies: enemies ?? this.enemies,
      gold: gold ?? this.gold,
      lifetimeGoldEarned: lifetimeGoldEarned ?? this.lifetimeGoldEarned,
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
      equipped: clearEquipped
          ? const <EquipmentSlot, EquipmentItem>{}
          : (equipped ?? this.equipped),
      missions: missions ?? this.missions,
      gearStash: gearStash ?? this.gearStash,
      dungeonMode: dungeonMode ?? this.dungeonMode,
      highestFloorCleared: highestFloorCleared ?? this.highestFloorCleared,
      highestDungeonCleared:
          highestDungeonCleared ?? this.highestDungeonCleared,
      activePet: clearActivePet ? null : (activePet ?? this.activePet),
      ownedPets: ownedPets ?? this.ownedPets,
      sanctuaryGoldLevel: sanctuaryGoldLevel ?? this.sanctuaryGoldLevel,
      sanctuaryPowerLevel: sanctuaryPowerLevel ?? this.sanctuaryPowerLevel,
      sanctuaryVitalityLevel:
          sanctuaryVitalityLevel ?? this.sanctuaryVitalityLevel,
      inDungeon: inDungeon ?? this.inDungeon,
      dungeonId: dungeonId ?? this.dungeonId,
      soulboundFragments: soulboundFragments ?? this.soulboundFragments,
      soulboundItem: clearSoulboundItem
          ? null
          : (soulboundItem ?? this.soulboundItem),
      godHandLevel: godHandLevel ?? this.godHandLevel,
      layoutSeed: layoutSeed ?? this.layoutSeed,
      soundMuted: soundMuted ?? this.soundMuted,
      reducedVfx: reducedVfx ?? this.reducedVfx,
      autoSellMaxPower: autoSellMaxPower ?? this.autoSellMaxPower,
      rogueUnlocked: rogueUnlocked ?? this.rogueUnlocked,
      seenTips: seenTips ?? this.seenTips,
      loadouts: loadouts ?? this.loadouts,
      achievements: achievements ?? this.achievements,
      codexEnemies: codexEnemies ?? this.codexEnemies,
      codexItems: codexItems ?? this.codexItems,
      challengeBossRush: challengeBossRush ?? this.challengeBossRush,
      challengeNoFlask: challengeNoFlask ?? this.challengeNoFlask,
      colorblindMode: colorblindMode ?? this.colorblindMode,
      uiTextScale: uiTextScale ?? this.uiTextScale,
      lastDailyDate: lastDailyDate ?? this.lastDailyDate,
      dailyClaimed: dailyClaimed ?? this.dailyClaimed,
      seenChangelogVersion: seenChangelogVersion ?? this.seenChangelogVersion,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 4,
    'heroes': heroes.map((hero) => hero.toJson()).toList(),
    'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
    'gold': gold,
    'lifetimeGoldEarned': lifetimeGoldEarned,
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
    'equipped': equipped.map(
      (slot, item) => MapEntry(slot.name, item.toJson()),
    ),
    'missions': missions.map((mission) => mission.toJson()).toList(),
    'gearStash': gearStash.map((item) => item.toJson()).toList(),
    'dungeonMode': dungeonMode.name,
    'highestFloorCleared': highestFloorCleared,
    'highestDungeonCleared': highestDungeonCleared,
    if (activePet != null) 'activePet': activePet!.toJson(),
    'ownedPets': ownedPets.map((pet) => pet.toJson()).toList(),
    'sanctuaryGoldLevel': sanctuaryGoldLevel,
    'sanctuaryPowerLevel': sanctuaryPowerLevel,
    'sanctuaryVitalityLevel': sanctuaryVitalityLevel,
    'inDungeon': inDungeon,
    'dungeonId': dungeonId,
    'soulboundFragments': soulboundFragments,
    if (soulboundItem != null) 'soulboundItem': soulboundItem!.toJson(),
    'godHandLevel': godHandLevel,
    'layoutSeed': layoutSeed,
    'soundMuted': soundMuted,
    'reducedVfx': reducedVfx,
    'autoSellMaxPower': autoSellMaxPower,
    'rogueUnlocked': rogueUnlocked,
    'seenTips': seenTips,
    'loadouts': loadouts.map((l) => l.toJson()).toList(),
    'achievements': achievements,
    'codexEnemies': codexEnemies,
    'codexItems': codexItems,
    'challengeBossRush': challengeBossRush,
    'challengeNoFlask': challengeNoFlask,
    'colorblindMode': colorblindMode,
    'uiTextScale': uiTextScale,
    if (lastDailyDate != null) 'lastDailyDate': lastDailyDate,
    'dailyClaimed': dailyClaimed,
    'seenChangelogVersion': seenChangelogVersion,
  };

  /// Parses a v2-v4 save. Legacy fields are migrated.
  factory GameState.fromJson(Map<String, dynamic> json) {
    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;
    final missionsJson = json['missions'] as List<dynamic>?;
    final stashJson = json['gearStash'] as List<dynamic>?;
    final petsJson = json['ownedPets'] as List<dynamic>?;
    final activePetJson = json['activePet'] as Map<String, dynamic>?;
    final modeRaw = json['dungeonMode'] as String?;
    final soulboundJson = json['soulboundItem'] as Map<String, dynamic>?;

    final equipped = <EquipmentSlot, EquipmentItem>{};
    final equippedJson = json['equipped'] as Map<String, dynamic>?;
    if (equippedJson != null) {
      for (final entry in equippedJson.entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        equipped[slot] = EquipmentItem.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } else {
      // v2: equippedWeapon / equippedArmor
      final weaponJson = json['equippedWeapon'] as Map<String, dynamic>?;
      final armorJson = json['equippedArmor'] as Map<String, dynamic>?;
      if (weaponJson != null) {
        equipped[EquipmentSlot.weapon] = EquipmentItem.fromJson(weaponJson);
      }
      if (armorJson != null) {
        equipped[EquipmentSlot.cloak] = EquipmentItem.fromJson(armorJson);
      }
    }

    var heroes = (json['heroes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PartyHero.fromJson)
        .toList();
    // Migrate legacy party loadout onto first hero without per-hero gear.
    final anyHeroGear = heroes.any((h) => h.equipped.isNotEmpty);
    var legacyEquipped = equipped;
    if (!anyHeroGear && equipped.isNotEmpty && heroes.isNotEmpty) {
      heroes = [
        heroes.first.copyWith(
          equipped: Map<EquipmentSlot, EquipmentItem>.from(equipped),
        ),
        ...heroes.skip(1),
      ];
      legacyEquipped = const <EquipmentSlot, EquipmentItem>{};
    }

    return GameState(
      heroes: heroes,
      enemies: (json['enemies'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(EnemyUnit.fromJson)
          .toList(),
      gold: json['gold'] as int,
      lifetimeGoldEarned: (json['lifetimeGoldEarned'] as int?) ?? 0,
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
      equipped: legacyEquipped,
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
          ? DungeonMode.push
          : DungeonMode.values.byName(modeRaw),
      highestFloorCleared: (json['highestFloorCleared'] as int?) ?? 0,
      highestDungeonCleared: (json['highestDungeonCleared'] as int?) ?? -1,
      activePet: activePetJson == null ? null : Pet.fromJson(activePetJson),
      ownedPets: petsJson == null
          ? <Pet>[]
          : petsJson.cast<Map<String, dynamic>>().map(Pet.fromJson).toList(),
      sanctuaryGoldLevel: (json['sanctuaryGoldLevel'] as int?) ?? 0,
      sanctuaryPowerLevel: (json['sanctuaryPowerLevel'] as int?) ?? 0,
      sanctuaryVitalityLevel: (json['sanctuaryVitalityLevel'] as int?) ?? 0,
      inDungeon: (json['inDungeon'] as bool?) ?? false,
      dungeonId: (json['dungeonId'] as String?) ?? 'sandy',
      soulboundFragments: (json['soulboundFragments'] as int?) ?? 0,
      soulboundItem: soulboundJson == null
          ? null
          : EquipmentItem.fromJson(soulboundJson),
      godHandLevel: (json['godHandLevel'] as int?) ?? 0,
      layoutSeed: (json['layoutSeed'] as int?) ?? 0,
      soundMuted: (json['soundMuted'] as bool?) ?? false,
      reducedVfx: (json['reducedVfx'] as bool?) ?? false,
      autoSellMaxPower: (json['autoSellMaxPower'] as int?) ?? 24,
      rogueUnlocked: (json['rogueUnlocked'] as bool?) ?? false,
      seenTips: (json['seenTips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      loadouts: (json['loadouts'] as List<dynamic>?)
              ?.map((e) => GearLoadout.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <GearLoadout>[],
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      codexEnemies: (json['codexEnemies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      codexItems: (json['codexItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      challengeBossRush: (json['challengeBossRush'] as bool?) ?? false,
      challengeNoFlask: (json['challengeNoFlask'] as bool?) ?? false,
      colorblindMode: (json['colorblindMode'] as bool?) ?? false,
      uiTextScale: (json['uiTextScale'] as num?)?.toDouble() ?? 1.0,
      lastDailyDate: json['lastDailyDate'] as String?,
      dailyClaimed: (json['dailyClaimed'] as bool?) ?? false,
      seenChangelogVersion: (json['seenChangelogVersion'] as String?) ?? '',
    );
  }
}
