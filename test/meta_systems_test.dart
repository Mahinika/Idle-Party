import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/pet.dart';
void main() {
  group('Daily run seeding', () {
    test('dailySeed is stable for the same UTC calendar date', () {
      final a = DateTime.utc(2026, 7, 27, 1, 5);
      final b = DateTime.utc(2026, 7, 27, 23, 55);
      expect(MetaSystems.dailySeed(a), MetaSystems.dailySeed(b));
      expect(MetaSystems.dailyDateKey(a), MetaSystems.dailyDateKey(b));
      expect(MetaSystems.dailyDungeonId(a), MetaSystems.dailyDungeonId(b));
    });

    test('dailySeed differs across different UTC calendar dates', () {
      final day1 = DateTime.utc(2026, 7, 27);
      final day2 = DateTime.utc(2026, 7, 28);
      expect(MetaSystems.dailyDateKey(day1), isNot(MetaSystems.dailyDateKey(day2)));
    });

    test('dailyDungeonId always returns a catalog id', () {
      for (var i = 0; i < 14; i++) {
        final day = DateTime.utc(2026, 1, 1 + i);
        expect(
          DungeonCatalog.all.map((d) => d.id),
          contains(MetaSystems.dailyDungeonId(day)),
        );
      }
    });

    test('enterDaily sets up an in-progress dungeon run and resets claim on a new day', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      state = state.copyWith(lastDailyDate: '2026-07-26', dailyClaimed: true);

      final now = DateTime.utc(2026, 7, 27, 9);
      final result = GameLogic.enterDaily(state, now: now);

      expect(result.inDungeon, isTrue);
      expect(result.dungeonId, MetaSystems.dailyDungeonId(now));
      expect(result.dailyClaimed, isFalse);
      expect(result.lastDailyDate, MetaSystems.dailyDateKey(now));
      expect(MetaSystems.isActiveDailyRun(result, now: now), isTrue);
    });

    test('daily floor clear claims reward and returns to hub', () {
      final now = DateTime.utc(2026, 8, 9, 12);
      var state = GameLogic.createInitialState(now: now);
      state = GameLogic.enterDaily(state, now: now);
      expect(state.inDungeon, isTrue);
      expect(MetaSystems.isActiveDailyRun(state, now: now), isTrue);

      // Simulate a cleared wave: no living foes, then complete room.
      state = state.copyWith(enemies: const []);
      final cleared = GameLogic.completeCurrentRoom(state, goldGain: 0);
      expect(cleared.dailyClaimed, isTrue);
      expect(cleared.inDungeon, isFalse);
      expect(MetaSystems.isActiveDailyRun(cleared, now: now), isFalse);
    });

    test('daily wipe restart keeps seed so claim still works', () {
      final now = DateTime.utc(2026, 8, 9, 12);
      var state = GameLogic.enterDaily(
        GameLogic.createInitialState(now: now),
        now: now,
      );
      final seed = state.layoutSeed;
      state = GameLogic.restartFloor(state);
      expect(state.layoutSeed, seed);
      expect(MetaSystems.isActiveDailyRun(state, now: now), isTrue);

      state = state.copyWith(enemies: const []);
      final cleared = GameLogic.completeCurrentRoom(state, goldGain: 0);
      expect(cleared.dailyClaimed, isTrue);
      expect(cleared.inDungeon, isFalse);
    });
  });

  group('Gear loadouts', () {
    test('save/apply loadout round-trips equipped gear', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      final weapon = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      );
      final heroes = [
        state.heroes.first.copyWith(equipped: {EquipmentSlot.weapon: weapon}),
        ...state.heroes.skip(1),
      ];
      state = state.copyWith(heroes: heroes);

      state = GameLogic.saveLoadout(state, id: '1', name: 'Starter Set');
      expect(state.loadouts, hasLength(1));
      expect(state.loadouts.first.name, 'Starter Set');

      // Unequip, then re-apply the saved loadout and confirm the weapon
      // returns to the same hero's weapon slot.
      final unequippedHero = state.heroes.first.copyWith(equipped: const {});
      state = state.copyWith(
        heroes: [unequippedHero, ...state.heroes.skip(1)],
        gearStash: [...state.gearStash, weapon],
      );

      state = GameLogic.applyLoadout(state, '1').state;
      expect(state.heroes.first.equipped[EquipmentSlot.weapon]?.id, weapon.id);

      state = GameLogic.deleteLoadout(state, '1');
      expect(state.loadouts, isEmpty);
    });
  });

  group('Achievements', () {
    test('evaluateAchievements unlocks and never re-locks', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      expect(state.achievements, isEmpty);

      final beforeEssence = state.essence;
      state = state.copyWith(highestFloorCleared: 1, bossVictories: 1);
      state = MetaSystems.evaluateAchievements(state);
      expect(state.achievements, containsAll(['first_floor', 'first_boss']));
      final expected =
          (AchievementCatalog.byId('first_floor')?.essenceReward ?? 0) +
          (AchievementCatalog.byId('first_boss')?.essenceReward ?? 0);
      expect(state.essence, beforeEssence + expected);

      // Simulate the daily flag flipping back to false later — the
      // achievement itself must persist once unlocked.
      state = state.copyWith(dailyClaimed: true);
      state = MetaSystems.evaluateAchievements(state);
      expect(state.achievements, contains('daily_clear'));
      state = state.copyWith(dailyClaimed: false);
      state = MetaSystems.evaluateAchievements(state);
      expect(state.achievements, contains('daily_clear'));
    });

    test('hardmode achievements require a clear, not dial alone', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25))
          .copyWith(hardmodeLevel: 5);
      state = MetaSystems.evaluateAchievements(state);
      expect(state.achievements.contains('hm_1'), isFalse);

      state = state.copyWith(
        metaDepth: state.metaDepth.copyWith(highestHardmodeCleared: 5),
      );
      state = MetaSystems.evaluateAchievements(state);
      expect(state.achievements, containsAll(['hm_1', 'hm_5']));
      expect(state.achievements.contains('hm_10'), isFalse);
    });
  });

  group('Meta rewards', () {
    test('ascend milestones and challenge clear bonuses', () {
      expect(MetaSystems.ascendMilestoneReward(0, 1), greaterThan(0));
      expect(MetaSystems.ascendMilestoneReward(1, 2), 0);
      expect(MetaSystems.ascendMilestoneReward(2, 3), greaterThan(0));

      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      expect(MetaSystems.challengeClearEssenceBonus(state), 0);
      state = state.copyWith(challengeBossRush: true, challengeNoFlask: true);
      expect(MetaSystems.challengeClearEssenceBonus(state), 4);
      expect(
        MetaSystems.challengeClearEssenceBonus(state, farmLoop: true),
        0,
      );
    });

    test('Loot Sprite grants gold and loot find', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      final lootPet = Pet(
        id: 'loot_sprite_1',
        name: 'Loot Sprite',
        attackBonus: 1,
        level: 2,
        speciesId: 'loot_sprite',
        passive: PetPassive.lootFind,
        passivePerLevel: 2,
      );
      final goldPet = Pet(
        id: 'gold_grub_1',
        name: 'Gold Grub',
        attackBonus: 1,
        level: 2,
        speciesId: 'gold_grub',
        passive: PetPassive.goldFind,
        passivePerLevel: 2,
      );
      state = state.copyWith(activePet: goldPet, ownedPets: [goldPet, lootPet]);
      expect(state.petGoldFindPercent, greaterThan(0));
      state = state.copyWith(activePet: lootPet);
      expect(state.petLootFindPercent, greaterThan(0));
      state = state.copyWith(activePet: goldPet);
      final gained = GameLogic.applyGoldGain(state, 100);
      expect(gained, greaterThan(100));
    });
  });

  group('Save export/import', () {
    test('exportSaveJson produces a string GameLogic can parse back', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      state = state.copyWith(gold: 555, achievements: const ['first_floor']);

      final json = GameLogic.exportSaveJson(state);
      expect(() => jsonDecode(json), returnsNormally);

      final restored = GameLogic.importSaveJson(json);
      expect(restored, isNotNull);
      expect(restored!.gold, 555);
      expect(restored.achievements, contains('first_floor'));
    });

    test('importSaveJson returns null for garbage input', () {
      expect(GameLogic.importSaveJson('not json'), isNull);
      expect(GameLogic.importSaveJson('[1,2,3]'), isNull);
    });
  });

  group('tide and ember dungeons', () {
    test('Sunken Tidehold and Ashen Vault are registered after Crystal Spire', () {
      final crystal = DungeonCatalog.byId('crystal');
      final tide = DungeonCatalog.byId('tide');
      final ember = DungeonCatalog.byId('ember');
      final grove = DungeonCatalog.byId('grove');
      final storm = DungeonCatalog.byId('storm');
      final rime = DungeonCatalog.byId('rime');
      expect(crystal.number, 6);
      expect(tide.number, 7);
      expect(tide.bossName, 'Tide Leviathan');
      expect(ember.number, 8);
      expect(ember.bossName, 'Cinder Sovereign');
      expect(grove.number, 9);
      expect(grove.bossName, 'Wyrd Root');
      expect(storm.number, 10);
      expect(storm.bossName, 'Storm Tyrant');
      expect(rime.number, 11);
      expect(rime.bossName, 'Rime Colossus');
      final fen = DungeonCatalog.byId('fen');
      expect(fen.number, 12);
      expect(fen.bossName, 'Fen Hydra');
      expect(DungeonCatalog.all.length, greaterThanOrEqualTo(13));
      expect(
        DungeonCatalog.isUnlocked('tide', 0, 6),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('ember', 0, 7),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('ember', 0, 6),
        isFalse,
      );
      expect(
        DungeonCatalog.isUnlocked('grove', 0, 8),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('grove', 0, 7),
        isFalse,
      );
      expect(
        DungeonCatalog.isUnlocked('storm', 0, 9),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('storm', 0, 8),
        isFalse,
      );
      expect(
        DungeonCatalog.isUnlocked('rime', 0, 10),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('rime', 0, 9),
        isFalse,
      );
      expect(
        DungeonCatalog.isUnlocked('fen', 0, 11),
        isTrue,
      );
      expect(
        DungeonCatalog.isUnlocked('fen', 0, 10),
        isFalse,
      );
    });
  });

  group('GameState meta fields', () {
    test('new meta fields round-trip through toJson/fromJson with safe defaults', () {
      var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
      state = state.copyWith(
        achievements: const ['first_floor'],
        codexEnemies: const ['Goblin'],
        codexItems: const ['Rusty Sword'],
        challengeBossRush: true,
        challengeNoFlask: true,
        colorblindMode: true,
        uiTextScale: 1.15,
        lastDailyDate: '2026-07-27',
        dailyClaimed: true,
        seenChangelogVersion: '1.0.0',
      );
      state = GameLogic.saveLoadout(state, id: '1', name: 'Loadout A');

      final round = GameLogic.stateFromJson(state.toJson());
      expect(round.achievements, contains('first_floor'));
      expect(round.codexEnemies, contains('Goblin'));
      expect(round.codexItems, contains('Rusty Sword'));
      expect(round.challengeBossRush, isTrue);
      expect(round.challengeNoFlask, isTrue);
      expect(round.colorblindMode, isTrue);
      expect(round.uiTextScale, closeTo(1.15, 0.001));
      expect(round.lastDailyDate, '2026-07-27');
      expect(round.dailyClaimed, isTrue);
      expect(round.seenChangelogVersion, '1.0.0');
      expect(round.loadouts, hasLength(1));
      expect(round.loadouts.first.name, 'Loadout A');
    });

    test('legacy saves without meta fields decode with safe defaults', () {
      final legacy = GameLogic.createInitialState(now: DateTime(2026, 7, 25)).toJson()
        ..remove('achievements')
        ..remove('codexEnemies')
        ..remove('codexItems')
        ..remove('challengeBossRush')
        ..remove('challengeNoFlask')
        ..remove('colorblindMode')
        ..remove('uiTextScale')
        ..remove('lastDailyDate')
        ..remove('dailyClaimed')
        ..remove('seenChangelogVersion')
        ..remove('loadouts');

      final decoded = GameLogic.stateFromJson(legacy);
      expect(decoded.achievements, isEmpty);
      expect(decoded.codexEnemies, isEmpty);
      expect(decoded.codexItems, isEmpty);
      expect(decoded.challengeBossRush, isFalse);
      expect(decoded.challengeNoFlask, isFalse);
      expect(decoded.colorblindMode, isFalse);
      expect(decoded.uiTextScale, 1.0);
      expect(decoded.lastDailyDate, isNull);
      expect(decoded.dailyClaimed, isFalse);
      expect(decoded.seenChangelogVersion, '');
      expect(decoded.loadouts, isEmpty);
    });
  });
}
