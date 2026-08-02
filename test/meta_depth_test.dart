import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/pet.dart';

void main() {
  test('pet catalog covers meta-depth species roster', () {
    expect(PetCatalog.all.length, greaterThanOrEqualTo(12));
    expect(
      PetCatalog.all.map((s) => s.passive).toSet(),
      containsAll([
        PetPassive.attack,
        PetPassive.goldFind,
        PetPassive.lootFind,
        PetPassive.xpFind,
        PetPassive.mitigate,
        PetPassive.healBoost,
      ]),
    );
  });

  test('achievement catalog spans categories', () {
    expect(AchievementCatalog.all.length, greaterThanOrEqualTo(30));
    expect(
      AchievementCatalog.all.map((a) => a.category).toSet().length,
      greaterThanOrEqualTo(4),
    );
  });

  test('hatch respects roster and rolls rarity fields', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(essence: 5000);
    state = GameLogic.hatchPet(state);
    expect(state.ownedPets, isNotEmpty);
    final pet = state.ownedPets.first;
    expect(pet.resolvedSpecies, isNotEmpty);
    expect(pet.rarity, isNotNull);
    expect(state.metaDepth.lifetimePetHatches, greaterThanOrEqualTo(1));
  });

  test('prestige shop and weekly contract operate', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(
      essence: 500,
      ascensionLevel: 5,
      metaDepth: const MetaDepthState(weeklyProgress: 3),
    );
    state = GameLogic.ensureWeeklyContract(state);
    expect(state.metaDepth.weeklyKey, isNotEmpty);
    state = GameLogic.buyPrestigeShopItem(state, 'torch_keep');
    expect(state.metaDepth.torchKeepLevel, greaterThan(0));
    expect(state.metaDepth.hasPrestige('torch_keep'), isTrue);
  });

  test('collection score and will rank move with progress', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31));
    final base = state.collectionScore;
    state = state.copyWith(
      achievements: ['first_floor', 'first_boss'],
      metaDepth: state.metaDepth.copyWith(
        zoneTrophies: ['sandy'],
        titles: ['Reborn'],
      ),
    );
    expect(state.collectionScore, greaterThan(base));
    expect(WillRanks.titleForScore(state.collectionScore), isNotEmpty);
    expect(MetaSystems.collectionScore(state), state.collectionScore);
  });

  test('merge pets upgrades rarity', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(essence: 200);
    final a = Pet(
      id: 'ember_pup_1',
      name: 'Ember Pup',
      attackBonus: 2,
      speciesId: 'ember_pup',
      rarity: PetRarity.common,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final b = Pet(
      id: 'ember_pup_2',
      name: 'Ember Pup',
      attackBonus: 2,
      speciesId: 'ember_pup',
      rarity: PetRarity.common,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    state = state.copyWith(ownedPets: [a, b], activePet: a);
    state = GameLogic.mergePets(state, a.id, b.id);
    expect(state.ownedPets.length, 1);
    expect(state.ownedPets.first.rarity.index, greaterThan(PetRarity.common.index));
    expect(state.metaDepth.lifetimePetMerges, 1);
  });

  test('weekly progress increments on floor clear path', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31));
    state = GameLogic.ensureWeeklyContract(state);
    expect(state.metaDepth.weeklyProgress, 0);
    state = GameLogic.completeCurrentRoom(state, goldGain: 10, skipLootRoll: true);
    expect(state.metaDepth.weeklyProgress, 1);
    expect(state.metaDepth.lifetimeFloorClears, greaterThanOrEqualTo(1));
    // Ascend must not double-count weekly progress.
    state = state.copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(state.ascensionLevel),
      metaDepth: state.metaDepth.copyWith(weeklyProgress: 2),
    );
    final beforeWeekly = state.metaDepth.weeklyProgress;
    state = GameLogic.ascend(state, now: DateTime(2026, 7, 31));
    expect(state.metaDepth.weeklyProgress, beforeWeekly);
  });

  test('createEnemyGroup glass modifier shrinks HP and boosts ATK', () {
    const room = DungeonRoom(
      floorNumber: 3,
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: 3,
      enemyCount: 4,
    );
    final baseState = GameLogic.createInitialState(now: DateTime(2026, 7, 31));
    final plain = GameLogic.createEnemyGroup(room, fromState: baseState);
    final glassState = baseState.copyWith(
      metaDepth: baseState.metaDepth.copyWith(weeklyModifier: 'glass'),
    );
    final glass = GameLogic.createEnemyGroup(room, fromState: glassState);
    expect(plain, isNotEmpty);
    expect(glass.length, plain.length);
    final plainHp = plain.fold<int>(0, (s, e) => s + e.maxHp);
    final glassHp = glass.fold<int>(0, (s, e) => s + e.maxHp);
    final plainAtk = plain.fold<int>(0, (s, e) => s + e.attack);
    final glassAtk = glass.fold<int>(0, (s, e) => s + e.attack);
    expect(glassHp, lessThan(plainHp));
    expect(glassAtk, greaterThan(plainAtk));
  });

  test('awardPartyXp applies sanctuary and pet XP bonuses', () {
    final xpPet = Pet(
      id: 'xp_pet',
      name: 'Scholar Cub',
      attackBonus: 1,
      speciesId: 'ember_pup',
      rarity: PetRarity.rare,
      passive: PetPassive.xpFind,
      affinityDungeonId: 'sandy',
      level: 5,
      passivePerLevel: 2,
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31)).copyWith(
      activePet: xpPet,
      ownedPets: [xpPet],
      metaDepth: const MetaDepthState(sanctuaryXpLevel: 5),
    );
    final beforeXp = state.heroes.first.xp;
    final amount = 20;
    final expectedBoost = amount +
        (amount *
                (state.sanctuaryXpBonusPercent + state.petXpFindPercent)) ~/
            100;
    state = GameLogic.awardPartyXp(state, amount);
    expect(state.heroes.first.level, 1);
    expect(state.heroes.first.xp - beforeXp, expectedBoost);
  });

  test('mergePets no-ops when both are already legendary', () {
    final a = Pet(
      id: 'leg_a',
      name: 'Ember Pup',
      attackBonus: 5,
      speciesId: 'ember_pup',
      rarity: PetRarity.legendary,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final b = Pet(
      id: 'leg_b',
      name: 'Ember Pup',
      attackBonus: 5,
      speciesId: 'ember_pup',
      rarity: PetRarity.legendary,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 31))
        .copyWith(ownedPets: [a, b], activePet: a);
    expect(GameLogic.canMergePets(state, a.id, b.id), isFalse);
    final next = GameLogic.mergePets(state, a.id, b.id);
    expect(identical(next, state) || next.ownedPets.length == 2, isTrue);
    expect(next.ownedPets.length, 2);
    expect(next.metaDepth.lifetimePetMerges, 0);
  });

  test('prestige shop respects level caps', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 31)).copyWith(
      essence: 5000,
      ascensionLevel: 20,
      metaDepth: const MetaDepthState(torchKeepLevel: 10),
    );
    final blocked = GameLogic.buyPrestigeShopItem(state, 'torch_keep');
    expect(blocked.metaDepth.torchKeepLevel, 10);
    expect(blocked.essence, state.essence);

    state = state.copyWith(
      metaDepth: const MetaDepthState(combinatorLuck: 4),
    );
    state = GameLogic.buyPrestigeShopItem(state, 'combine_luck');
    expect(state.metaDepth.combinatorLuck, 5);
    final atCap = GameLogic.buyPrestigeShopItem(state, 'combine_luck');
    expect(atCap.metaDepth.combinatorLuck, 5);
    expect(atCap.essence, state.essence);
  });

  test('MetaDepthState.fromJson parses num ints safely', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{
      'weeklyProgress': 2.0,
      'torchKeepLevel': 3,
      'lifetimeAbilityCasts': 12.5,
    });
    expect(md.weeklyProgress, 2);
    expect(md.torchKeepLevel, 3);
    expect(md.lifetimeAbilityCasts, 12);
  });
}
