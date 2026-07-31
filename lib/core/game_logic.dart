import 'dart:convert';
import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../models/mission.dart';
import '../models/pet.dart';
import '../models/proficiency.dart';
import '../models/stats.dart';
import 'dungeon_generator.dart';
import 'equipment_factory.dart';
import 'game_state.dart';
import 'meta_systems.dart';

class GameLogic {
  /// Injectable randomness for enemy targeting (seed in tests).
  static Random random = Random();

  static const String warBannerRelic = 'war_banner';
  static const String ironWardRelic = 'iron_ward';
  static const String phoenixEmberRelic = 'phoenix_ember';
  static const List<String> relicOrder = <String>[
    warBannerRelic,
    ironWardRelic,
    phoenixEmberRelic,
  ];
  static const Map<LootRarity, String> rarityNames = <LootRarity, String>{
    LootRarity.common: 'Common',
    LootRarity.uncommon: 'Uncommon',
    LootRarity.rare: 'Rare',
    LootRarity.epic: 'Epic',
    LootRarity.legendary: 'Legendary',
  };
  static const Map<String, String> relicNames = <String, String>{
    warBannerRelic: 'War Banner',
    ironWardRelic: 'Iron Ward',
    phoenixEmberRelic: 'Phoenix Ember',
  };
  static const Map<String, String> relicDescriptions = <String, String>{
    warBannerRelic: 'Permanent +4 team attack aura.',
    ironWardRelic: 'Permanent +2 team defense aura.',
    phoenixEmberRelic: 'Permanent +10 max HP for every hero.',
  };
  static const Map<String, int> relicCosts = <String, int>{
    warBannerRelic: 6,
    ironWardRelic: 14,
    phoenixEmberRelic: 28,
  };

