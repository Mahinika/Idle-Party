import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/pet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GameState JSON round-trips core fields', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25, 12));
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    state = GameLogic.setDungeonMode(state, DungeonMode.farm);
    state = state.copyWith(
      gold: 777,
      essence: 12,
      attackBonus: 4,
      defenseBonus: 3,
      vitalityBonus: 12,
      highestFloorCleared: 3,
      ascensionLevel: 1,
      godHandLevel: 2,
      autoSellMaxPower: 30,
      autoSellMaxRarity: 2,
      autoDisassembleMaxIlvl: 18,
      autoDisassembleMaxRarity: 1,
      soundMuted: true,
      reducedVfx: true,
      rogueUnlocked: true,
      offlineSecondsRecovered: 90,
      layoutSeed: 4242,
    );
    state = GameLogic.ensureRogueHero(state);

    final raw = state.toJson();
    final encoded = jsonEncode(raw);
    final decoded = GameLogic.stateFromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    // Load re-evaluates achievements and grants essence for unmet unlocks.
    final grant = (AchievementCatalog.byId('first_floor')?.essenceReward ?? 0) +
        (AchievementCatalog.byId('first_ascend')?.essenceReward ?? 0) +
        (AchievementCatalog.byId('full_party')?.essenceReward ?? 0);
    expect(decoded.gold, 777);
    expect(decoded.essence, 12 + grant);
    expect(decoded.achievements, containsAll(['first_floor', 'first_ascend', 'full_party']));
    expect(decoded.attackBonus, 4);
    expect(decoded.defenseBonus, 3);
    expect(decoded.vitalityBonus, 12);
    expect(decoded.highestFloorCleared, 3);
    expect(decoded.ascensionLevel, 1);
    expect(decoded.godHandLevel, 2);
    expect(decoded.autoSellMaxPower, 30);
    expect(decoded.autoSellMaxRarity, 2);
    expect(decoded.autoDisassembleMaxIlvl, 18);
    expect(decoded.autoDisassembleMaxRarity, 1);
    expect(decoded.soundMuted, isTrue);
    expect(decoded.reducedVfx, isTrue);
    expect(decoded.vfxQuality.name, 'lite');
    expect(decoded.rogueUnlocked, isTrue);
    expect(decoded.offlineSecondsRecovered, 90);
    expect(decoded.layoutSeed, 4242);
    expect(decoded.dungeonId, 'sandy');
    expect(decoded.dungeonMode, DungeonMode.farm);
    expect(decoded.inDungeon, isTrue);
    expect(decoded.heroes.length, state.heroes.length);
    // Load may run syncSpecUnlocks and bump lastUpdated.
    expect(
      !decoded.lastUpdated.isBefore(state.lastUpdated),
      isTrue,
    );
  });

  test('equipped gear and stash survive serialization', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
    final weapon = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    final cloak = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.mage,
    );
    // Prefer per-hero gear (current save shape).
    final heroes = [
      state.heroes.first.copyWith(
        equipped: {
          EquipmentSlot.weapon: weapon,
          EquipmentSlot.cloak: cloak,
        },
      ),
      ...state.heroes.skip(1),
    ];
    state = state.copyWith(heroes: heroes, gearStash: [cloak]);

    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.heroes.first.equipped[EquipmentSlot.weapon]?.name, weapon.name);
    expect(round.heroes.first.equipped[EquipmentSlot.cloak]?.name, cloak.name);
    expect(round.gearStash, isNotEmpty);
    expect(round.gearStash.first.name, cloak.name);
  });

  test('SharedPreferences storage load/save round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesGameStorage(preferences: prefs);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
    state = state.copyWith(gold: 321, essence: 7, highestFloorCleared: 2);
    await storage.save(state);

    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.gold, 321);
    expect(
      loaded.essence,
      7 + (AchievementCatalog.byId('first_floor')?.essenceReward ?? 0),
    );
    expect(loaded.achievements, contains('first_floor'));
    expect(loaded.highestFloorCleared, 2);
  });

  test('boot applies offline progress into director summary', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesGameStorage(preferences: prefs);

    var saved = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
      dungeonId: 'sandy',
    );
    saved = GameLogic.setDungeonMode(saved, DungeonMode.farm);
    saved = saved.copyWith(
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    await storage.save(saved);

    final director = GameDirector(storage, enableSpatialLoop: false);
    await director.boot();

    expect(director.isLoading, isFalse);
    expect(director.state.gold, greaterThan(saved.gold));
    expect(director.offlineSummary, isNotNull);
    expect(director.offlineSummary!.headline, contains('Away'));
    expect(director.toast, isNotNull);

    director.dismissOfflineSummary();
    expect(director.offlineSummary, isNull);
    director.dispose();
  });

  test('fromJson merges orphan activePet into ownedPets', () {
    final pet = Pet(
      id: 'ash_fox_1',
      name: 'Ash Fox',
      attackBonus: 3,
      speciesId: 'ash_fox',
      rarity: PetRarity.rare,
      affinityDungeonId: 'hell',
    );
    final json = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .copyWith(activePet: pet, ownedPets: const <Pet>[])
        .toJson();
    // Simulate desync: active present, roster empty.
    json['ownedPets'] = <dynamic>[];
    json['activePet'] = pet.toJson();
    final loaded = GameState.fromJson(json);
    expect(loaded.ownedPets, hasLength(1));
    expect(loaded.activePet?.id, pet.id);
    expect(loaded.ownedPets.first.id, pet.id);
  });

  test('corrupt SharedPreferences save is quarantined on load', () async {
    SharedPreferences.setMockInitialValues({
      'idle_party_save_v2': '{not-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesGameStorage(preferences: prefs);

    expect(await storage.hasSave(), isTrue);
    expect(await storage.load(), isNull);
    expect(await storage.hasSave(), isFalse);
    expect(prefs.getString('idle_party_save_v2_corrupt'), '{not-json');
  });

  test('corrupt v2 recovers from valid legacy v1', () async {
    final v1 = await File(
      'test/fixtures/save_v1.json',
    ).readAsString();
    SharedPreferences.setMockInitialValues({
      'idle_party_save_v2': '{not-json',
      'idle_party_save_v1': v1,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesGameStorage(preferences: prefs);

    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.gold, 1450);
    expect(prefs.getString('idle_party_save_v2'), isNull);
    expect(prefs.getString('idle_party_save_v1'), isNotNull);
    expect(prefs.getString('idle_party_save_v2_corrupt'), '{not-json');
  });
}
