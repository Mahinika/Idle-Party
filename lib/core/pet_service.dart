import 'dart:math';

import '../models/pet.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// Hatching, bonding, merging and framing pets.
///
/// Pets survive Ascend (see AGENTS.md), so everything here writes through
/// `metaDepth` / the pet collection rather than run state.
abstract final class PetService {
  static PetRarity _rollPetRarity() {
    final total = PetRarity.values.fold<int>(
      0,
      (sum, r) => sum + PetCatalog.rarityWeight(r),
    );
    var roll = GameLogic.random.nextInt(total);
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
    final species = PetCatalog.all[GameLogic.random.nextInt(PetCatalog.all.length)];
    final rarity = _rollPetRarity();
    final pet = Pet(
      id: '${species.id}_${GameLogic.random.nextInt(100000)}',
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
    if (a.rarity != b.rarity) return false;
    if (a.rarity == PetRarity.legendary) return false;
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
      id: '${a.resolvedSpecies}_${GameLogic.random.nextInt(100000)}',
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
    final pets =
        state.ownedPets.where((p) => p.id != petIdA && p.id != petIdB).toList()
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
    if (!PetCatalog.all.any((s) => s.id == speciesId)) return state;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(favoritePetSpecies: speciesId),
        lastUpdated: DateTime.now(),
      ),
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

  static const int maxPetBondLevel = 25;

  static const int maxPetLevel = 30;

  static int bondPetCost(int bondLevel) => 5 + bondLevel * 3;

  static GameState bondPet(GameState state, String petId) {
    final idx = state.ownedPets.indexWhere((p) => p.id == petId);
    if (idx < 0) return state;
    final pet = state.ownedPets[idx];
    if (pet.bondLevel >= maxPetBondLevel) return state;
    final cost = bondPetCost(pet.bondLevel);
    if (state.essence < cost) return state;
    final pets = List<Pet>.from(state.ownedPets);
    pets[idx] = pet.copyWith(
      bondLevel: min(maxPetBondLevel, pet.bondLevel + 1),
    );
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
    if (pet.level >= maxPetLevel) return state;
    final cost = petLevelUpCost(pet);
    if (state.essence < cost) {
      return state;
    }

    final leveledPet = pet.copyWith(level: min(maxPetLevel, pet.level + 1));
    final pets = List<Pet>.from(state.ownedPets)..[index] = leveledPet;
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: state.activePet?.id == petId ? leveledPet : state.activePet,
      lastUpdated: DateTime.now(),
    );
  }
}