  static GameState createInitialState({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: 0,
      dungeonId: 'sandy',
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    final aegis = PartyHero.starting(
      name: 'Aegis',
      role: HeroRole.warrior,
      stats: PartyHero.startingStatsFor(HeroRole.warrior),
      equipped: _starterGear(HeroRole.warrior),
    );
    final vale = PartyHero.starting(
      name: 'Vale',
      role: HeroRole.healer,
      stats: PartyHero.startingStatsFor(HeroRole.healer),
      equipped: _starterGear(HeroRole.healer),
    );
    final ember = PartyHero.starting(
      name: 'Ember',
      role: HeroRole.mage,
      stats: PartyHero.startingStatsFor(HeroRole.mage),
      equipped: _starterGear(HeroRole.mage),
    );
    var state = GameState(
      heroes: <PartyHero>[aegis, vale, ember],
      enemies: createEnemyGroup(firstRoom, dungeonId: 'sandy'),
      gold: 0,
      lifetimeGoldEarned: 0,
      essence: 0,
      bossVictories: 0,
      lastUpdated: timestamp,
      offlineSecondsRecovered: 0,
      attackBonus: 0,
      defenseBonus: 0,
      vitalityBonus: 0,
      recentLoot: <LootDrop>[],
      unlockedRelics: <String>[],
      currentRoom: firstRoom,
      dungeonFloor: floor,
      ascensionLevel: 0,
      equipped: const <EquipmentSlot, EquipmentItem>{},
      missions: createMissionBoard(ascensionLevel: 0),
      gearStash: const <EquipmentItem>[],
      dungeonMode: DungeonMode.push,
      highestFloorCleared: 0,
      highestDungeonCleared: -1,
      activePet: null,
      ownedPets: const <Pet>[],
      sanctuaryGoldLevel: 0,
      sanctuaryPowerLevel: 0,
      sanctuaryVitalityLevel: 0,
      metaDepth: MetaDepthState.empty,
      inDungeon: false,
      dungeonId: 'sandy',
      soulboundFragments: 0,
      godHandLevel: 0,
      layoutSeed: layoutSeed,
    );
    return state.copyWith(
      heroes: state.heroes
          .map((h) => h.copyWith(currentHp: state.effectiveHeroMaxHp(h)))
          .toList(),
    );
  }

  static int newLayoutSeed() => random.nextInt(0x3fffffff);

  static const double ascensionDropPenalty = 0.15;

  static Map<String, String> get dungeonNames => {
    for (final d in DungeonCatalog.all) d.id: d.name,
  };

  static int bossFloorFor(GameState state) =>
      DungeonGenerator.bossFloorFor(state.ascensionLevel);

  static GameState enterDungeon(GameState state, {String dungeonId = 'sandy'}) {
    final def = DungeonCatalog.byId(dungeonId);
    final unlocked = DungeonCatalog.isUnlocked(
      dungeonId,
      state.lifetimeGoldEarned,
      state.highestDungeonCleared,
    );
    if (!unlocked && def.number > 0) {
      return state;
    }
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
    );
    final room = floor.first;
    return state.copyWith(
      inDungeon: true,
      dungeonId: dungeonId,
      dungeonMode: state.dungeonMode,
      highestFloorCleared: 0,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: createEnemyGroup(
        room,
        dungeonId: dungeonId,
        fromState: state,
      ),
      layoutSeed: layoutSeed,
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState leaveDungeon(GameState state) {
    return state.copyWith(inDungeon: false, lastUpdated: DateTime.now());
  }

  static int godHandUpgradeCost(int level) => 10 + level * 8;

  static GameState upgradeGodHand(GameState state) {
    final cost = godHandUpgradeCost(state.godHandLevel);
    if (state.essence < cost) {
      return state;
    }
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        godHandLevel: state.godHandLevel + 1,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Bind an equipped weapon (or armor when preferred) into the permanent
  /// soulbound slot.
  static GameState bindSoulbound(GameState state, {int? heroIndex}) {
    if (state.soulboundFragments < 3) {
      return state;
    }
    final preferArmor = state.metaDepth.soulboundIsArmor;
    final preferredSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak]
        : <EquipmentSlot>[EquipmentSlot.weapon];
    final fallbackSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.weapon]
        : <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak];

    var sourceIndex = heroIndex;
    EquipmentItem? piece;
    EquipmentSlot? pieceSlot;

    EquipmentItem? findOnHero(int i, List<EquipmentSlot> slots) {
      for (final slot in slots) {
        final candidate = state.heroes[i].itemIn(slot);
        if (candidate != null) return candidate;
      }
      return null;
    }

    EquipmentSlot? slotOf(PartyHero hero, EquipmentItem item) {
      for (final e in hero.equipped.entries) {
        if (e.value.id == item.id) return e.key;
      }
      return null;
    }

    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      piece = findOnHero(sourceIndex, preferredSlots) ??
          findOnHero(sourceIndex, fallbackSlots);
      if (piece != null) {
        pieceSlot = slotOf(state.heroes[sourceIndex], piece);
      }
    } else {
      for (var i = 0; i < state.heroes.length; i++) {
        piece = findOnHero(i, preferredSlots);
        if (piece != null) {
          sourceIndex = i;
          pieceSlot = slotOf(state.heroes[i], piece);
          break;
        }
      }
      if (piece == null) {
        for (var i = 0; i < state.heroes.length; i++) {
          piece = findOnHero(i, fallbackSlots);
          if (piece != null) {
            sourceIndex = i;
            pieceSlot = slotOf(state.heroes[i], piece);
            break;
          }
        }
      }
    }
    if (piece == null || sourceIndex == null || pieceSlot == null) {
      return state;
    }
    final isArmor = pieceSlot == EquipmentSlot.chest ||
        pieceSlot == EquipmentSlot.cloak;
    final bound = piece.copyWith(
      id: 'soulbound_${piece.id}',
      name: 'Soulbound ${piece.name}',
    );
    final hero = state.heroes[sourceIndex];
    final nextHeroGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(pieceSlot);
    final heroes = [...state.heroes];
    heroes[sourceIndex] = hero.copyWith(equipped: nextHeroGear);
    return state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
      soulboundItem: bound,
      soulboundFragments: state.soulboundFragments - 3,
      metaDepth: state.metaDepth.copyWith(soulboundIsArmor: isArmor),
      lastUpdated: DateTime.now(),
    );
  }

  /// Spend soulbound fragments to refine the bound piece (+1 refine).
  static int refineSoulboundCost(int refineLevel) => 2 + (refineLevel ~/ 3);

  static GameState refineSoulbound(GameState state) {
    if (state.soulboundItem == null) return state;
    final cost = refineSoulboundCost(state.metaDepth.soulboundRefine);
    if (state.soulboundFragments < cost) return state;
    return state.copyWith(
      soulboundFragments: state.soulboundFragments - cost,
      metaDepth: state.metaDepth.copyWith(
        soulboundRefine: state.metaDepth.soulboundRefine + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static const Map<String, String> sanctuaryNames = <String, String>{
    'gold': 'Gold Find',
    'power': 'War Altar',
    'vitality': 'Life Well',
    'xp': 'Lore Font',
  };

  static int sanctuaryCost(int level) => 15 + (level * 12);

  static String sanctuaryBonusLabel(String track, int level) {
    return switch (track) {
      'gold' => '+${level * 5}% gold find',
      'power' => '+$level party attack',
      'vitality' => '+${level * 2} max HP',
      'xp' => '+${level * 4}% XP find',
      _ => '',
    };
  }

  static GameState upgradeSanctuary(GameState state, String track) {
    final level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
      'xp' => state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (level < 0) {
      return state;
    }
    final cost = sanctuaryCost(level);
    if (state.essence < cost) {
      return state;
    }
    var next = state.copyWith(essence: state.essence - cost);
    next = switch (track) {
      'gold' => next.copyWith(sanctuaryGoldLevel: level + 1),
      'power' => next.copyWith(sanctuaryPowerLevel: level + 1),
      'vitality' => next.copyWith(sanctuaryVitalityLevel: level + 1),
      'xp' => next.copyWith(
          metaDepth: next.metaDepth.copyWith(sanctuaryXpLevel: level + 1),
        ),
      _ => state,
    };
    if (track == 'vitality') {
      next = next.copyWith(
        heroes: next.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: min(
                  next.effectiveHeroMaxHp(hero),
                  hero.currentHp + 2,
                ),
              ),
            )
            .toList(),
      );
    }
    return MetaSystems.evaluateAchievements(
      next.copyWith(lastUpdated: DateTime.now()),
    );
  }

  /// Prestige a sanctuary track at level 12+: reset to 0, +1 prestige, essence.
  static GameState prestigeSanctuaryTrack(GameState state, String track) {
    final level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
      'xp' => state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (level < 12) return state;
    final essenceGain = 25 + level;
    final md = state.metaDepth;
    final nextMd = switch (track) {
      'gold' => md.copyWith(sanctuaryGoldPrestige: md.sanctuaryGoldPrestige + 1),
      'power' =>
        md.copyWith(sanctuaryPowerPrestige: md.sanctuaryPowerPrestige + 1),
      'vitality' => md.copyWith(
          sanctuaryVitalityPrestige: md.sanctuaryVitalityPrestige + 1,
        ),
      'xp' => md.copyWith(
          sanctuaryXpLevel: 0,
          sanctuaryXpPrestige: md.sanctuaryXpPrestige + 1,
        ),
      _ => md,
    };
    final next = switch (track) {
      'gold' => state.copyWith(
          sanctuaryGoldLevel: 0,
          essence: state.essence + essenceGain,
          metaDepth: nextMd,
        ),
      'power' => state.copyWith(
          sanctuaryPowerLevel: 0,
          essence: state.essence + essenceGain,
          metaDepth: nextMd,
        ),
      'vitality' => state.copyWith(
          sanctuaryVitalityLevel: 0,
          essence: state.essence + essenceGain,
          metaDepth: nextMd,
        ),
      'xp' => state.copyWith(
          essence: state.essence + essenceGain,
          metaDepth: nextMd,
        ),
      _ => state,
    };
    return MetaSystems.evaluateAchievements(
      next.copyWith(lastUpdated: DateTime.now()),
    );
  }

  static PetRarity _rollPetRarity() {
    final total = PetRarity.values.fold<int>(
      0,
      (sum, r) => sum + PetCatalog.rarityWeight(r),
    );
    var roll = random.nextInt(total);
    for (final r in PetRarity.values) {
      roll -= PetCatalog.rarityWeight(r);
      if (roll < 0) return r;
    }
    return PetRarity.common;
  }

  static int hatchPetCost(GameState state) =>
      20 + (state.ownedPets.length * 15);

  static GameState hatchPet(GameState state) {
    if (state.ownedPets.length >= state.metaDepth.basePetRosterCap) {
      return state;
    }
    final cost = hatchPetCost(state);
    if (state.essence < cost) {
      return state;
    }
    final species = PetCatalog.all[random.nextInt(PetCatalog.all.length)];
    final rarity = _rollPetRarity();
    final pet = Pet(
      id: '${species.id}_${random.nextInt(100000)}',
      name: species.name,
      attackBonus: species.baseAttack + state.ascensionLevel,
      speciesId: species.id,
      rarity: rarity,
      passive: species.passive,
      affinityDungeonId: species.affinityDungeonId,
      passivePerLevel: species.passivePerLevel,
    );
    final pets = List<Pet>.from(state.ownedPets)..add(pet);
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        ownedPets: pets,
        activePet: state.activePet ?? pet,
        metaDepth: state.metaDepth.copyWith(
          lifetimePetHatches: state.metaDepth.lifetimePetHatches + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Merge two same-species pets into one higher-rarity result.
  static bool canMergePets(GameState state, String petIdA, String petIdB) {
    if (petIdA == petIdB) return false;
    Pet? a;
    Pet? b;
    for (final pet in state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return false;
    if (a.resolvedSpecies != b.resolvedSpecies) return false;
    if (a.rarity == PetRarity.legendary && b.rarity == PetRarity.legendary) {
      return false;
    }
    return true;
  }

  /// Merge two same-species pets into one higher-rarity result.
  static GameState mergePets(GameState state, String petIdA, String petIdB) {
    if (!canMergePets(state, petIdA, petIdB)) return state;
    Pet? a;
    Pet? b;
    for (final pet in state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return state;
    final species = PetCatalog.byId(a.resolvedSpecies);
    final maxIdx = max(a.rarity.index, b.rarity.index);
    final nextIdx = min(PetRarity.values.length - 1, maxIdx + 1);
    final rarity = PetRarity.values[nextIdx];
    final bond = max(a.bondLevel, b.bondLevel);
    final level = max(a.level, b.level);
    final merged = Pet(
      id: '${a.resolvedSpecies}_${random.nextInt(100000)}',
      name: species?.name ?? a.name,
      attackBonus: max(a.attackBonus, b.attackBonus),
      level: level,
      speciesId: a.resolvedSpecies,
      rarity: rarity,
      passive: species?.passive ?? a.passive,
      affinityDungeonId: species?.affinityDungeonId ?? a.affinityDungeonId,
      bondLevel: bond,
      frame: a.frame.index >= b.frame.index ? a.frame : b.frame,
      passivePerLevel: species?.passivePerLevel ?? a.passivePerLevel,
    );
    final pets = state.ownedPets
        .where((p) => p.id != petIdA && p.id != petIdB)
        .toList()
      ..add(merged);
    final activeWasMerged =
        state.activePet?.id == petIdA || state.activePet?.id == petIdB;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        ownedPets: pets,
        activePet: activeWasMerged ? merged : state.activePet,
        metaDepth: state.metaDepth.copyWith(
          lifetimePetMerges: state.metaDepth.lifetimePetMerges + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static GameState setFavoritePetSpecies(GameState state, String speciesId) {
    if (speciesId.isEmpty) return state;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(favoritePetSpecies: speciesId),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static GameState setActiveTitle(GameState state, String title) {
    if (title.isEmpty) return state;
    if (!state.metaDepth.titles.contains(title)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(activeTitle: title),
      lastUpdated: DateTime.now(),
    );
  }

  static int petFrameCost(PetFrame frame) => switch (frame) {
        PetFrame.none => 0,
        PetFrame.bronze => 5,
        PetFrame.silver => 12,
        PetFrame.gold => 22,
        PetFrame.crystal => 35,
      };

  static GameState buyPetFrame(GameState state, String petId, PetFrame frame) {
    if (frame == PetFrame.none) return state;
    final cost = petFrameCost(frame);
    if (state.essence < cost) return state;
    final idx = state.ownedPets.indexWhere((p) => p.id == petId);
    if (idx < 0) return state;
    final pet = state.ownedPets[idx];
    if (pet.frame.index >= frame.index) return state;
    final pets = List<Pet>.from(state.ownedPets);
    pets[idx] = pet.copyWith(frame: frame);
    Pet? active = state.activePet;
    if (active?.id == petId) active = pets[idx];
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: active,
      lastUpdated: DateTime.now(),
    );
  }

  static int bondPetCost(int bondLevel) => 5 + bondLevel * 3;

  static GameState bondPet(GameState state, String petId) {
    final idx = state.ownedPets.indexWhere((p) => p.id == petId);
    if (idx < 0) return state;
    final pet = state.ownedPets[idx];
    final cost = bondPetCost(pet.bondLevel);
    if (state.essence < cost) return state;
    final pets = List<Pet>.from(state.ownedPets);
    pets[idx] = pet.copyWith(bondLevel: pet.bondLevel + 1);
    Pet? active = state.activePet;
    if (active?.id == petId) active = pets[idx];
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: active,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState setActivePet(GameState state, String petId) {
    Pet? match;
    for (final pet in state.ownedPets) {
      if (pet.id == petId) {
        match = pet;
        break;
      }
    }
    if (match == null) {
      return state;
    }
    return state.copyWith(activePet: match, lastUpdated: DateTime.now());
  }

  static int petLevelUpCost(Pet pet) => 15 + pet.level * 10;

  static GameState levelUpPet(GameState state, String petId) {
    final index = state.ownedPets.indexWhere((pet) => pet.id == petId);
    if (index < 0) {
      return state;
    }
    final pet = state.ownedPets[index];
    final cost = petLevelUpCost(pet);
    if (state.essence < cost) {
      return state;
    }

    final leveledPet = pet.copyWith(level: pet.level + 1);
    final pets = List<Pet>.from(state.ownedPets)..[index] = leveledPet;
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: state.activePet?.id == petId ? leveledPet : state.activePet,
      lastUpdated: DateTime.now(),
    );
  }

  static bool canUseConsumable(GameState state) =>
      !state.challengeNoFlask &&
      state.heroes.any((h) => h.itemIn(EquipmentSlot.consumable) != null);

  static GameState useConsumable(GameState state, {int? heroIndex}) {
    if (state.challengeNoFlask) {
      return state;
    }
    var sourceIndex = heroIndex;
    EquipmentItem? item;
    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      item = state.heroes[sourceIndex].itemIn(EquipmentSlot.consumable);
    } else {
      for (var i = 0; i < state.heroes.length; i++) {
        final candidate = state.heroes[i].itemIn(EquipmentSlot.consumable);
        if (candidate != null) {
          item = candidate;
          sourceIndex = i;
          break;
        }
      }
    }
    if (item == null || sourceIndex == null) {
      return state;
    }

    final hero = state.heroes[sourceIndex];
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(EquipmentSlot.consumable);
    final heroes = [...state.heroes];
    heroes[sourceIndex] = hero.copyWith(equipped: nextGear);
    var next = state.copyWith(heroes: heroes);
    final healAmount = max(
      8,
      12 + state.vitalityBonus ~/ 2 + item.vitalityBonus + item.attackBonus,
    );
    return next.copyWith(
      heroes: next.heroes
          .map(
            (h) => h.isAlive
                ? h.copyWith(
                    currentHp: min(
                      next.effectiveHeroMaxHp(h),
                      h.currentHp + healAmount,
                    ),
                  )
                : h,
          )
          .toList(),
    );
  }

  static GameState setDungeonMode(GameState state, DungeonMode mode) {
    if (state.dungeonMode == mode) {
      return state;
    }
    return state.copyWith(dungeonMode: mode, lastUpdated: DateTime.now());
  }

  static bool canTravelToFloor(GameState state, int floorNumber) {
    if (floorNumber < 1) {
      return false;
    }
    return floorNumber <= state.maxReachableFloor;
  }

  /// Jump to an unlocked floor wave (farm/push zone select).
  static GameState travelToFloor(GameState state, int floorNumber) {
    if (!canTravelToFloor(state, floorNumber)) {
      return state;
    }
    if (floorNumber == state.currentRoom.floorNumber &&
        !state.isPartyDefeated) {
      return state;
    }
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      floorNumber,
      ascensionLevel: state.ascensionLevel,
      dungeonId: state.dungeonId,
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    return state.copyWith(
      currentRoom: firstRoom,
      dungeonFloor: floor,
      enemies: createEnemyGroup(
        firstRoom,
        dungeonId: state.dungeonId,
        fromState: state,
      ),
      layoutSeed: layoutSeed,
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Failed push: retreat to the highest cleared floor (or floor 1).
  static GameState retreatFromFailedPush(GameState state) {
    final safeFloor = max(1, state.highestFloorCleared);
    return travelToFloor(
      state.copyWith(
        dungeonMode: DungeonMode.farm,
        metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
      ),
      safeFloor,
    );
  }

  /// Builds the standard 3-contract board scaled by Ascension Level.
  static List<Mission> createMissionBoard({required int ascensionLevel}) {
    return MissionType.values
        .map(
          (type) => createMission(type: type, ascensionLevel: ascensionLevel),
        )
        .toList();
  }

  static Mission createMission({
    required MissionType type,
    required int ascensionLevel,
  }) {
    final al = ascensionLevel;
    return switch (type) {
      MissionType.defeatEnemies => Mission(
        id: 'defeat_enemies',
        type: type,
        title: 'Slay foes',
        target: 8 + (al * 4),
        progress: 0,
        goldReward: 20 + (al * 12),
        essenceReward: 2 + al,
      ),
      MissionType.clearBosses => Mission(
        id: 'clear_bosses',
        type: type,
        title: 'Fell wardens',
        target: max(1, 1 + (al ~/ 2)),
        progress: 0,
        goldReward: 35 + (al * 18),
        essenceReward: 3 + al,
      ),
      MissionType.earnGold => Mission(
        id: 'earn_gold',
        type: type,
        title: 'Gather gold',
        target: 40 + (al * 35),
        progress: 0,
        goldReward: 15 + (al * 10),
        essenceReward: 2 + (al ~/ 2),
      ),
    };
  }

  static GameState applyMissionProgress(
    GameState state, {
    int enemiesDefeated = 0,
    int bossesCleared = 0,
    int goldEarned = 0,
  }) {
    if (state.missions.isEmpty) {
      return state;
    }
    if (enemiesDefeated <= 0 && bossesCleared <= 0 && goldEarned <= 0) {
      return state;
    }

    final updated = state.missions.map((mission) {
      if (mission.isComplete) {
        return mission;
      }
      final add = switch (mission.type) {
        MissionType.defeatEnemies => enemiesDefeated,
        MissionType.clearBosses => bossesCleared,
        MissionType.earnGold => goldEarned,
      };
      if (add <= 0) {
        return mission;
      }
      return mission.copyWith(
        progress: min(mission.target, mission.progress + add),
      );
    }).toList();

    return state.copyWith(missions: updated);
  }

  /// Claims a completed mission, grants rewards, and rolls a fresh contract.
  static GameState claimMission(GameState state, String missionId) {
    final index = state.missions.indexWhere(
      (mission) => mission.id == missionId,
    );
    if (index < 0) {
      return state;
    }
    final mission = state.missions[index];
    if (!mission.isComplete) {
      return state;
    }

    final missions = List<Mission>.from(state.missions);
    missions[index] = createMission(
      type: mission.type,
      ascensionLevel: state.ascensionLevel,
    );

    var nextChain = state.metaDepth.jobChainCount + 1;
    var chainBonus = 0;
    if (nextChain >= 3) {
      chainBonus = 5;
      nextChain = 0;
    }

    return state.copyWith(
      gold: state.gold + mission.goldReward,
      lifetimeGoldEarned: state.lifetimeGoldEarned + mission.goldReward,
      essence: state.essence + mission.essenceReward + chainBonus,
      missions: missions,
      metaDepth: state.metaDepth.copyWith(jobChainCount: nextChain),
      lastUpdated: DateTime.now(),
    );
  }

  /// Bosses needed this run before Ascend unlocks.
  /// AL 0 → 1 boss, AL 1 → 2 bosses, etc.
  static int bossesRequiredForAscension(int ascensionLevel) =>
      ascensionLevel + 1;

  static bool canAscend(GameState state) =>
      state.bossVictories >= bossesRequiredForAscension(state.ascensionLevel);

  /// Essence granted when ascending into [newLevel].
  static int ascendEssenceReward(int newLevel) => 4 + (newLevel * 3);

  /// Applies Ascension + Sanctuary + gear + pet gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) {
    if (baseGold <= 0) {
      return baseGold;
    }
    final percent =
        state.ascensionGoldBonusPercent +
        state.sanctuaryGoldBonusPercent +
        state.gearGoldFindPercent +
        state.petGoldFindPercent;
    if (percent <= 0) {
      return baseGold;
    }
    return baseGold + (baseGold * percent) ~/ 100;
  }

  /// Prestige: reset the run, keep essence/relics/sanctuary/pets/soulbound, bump AL.
  /// Returns [state] unchanged if Ascend is locked.
  static GameState ascend(GameState state, {DateTime? now}) {
    if (!canAscend(state)) {
      return state;
    }

    final nextLevel = state.ascensionLevel + 1;
    final milestoneBonus = MetaSystems.ascendMilestoneReward(
      state.ascensionLevel,
      nextLevel,
    );
    final preservedEssence =
        state.essence + ascendEssenceReward(nextLevel) + milestoneBonus;
    final preservedRelics = List<String>.from(state.unlockedRelics);
    final fragmentGain = 1 + (state.highestFloorCleared ~/ 3);

    final streak = state.metaDepth.noWipeAscendReady
        ? state.metaDepth.ascendStreak + 1
        : 0;
    final bestStreak = max(state.metaDepth.bestAscendStreak, streak);
    final legacyGain = (nextLevel ~/ 5) - (state.ascensionLevel ~/ 5);
    final titles = List<String>.from(state.metaDepth.titles);
    for (final entry in AscendTitles.byAl.entries) {
      if (nextLevel >= entry.key && !titles.contains(entry.value)) {
        titles.add(entry.value);
      }
    }
    final trophies = List<String>.from(state.metaDepth.zoneTrophies);
    for (final d in DungeonCatalog.all) {
      if (d.number <= state.highestDungeonCleared &&
          !trophies.contains(d.id)) {
        trophies.add(d.id);
      }
    }
    final nextMeta = state.metaDepth.copyWith(
      ascendStreak: streak,
      bestAscendStreak: bestStreak,
      lifetimeAscends: state.metaDepth.lifetimeAscends + 1,
      titles: titles,
      legacyPoints: state.metaDepth.legacyPoints + legacyGain,
      heirloomAlBonus: nextLevel ~/ 5,
      zoneTrophies: trophies,
      noWipeAscendReady: true,
    );

    final fresh = createInitialState(now: now);
    final hmCap = min(10, 3 + nextLevel ~/ 2);
    var withMeta = fresh.copyWith(
      essence: preservedEssence,
      lifetimeGoldEarned: state.lifetimeGoldEarned,
      unlockedRelics: preservedRelics,
      ascensionLevel: nextLevel,
      missions: createMissionBoard(ascensionLevel: nextLevel),
      activePet: state.activePet,
      ownedPets: List<Pet>.from(state.ownedPets),
      sanctuaryGoldLevel: state.sanctuaryGoldLevel,
      sanctuaryPowerLevel: state.sanctuaryPowerLevel,
      sanctuaryVitalityLevel: state.sanctuaryVitalityLevel,
      metaDepth: nextMeta,
      dungeonMode: state.dungeonMode,
      highestFloorCleared: 0,
      highestDungeonCleared: state.highestDungeonCleared,
      inDungeon: false,
      soulboundFragments: state.soulboundFragments + fragmentGain,
      soulboundItem: state.soulboundItem,
      godHandLevel: state.godHandLevel,
      soundMuted: state.soundMuted,
      reducedVfx: state.reducedVfx,
      autoSellMaxPower: state.autoSellMaxPower,
      rogueUnlocked: true,
      seenTips: List<String>.from(state.seenTips),
      loadouts: List<GearLoadout>.from(state.loadouts),
      achievements: List<String>.from(state.achievements),
      codexEnemies: List<String>.from(state.codexEnemies),
      codexItems: List<String>.from(state.codexItems),
      challengeBossRush: state.challengeBossRush,
      challengeNoFlask: state.challengeNoFlask,
      hardmodeLevel: state.hardmodeLevel.clamp(0, hmCap),
      colorblindMode: state.colorblindMode,
      uiTextScale: state.uiTextScale,
      lastDailyDate: state.lastDailyDate,
      dailyClaimed: state.dailyClaimed,
      seenChangelogVersion: state.seenChangelogVersion,
      lastUpdated: now ?? DateTime.now(),
    );
    withMeta = ensureRogueHero(withMeta);
    withMeta = withMeta.copyWith(
      heroes: withMeta.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: withMeta.effectiveHeroMaxHp(hero)),
          )
          .toList(),
    );
    withMeta = ensureWeeklyContract(withMeta, now: now);
    return MetaSystems.evaluateAchievements(withMeta);
  }

  /// Unlocks Shade (rogue) as 4th party member when [rogueUnlocked].
  static GameState ensureRogueHero(GameState state) {
    if (!state.rogueUnlocked) {
      return fillMissingStarterGear(state);
    }
    if (state.heroes.any((h) => h.role == HeroRole.rogue)) {
      return fillMissingStarterGear(state);
    }
    final rogue = PartyHero.starting(
      name: 'Shade',
      role: HeroRole.rogue,
      stats: PartyHero.startingStatsFor(HeroRole.rogue),
      equipped: _starterGear(HeroRole.rogue),
    );
    return fillMissingStarterGear(
      state.copyWith(heroes: [...state.heroes, rogue]),
    );
  }

  /// Fills empty equipment slots with class starter pieces (keeps worn gear).
  static GameState fillMissingStarterGear(GameState state) {
    var changed = false;
    final rebuilt = <PartyHero>[];
    for (final hero in state.heroes) {
      final starter = _starterGear(hero.role);
      final next = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
      var heroChanged = false;
      for (final entry in starter.entries) {
        if (!next.containsKey(entry.key)) {
          next[entry.key] = entry.value.copyWith(
            id: '${entry.value.id}_fill',
          );
          heroChanged = true;
          changed = true;
        }
      }
      rebuilt.add(heroChanged ? hero.copyWith(equipped: next) : hero);
    }
    if (!changed) return state;
    return state.copyWith(heroes: rebuilt, lastUpdated: DateTime.now());
  }

  static Map<EquipmentSlot, EquipmentItem> _starterGear(HeroRole role) {
    EquipmentItem piece({
      required String id,
      required String name,
      required EquipmentSlot slot,
      ArmorType? armorType,
      WeaponType? weaponType,
      WeaponHanded? handed,
      OffHandKind? offHandKind,
      int str = 0,
      int agi = 0,
      int sta = 0,
      int intel = 0,
      int spi = 0,
      int sp = 0,
      int armor = 0,
      int crit = 0,
      int aspd = 0,
      int move = 0,
      int mp5 = 0,
    }) {
      return EquipmentItem(
        id: id,
        name: name,
        slot: slot,
        rarity: LootRarity.common,
        strengthBonus: str,
        agilityBonus: agi,
        staminaBonus: sta,
        intellectBonus: intel,
        spiritBonus: spi,
        spellPowerBonus: sp,
        armorBonus: armor,
        critChanceBonus: crit,
        attackSpeedBonus: aspd,
        moveSpeedBonus: move,
        mp5Bonus: mp5,
        affinity: role.name,
        itemLevel: 5,
        armorType: armorType,
        weaponType: weaponType,
        handed: handed,
        offHandKind: offHandKind,
        iconId: slot == EquipmentSlot.consumable ? 'flask' : null,
      );
    }

    final prefix = switch (role) {
      HeroRole.warrior => 'Guard',
      HeroRole.healer => 'Soft',
      HeroRole.mage => 'Spark',
      HeroRole.rogue => 'Swift',
    };
    final armorMat = switch (role) {
      HeroRole.warrior => ArmorType.mail,
      HeroRole.rogue => ArmorType.leather,
      HeroRole.healer || HeroRole.mage => ArmorType.cloth,
    };
    final matName = armorMat.name[0].toUpperCase() + armorMat.name.substring(1);

    // Starter budget: modest — primaries mainly on weapon/chest.
    final p = switch (role) {
      HeroRole.warrior => (
          str: 1,
          agi: 0,
          sta: 1,
          intel: 0,
          spi: 0,
          sp: 0,
        ),
      HeroRole.rogue => (
          str: 0,
          agi: 1,
          sta: 1,
          intel: 0,
          spi: 0,
          sp: 0,
        ),
      HeroRole.healer => (
          str: 0,
          agi: 0,
          sta: 1,
          intel: 1,
          spi: 1,
          sp: 1,
        ),
      HeroRole.mage => (
          str: 0,
          agi: 0,
          sta: 1,
          intel: 1,
          spi: 1,
          sp: 1,
        ),
    };

    EquipmentItem armorPiece(EquipmentSlot slot, String noun, {int armorPts = 1}) {
      final isCore = slot == EquipmentSlot.chest ||
          slot == EquipmentSlot.legs ||
          slot == EquipmentSlot.head;
      return piece(
          id: 'start_${role.name}_${slot.name}',
          name: '$prefix $matName $noun',
          slot: slot,
          armorType: armorMat,
          str: isCore ? p.str : 0,
          agi: isCore ? p.agi : 0,
          sta: isCore ? p.sta : (slot == EquipmentSlot.boots ? 1 : 0),
          intel: isCore ? p.intel : 0,
          spi: isCore ? p.spi : 0,
          sp: slot == EquipmentSlot.chest ? p.sp : 0,
          armor: role == HeroRole.warrior && isCore ? armorPts + 1 : armorPts,
          move: slot == EquipmentSlot.boots ? 2 : 0,
          aspd: slot == EquipmentSlot.hands || slot == EquipmentSlot.boots
              ? 1
              : 0,
          mp5: armorMat == ArmorType.cloth ? 1 : 0,
        );
    }

    EquipmentItem jewelry(EquipmentSlot slot, String noun) => piece(
          id: 'start_${role.name}_${slot.name}',
          name: '$prefix $noun',
          slot: slot,
          str: slot == EquipmentSlot.neck ? p.str : 0,
          agi: slot == EquipmentSlot.neck ? p.agi : 0,
          sta: 0,
          intel: slot == EquipmentSlot.neck ? p.intel : 0,
          spi: slot == EquipmentSlot.neck ? p.spi : 0,
          sp: p.sp > 0 && slot == EquipmentSlot.neck ? 1 : 0,
          crit: role == HeroRole.rogue && slot == EquipmentSlot.ring ? 1 : 0,
        );

    final weapon = switch (role) {
      HeroRole.warrior => piece(
          id: 'start_war_wpn',
          name: '$prefix 1H Mace',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.mace,
          handed: WeaponHanded.oneHand,
          str: 3,
          sta: 2,
          aspd: 1,
        ),
      HeroRole.healer => piece(
          id: 'start_pri_wpn',
          name: '$prefix 1H Mace',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.mace,
          handed: WeaponHanded.oneHand,
          intel: 2,
          spi: 1,
          sp: 1,
          mp5: 1,
        ),
      HeroRole.mage => piece(
          id: 'start_mag_wpn',
          name: '$prefix 1H Sword',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.sword,
          handed: WeaponHanded.oneHand,
          intel: 2,
          spi: 1,
          sp: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_wpn',
          name: '$prefix Dagger',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agi: 3,
          str: 1,
          crit: 1,
          aspd: 1,
        ),
    };

    final offHand = switch (role) {
      HeroRole.warrior => piece(
          id: 'start_war_oh',
          name: '$prefix Tower Shield',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.shield,
          str: 1,
          sta: 2,
          armor: 3,
        ),
      HeroRole.healer || HeroRole.mage => piece(
          id: 'start_${role.name}_oh',
          name: '$prefix Tome',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.frill,
          intel: 1,
          spi: 1,
          sp: 2,
          mp5: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_oh',
          name: '$prefix Off-hand Dagger',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agi: 2,
          crit: 1,
          aspd: 1,
        ),
    };

    final ranged = switch (role) {
      HeroRole.healer || HeroRole.mage => piece(
          id: 'start_${role.name}_rng',
          name: '$prefix Wand',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.wand,
          handed: WeaponHanded.oneHand,
          intel: 1,
          sp: 2,
        ),
      HeroRole.warrior => piece(
          id: 'start_war_rng',
          name: '$prefix Thrown',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.thrown,
          handed: WeaponHanded.oneHand,
          str: 1,
          agi: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_rng',
          name: '$prefix Bow',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.bow,
          handed: WeaponHanded.twoHand,
          agi: 2,
        ),
    };

    final flask = piece(
      id: 'start_${role.name}_flask',
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      sta: 1,
    );

    return {
      EquipmentSlot.weapon: weapon,
      EquipmentSlot.offHand: offHand,
      EquipmentSlot.ranged: ranged,
      EquipmentSlot.head: armorPiece(EquipmentSlot.head, 'Helm', armorPts: 2),
      EquipmentSlot.shoulder:
          armorPiece(EquipmentSlot.shoulder, 'Pauldrons', armorPts: 1),
      EquipmentSlot.chest:
          armorPiece(EquipmentSlot.chest, 'Chestguard', armorPts: 3),
      EquipmentSlot.waist: armorPiece(EquipmentSlot.waist, 'Belt'),
      EquipmentSlot.legs: armorPiece(EquipmentSlot.legs, 'Legguards', armorPts: 2),
      EquipmentSlot.boots: armorPiece(EquipmentSlot.boots, 'Boots'),
      EquipmentSlot.wrist: armorPiece(EquipmentSlot.wrist, 'Bracers'),
      EquipmentSlot.hands: armorPiece(EquipmentSlot.hands, 'Gloves'),
      EquipmentSlot.cloak: jewelry(EquipmentSlot.cloak, 'Cloak'),
      EquipmentSlot.neck: jewelry(EquipmentSlot.neck, 'Amulet'),
      EquipmentSlot.ring: jewelry(EquipmentSlot.ring, 'Ring'),
      EquipmentSlot.ring2: jewelry(EquipmentSlot.ring2, 'Band'),
      EquipmentSlot.trinket: jewelry(EquipmentSlot.trinket, 'Trinket'),
      EquipmentSlot.trinket2: jewelry(EquipmentSlot.trinket2, 'Charm'),
      EquipmentSlot.consumable: flask,
    };
  }

  static bool isBossBattle(int battleNumber, {int ascensionLevel = 0}) =>
      battleNumber == DungeonGenerator.bossFloorFor(ascensionLevel);

  static bool isEliteBattle(int battleNumber) {
    final room = DungeonGenerator.generateFloor(max(1, battleNumber)).first;
    return room.type == RoomType.elite || battleNumber % 5 == 3;
  }

  /// Combat budget for a room: total effective attack/HP/gold the enemy
  /// group should add up to. Tuned so fresh parties barely scrape early floors.
  ///
  /// Mid-game pressure: [ascensionLevel] and [gearPressure] scale threat so
  /// filling empty slots does not trivialize the same floors.
  static ({int attack, int hp, int gold}) roomCombatBudget(
    DungeonRoom room, {
    String? dungeonId,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
  }) {
    final level = room.globalBattleNumber;
    final isBoss = room.type == RoomType.boss;
    final isElite = room.type == RoomType.elite;
    final diff = DungeonGenerator.getDifficultyMultiplier(room.type);
    final zone = DungeonCatalog.byId(dungeonId ?? 'sandy').number;
    final zoneMult = 1.0 + zone * 0.28;
    final hm = hardmodeLevel.clamp(0, 10);
    // Linear to HM+10 = 10× (1000%) enemy HP/ATK.
    final hmThreat = 1.0 + hm * 0.9;
    final hmGold = 1.0 + hm * 0.15;
    final alThreat = 1.0 + ascensionLevel.clamp(0, 40) * 0.08;
    final gpRaw = gearPressure.clamp(1.0, 2.5);
    // Fresh early floors: don't let gear-pressure spike packs before F5.
    final gp = level <= 4
        ? 1.0 + (gpRaw - 1.0) * (0.25 + level * 0.12)
        : gpRaw;
    final threat = hmThreat * alThreat;
    // Early attrition ramp: F1–F3 should be clearable for fresh parties.
    final earlyEase = switch (level) {
      1 => 0.94,
      2 => 0.90,
      3 => 0.86,
      4 => 0.92,
      _ => 1.0,
    };

    // Attrition curve: packs hurt over time, not via one-shots.
    // Extra quadratic after F2 so geared mid-run parties still feel pressure.
    final curve = level + ((level * level) ~/ 12);
    final midFloor = max(0, level - 2);
    final midHpBump = midFloor * midFloor * 12;
    final attack = ((((42 + (isBoss ? 22 : 0) + (isElite ? 10 : 0)) +
                    curve * 5.5) *
                diff *
                zoneMult *
                earlyEase) *
            threat *
            (1.0 + (gp - 1.0) * 0.7))
        .round();
    final hp = ((((380 +
                        level * 62 +
                        (level ~/ 2) * 55 +
                        midHpBump) +
                    (isBoss ? 600 : 0) +
                    (isElite ? 180 : 0)) *
                diff *
                zoneMult *
                earlyEase) *
            threat *
            gp)
        .round();
    final gold =
        (((12 + level * 2.5) * (isBoss ? 3.4 : 1.0) * diff) * hmGold).round();

    return (attack: attack, hp: hp, gold: gold);
  }

  /// How much equipped loot should pull dungeon threat.
  /// Starters barely register; ~8–12 real upgrades is where pressure bites.
  static double partyGearPressure(GameState state) {
    var meaningful = 0;
    var primaryScore = 0;
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        // Ignore class starters / fill-ins — only real drops pull threat.
        if (item.id.startsWith('start_') || item.id.contains('_fill')) {
          continue;
        }
        final primary = item.strengthBonus +
            item.agilityBonus +
            item.staminaBonus +
            item.intellectBonus +
            item.spiritBonus +
            item.spellPowerBonus;
        if (primary >= 4 || item.rarity.index >= LootRarity.uncommon.index) {
          meaningful++;
          primaryScore += primary;
        }
      }
    }
    // ~4 pieces ≈ mild; ~10 pieces ≈ +70–100% HP threat.
    final pieceRamp = max(0, meaningful - 2) * 0.085;
    final scoreRamp = (primaryScore * 0.0028).clamp(0.0, 1.15);
    return (1.0 + pieceRamp + scoreRamp).clamp(1.0, 2.85);
  }

  /// XP required to go from [level] → level+1.
  static int xpPoolForLevel(int level) {
    final L = max(1, level);
    return 24 + (L * 16) + ((L * L) ~/ 2);
  }

  /// Combat XP granted for defeating one enemy.
  static int xpForEnemy(EnemyUnit enemy) {
    var xp = 5 + enemy.level + (enemy.level ~/ 3);
    xp += switch (enemy.role) {
      EnemyRole.boss => 28,
      EnemyRole.elite => 10,
      EnemyRole.normal => 0,
    };
    xp += switch (enemy.archetype) {
      EnemyArchetype.tank => 3,
      EnemyArchetype.glass => 2,
      EnemyArchetype.ranged => 2,
      EnemyArchetype.support => 1,
      EnemyArchetype.swarm => 0,
      EnemyArchetype.brute => 1,
    };
    return xp;
  }

  /// Awards [amount] XP to every living hero; levels up when pools fill.
  static GameState awardPartyXp(GameState state, int amount) {
    if (amount <= 0) return state;
    final boosted = amount +
        (amount *
                (state.sanctuaryXpBonusPercent + state.petXpFindPercent)) ~/
            100;
    final heroes = <PartyHero>[];
    var leveled = false;
    for (final hero in state.heroes) {
      if (!hero.isAlive) {
        heroes.add(hero);
        continue;
      }
      var level = hero.level;
      var xp = hero.xp + boosted;
      var hp = hero.currentHp;
      var guard = 0;
      while (guard < 40) {
        guard++;
        final need = xpPoolForLevel(level);
        if (xp < need) break;
        xp -= need;
        level += 1;
        leveled = true;
        final grown = hero.copyWith(level: level);
        hp = min(
          state.effectiveHeroMaxHp(grown),
          hp + 5 + state.vitalityBonus ~/ 4,
        );
      }
      heroes.add(hero.copyWith(level: level, xp: xp, currentHp: hp));
    }
    final next = state.copyWith(heroes: heroes, lastUpdated: DateTime.now());
    return leveled ? next : next;
  }

  static GameState awardEnemyKillXp(GameState state, EnemyUnit enemy) =>
      awardPartyXp(state, xpForEnemy(enemy));

  /// Builds the enemy group for a room. Treasure rooms have no enemies.
  /// [threatScale] < 1 softens packs (used for AFK spatial sim).
  /// Pass [fromState] to apply AL + gear-pressure scaling automatically.
  static List<EnemyUnit> createEnemyGroup(
    DungeonRoom room, {
    String? dungeonId,
    bool bossRush = false,
    double threatScale = 1.0,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
    GameState? fromState,
  }) {
    if (room.type == RoomType.treasure || room.enemyCount == 0) {
      return <EnemyUnit>[];
    }

    final id = dungeonId ?? fromState?.dungeonId ?? 'sandy';
    final hm = fromState?.hardmodeLevel ?? hardmodeLevel;
    final al = fromState?.ascensionLevel ?? ascensionLevel;
    final rush = fromState?.challengeBossRush ?? bossRush;
    final weeklyMod = fromState?.metaDepth.weeklyModifier ?? '';
    final level = room.globalBattleNumber;
    final gpRaw =
        (fromState != null ? partyGearPressure(fromState) : gearPressure)
            .clamp(1.0, 2.5);
    final gp = level <= 4
        ? 1.0 + (gpRaw - 1.0) * (0.25 + level * 0.12)
        : gpRaw;
    var budget = roomCombatBudget(
      room,
      dungeonId: id,
      hardmodeLevel: hm,
      ascensionLevel: al,
      gearPressure: fromState != null ? partyGearPressure(fromState) : gearPressure,
    );
    // Weekly modifiers apply after reading fromState.
    final glassWeek = weeklyMod == 'glass';
    final swarmWeek = weeklyMod == 'swarm';
    final eliteWeek = weeklyMod == 'elite';
    if (eliteWeek) {
      budget = (
        attack: (budget.attack * 1.15).round(),
        hp: (budget.hp * 1.2).round(),
        gold: (budget.gold * 1.1).round(),
      );
    }
    // Hardmode densifies packs: HM+10 = 10× (1000%) enemy count.
    // Swarm weekly multiplies count before HM density.
    final baseCount = max(
      1,
      (room.enemyCount * (swarmWeek ? 1.35 : 1.0)).round(),
    );
    final count = min(
      80,
      max(1, (baseCount * (1.0 + hm * 0.9)).round()),
    );
    // Full density keep: each body still carries HM-scaled HP/ATK (not diluted).
    final density = count / baseCount;
    var packAttack = (budget.attack * density).round();
    var packHp = (budget.hp * density).round();
    final packGold = (budget.gold * (1.0 + (density - 1.0) * 0.25)).round();
    final bossName = DungeonCatalog.byId(id).bossName;
    final rng = Random(level * 9173 + id.hashCode + room.type.index * 41);
    final isBossRoom = room.type == RoomType.boss;
    final pickType = eliteWeek && !isBossRoom ? RoomType.elite : room.type;

    final archetypes = <EnemyArchetype>[
      for (var i = 0; i < count; i++)
        rush && !(isBossRoom && i == 0)
            ? (i == 0
                ? EnemyArchetype.tank
                : _pickArchetype(RoomType.elite, isBossUnit: false, rng: rng))
            : _pickArchetype(
                pickType,
                isBossUnit: isBossRoom && i == 0,
                rng: rng,
              ),
    ];

    // Weight shares by archetype (tanks eat HP budget, glass eats ATK).
    final rawShares = <double>[
      for (final a in archetypes) _archetypeBudgetWeight(a),
    ];
    if (room.type == RoomType.boss && rawShares.isNotEmpty) {
      rawShares[0] *= 2.4;
    }
    final shareSum = rawShares.fold<double>(0, (s, v) => s + v);
    final shares = rawShares.map((w) => w / shareSum).toList();

    final group = <EnemyUnit>[];
    var hpLeft = packHp;
    var attackLeft = packAttack;
    var goldLeft = packGold;

    // Front-load threat: early indices (first chambers) eat more of the budget
    // so gated maps still hurt before the whole pack wakes.
    final frontWeights = <double>[
      for (var i = 0; i < count; i++)
        shares[i] * (1.55 - (i / count) * 0.9),
    ];
    final frontSum = frontWeights.fold<double>(0, (s, v) => s + v);
    final adjShares = frontWeights.map((w) => w / frontSum).toList();

    // Absolute floor so a single woken mob is never free.
    // Early floors ease the floor so fresh parties aren't deleted by min-stats.
    final earlyMinEase = switch (level) {
      1 => 0.52,
      2 => 0.60,
      3 => 0.68,
      4 => 0.80,
      _ => 1.0,
    };
    final minHp = max(
      (55 * earlyMinEase).round().clamp(28, 110),
      ((90 + level * 42 + (isBossRoom ? 140 : 0)) *
              (0.75 + gp * 0.25) *
              earlyMinEase)
          .round(),
    );
    final minAtk = max(
      (12 * earlyMinEase).round().clamp(6, 28),
      ((24 + level * 8 + (isBossRoom ? 12 : 0)) *
              (0.85 + (gp - 1.0) * 0.4) *
              earlyMinEase)
          .round(),
    );

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final archetype = archetypes[i];
      final skew = _archetypeStatSkew(archetype);
      final baseHp = isLast
          ? hpLeft
          : max(1, (packHp * adjShares[i]).round());
      final baseAtk = isLast
          ? max(1, attackLeft)
          : max(1, (packAttack * adjShares[i]).round());
      final gold = isLast
          ? max(0, goldLeft)
          : (packGold * adjShares[i]).round();
      hpLeft -= baseHp;
      attackLeft -= baseAtk;
      goldLeft -= gold;

      // Boss Rush: every non-boss pack fights like an elite pull.
      final rushMult = rush && !(isBossRoom && i == 0) ? 1.6 : 1.0;
      final hpRaw = max(
        (minHp * threatScale).round(),
        (baseHp * skew.hp * rushMult * threatScale).round(),
      );
      final atkRaw = max(
        (minAtk * threatScale).round(),
        (baseAtk * skew.atk * rushMult * threatScale).round(),
      );
      final hp = glassWeek ? max(1, (hpRaw * 0.75).round()) : hpRaw;
      final attack = glassWeek ? max(1, (atkRaw * 1.2).round()) : atkRaw;
      // DEF scales hard so fights aren't melted by raw ATK.
      final partyLevel = max(1, level);
      final isBossUnit = isBossRoom && i == 0;
      final role = isBossUnit
          ? EnemyRole.boss
          : (rush ||
                  eliteWeek ||
                  room.type == RoomType.boss ||
                  room.type == RoomType.elite)
          ? EnemyRole.elite
          : EnemyRole.normal;
      final defense = ((skew.def +
                  (partyLevel ~/ 3) +
                  (isBossUnit ? 6 : 0) +
                  (role == EnemyRole.elite ? 2 : 0) +
                  (rush && !isBossUnit ? 2 : 0)) *
              (0.7 + gp * 0.3))
          .round();

      final namingType = (rush && !isBossUnit) || (eliteWeek && !isBossUnit)
          ? RoomType.elite
          : room.type;

      group.add(
        EnemyUnit(
          name: _enemyNameFor(
            namingType,
            isBossUnit: isBossUnit,
            bossName: bossName,
            archetype: archetype,
            dungeonId: id,
            index: i,
          ),
          level: level,
          currentHp: hp,
          stats: Stats.enemy(attack: attack, defense: defense, maxHp: hp),
          rewardGold: rush ? (gold * 3) ~/ 2 : gold,
          role: role,
          archetype: archetype,
        ),
      );
    }

    return group;
  }

  static EnemyArchetype _pickArchetype(
    RoomType type, {
    required bool isBossUnit,
    required Random rng,
  }) {
    if (isBossUnit) return EnemyArchetype.tank;
    if (type == RoomType.elite) {
      return switch (rng.nextInt(5)) {
        0 => EnemyArchetype.tank,
        1 => EnemyArchetype.ranged,
        2 => EnemyArchetype.glass,
        3 => EnemyArchetype.support,
        _ => EnemyArchetype.brute,
      };
    }
    return switch (rng.nextInt(12)) {
      0 || 1 => EnemyArchetype.swarm,
      2 || 3 => EnemyArchetype.brute,
      4 || 5 => EnemyArchetype.tank,
      6 || 7 => EnemyArchetype.ranged,
      8 || 9 => EnemyArchetype.glass,
      _ => EnemyArchetype.support,
    };
  }

  static double _archetypeBudgetWeight(EnemyArchetype a) => switch (a) {
    EnemyArchetype.swarm => 0.55,
    EnemyArchetype.brute => 1.0,
    EnemyArchetype.tank => 1.45,
    EnemyArchetype.ranged => 0.85,
    EnemyArchetype.glass => 0.65,
    EnemyArchetype.support => 0.7,
  };

  static ({double hp, double atk, int def}) _archetypeStatSkew(
    EnemyArchetype a,
  ) => switch (a) {
    EnemyArchetype.swarm => (hp: 0.7, atk: 0.95, def: 1),
    EnemyArchetype.brute => (hp: 1.15, atk: 1.15, def: 2),
    EnemyArchetype.tank => (hp: 1.7, atk: 0.8, def: 7),
    EnemyArchetype.ranged => (hp: 0.85, atk: 1.25, def: 2),
    EnemyArchetype.glass => (hp: 0.55, atk: 1.55, def: 0),
    EnemyArchetype.support => (hp: 0.9, atk: 0.9, def: 2),
  };

  static String _enemyNameFor(
    RoomType type, {
    required bool isBossUnit,
    required String bossName,
    required EnemyArchetype archetype,
    required String dungeonId,
    required int index,
  }) {
    if (isBossUnit) {
      return bossName;
    }
    if (type == RoomType.elite) {
      return switch (archetype) {
        EnemyArchetype.tank => 'Bulwark Golem',
        EnemyArchetype.ranged => 'Hex Cultist',
        EnemyArchetype.glass => 'Blood Stalker',
        _ => 'Elite Brute',
      };
    }
    if (type == RoomType.boss) {
      return switch (archetype) {
        EnemyArchetype.ranged => 'Warden Archer',
        EnemyArchetype.tank => 'Warden Shield',
        EnemyArchetype.support => 'Warden Adept',
        _ => 'Warden Guard',
      };
    }
    return _zoneArchetypeName(dungeonId, archetype, index);
  }

  static String _zoneArchetypeName(
    String dungeonId,
    EnemyArchetype archetype,
    int index,
  ) {
    final table = switch (dungeonId) {
      'sandy' => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite', 'Drip Ooze'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Needle Rat', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
      'goblin' => const {
        EnemyArchetype.swarm: ['Goblin Scrapper', 'Sneak Rat', 'Pest'],
        EnemyArchetype.brute: ['Goblin Thug', 'Clubber'],
        EnemyArchetype.tank: ['Hideout Guard', 'Scrap Shield'],
        EnemyArchetype.ranged: ['Goblin Slinger', 'Dart Rascal'],
        EnemyArchetype.glass: ['Cutthroat', 'Knife Kin'],
        EnemyArchetype.support: ['Hex Witch', 'Totem Caller'],
      },
      'king' => const {
        EnemyArchetype.swarm: ['Fort Rat', 'Drill Bat'],
        EnemyArchetype.brute: ['Fort Sentry', 'Hall Guard'],
        EnemyArchetype.tank: ['Iron Ward', 'Gate Knight'],
        EnemyArchetype.ranged: ['Crossbowman', 'Tower Archer'],
        EnemyArchetype.glass: ['Royal Assassin', 'Blade Page'],
        EnemyArchetype.support: ['Court Mage', 'Banner Cleric'],
      },
      'underworld' => const {
        EnemyArchetype.swarm: ['Imp Swarm', 'Ash Tick'],
        EnemyArchetype.brute: ['Underworld Imp', 'Bone Brute'],
        EnemyArchetype.tank: ['Obsidian Golem', 'Pit Guard'],
        EnemyArchetype.ranged: ['Soul Spitter', 'Hex Spider'],
        EnemyArchetype.glass: ['Shade Stalker', 'Wisp Blade'],
        EnemyArchetype.support: ['Cult Chanter', 'Rift Adept'],
      },
      'dead' => const {
        EnemyArchetype.swarm: ['Risen Husk', 'Bone Swarm'],
        EnemyArchetype.brute: ['Grave Knight', 'Crypt Brute'],
        EnemyArchetype.tank: ['Tomb Shield', 'Ossuary Guard'],
        EnemyArchetype.ranged: ['Wailing Ghost', 'Bone Archer'],
        EnemyArchetype.glass: ['Specter Blade', 'Pale Reaper'],
        EnemyArchetype.support: ['Necro Acolyte', 'Death Chanter'],
      },
      'hell' => const {
        EnemyArchetype.swarm: ['Hellspawn', 'Cinder Rat'],
        EnemyArchetype.brute: ['Infernal Brute', 'Flame Guard'],
        EnemyArchetype.tank: ['Molten Golem', 'Ash Colossus'],
        EnemyArchetype.ranged: ['Fire Cultist', 'Ember Archer'],
        EnemyArchetype.glass: ['Flame Assassin', 'Cinder Blade'],
        EnemyArchetype.support: ['Hell Chanter', 'Rift Priest'],
      },
      'crystal' => const {
        EnemyArchetype.swarm: ['Frost Wisp', 'Rime Bat'],
        EnemyArchetype.brute: ['Glacial Brute', 'Shard Brawler'],
        EnemyArchetype.tank: ['Crystal Golem', 'Frozen Bulwark'],
        EnemyArchetype.ranged: ['Ice Caster', 'Frost Slinger'],
        EnemyArchetype.glass: ['Splinter Blade', 'Shatter Fang'],
        EnemyArchetype.support: ['Rime Chanter', 'Frost Adept'],
      },
      _ => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Needle Rat', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
    };
    final names = table[archetype]!;
    return names[index % names.length];
  }

  /// Restarts the current floor wave with a healed party.
  static GameState restartFloor(GameState state) {
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      state.currentRoom.floorNumber,
      ascensionLevel: state.ascensionLevel,
      dungeonId: state.dungeonId,
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    return state.copyWith(
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      enemies: createEnemyGroup(
        firstRoom,
        dungeonId: state.dungeonId,
        fromState: state,
      ),
      currentRoom: firstRoom,
      dungeonFloor: floor,
      layoutSeed: layoutSeed,
      metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
    );
  }

  static GameState advance(GameState state, {int steps = 1}) {
    var current = state;
    for (var i = 0; i < steps; i++) {
      current = _advanceOneTick(current);
    }
    return current;
  }

  /// Result of crediting AFK time on boot / resume.
  static OfflineProgressResult applyOfflineProgress(
    GameState state,
    Duration elapsed,
  ) {
    // Soft wall: up to 8h of absence is credited (diminishing via floor budget).
    final seconds = elapsed.inSeconds.clamp(0, 8 * 3600);
    if (seconds == 0) {
      final next = state.copyWith(lastUpdated: DateTime.now());
      return OfflineProgressResult(
        state: next,
        secondsApplied: 0,
        goldGained: 0,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
      );
    }

    final beforeGold = state.gold;
    final beforeEssence = state.essence;
    final beforeHighest = state.highestFloorCleared;
    final beforeBoss = state.bossVictories;
    var roomsCleared = 0;

    late GameState progressed;
    if (state.inDungeon) {
      final sim = simulateSpatialOffline(state, seconds);
      progressed = sim.state;
      roomsCleared = sim.roomsCleared;
    } else {
      // Hub AFK: sanctuary idle gold only — no ghost combat / boss farms.
      progressed = applyHubIdleProgress(state, seconds);
    }
    progressed = progressed.copyWith(
      offlineSecondsRecovered: progressed.offlineSecondsRecovered + seconds,
      lastUpdated: DateTime.now(),
    );
    return OfflineProgressResult(
      state: progressed,
      secondsApplied: seconds,
      goldGained: progressed.gold - beforeGold,
      essenceGained: progressed.essence - beforeEssence,
      roomsCleared: roomsCleared,
      highestFloorDelta: progressed.highestFloorCleared - beforeHighest,
      bossDelta: progressed.bossVictories - beforeBoss,
    );
  }

  /// Hub-only AFK: small gold (and rare essence) from sanctuary — no combat ticks.
  static GameState applyHubIdleProgress(GameState state, int seconds) {
    if (seconds <= 0) return state;
    final perMinute = 2 +
        state.sanctuaryGoldLevel +
        state.ascensionLevel +
        (state.highestDungeonCleared + 1);
    final rawGold = max(0, (seconds * perMinute) ~/ 60);
    final gold = applyGoldGain(
      state,
      rawGold + (rawGold * state.torchOfflineGoldPercent) ~/ 100,
    );
    final essence = seconds >= 600
        ? (seconds ~/ 900) + (state.sanctuaryPowerLevel ~/ 2)
        : 0;
    if (gold <= 0 && essence <= 0) return state;
    return state.copyWith(
      gold: state.gold + gold,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
      essence: state.essence + essence,
    );
  }

  /// How many room clears offline combat may award for [seconds] away.
  /// Front-loaded for the first 30 minutes, then half rate, hard-capped.
  static int offlineFloorBudget(int seconds) {
    if (seconds <= 0) return 0;
    // ~1 clear / 40s for the first 30 minutes (5m≈7, 30m≈45).
    if (seconds <= 30 * 60) {
      return max(1, seconds ~/ 40);
    }
    const firstBand = (30 * 60) ~/ 40; // 45
    // After 30m: ~1 clear / 80s (1h≈45+22, 8h≈45+337 → cap).
    final extra = (seconds - 30 * 60) ~/ 80;
    return min(120, firstBand + extra);
  }

  /// Replays combat while offline across multiple floors.
  /// Uses abstract ticks (not full spatial) so boot/AFK stays responsive.
  static ({GameState state, int roomsCleared}) simulateSpatialOffline(
    GameState state,
    int seconds,
  ) {
    if (!state.inDungeon || seconds <= 0) {
      return (state: state, roomsCleared: 0);
    }

    final maxFloors = offlineFloorBudget(seconds);
    final maxSteps = min(12000, max(120, maxFloors * 90));
    var current = state;
    var floorsCleared = 0;
    var prevCleared = state.highestFloorCleared;
    var prevGold = state.gold;
    var prevBoss = state.bossVictories;

    for (var step = 0; step < maxSteps; step++) {
      final next = _advanceOneTick(current);
      final progressed = next.gold > prevGold ||
          next.highestFloorCleared > prevCleared ||
          next.bossVictories > prevBoss ||
          next.currentRoom.floorNumber != current.currentRoom.floorNumber ||
          (!next.inDungeon && current.inDungeon);
      if (progressed) {
        // Count a room clear when gold/floor/boss moved forward.
        if (next.gold > prevGold ||
            next.highestFloorCleared > prevCleared ||
            next.bossVictories > prevBoss ||
            (!next.inDungeon && current.inDungeon)) {
          floorsCleared++;
          prevGold = next.gold;
          prevCleared = next.highestFloorCleared;
          prevBoss = next.bossVictories;
        }
      }
      current = next;
      if (!current.inDungeon || floorsCleared >= maxFloors) {
        break;
      }
      // Push wipe retreat ends the AFK run.
      if (current.isPartyDefeated) {
        break;
      }
    }
    return (state: current, roomsCleared: floorsCleared);
  }

  static int partyTrainingCostFor(GameState state) {
    final totalLevels = state.heroes.fold<int>(
      0,
      (sum, hero) => sum + hero.level,
    );
    return 16 + (totalLevels * 3) + (state.bossVictories * 6);
  }

  static int upgradeCostFor(GameState state, PartyUpgradeType type) {
    final currentTier = switch (type) {
      PartyUpgradeType.attack => state.attackBonus ~/ 2,
      PartyUpgradeType.defense => state.defenseBonus,
      PartyUpgradeType.vitality => state.vitalityBonus ~/ 6,
    };

    return 18 + (currentTier * 10) + (state.bossVictories * 5);
  }

  static GameState trainParty(GameState state) {
    final trainingCost = partyTrainingCostFor(state);
    if (state.gold < trainingCost) {
      return state;
    }

    final trainedHeroes = state.heroes.map((hero) {
      final next = hero.copyWith(level: hero.level + 1, xp: 0);
      return next.copyWith(
        currentHp: state.effectiveHeroMaxHp(next),
      );
    }).toList();
    return state.copyWith(
      heroes: trainedHeroes,
      gold: state.gold - trainingCost,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState upgradeAttack(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.attack);

  static GameState upgradeDefense(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.defense);

  static GameState upgradeVitality(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.vitality);

  static GameState _applyUpgrade(
    GameState state, {
    required PartyUpgradeType type,
  }) {
    final cost = upgradeCostFor(state, type);
    if (state.gold < cost) {
      return state;
    }

    switch (type) {
      case PartyUpgradeType.attack:
        return state.copyWith(
          attackBonus: state.attackBonus + 2,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.defense:
        return state.copyWith(
          defenseBonus: state.defenseBonus + 1,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.vitality:
        final healedHeroes = state.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: hero.maxHp + state.vitalityBonus + 6,
              ),
            )
            .toList();
        return state.copyWith(
          vitalityBonus: state.vitalityBonus + 6,
          heroes: healedHeroes,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
    }
  }

  static GameState unlockRelic(GameState state, String relicId) {
    final cost = relicCosts[relicId];
    if (cost == null || state.hasRelic(relicId) || state.essence < cost) {
      return state;
    }

    final unlockedRelics = List<String>.from(state.unlockedRelics)
      ..add(relicId);
    final tiers = Map<String, int>.from(state.metaDepth.relicTiers);
    tiers[relicId] = max(1, tiers[relicId] ?? 0);
    final healedHeroes = state.heroes
        .map(
          (hero) => hero.copyWith(
            currentHp: min(
              hero.currentHp,
              hero.maxHp +
                  state.totalVitalityBonus +
                  (relicId == phoenixEmberRelic ? 10 : 0),
            ),
          ),
        )
        .toList();

    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        heroes: healedHeroes,
        unlockedRelics: unlockedRelics,
        metaDepth: state.metaDepth.copyWith(relicTiers: tiers),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static int relicTierUpgradeCost(int nextTier) => 12 + nextTier * 14;

  static GameState upgradeRelicTier(GameState state, String relicId) {
    if (!state.hasRelic(relicId) || !relicCosts.containsKey(relicId)) {
      return state;
    }
    final current = max(1, state.metaDepth.relicTierOf(relicId));
    if (current >= 3) return state;
    final nextTier = current + 1;
    final cost = relicTierUpgradeCost(nextTier);
    if (state.essence < cost) return state;
    final tiers = Map<String, int>.from(state.metaDepth.relicTiers);
    tiers[relicId] = nextTier;
    return state.copyWith(
      essence: state.essence - cost,
      metaDepth: state.metaDepth.copyWith(relicTiers: tiers),
      lastUpdated: DateTime.now(),
    );
  }

  static int respecRelicsCost(GameState state) =>
      40 + state.metaDepth.relicRespecs * 25;

  static GameState respecRelics(GameState state) {
    if (state.unlockedRelics.isEmpty && state.metaDepth.relicTiers.isEmpty) {
      return state;
    }
    final cost = respecRelicsCost(state);
    if (state.essence < cost) return state;
    return state.copyWith(
      essence: state.essence - cost,
      unlockedRelics: const <String>[],
      metaDepth: state.metaDepth.copyWith(
        relicTiers: const <String, int>{},
        relicRespecs: state.metaDepth.relicRespecs + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static int godHandCdUpgradeCost(int level) => 12 + level * 10;

  static GameState upgradeGodHandCd(GameState state) {
    if (state.metaDepth.godHandCdLevel >= 8) return state;
    final cost = godHandCdUpgradeCost(state.metaDepth.godHandCdLevel);
    if (state.essence < cost) return state;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        metaDepth: state.metaDepth.copyWith(
          godHandCdLevel: state.metaDepth.godHandCdLevel + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static GameState buyPrestigeShopItem(GameState state, String id) {
    PrestigeShopItem? item;
    for (final candidate in PrestigeShopCatalog.all) {
      if (candidate.id == id) {
        item = candidate;
        break;
      }
    }
    if (item == null) return state;
    if (state.ascensionLevel < item.minAl) return state;
    if (state.essence < item.cost) return state;

    final md = state.metaDepth;
    final atCap = switch (id) {
      'stash_slot' => md.stashBonusSlots >= 20,
      'combine_luck' => md.combinatorLuck >= 5,
      'torch_keep' => md.torchKeepLevel >= 10,
      'gh_cdr' => md.godHandCdLevel >= 8,
      'roster_cap' => md.petRosterCapBonus >= 10,
      'legacy_spark' => md.legacyPoints >= 20,
      _ => false,
    };
    if (atCap) return state;

    var nextMd = switch (id) {
      'stash_slot' =>
        md.copyWith(stashBonusSlots: min(20, md.stashBonusSlots + 2)),
      'combine_luck' =>
        md.copyWith(combinatorLuck: min(5, md.combinatorLuck + 1)),
      'torch_keep' =>
        md.copyWith(torchKeepLevel: min(10, md.torchKeepLevel + 1)),
      'gh_cdr' =>
        md.copyWith(godHandCdLevel: min(8, md.godHandCdLevel + 1)),
      'roster_cap' =>
        md.copyWith(petRosterCapBonus: min(10, md.petRosterCapBonus + 2)),
      'legacy_spark' =>
        md.copyWith(legacyPoints: min(20, md.legacyPoints + 1)),
      _ => md,
    };
    // Track ownership once via levels; keep a de-duplicated purchase mark.
    if (!nextMd.prestigePurchases.contains(id)) {
      nextMd = nextMd.copyWith(
        prestigePurchases: [...nextMd.prestigePurchases, id],
      );
    }
    return state.copyWith(
      essence: state.essence - item.cost,
      metaDepth: nextMd,
      lastUpdated: DateTime.now(),
    );
  }

  /// ISO week key (`yyyy-Www`) for weekly contract rotation.
  static String isoWeekKey(DateTime utc) {
    final d = DateTime.utc(utc.year, utc.month, utc.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(yearStart).inDays ~/ 7) + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static const List<String> weeklyModifiers = <String>['glass', 'swarm', 'elite'];

  static GameState ensureWeeklyContract(GameState state, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final key = isoWeekKey(t);
    if (state.metaDepth.weeklyKey == key) return state;
    final mod = weeklyModifiers[(key.hashCode & 0x7fffffff) % weeklyModifiers.length];
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: key,
        weeklyProgress: 0,
        weeklyClaimed: false,
        weeklyModifier: mod,
      ),
    );
  }

  static int weeklyClaimEssence = 18;

  static GameState claimWeekly(GameState state) {
    var next = ensureWeeklyContract(state);
    final md = next.metaDepth;
    if (md.weeklyProgress < 3 || md.weeklyClaimed) return next;
    next = next.copyWith(
      essence: next.essence + weeklyClaimEssence,
      metaDepth: md.copyWith(weeklyClaimed: true),
      lastUpdated: DateTime.now(),
    );
    return MetaSystems.evaluateAchievements(next);
  }

  /// Soft expected codex size for percentage milestone claims (soft goal).
  static const int expectedCodexEntries = 60;

  static const Map<String, ({int pct, int reward})> codexRewardTiers =
      <String, ({int pct, int reward})>{
    'codex_25pct': (pct: 25, reward: 8),
    'codex_50pct': (pct: 50, reward: 15),
    'codex_75pct': (pct: 75, reward: 22),
    'codex_100pct': (pct: 100, reward: 30),
  };

  static int codexCompletionPercent(GameState state) {
    final discovered = state.codexEnemies.length + state.codexItems.length;
    return min(100, (discovered * 100) ~/ expectedCodexEntries);
  }

  static GameState claimCodexReward(GameState state, String tierId) {
    final tier = codexRewardTiers[tierId];
    if (tier == null) return state;
    if (state.metaDepth.codexClaims.contains(tierId)) return state;
    if (codexCompletionPercent(state) < tier.pct) return state;
    final claims = List<String>.from(state.metaDepth.codexClaims)..add(tierId);
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence + tier.reward,
        metaDepth: state.metaDepth.copyWith(codexClaims: claims),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Clamp hardmode to the AL-gated effective max.
  static GameState setHardmodeLevel(GameState state, int level) {
    final capped = level.clamp(0, state.effectiveMaxHardmode);
    return MetaSystems.evaluateAchievements(
      state.copyWith(hardmodeLevel: capped, lastUpdated: DateTime.now()),
    );
  }

  static List<LootDrop> rollLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
  }) {
    final floorNumber = max(1, battleNumber);
    final bossFloor = DungeonGenerator.bossFloorFor(ascensionLevel);
    final isBoss = floorNumber == bossFloor;
    final hm = hardmodeLevel.clamp(0, 10);

    final floor = DungeonGenerator.generateFloor(
      floorNumber,
      ascensionLevel: ascensionLevel,
      dungeonId: 'sandy',
    );
    final room = floor.first;

    // AL drop penalty: chance to skip gear entirely (pets can blunt this).
    final skipChance = (ascensionLevel * ascensionDropPenalty -
            lootFindPercent / 100.0 -
            hm * 0.01)
        .clamp(0.0, 0.75);
    if (random.nextDouble() < skipChance) {
      return <LootDrop>[
        const LootDrop(
          name: 'Faded Dust',
          amount: 1,
          rarity: LootRarity.common,
        ),
      ];
    }

    final primaryRarity = _rarityForBattle(battleNumber, hardmodeLevel: hm);
    final slots = EquipmentSlot.values
        .where((s) => s != EquipmentSlot.consumable)
        .toList();
    final slot = slots[random.nextInt(slots.length)];
    final bias = HeroRole.values[random.nextInt(HeroRole.values.length)];
    final drops = <LootDrop>[
      LootDrop(
        name: _equipmentNameFor(slot, primaryRarity, bias: bias),
        amount: 1,
        rarity: primaryRarity,
        equipment: createEquipment(
          slot: slot,
          rarity: primaryRarity,
          battleNumber: battleNumber,
          bias: bias,
        ),
      ),
    ];

    // Chance at a second class-biased piece — delayed so early clears don't
    // fill every jewelry slot in one boss cycle.
    final secondChance = battleNumber >= 6
        ? (0.22 + lootFindPercent / 200.0).clamp(0.0, 0.48)
        : (0.08 + lootFindPercent / 250.0).clamp(0.0, 0.22);
    if (battleNumber >= 4 && random.nextDouble() < secondChance) {
      final slot2 = slots[random.nextInt(slots.length)];
      final bias2 = HeroRole.values[random.nextInt(HeroRole.values.length)];
      final rarity2 = primaryRarity.index > 0
          ? LootRarity.values[primaryRarity.index - 1]
          : LootRarity.common;
      drops.add(
        LootDrop(
          name: _equipmentNameFor(slot2, rarity2, bias: bias2),
          amount: 1,
          rarity: rarity2,
          equipment: createEquipment(
            slot: slot2,
            rarity: rarity2,
            battleNumber: battleNumber,
            bias: bias2,
          ),
        ),
      );
    }

    if (battleNumber % 4 == 0) {
      drops.add(
        const LootDrop(
          name: 'Gold Pouch',
          amount: 1,
          rarity: LootRarity.common,
        ),
      );
    }

    if (battleNumber % 9 == 0) {
      drops.add(
        const LootDrop(name: 'Relic Shard', amount: 1, rarity: LootRarity.rare),
      );
    }

    if (isBoss) {
      drops.add(
        const LootDrop(name: 'Boss Sigil', amount: 1, rarity: LootRarity.epic),
      );
    }

    if (room.type == RoomType.treasure) {
      drops.add(
        const LootDrop(
          name: 'Essence Vial',
          amount: 1,
          rarity: LootRarity.rare,
        ),
      );
    }

    return drops.take(3).toList();
  }

  static EquipmentItem createEquipment({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
    HeroRole? bias,
  }) {
    EquipmentFactory.random = random;
    return EquipmentFactory.create(
      slot: slot,
      rarity: rarity,
      battleNumber: battleNumber,
      bias: bias,
    );
  }

  /// WoW-style item level from floor + rarity (common F1 ≈ 5, rare F10 ≈ 29).
  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
  }) =>
      EquipmentFactory.itemLevelFor(
        battleNumber: battleNumber,
        rarity: rarity,
      );

  static String _equipmentNameFor(
    EquipmentSlot slot,
    LootRarity rarity, {
    HeroRole? bias,
    ArmorType? armorType,
    WeaponType? weaponType,
    OffHandKind? offHandKind,
    WeaponHanded? handed,
  }) =>
      EquipmentFactory.equipmentNameFor(
        slot: slot,
        rarity: rarity,
        bias: bias,
        armorType: armorType,
        weaponType: weaponType,
        offHandKind: offHandKind,
        handed: handed,
      );

  static int lootEssenceValue(LootDrop drop) {
    if (drop.essenceGained > 0) {
      return drop.essenceGained;
    }
    if (drop.equipment != null) {
      return equipmentEssenceValue(drop.equipment!);
    }
    final perItem = switch (drop.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };

    return perItem * drop.amount;
  }

  static int equipmentEssenceValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };
    return base + (item.powerScore ~/ 4);
  }

  /// Merchant gold payout (stash-only sales).
  static int equipmentGoldValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 8,
      LootRarity.uncommon => 18,
      LootRarity.rare => 40,
      LootRarity.epic => 90,
      LootRarity.legendary => 160,
    };
    return base + item.powerScore + (item.effectiveItemLevel * 2);
  }

  static int marketFlaskCost(GameState state) =>
      40 + (state.highestFloorCleared * 3) + (state.ascensionLevel * 15);

  static EquipmentItem createMarketFlask() {
    final id = 'flask_${DateTime.now().microsecondsSinceEpoch}';
    return EquipmentItem(
      id: id,
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      vitalityBonus: 1,
      itemLevel: 1,
      iconId: 'flask',
    );
  }

  static GameState buyMarketFlask(GameState state) {
    final cost = marketFlaskCost(state);
    if (state.gold < cost) return state;
    final flask = createMarketFlask();
    var next = state.copyWith(gold: state.gold - cost);
    // Prefer empty consumable slot on first hero, else stash.
    for (var i = 0; i < next.heroes.length; i++) {
      final hero = next.heroes[i];
      if (hero.itemIn(EquipmentSlot.consumable) == null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
          ..[EquipmentSlot.consumable] = flask;
        final heroes = List<PartyHero>.from(next.heroes);
        heroes[i] = hero.copyWith(equipped: eq);
        return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
      }
    }
    next = stashEquipment(next, flask);
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState sellGearForGold(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) return state;
    final item = findGear(state, itemId);
    if (item == null) return state;
    final value = equipmentGoldValue(item);
    final next = removeGear(state, itemId);
    return next.copyWith(
      gold: next.gold + value,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState dismissTip(GameState state, String tipId) {
    if (state.seenTips.contains(tipId)) return state;
    return state.copyWith(
      seenTips: [...state.seenTips, tipId],
      lastUpdated: DateTime.now(),
    );
  }

  static const int maxGearStash = 50;

  static int maxGearStashFor(GameState state) =>
      maxGearStash + state.metaDepth.stashBonusSlots;

  /// Puts gear into the inventory stash. Overflow salvages the oldest piece.
  static GameState stashEquipment(GameState state, EquipmentItem item) {
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    final cap = maxGearStashFor(state);
    if (stash.length >= cap) {
      final overflow = stash.removeAt(0);
      essence += equipmentEssenceValue(overflow);
    }
    stash.add(item);
    return state.copyWith(gearStash: stash, essence: essence);
  }

  static EquipmentItem? findGear(GameState state, String id) {
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        if (item.id == id) return item;
      }
    }
    for (final item in state.gearStash) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) {
    for (var i = 0; i < state.heroes.length; i++) {
      for (final entry in state.heroes[i].equipped.entries) {
        if (entry.value.id == id) {
          return (heroIndex: i, slot: entry.key);
        }
      }
    }
    return null;
  }

  static GameState removeGear(GameState state, String id) {
    final location = findEquippedLocation(state, id);
    if (location != null) {
      final hero = state.heroes[location.heroIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(location.slot);
      final heroes = [...state.heroes];
      heroes[location.heroIndex] = hero.copyWith(equipped: nextGear);
      return state.copyWith(heroes: heroes);
    }
    return state.copyWith(
      gearStash: state.gearStash.where((item) => item.id != id).toList(),
    );
  }

  /// Slots a stash piece may fill (rings/trinkets share dual slots).
  static List<EquipmentSlot> equipTargetsFor(EquipmentItem item) {
    return switch (item.slot) {
      EquipmentSlot.ring || EquipmentSlot.ring2 => <EquipmentSlot>[
          EquipmentSlot.ring,
          EquipmentSlot.ring2,
        ],
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => <EquipmentSlot>[
          EquipmentSlot.trinket,
          EquipmentSlot.trinket2,
        ],
      _ => <EquipmentSlot>[item.slot],
    };
  }

  /// Whether [hero] can actually receive [item] into [slot] right now.
  static bool canHeroReceive(
    PartyHero hero,
    EquipmentItem item, {
    required EquipmentSlot slot,
  }) {
    final remapped = item.slot == slot ? item : item.copyWith(slot: slot);
    if (!ClassProficiency.canEquip(
      role: hero.role,
      level: hero.level,
      item: remapped,
    )) {
      return false;
    }
    if (slot == EquipmentSlot.offHand &&
        ClassProficiency.weaponBlocksOffHand(
          hero.itemIn(EquipmentSlot.weapon),
        )) {
      return false;
    }
    return true;
  }

  /// Equip a stash item onto a hero slot (current piece moves to stash).
  static GameState equipFromStash(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    EquipmentItem? item;
    for (final candidate in state.gearStash) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      return state;
    }

    final targetSlot = intoSlot ?? item.slot;
    if (!equipTargetsFor(item).contains(targetSlot)) {
      return state;
    }

    final heroCheck = state.heroes[heroIndex];
    if (!canHeroReceive(heroCheck, item, slot: targetSlot)) {
      return state;
    }

    final equippedItem =
        item.slot == targetSlot ? item : item.copyWith(slot: targetSlot);

    var next = state.copyWith(
      gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    final hero = next.heroes[heroIndex];
    final current = hero.itemIn(targetSlot);
    if (current != null) {
      next = stashEquipment(next, current);
    }

    final vitalityBefore = next.effectiveHeroMaxHp(hero);
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
      next.heroes[heroIndex].equipped,
    )..[targetSlot] = equippedItem;

    // 2H main-hand unequips off-hand.
    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = nextGear.remove(EquipmentSlot.offHand);
      if (off != null) {
        next = stashEquipment(next, off);
      }
    }

    final heroes = [...next.heroes];
    heroes[heroIndex] = next.heroes[heroIndex].copyWith(equipped: nextGear);
    next = next.copyWith(heroes: heroes);
    final updated = next.heroes[heroIndex];
    final vitalityAfter = next.effectiveHeroMaxHp(updated);
    final vitalityDelta = vitalityAfter - vitalityBefore;
    if (vitalityDelta != 0) {
      heroes[heroIndex] = updated.copyWith(
        currentHp: vitalityDelta > 0
            ? min(vitalityAfter, updated.currentHp + vitalityDelta)
            : min(vitalityAfter, updated.currentHp),
      );
      next = next.copyWith(heroes: heroes);
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState unequipSlot(
    GameState state,
    EquipmentSlot slot, {
    int heroIndex = 0,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    final hero = state.heroes[heroIndex];
    final current = hero.itemIn(slot);
    if (current == null) {
      return state;
    }
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(slot);
    final heroes = [...state.heroes];
    heroes[heroIndex] = hero.copyWith(equipped: nextGear);
    var next = state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    next = stashEquipment(next, current);
    final updated = next.heroes[heroIndex];
    heroes[heroIndex] = updated.copyWith(
      currentHp: min(next.effectiveHeroMaxHp(updated), updated.currentHp),
    );
    return next.copyWith(
      heroes: heroes,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState sellGear(GameState state, String itemId) {
    final item = findGear(state, itemId);
    if (item == null) {
      return state;
    }
    final value = equipmentEssenceValue(item);
    final next = removeGear(state, itemId);
    return next.copyWith(
      essence: next.essence + value,
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static int combineCost(
    EquipmentItem primary,
    EquipmentItem secondary, {
    int combinatorLuck = 0,
  }) =>
      max(
        1,
        20 +
            primary.powerScore +
            secondary.powerScore +
            ((primary.rarity.index + secondary.rarity.index) * 5) -
            combinatorLuck * 3,
      );

  /// Slot groups for BiS planning: dual ring/trinket, then singletons.
  static List<List<EquipmentSlot>> equipSlotGroups() {
    return <List<EquipmentSlot>>[
      <EquipmentSlot>[EquipmentSlot.ring, EquipmentSlot.ring2],
      <EquipmentSlot>[EquipmentSlot.trinket, EquipmentSlot.trinket2],
      for (final slot in EquipmentSlot.values)
        if (slot != EquipmentSlot.ring &&
            slot != EquipmentSlot.ring2 &&
            slot != EquipmentSlot.trinket &&
            slot != EquipmentSlot.trinket2 &&
            slot != EquipmentSlot.consumable)
          <EquipmentSlot>[slot],
    ];
  }

  /// Net score for putting [item] into [slot] on [hero].
  ///
  /// Two-hand weapons subtract the currently worn off-hand so Auto Equip
  /// does not drop a strong shield/tome for a marginally better 2H.
  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
  }) {
    if (item == null) return 0;
    if (!canHeroReceive(hero, item, slot: slot)) {
      return -999999;
    }
    var score = roleEquipScore(hero.role, item);
    if (slot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(item)) {
      final off = hero.itemIn(EquipmentSlot.offHand);
      if (off != null) {
        score -= roleEquipScore(hero.role, off);
      }
    }
    return score;
  }

  /// Class-aware score for deciding whether gear is an upgrade for a hero.
  static int roleEquipScore(HeroRole role, EquipmentItem item) {
    if (!ClassProficiency.canEquip(role: role, level: 60, item: item) &&
        !(item.armorType == ArmorType.plate && role == HeroRole.warrior)) {
      // Still score plate for high-level warriors; low-level handled in compare.
    }
    final str = item.strengthBonus;
    final agi = item.agilityBonus;
    final sta = item.resolvedStamina;
    final intel = item.intellectBonus;
    final spi = item.spiritBonus;
    final sp = item.spellPowerBonus;
    final armor = item.resolvedArmor;
    final crit = item.critChanceBonus;
    final aspd = item.attackSpeedBonus;
    final move = item.moveSpeedBonus;
    final mp5 = item.mp5Bonus;
    final effect = switch (item.effectId) {
      GearEffectId.lifesteal => switch (role) {
          HeroRole.warrior => item.effectValue * 4,
          HeroRole.rogue => item.effectValue * 2,
          _ => item.effectValue,
        },
      GearEffectId.pierce => switch (role) {
          HeroRole.mage => 24,
          HeroRole.rogue => 12,
          _ => 6,
        },
      GearEffectId.crit => switch (role) {
          HeroRole.rogue => item.effectValue * 4,
          HeroRole.mage => item.effectValue * 2,
          _ => item.effectValue,
        },
      GearEffectId.haste => switch (role) {
          HeroRole.mage || HeroRole.healer => item.effectValue * 3,
          HeroRole.rogue => item.effectValue * 2,
          _ => item.effectValue,
        },
      GearEffectId.goldFind => item.effectValue,
      GearEffectId.none => 0,
    };
    final core = switch (role) {
      HeroRole.warrior =>
        (sta * 10 + armor * 9 + str * 8.5 + agi * 4.5 + spi).round() +
            item.attackBonus * 2,
      HeroRole.healer =>
        (sp * 10 + spi * 9.5 + intel * 8.5 + mp5 * 7 + sta * 4 + crit * 3.5)
            .round(),
      HeroRole.mage =>
        (intel * 10 + sp * 9.5 + crit * 8.5 + spi * 5.5 + sta * 3.5).round(),
      HeroRole.rogue =>
        (agi * 10 + str * 7.5 + crit * 7 + sta * 4 + aspd * 5 + move * 3)
            .round() +
            item.attackBonus * 2,
    };
    return core +
        effect +
        item.rarity.index * 2 +
        (item.affinity == role.name ? 8 : 0);
  }

  /// Compare a bag candidate against what a hero wears in that slot family.
  ///
  /// Rings/trinkets pick the best of the dual slots. Off-hand is not an upgrade
  /// while a two-hand weapon is equipped.
  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
    EquipmentSlot intoSlot,
  }) compareForHero(
    PartyHero hero,
    EquipmentItem candidate, {
    EquipmentSlot? intoSlot,
  }) {
    final targets = intoSlot != null
        ? <EquipmentSlot>[intoSlot]
        : equipTargetsFor(candidate);

    var bestDelta = -99999;
    var best = (
      powerDelta: -9999,
      atkDelta: 0,
      defDelta: 0,
      vitDelta: 0,
      isUpgrade: false,
      intoSlot: targets.first,
    );

    for (final slot in targets) {
      final cmp = _compareForHeroSlot(hero, candidate, slot);
      if (cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
        best = (
          powerDelta: cmp.powerDelta,
          atkDelta: cmp.atkDelta,
          defDelta: cmp.defDelta,
          vitDelta: cmp.vitDelta,
          isUpgrade: cmp.isUpgrade,
          intoSlot: slot,
        );
      }
    }
    return best;
  }

  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
  }) _compareForHeroSlot(
    PartyHero hero,
    EquipmentItem candidate,
    EquipmentSlot slot,
  ) {
    if (!canHeroReceive(hero, candidate, slot: slot)) {
      return (
        powerDelta: -9999,
        atkDelta: 0,
        defDelta: 0,
        vitDelta: 0,
        isUpgrade: false,
      );
    }
    final current = hero.itemIn(slot);
    final curScore = slotEquipScore(hero, current, slot: slot);
    final newScore = slotEquipScore(hero, candidate, slot: slot);
    final curAtk = (current?.strengthBonus ?? 0) +
        (current?.agilityBonus ?? 0) +
        (current?.spellPowerBonus ?? 0) +
        (current?.attackBonus ?? 0);
    final curDef = current?.resolvedArmor ?? 0;
    final curVit = current?.resolvedStamina ?? 0;
    final newAtk = candidate.strengthBonus +
        candidate.agilityBonus +
        candidate.spellPowerBonus +
        candidate.attackBonus;
    final powerDelta = newScore - curScore;
    return (
      powerDelta: powerDelta,
      atkDelta: newAtk - curAtk,
      defDelta: candidate.resolvedArmor - curDef,
      vitDelta: candidate.resolvedStamina - curVit,
      isUpgrade: powerDelta > 0,
    );
  }

  /// Planned stash→slot upgrades from BiS assignment (shared by Auto Equip / Sell Junk).
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
      planBiSAssignments(GameState state) {
    final stashById = <String, EquipmentItem>{
      for (final item in state.gearStash) item.id: item,
    };
    if (stashById.isEmpty) return const [];

    final reserved = <String>{};
    final plan =
        <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];
    final filledSlots = <String>{};

    String slotKey(int heroIndex, EquipmentSlot slot) =>
        '$heroIndex:${slot.name}';

    for (var round = 0; round < 6; round++) {
      final proposals =
          <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];

      for (var hi = 0; hi < state.heroes.length; hi++) {
        final hero = state.heroes[hi];
        String? plannedWeaponId;
        for (final p in plan) {
          if (p.heroIndex == hi && p.slot == EquipmentSlot.weapon) {
            plannedWeaponId = p.itemId;
            break;
          }
        }
        final plannedWeapon = plannedWeaponId == null
            ? hero.itemIn(EquipmentSlot.weapon)
            : stashById[plannedWeaponId] ?? hero.itemIn(EquipmentSlot.weapon);
        final blocksOffHand =
            ClassProficiency.weaponBlocksOffHand(plannedWeapon);

        for (final group in equipSlotGroups()) {
          if (blocksOffHand &&
              group.length == 1 &&
              group.first == EquipmentSlot.offHand) {
            continue;
          }

          final available = <EquipmentItem>[
            for (final item in state.gearStash)
              if (!reserved.contains(item.id)) item,
          ];

          final scored = <({EquipmentItem item, int score})>[];
          for (final item in available) {
            if (!equipTargetsFor(item).any(group.contains)) continue;
            var best = -999999;
            for (final slot in group) {
              if (filledSlots.contains(slotKey(hi, slot))) continue;
              if (!canHeroReceive(hero, item, slot: slot)) continue;
              best = max(best, slotEquipScore(hero, item, slot: slot));
            }
            if (best > -999999) {
              scored.add((item: item, score: best));
            }
          }
          scored.sort((a, b) => b.score.compareTo(a.score));

          final slots = [...group]..sort((a, b) {
              final sa = filledSlots.contains(slotKey(hi, a))
                  ? 999999
                  : slotEquipScore(hero, hero.itemIn(a), slot: a);
              final sb = filledSlots.contains(slotKey(hi, b))
                  ? 999999
                  : slotEquipScore(hero, hero.itemIn(b), slot: b);
              return sa.compareTo(sb);
            });

          final usedLocal = <String>{};
          for (final slot in slots) {
            if (filledSlots.contains(slotKey(hi, slot))) continue;
            final cur = hero.itemIn(slot);
            final curScore = slotEquipScore(hero, cur, slot: slot);
            for (final entry in scored) {
              if (usedLocal.contains(entry.item.id)) continue;
              if (reserved.contains(entry.item.id)) continue;
              if (!canHeroReceive(hero, entry.item, slot: slot)) continue;
              final sc = slotEquipScore(hero, entry.item, slot: slot);
              if (sc > curScore) {
                usedLocal.add(entry.item.id);
                proposals.add((
                  heroIndex: hi,
                  slot: slot,
                  itemId: entry.item.id,
                  delta: sc - curScore,
                ));
                break;
              }
            }
          }
        }
      }

      if (proposals.isEmpty) break;

      final bestByItem = <String,
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})>{};
      for (final p in proposals) {
        final prev = bestByItem[p.itemId];
        if (prev == null || p.delta > prev.delta) {
          bestByItem[p.itemId] = p;
        }
      }

      final bestBySlot = <String,
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})>{};
      for (final p in bestByItem.values) {
        final key = slotKey(p.heroIndex, p.slot);
        final prev = bestBySlot[key];
        if (prev == null || p.delta > prev.delta) {
          bestBySlot[key] = p;
        }
      }

      var added = 0;
      final winners = bestBySlot.values.toList()
        ..sort((a, b) => b.delta.compareTo(a.delta));
      final claimedThisRound = <String>{};
      for (final w in winners) {
        if (reserved.contains(w.itemId)) continue;
        if (claimedThisRound.contains(w.itemId)) continue;
        final key = slotKey(w.heroIndex, w.slot);
        if (filledSlots.contains(key)) continue;
        reserved.add(w.itemId);
        claimedThisRound.add(w.itemId);
        filledSlots.add(key);
        plan.add(w);
        added++;
      }
      if (added == 0) break;
    }

    return plan;
  }

  /// Equip every stash piece that is a class-aware upgrade for some hero.
  ///
  /// Uses per-hero BiS slot fill with party-wide conflict resolution (largest
  /// power delta wins contested items; losers re-pick next round).
  static GameState autoEquipBetterGear(GameState state) {
    var next = state;
    final plan = planBiSAssignments(next);
    final ordered = [...plan]..sort((a, b) {
        final aw = a.slot == EquipmentSlot.weapon ? 0 : 1;
        final bw = b.slot == EquipmentSlot.weapon ? 0 : 1;
        return aw.compareTo(bw);
      });
    for (final step in ordered) {
      EquipmentItem? item;
      for (final g in next.gearStash) {
        if (g.id == step.itemId) {
          item = g;
          break;
        }
      }
      if (item == null) continue;
      final hero = next.heroes[step.heroIndex];
      if (!canHeroReceive(hero, item, slot: step.slot)) continue;
      final beforeLen = next.gearStash.length;
      next = equipFromStash(
        next,
        step.itemId,
        heroIndex: step.heroIndex,
        intoSlot: step.slot,
      );
      if (next.gearStash.length >= beforeLen) {
        continue;
      }
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static String formatDelta(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }

  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      primary.slot == secondary.slot && primary.id != secondary.id;

  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) {
    if (secondary.index > primary.index) {
      return secondary;
    }
    if (secondary.index == primary.index &&
        primary.index < LootRarity.legendary.index) {
      return LootRarity.values[primary.index + 1];
    }
    return primary;
  }

  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return _mergedEquipment(
      primary,
      secondary,
      id: 'combined_${primary.slot.name}_${random.nextInt(1000000)}',
    );
  }

  /// Shows a combination result without changing state or consuming randomness.
  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return _mergedEquipment(
      primary,
      secondary,
      id: 'preview_${primary.id}_${secondary.id}',
    );
  }

  static EquipmentItem _mergedEquipment(
    EquipmentItem primary,
    EquipmentItem secondary, {
    required String id,
  }) {
    final rarity = mergedRarity(primary.rarity, secondary.rarity);
    // Primary drives slot + pattern; secondary can upgrade pattern if rarer.
    final pattern = secondary.rarity.index > primary.rarity.index
        ? secondary.pattern
        : primary.pattern;
    final effectId = primary.effectId != GearEffectId.none
        ? primary.effectId
        : secondary.effectId;
    final effectValue = effectId == GearEffectId.none
        ? 0
        : max(primary.effectValue, secondary.effectValue);
    return EquipmentItem(
      id: id,
      name: _equipmentNameFor(
        primary.slot,
        rarity,
        bias: primary.affinity == null
            ? null
            : HeroRole.values.byName(primary.affinity!),
        armorType: primary.armorType ?? secondary.armorType,
        weaponType: primary.weaponType ?? secondary.weaponType,
        offHandKind: primary.offHandKind ?? secondary.offHandKind,
        handed: primary.handed ?? secondary.handed,
      ),
      slot: primary.slot,
      rarity: rarity,
      strengthBonus:
          primary.strengthBonus + ((secondary.strengthBonus * 50) ~/ 100),
      agilityBonus:
          primary.agilityBonus + ((secondary.agilityBonus * 50) ~/ 100),
      staminaBonus:
          primary.staminaBonus + ((secondary.staminaBonus * 50) ~/ 100),
      intellectBonus:
          primary.intellectBonus + ((secondary.intellectBonus * 50) ~/ 100),
      spiritBonus: primary.spiritBonus + ((secondary.spiritBonus * 50) ~/ 100),
      spellPowerBonus:
          primary.spellPowerBonus + ((secondary.spellPowerBonus * 50) ~/ 100),
      armorBonus: primary.armorBonus + ((secondary.armorBonus * 50) ~/ 100),
      mp5Bonus: primary.mp5Bonus + ((secondary.mp5Bonus * 50) ~/ 100),
      attackBonus: primary.attackBonus + ((secondary.attackBonus * 50) ~/ 100),
      defenseBonus:
          primary.defenseBonus + ((secondary.defenseBonus * 50) ~/ 100),
      vitalityBonus:
          primary.vitalityBonus + ((secondary.vitalityBonus * 50) ~/ 100),
      critChanceBonus:
          primary.critChanceBonus + ((secondary.critChanceBonus * 50) ~/ 100),
      attackSpeedBonus:
          primary.attackSpeedBonus + ((secondary.attackSpeedBonus * 50) ~/ 100),
      moveSpeedBonus:
          primary.moveSpeedBonus + ((secondary.moveSpeedBonus * 50) ~/ 100),
      pattern: pattern,
      effectId: effectId,
      effectValue: effectValue,
      affinity: primary.affinity ?? secondary.affinity,
      itemLevel: max(primary.effectiveItemLevel, secondary.effectiveItemLevel) +
          (rarity.index > primary.rarity.index ? 2 : 1),
      armorType: primary.armorType ?? secondary.armorType,
      weaponType: primary.weaponType ?? secondary.weaponType,
      handed: primary.handed ?? secondary.handed,
      offHandKind: primary.offHandKind ?? secondary.offHandKind,
      iconId: primary.iconId ?? secondary.iconId,
    );
  }

  /// Combines two same-slot pieces (stash and/or equipped). Primary keeps
  /// slot/pattern identity; secondary contributes half its stats.
  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) {
    final primary = findGear(state, primaryId);
    final secondary = findGear(state, secondaryId);
    if (primary == null || secondary == null) {
      return state;
    }
    if (!canCombine(primary, secondary)) {
      return state;
    }
    final cost = combineCost(
      primary,
      secondary,
      combinatorLuck: state.metaDepth.combinatorLuck,
    );
    if (state.gold < cost) {
      return state;
    }

    var next = state.copyWith(gold: state.gold - cost);
    next = removeGear(next, primaryId);
    next = removeGear(next, secondaryId);

    final result = mergeEquipment(primary, secondary);
    // Always stash result — player equips manually.
    next = stashEquipment(next, result);

    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Gear always goes to stash (manual equip). Non-gear → essence.
  /// Weak junk is auto-sold on pickup when [autoSellMaxPower] > 0 (ilvl cap).
  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    var next = state;
    final resolved = <LootDrop>[];

    for (final drop in drops) {
      final item = drop.equipment;
      if (item == null) {
        final essence = lootEssenceValue(drop);
        next = next.copyWith(essence: next.essence + essence);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: essence),
        );
        continue;
      }

      if (_shouldAutoSellOnPickup(next, item)) {
        final value = equipmentEssenceValue(item);
        next = next.copyWith(essence: next.essence + value);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: value),
        );
        continue;
      }

      final essenceBefore = next.essence;
      next = stashEquipment(next, item);
      resolved.add(
        drop.copyWith(
          outcome: LootOutcome.stashed,
          essenceGained: max(0, next.essence - essenceBefore),
        ),
      );
    }

    return (state: next, resolved: resolved);
  }

  static bool _shouldAutoSellOnPickup(GameState state, EquipmentItem item) {
    if (state.autoSellMaxPower <= 0) return false;
    if (item.effectiveItemLevel > state.autoSellMaxPower) return false;
    return !_shouldKeepInBag(state, item);
  }

  /// Keep bag piece if BiS planning would equip it, or it still upgrades a worn slot.
  static bool _shouldKeepInBag(GameState state, EquipmentItem item) {
    final plan = planBiSAssignments(state);
    if (plan.any((p) => p.itemId == item.id)) {
      return true;
    }
    for (final hero in state.heroes) {
      for (final slot in equipTargetsFor(item)) {
        if (!canHeroReceive(hero, item, slot: slot)) {
          continue;
        }
        if (_compareForHeroSlot(hero, item, slot).isUpgrade) {
          return true;
        }
      }
    }
    return false;
  }

  /// Sell every stash piece that is not worth keeping for any hero.
  ///
  /// The settings ilvl cap only gates *pickup* autosell; this button clears
  /// bag junk even when power/ilvl is above the cap (that was the old bug).
  static GameState autoSellJunk(GameState state) {
    var essence = state.essence;
    // Multi-pass: after selling, another piece may become "best for empty".
    var stash = List<EquipmentItem>.from(state.gearStash);
    var guard = 0;
    while (guard < 64) {
      guard++;
      final probe = state.copyWith(gearStash: stash);
      EquipmentItem? sellId;
      for (final item in stash) {
        if (!_shouldKeepInBag(probe, item)) {
          sellId = item;
          break;
        }
      }
      if (sellId == null) break;
      essence += equipmentEssenceValue(sellId);
      stash = stash.where((g) => g.id != sellId!.id).toList();
    }
    return state.copyWith(
      gearStash: stash,
      essence: essence,
      lastUpdated: DateTime.now(),
    );
  }

  static int recommendedForgeUpgrade(GameState state) {
    // 0=atk 1=def 2=vit — pick cheapest relative gap.
    final atkCost = upgradeCostFor(state, PartyUpgradeType.attack);
    final defCost = upgradeCostFor(state, PartyUpgradeType.defense);
    final vitCost = upgradeCostFor(state, PartyUpgradeType.vitality);
    final scores = <(int, double)>[
      (0, state.attackBonus / max(1, atkCost)),
      (1, state.defenseBonus / max(1, defCost)),
      (2, (state.vitalityBonus / 6) / max(1, vitCost)),
    ];
    // Prefer the lowest tier (most behind).
    scores.sort((a, b) => a.$2.compareTo(b.$2));
    return scores.first.$1;
  }

  static int levelsUntilSoftcap(GameState state) {
    final mean =
        state.heroes.fold<int>(0, (s, h) => s + h.level) /
        max(1, state.heroes.length);
    final floor = state.currentRoom.floorNumber.toDouble();
    final gap = floor + 2 - mean;
    return max(0, gap.ceil());
  }

  static LootRarity _rarityForBattle(
    int battleNumber, {
    int hardmodeLevel = 0,
  }) {
    final hm = hardmodeLevel.clamp(0, 10);
    // Direct legendary roll — worst at +0, best at +10.
    final legendaryChance = 0.004 + hm * 0.011;
    if (random.nextDouble() < legendaryChance) {
      return LootRarity.legendary;
    }

    var rarity = LootRarity.common;
    if (battleNumber % 12 == 0) {
      rarity = LootRarity.epic;
    } else if (battleNumber % 6 == 0) {
      rarity = LootRarity.rare;
    } else if (battleNumber % 3 == 0) {
      rarity = LootRarity.uncommon;
    }

    // Hardmode can bump the base tier (never past legendary).
    final bumpChance = hm * 0.04;
    if (rarity.index < LootRarity.legendary.index &&
        random.nextDouble() < bumpChance) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    if (rarity.index < LootRarity.legendary.index &&
        hm >= 7 &&
        random.nextDouble() < bumpChance * 0.5) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    return rarity;
  }

  static GameState _advanceOneTick(GameState state) {
    // Full party wipe: failed push retreats; otherwise restart the floor.
    if (state.isPartyDefeated) {
      if (state.dungeonMode == DungeonMode.push &&
          state.currentRoom.floorNumber > state.highestFloorCleared) {
        return retreatFromFailedPush(state);
      }
      return restartFloor(state);
    }

    final room = state.currentRoom;

    // Treasure room: no combat — open the chest and move on.
    if (room.type == RoomType.treasure || state.enemies.isEmpty) {
      final budget = roomCombatBudget(room);
      return _advanceToNextRoom(state, goldGain: budget.gold);
    }

    // Heroes attack: spread targeting — hero i strikes alive enemy i % n.
    final enemies = List<EnemyUnit>.from(state.enemies);
    var targetSlot = 0;
    for (final hero in state.heroes) {
      if (!hero.isAlive) {
        continue;
      }
      final aliveIndices = <int>[
        for (var i = 0; i < enemies.length; i++)
          if (!enemies[i].isDefeated) i,
      ];
      if (aliveIndices.isEmpty) {
        break;
      }
      final target = aliveIndices[targetSlot % aliveIndices.length];
      final raw = state.effectiveHeroAttack(hero);
      // Idle tick abstraction: faster clears than live spatial.
      final mitigated = max(1, raw * 2 - enemies[target].defense ~/ 5);
      enemies[target] = enemies[target].takeDamage(mitigated);
      targetSlot++;
    }

    var next = state.copyWith(enemies: enemies);
    for (var i = 0; i < enemies.length; i++) {
      if (!state.enemies[i].isDefeated && enemies[i].isDefeated) {
        next = awardEnemyKillXp(next, state.enemies[i]);
      }
    }

    // Room cleared when every enemy in the group is down.
    if (enemies.every((enemy) => enemy.isDefeated)) {
      final goldGain = state.enemies.fold<int>(
        0,
        (sum, enemy) => sum + enemy.rewardGold,
      );
      return _advanceToNextRoom(next, goldGain: goldGain);
    }

    // Enemy counterattack: one frontliner (idle abstraction stays farmable).
    final heroes = List<PartyHero>.from(next.heroes);
    final livingEnemies = [
      for (final enemy in enemies)
        if (!enemy.isDefeated) enemy,
    ];
    final attackers = livingEnemies.take(1);
    for (final enemy in attackers) {
      final defenderIndex = _pickTauntedDefenderIndex(heroes);
      if (defenderIndex < 0) {
        break;
      }
      final defender = heroes[defenderIndex];
      // Abstract/tick combat is far softer than live spatial.
      final softAtk = max(1, (enemy.attack * 0.12).round());
      final damageTaken = max(
        1,
        softAtk - next.effectiveHeroDefense(defender),
      );
      heroes[defenderIndex] = defender.copyWith(
        currentHp: max(0, defender.currentHp - damageTaken),
      );
    }

    // Healer passive: mend living allies after the exchange.
    final mend = next.healerMendAmount;
    if (mend > 0 && heroes.any((hero) => hero.isAlive)) {
      for (var i = 0; i < heroes.length; i++) {
        final hero = heroes[i];
        if (!hero.isAlive) {
          continue;
        }
        final maxHp = next.effectiveHeroMaxHp(hero);
        heroes[i] = hero.copyWith(currentHp: min(maxHp, hero.currentHp + mend));
      }
    }

    return next.copyWith(heroes: heroes, enemies: enemies);
  }

  /// Prefer warriors (weight 3) over other living heroes (weight 1).
  static int _pickTauntedDefenderIndex(List<PartyHero> heroes) {
    final weighted = <int>[];
    for (var i = 0; i < heroes.length; i++) {
      final hero = heroes[i];
      if (!hero.isAlive) {
        continue;
      }
      final weight = hero.role == HeroRole.warrior ? 3 : 1;
      for (var w = 0; w < weight; w++) {
        weighted.add(i);
      }
    }
    if (weighted.isEmpty) {
      return -1;
    }
    return weighted[random.nextInt(weighted.length)];
  }

  /// Public room-clear: awards loot/gold and advances (farm loop or push).
  static GameState completeCurrentRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) => _advanceToNextRoom(
    state,
    goldGain: goldGain,
    skipLootRoll: skipLootRoll,
    recentLoot: recentLoot,
  );

  /// Marks the current floor wave cleared, awards gold/loot and advances.
  /// Farm loops the same floor; push goes to the next floor.
  /// Clearing the boss floor (5+AL) counts a boss victory; push returns to hub.
  static GameState _advanceToNextRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) {
    final room = state.currentRoom;
    final enemiesDefeated = state.enemies.length;
    final bossesCleared = room.type == RoomType.boss ? 1 : 0;

    late GameState awarded;
    late List<LootDrop> drops;
    if (skipLootRoll) {
      awarded = state;
      drops = recentLoot ?? state.recentLoot;
    } else {
      final rawDrops = rollLoot(
        room.globalBattleNumber,
        ascensionLevel: state.ascensionLevel,
        lootFindPercent: state.petLootFindPercent,
        hardmodeLevel: state.hardmodeLevel,
      );
      final lootResult = applyLootDrops(state, rawDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
    }
    final goldAwarded = applyGoldGain(awarded, goldGain);
    final highest = max(awarded.highestFloorCleared, room.floorNumber);
    final farmLoop = awarded.dungeonMode == DungeonMode.farm;
    final clearedBoss = bossesCleared > 0;

    // Push + boss floor clear → dungeon cleared, back to hub.
    if (!farmLoop && clearedBoss) {
      final def = DungeonCatalog.byId(awarded.dungeonId);
      var progressed = awarded.copyWith(
        gold: awarded.gold + goldAwarded,
        lifetimeGoldEarned: awarded.lifetimeGoldEarned + goldAwarded,
        bossVictories: awarded.bossVictories + bossesCleared,
        highestFloorCleared: highest,
        highestDungeonCleared: max(awarded.highestDungeonCleared, def.number),
        inDungeon: false,
        recentLoot: drops,
        heroes: awarded.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: awarded.effectiveHeroMaxHp(hero)),
            )
            .toList(),
      );
      progressed = _applyMetaProgress(state, progressed, drops);
      return applyMissionProgress(
        progressed,
        enemiesDefeated: enemiesDefeated,
        bossesCleared: bossesCleared,
        goldEarned: goldAwarded,
      );
    }

    final targetFloor = farmLoop ? room.floorNumber : room.floorNumber + 1;
    final layoutSeed = newLayoutSeed();
    final nextFloor = DungeonGenerator.generateFloor(
      targetFloor,
      ascensionLevel: awarded.ascensionLevel,
      dungeonId: awarded.dungeonId,
      layoutSeed: layoutSeed,
    );
    final nextRoom = nextFloor.first;
    var progressed = awarded.copyWith(
      gold: awarded.gold + goldAwarded,
      lifetimeGoldEarned: awarded.lifetimeGoldEarned + goldAwarded,
      bossVictories: awarded.bossVictories + bossesCleared,
      highestFloorCleared: highest,
      enemies: createEnemyGroup(
        nextRoom,
        dungeonId: awarded.dungeonId,
        fromState: awarded,
      ),
      currentRoom: nextRoom,
      dungeonFloor: nextFloor,
      layoutSeed: layoutSeed,
      heroes: awarded.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: awarded.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      recentLoot: drops,
    );
    progressed = _applyMetaProgress(state, progressed, drops);

    return applyMissionProgress(
      progressed,
      enemiesDefeated: enemiesDefeated,
      bossesCleared: bossesCleared,
      goldEarned: goldAwarded,
    );
  }

  /// Codex discovery, local achievements, and Daily Run claim — evaluated on
  /// every floor/boss clear. [before] is the pre-clear state (still holding
  /// the defeated enemy roster); [after] is the state post gold/loot award.
  static GameState _applyMetaProgress(
    GameState before,
    GameState after,
    List<LootDrop> drops,
  ) {
    var next = MetaSystems.registerEnemyEncounters(after, before.enemies);
    next = MetaSystems.registerItemDrops(next, drops);
    next = _claimDailyIfEligible(next);
    final challengeBonus = MetaSystems.challengeClearEssenceBonus(before);
    if (challengeBonus > 0) {
      next = next.copyWith(essence: next.essence + challengeBonus);
    }
    final bossKill = before.currentRoom.type == RoomType.boss ? 1 : 0;
    final trophies = List<String>.from(next.metaDepth.zoneTrophies);
    if (bossKill > 0 && !trophies.contains(before.dungeonId)) {
      trophies.add(before.dungeonId);
    }
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        lifetimeFloorClears: next.metaDepth.lifetimeFloorClears + 1,
        lifetimeBossKills: next.metaDepth.lifetimeBossKills + bossKill,
        zoneTrophies: trophies,
      ),
    );
    next = ensureWeeklyContract(next);
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        weeklyProgress: min(3, next.metaDepth.weeklyProgress + 1),
      ),
    );
    next = MetaSystems.evaluateAchievements(next);
    return next;
  }

  static GameState _claimDailyIfEligible(GameState state) {
    if (state.dailyClaimed) return state;
    final now = DateTime.now().toUtc();
    final todayKey = MetaSystems.dailyDateKey(now);
    if (state.lastDailyDate != todayKey) return state;
    if (state.dungeonId != MetaSystems.dailyDungeonId(now)) return state;
    const dailyEssenceReward = 25;
    return state.copyWith(
      dailyClaimed: true,
      essence: state.essence + dailyEssenceReward,
    );
  }

  /// Enters the free, seeded Daily Run — a single floor in whichever
  /// dungeon today's UTC date rotates to. Ignores normal unlock gating
  /// (it's a bounded daily trial, not a permanent unlock). Clearing any
  /// floor/boss while inside claims today's reward exactly once.
  static GameState enterDaily(GameState state, {DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    final dateKey = MetaSystems.dailyDateKey(t);
    final seed = MetaSystems.dailySeed(t);
    final dungeonId = MetaSystems.dailyDungeonId(t);
    final isNewDay = state.lastDailyDate != dateKey;
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: dungeonId,
      layoutSeed: seed,
    );
    final room = floor.first;
    return state.copyWith(
      inDungeon: true,
      dungeonId: dungeonId,
      dungeonMode: DungeonMode.push,
      highestFloorCleared: 0,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: createEnemyGroup(
        room,
        dungeonId: dungeonId,
        fromState: state,
      ),
      layoutSeed: seed,
      lastDailyDate: dateKey,
      dailyClaimed: isNewDay ? false : state.dailyClaimed,
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Parses a save of any version, migrating legacy v1 saves
  /// (single `enemy` + stored `battleNumber`) to the room-based v2 model.
  static GameState stateFromJson(Map<String, dynamic> json) {
    final loaded = json.containsKey('enemies')
        ? GameState.fromJson(json)
        : _migrateV1(json);
    var next = loaded.missions.isNotEmpty
        ? loaded
        : loaded.copyWith(
            missions: createMissionBoard(ascensionLevel: loaded.ascensionLevel),
          );
    if (next.ascensionLevel > 0) {
      next = next.copyWith(rogueUnlocked: true);
    }
    return MetaSystems.evaluateAchievements(ensureRogueHero(next));
  }

  // —— Save export / import (clipboard JSON, no server) ——————————

  /// Serializes [state] to a JSON string suitable for clipboard export.
  static String exportSaveJson(GameState state) => jsonEncode(state.toJson());

  /// Parses a previously-exported save string. Returns null on any parse
  /// failure so the caller can show a friendly error instead of crashing.
  static GameState? importSaveJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return stateFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // —— Gear loadouts (save/apply up to 3 named presets) ——————————

  static const int maxLoadouts = 3;

  /// Captures each hero's currently-equipped gear as a named preset.
  /// Replaces an existing loadout with the same [id], otherwise appends
  /// (capped at [maxLoadouts] — oldest is dropped to make room).
  static GameState saveLoadout(
    GameState state, {
    required String id,
    required String name,
  }) {
    final heroSlots = <Map<String, String>>[
      for (final hero in state.heroes)
        <String, String>{
          for (final entry in hero.equipped.entries) entry.key.name: entry.value.id,
        },
    ];
    final loadout = GearLoadout(id: id, name: name, heroSlotItemIds: heroSlots);
    final next = List<GearLoadout>.from(state.loadouts);
    final existingIndex = next.indexWhere((l) => l.id == id);
    if (existingIndex >= 0) {
      next[existingIndex] = loadout;
    } else {
      if (next.length >= maxLoadouts) {
        next.removeAt(0);
      }
      next.add(loadout);
    }
    return state.copyWith(loadouts: next, lastUpdated: DateTime.now());
  }

  static GameState deleteLoadout(GameState state, String id) {
    if (!state.loadouts.any((l) => l.id == id)) return state;
    return state.copyWith(
      loadouts: state.loadouts.where((l) => l.id != id).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Locates [itemId] anywhere it might currently live (any hero's equipped
  /// gear, or the stash) and removes it from there.
  static (EquipmentItem?, GameState) _extractItemById(
    GameState state,
    String itemId,
  ) {
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      for (final entry in hero.equipped.entries) {
        if (entry.value.id == itemId) {
          final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
            hero.equipped,
          )..remove(entry.key);
          final heroes = [...state.heroes];
          heroes[i] = hero.copyWith(equipped: nextGear);
          return (entry.value, state.copyWith(heroes: heroes));
        }
      }
    }
    for (final item in state.gearStash) {
      if (item.id == itemId) {
        return (
          item,
          state.copyWith(
            gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
          ),
        );
      }
    }
    return (null, state);
  }

  /// Re-equips a saved [GearLoadout] by id. Items sold/lost since the
  /// loadout was saved are silently skipped (no-op for that slot); items
  /// that fail a class proficiency check are returned to the stash.
  static GameState applyLoadout(GameState state, String id) {
    GearLoadout? loadout;
    for (final l in state.loadouts) {
      if (l.id == id) {
        loadout = l;
        break;
      }
    }
    if (loadout == null) return state;

    var next = state;
    for (var heroIndex = 0;
        heroIndex < loadout.heroSlotItemIds.length &&
            heroIndex < next.heroes.length;
        heroIndex++) {
      for (final entry in loadout.heroSlotItemIds[heroIndex].entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        final itemId = entry.value;
        if (next.heroes[heroIndex].itemIn(slot)?.id == itemId) {
          continue;
        }
        final extracted = _extractItemById(next, itemId);
        final item = extracted.$1;
        next = extracted.$2;
        if (item == null) continue;

        final hero = next.heroes[heroIndex];
        if (!ClassProficiency.canEquip(
          role: hero.role,
          level: hero.level,
          item: item,
        )) {
          next = stashEquipment(next, item);
          continue;
        }
        final current = hero.itemIn(slot);
        if (current != null) {
          next = stashEquipment(next, current);
        }
        final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
          next.heroes[heroIndex].equipped,
        )..[slot] = item;
        final heroes = [...next.heroes];
        heroes[heroIndex] = next.heroes[heroIndex].copyWith(equipped: nextGear);
        next = next.copyWith(heroes: heroes);
      }
    }

    next = next.copyWith(
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
    return next;
  }

  static GameState _migrateV1(Map<String, dynamic> json) {
    final battleNumber = (json['battleNumber'] as int?) ?? 1;
    final floorNumber = max(1, battleNumber);
    final floor = DungeonGenerator.generateFloor(floorNumber);
    final room = floor.first;

    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;

    return GameState(
      heroes: (json['heroes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PartyHero.fromJson)
          .toList(),
      enemies: createEnemyGroup(room),
      gold: json['gold'] as int,
      essence: (json['essence'] as int?) ?? 0,
      bossVictories: (json['bossVictories'] as int?) ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      offlineSecondsRecovered: (json['offlineSecondsRecovered'] as int?) ?? 0,
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
      currentRoom: room,
      dungeonFloor: floor,
      ascensionLevel: (json['ascensionLevel'] as int?) ?? 0,
      equipped: () {
        final map = <EquipmentSlot, EquipmentItem>{};
        if (json['equippedWeapon'] != null) {
          map[EquipmentSlot.weapon] = EquipmentItem.fromJson(
            json['equippedWeapon'] as Map<String, dynamic>,
          );
        }
        if (json['equippedArmor'] != null) {
          map[EquipmentSlot.cloak] = EquipmentItem.fromJson(
            json['equippedArmor'] as Map<String, dynamic>,
          );
        }
        return map;
      }(),
    );
  }
}

/// Snapshot of what AFK time awarded on a single apply.
class OfflineProgressResult {
  const OfflineProgressResult({
    required this.state,
    required this.secondsApplied,
    required this.goldGained,
    required this.essenceGained,
    required this.roomsCleared,
    required this.highestFloorDelta,
    required this.bossDelta,
  });

  final GameState state;
  final int secondsApplied;
  final int goldGained;
  final int essenceGained;
  final int roomsCleared;
  final int highestFloorDelta;
  final int bossDelta;

  bool get hasSummary =>
      secondsApplied >= 45 &&
      (goldGained > 0 ||
          essenceGained > 0 ||
          roomsCleared > 0 ||
          highestFloorDelta > 0 ||
          bossDelta > 0);

  String get headline {
    final away = formatOfflineDuration(secondsApplied);
    final parts = <String>['Away $away'];
    if (goldGained > 0) parts.add('+${goldGained}g');
    if (essenceGained > 0) parts.add('+$essenceGained ess');
    if (roomsCleared > 0) parts.add('$roomsCleared clears');
    if (highestFloorDelta > 0) parts.add('floor +$highestFloorDelta');
    if (bossDelta > 0) parts.add('boss x$bossDelta');
    return parts.join(' · ');
  }

  static String formatOfflineDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return s == 0 ? '${m}m' : '${m}m ${s}s';
    }
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

enum PartyUpgradeType { attack, defense, vitality }
