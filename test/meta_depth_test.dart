import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
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
}
