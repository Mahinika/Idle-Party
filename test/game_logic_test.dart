import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/mission.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/models/stats.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('xp pools fill and level heroes from kills', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final before = state.heroes.first.level;
    final enemy = state.enemies.first;
    final need = GameLogic.xpPoolForLevel(before);
    state = GameLogic.awardPartyXp(state, need);
    expect(state.heroes.first.level, before + 1);
    expect(state.heroes.first.xp, 0);
    expect(GameLogic.xpProgress(state.heroes.first), 0);
    expect(GameLogic.xpForEnemy(enemy), greaterThan(0));
    final half = GameLogic.xpPoolForLevel(state.heroes.first.level) ~/ 2;
    state = GameLogic.awardPartyXp(state, half);
    expect(GameLogic.xpProgress(state.heroes.first), closeTo(0.5, 0.05));
  });

  test('enemy groups use varied archetypes', () {
    final room = DungeonGenerator.generateFloor(3, layoutSeed: 42).first;
    final group = GameLogic.createEnemyGroup(room, dungeonId: 'sandy');
    expect(group, isNotEmpty);
    final kinds = group.map((e) => e.archetype).toSet();
    expect(kinds, isNotEmpty);
    expect(group.every((e) => e.name.isNotEmpty), isTrue);
  });

  test('class-biased loot favors matching roles', () {
    GameLogic.random = Random(42);
    final mageStaff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.mage,
    );
    final tankShield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.warrior,
    );
    expect(mageStaff.affinity, 'mage');
    expect(tankShield.affinity, 'warrior');
    expect(tankShield.offHandKind, OffHandKind.shield);
    expect(
      mageStaff.weaponType == WeaponType.staff ||
          mageStaff.weaponType == WeaponType.sword ||
          mageStaff.weaponType == WeaponType.dagger,
      isTrue,
    );
    expect(
      mageStaff.intellectBonus + mageStaff.spellPowerBonus,
      greaterThan(0),
    );
    expect(tankShield.resolvedArmor + tankShield.resolvedStamina, greaterThan(0));
    expect(tankShield.intellectBonus + tankShield.spellPowerBonus, 0);
  });

  test('spatial offline progresses battle and gold', () {
    final initial = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
      dungeonId: 'sandy',
    );

    final progressed = GameLogic.simulateSpatialOffline(initial, 3 * 60).state;

    expect(progressed.gold, greaterThan(initial.gold));
    expect(progressed.highestFloorCleared, greaterThanOrEqualTo(1));
  });

  test('offline progress is tracked and applied', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(seconds: 30),
    );

    expect(progressed.state.offlineSecondsRecovered, 30);
    expect(progressed.state.gold, greaterThanOrEqualTo(initial.gold));
  });

  test('hub offline earns gold without boss or floor combat', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 26));
    expect(initial.inDungeon, isFalse);

    final progressed = GameLogic.applyOfflineProgress(
      initial,
      const Duration(hours: 2),
    );

    expect(progressed.state.bossVictories, initial.bossVictories);
    expect(progressed.state.highestFloorCleared, initial.highestFloorCleared);
    expect(progressed.state.inDungeon, isFalse);
    expect(progressed.state.gold, greaterThan(initial.gold));
    expect(progressed.bossDelta, 0);
    expect(progressed.roomsCleared, 0);
  });

  test('offline floor budget scales with time then soft-caps', () {
    expect(GameLogic.offlineFloorBudget(5 * 60), 7); // 300/40
    expect(GameLogic.offlineFloorBudget(30 * 60), 45); // 1800/40
    expect(GameLogic.offlineFloorBudget(60 * 60), greaterThan(45));
    expect(
      GameLogic.offlineFloorBudget(8 * 3600),
      lessThanOrEqualTo(120),
    );
    expect(
      GameLogic.offlineFloorBudget(60 * 60),
      lessThan(GameLogic.offlineFloorBudget(8 * 3600)),
    );
  });

  test('longer dungeon offline earns more gold than short AFK', () {
    final base = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
      dungeonId: 'sandy',
    );
    final farm = GameLogic.setDungeonMode(base, DungeonMode.farm);

    final shortAfk = GameLogic.applyOfflineProgress(
      farm,
      const Duration(minutes: 5),
    );
    final longAfk = GameLogic.applyOfflineProgress(
      farm,
      const Duration(minutes: 30),
    );

    expect(longAfk.state.gold, greaterThan(shortAfk.state.gold));
    expect(
      longAfk.state.offlineSecondsRecovered,
      greaterThan(shortAfk.state.offlineSecondsRecovered),
    );
    expect(longAfk.roomsCleared, greaterThan(shortAfk.roomsCleared));
    expect(longAfk.hasSummary, isTrue);
    expect(longAfk.headline, contains('Away'));
    expect(longAfk.headline, contains('g'));
  });

  test('dungeon offline catch-up clears rooms via SpatialCombat', () {
    final farm = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 1)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );
    final sim = GameLogic.simulateSpatialOffline(farm, 5 * 60);
    expect(sim.roomsCleared, greaterThan(0));
    expect(sim.state.gold, greaterThanOrEqualTo(farm.gold));
  });

  test('offline catch-up auto-uses flask when party HP is critical', () {
    final flask = GameLogic.createMarketFlask(salt: 99);
    var state = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 1)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );
    state = state.copyWith(
      heroes: [
        for (var i = 0; i < state.heroes.length; i++)
          state.heroes[i].copyWith(
            currentHp: max(
              1,
              (state.effectiveHeroMaxHp(state.heroes[i]) * 0.2).floor(),
            ),
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.consumable) e.key: e.value,
              if (i == 0) EquipmentSlot.consumable: flask,
            },
          ),
      ],
      gearStash: [
        for (final g in state.gearStash)
          if (g.slot != EquipmentSlot.consumable) g,
      ],
    );
    expect(GameLogic.canUseConsumable(state), isTrue);
    final sim = GameLogic.simulateSpatialOffline(state, 90);
    expect(GameLogic.canUseConsumable(sim.state), isFalse);
  });

  test('buyMarketFlasks purchases multiple flasks into slots then stash', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes)
          h.copyWith(
            equipped: {
              for (final e in h.equipped.entries)
                if (e.key != EquipmentSlot.consumable) e.key: e.value,
            },
          ),
      ],
      gearStash: [
        for (final g in state.gearStash)
          if (g.slot != EquipmentSlot.consumable) g,
      ],
    );
    final unit = GameLogic.marketFlaskCost(state);
    state = state.copyWith(gold: unit * 5);
    state = GameLogic.buyMarketFlasks(state, count: 3);
    expect(state.gold, unit * 2);
    var flasks = 0;
    for (final h in state.heroes) {
      if (h.itemIn(EquipmentSlot.consumable) != null) flasks++;
    }
    flasks += state.gearStash
        .where((g) => g.slot == EquipmentSlot.consumable)
        .length;
    expect(flasks, 3);
  });

  test('training spends gold and levels up the party', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.partyTrainingCostFor(seeded),
    );

    final trained = GameLogic.trainParty(initial);

    expect(trained.gold, 0);
    expect(trained.heroes.first.level, initial.heroes.first.level + 1);
    expect(
      trained.heroes.first.currentHp,
      trained.effectiveHeroMaxHp(trained.heroes.first),
    );
  });

  test('loot rolls after battle victories', () {
    final initial = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
      dungeonId: 'sandy',
    );

    final progressed = GameLogic.simulateSpatialOffline(initial, 8 * 60).state;

    expect(progressed.gold, greaterThan(initial.gold));
    // Early clears may stash gear, show recent loot, and/or convert junk to essence.
    expect(
      progressed.recentLoot.isNotEmpty ||
          progressed.essence > 0 ||
          progressed.gearStash.isNotEmpty,
      isTrue,
    );
  });

  test('forge gold spend modes dump a wallet percent into one track', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 8, 21));
    final state = seeded.copyWith(gold: 1000);
    final preview = GameLogic.previewForgeGoldSpend(
      state,
      PartyUpgradeType.attack,
      ForgeGoldSpendMode.pct25,
    );
    expect(preview.buys, greaterThan(1));
    expect(preview.spent, lessThanOrEqualTo(250));

    final spent = GameLogic.upgradeWithSpendMode(
      state,
      type: PartyUpgradeType.attack,
      mode: ForgeGoldSpendMode.pct25,
    );
    expect(spent.attackBonus, GameLogic.forgeAttackGain * preview.buys);
    expect(spent.gold, state.gold - preview.spent);
    expect(state.gold - spent.gold, lessThanOrEqualTo(250));
  });

  test('forge gold spend all evenly round-robins tracks', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 8, 21));
    final state = seeded.copyWith(gold: 500);
    final next = GameLogic.upgradeSpendAllEvenly(state);
    expect(next.gold, lessThan(state.gold));
    final tiers = [
      for (final type in PartyUpgradeType.values)
        GameLogic.forgeTrackTier(next, type),
    ];
    expect(tiers.reduce(max) - tiers.reduce(min), lessThanOrEqualTo(1));
    expect(GameLogic.canForgeGoldSpendEven(next), isFalse);
  });

  test('upgrade paths spend gold and change bonuses', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final initial = seeded.copyWith(
      gold: GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack),
    );

    final attackUpgraded = GameLogic.upgradeAttack(initial);
    final defenseUpgraded = GameLogic.upgradeDefense(initial);
    final vitalityUpgraded = GameLogic.upgradeVitality(initial);

    expect(attackUpgraded.attackBonus, GameLogic.forgeAttackGain);
    expect(defenseUpgraded.defenseBonus, GameLogic.forgeDefenseGain);
    expect(vitalityUpgraded.vitalityBonus, GameLogic.forgeVitalityGain);
    expect(attackUpgraded.gold, 0);
  });

  test('forge gold buys share one cost tier', () {
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 8, 17));
    for (final type in PartyUpgradeType.values) {
      expect(GameLogic.forgeTrackTier(seeded, type), 0);
      expect(
        GameLogic.upgradeCostFor(seeded, type),
        GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack),
      );
    }
    final gold = GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack);
    var state = seeded.copyWith(gold: gold * PartyUpgradeType.values.length);
    for (final type in PartyUpgradeType.values) {
      state = switch (type) {
        PartyUpgradeType.attack => GameLogic.upgradeAttack(state),
        PartyUpgradeType.defense => GameLogic.upgradeDefense(state),
        PartyUpgradeType.vitality => GameLogic.upgradeVitality(state),
        PartyUpgradeType.moveSpeed => GameLogic.upgradeMoveSpeed(state),
        PartyUpgradeType.attackSpeed => GameLogic.upgradeAttackSpeed(state),
        PartyUpgradeType.crit => GameLogic.upgradeCrit(state),
      };
    }
    for (final type in PartyUpgradeType.values) {
      expect(GameLogic.forgeTrackTier(state, type), 1);
    }
  });

  test('KEEP relics AL and Blessing STA match ATK after percent armor', () {
    expect(GameLogic.forgeDefenseGain, GameLogic.forgeAttackGain * 4);
    expect(GameLogic.forgeVitalityGain, GameLogic.forgeAttackGain * 12);
    expect(GameLogic.relicDefensePerTier, GameLogic.relicAttackPerTier * 4);
    expect(GameLogic.relicVitalityPerTier, GameLogic.relicAttackPerTier * 12);
    expect(GameLogic.alDefensePerLevel, GameLogic.alAttackPerLevel * 4);
    expect(GameLogic.alVitalityPerLevel, GameLogic.alAttackPerLevel * 12);
    expect(GameLogic.ascendBlessingDef, GameLogic.ascendBlessingAtk * 4);
    expect(GameLogic.ascendBlessingVit, GameLogic.ascendBlessingAtk * 12);

    final seeded = GameLogic.createInitialState(now: DateTime(2026, 8, 17));
    var state = seeded.copyWith(essence: 200);
    state = GameLogic.unlockRelic(state, GameLogic.ironWardRelic);
    expect(state.relicDefenseBonus, GameLogic.relicDefensePerTier);
    state = GameLogic.unlockRelic(state, GameLogic.phoenixEmberRelic);
    expect(state.relicVitalityBonus, GameLogic.relicVitalityPerTier);
    state = state.copyWith(ascensionLevel: 1);
    expect(state.ascensionDefenseBonus, GameLogic.alDefensePerLevel);
    expect(state.ascensionVitalityBonus, GameLogic.alVitalityPerLevel);
  });

  test('forge haste tracks are infinite and scale combat speed', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 3));
    final hero = state.heroes.first;
    final baseMove = state.effectiveHeroMoveSpeed(hero);
    final baseAtkSpd = state.effectiveHeroAttackSpeed(hero);
    final baseCrit = state.effectiveHeroCrit(hero);

    for (var i = 0; i < 12; i++) {
      final cost = GameLogic.upgradeCostFor(state, PartyUpgradeType.moveSpeed) +
          GameLogic.upgradeCostFor(state, PartyUpgradeType.attackSpeed) +
          GameLogic.upgradeCostFor(state, PartyUpgradeType.crit);
      state = state.copyWith(gold: cost);
      state = GameLogic.upgradeMoveSpeed(state);
      state = GameLogic.upgradeAttackSpeed(state);
      state = GameLogic.upgradeCrit(state);
    }

    expect(state.moveSpeedBonus, 24);
    expect(state.attackSpeedBonus, 24);
    expect(state.critBonus, 24);
    expect(state.effectiveHeroMoveSpeed(hero), greaterThan(baseMove));
    expect(state.effectiveHeroAttackSpeed(hero), greaterThan(baseAtkSpd));
    expect(state.effectiveHeroCrit(hero), greaterThan(baseCrit));
    // Soft-cap keeps absurd stacks from exploding.
    expect(GameState.softForgePercent(100), lessThan(100));
  });

  test('ascend clears forge haste tracks with ATK/DEF/VIT', () {
    final ready = GameLogic.createInitialState(now: DateTime(2026, 8, 3))
        .copyWith(
          bossVictories: 1,
          attackBonus: 4,
          moveSpeedBonus: 10,
          attackSpeedBonus: 8,
          critBonus: 5,
        );
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 8, 4));
    expect(ascended.attackBonus, 0);
    expect(ascended.moveSpeedBonus, 0);
    expect(ascended.attackSpeedBonus, 0);
    expect(ascended.critBonus, 0);
  });

  test('recommendedDungeonId prefers frontier; ascend updates dungeonId', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 8, 3));
    expect(GameLogic.recommendedDungeonId(initial), 'sandy');

    final mid = initial.copyWith(highestDungeonCleared: 0);
    expect(GameLogic.recommendedDungeonId(mid), 'goblin');

    final crystalClear = initial.copyWith(highestDungeonCleared: 6);
    expect(GameLogic.recommendedDungeonId(crystalClear), 'tide');

    final groveFrontier = initial.copyWith(highestDungeonCleared: 8);
    expect(GameLogic.recommendedDungeonId(groveFrontier), 'grove');

    final stormFrontier = initial.copyWith(highestDungeonCleared: 9);
    expect(GameLogic.recommendedDungeonId(stormFrontier), 'storm');

    final rimeFrontier = initial.copyWith(highestDungeonCleared: 10);
    expect(GameLogic.recommendedDungeonId(rimeFrontier), 'rime');

    final fenFrontier = initial.copyWith(highestDungeonCleared: 11);
    expect(GameLogic.recommendedDungeonId(fenFrontier), 'fen');

    final brassFrontier = initial.copyWith(highestDungeonCleared: 12);
    expect(GameLogic.recommendedDungeonId(brassFrontier), 'brass');

    final veilFrontier = initial.copyWith(highestDungeonCleared: 13);
    expect(GameLogic.recommendedDungeonId(veilFrontier), 'veil');

    final allClear = initial.copyWith(highestDungeonCleared: 14);
    expect(GameLogic.recommendedDungeonId(allClear), 'veil');

    final ready = mid.copyWith(bossVictories: 1);
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 8, 4));
    expect(ascended.dungeonId, 'goblin');
  });

  test('boss floor clear increases boss victory count', () {
    final bossFloor = DungeonGenerator.bossFloorFor(0);
    final floor = DungeonGenerator.generateFloor(bossFloor, ascensionLevel: 0);
    final bossRoom = floor.first;
    expect(bossRoom.type, RoomType.boss);

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          inDungeon: true,
          currentRoom: bossRoom,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(bossRoom)
              .map((enemy) => enemy.copyWith(currentHp: 1))
              .toList(),
        );

    final progressed = GameLogic.completeCurrentRoom(
      initial,
      goldGain: 50,
      skipLootRoll: true,
    );

    expect(progressed.bossVictories, greaterThan(0));
    expect(progressed.inDungeon, isFalse); // push boss clear → hub
    expect(progressed.highestFloorCleared, bossFloor);
    expect(progressed.highestDungeonCleared, greaterThanOrEqualTo(0));
  });

  test('enemy scaling increases with floor number', () {
    final f1 = DungeonGenerator.generateFloor(1).first;
    final f5 = DungeonGenerator.generateFloor(5, ascensionLevel: 0).first;
    final f6 = DungeonGenerator.generateFloor(6).first;

    final b1 = GameLogic.roomCombatBudget(f1);
    final b5 = GameLogic.roomCombatBudget(f5);
    final b6 = GameLogic.roomCombatBudget(f6);

    expect(f5.type, RoomType.boss);
    expect(b5.hp, greaterThan(b1.hp));
    expect(b6.hp, lessThan(b5.hp)); // normal floor after boss is softer than boss
  });

  test('treasure gold scales with zone HM and AL', () {
    final room = DungeonGenerator.generateFloor(6).first;
    expect(room.type, RoomType.treasure);
    final base = GameLogic.roomCombatBudget(room, dungeonId: 'sandy');
    final hell = GameLogic.roomCombatBudget(room, dungeonId: 'hell');
    final hm = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'sandy',
      hardmodeLevel: 5,
    );
    final al = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'sandy',
      ascensionLevel: 8,
    );
    expect(hell.gold, greaterThan(base.gold));
    expect(hm.gold, greaterThan(base.gold));
    expect(al.gold, greaterThan(base.gold));
  });

  test('creditCombatGold banks kill gold immediately', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final next = GameLogic.creditCombatGold(state, 40);
    expect(next.gold, greaterThan(state.gold));
    expect(next.lifetimeGoldEarned, greaterThan(state.lifetimeGoldEarned));
  });

  test('essence can unlock relic bonuses', () {
    final initial = GameLogic.createInitialState(
      now: DateTime(2026, 7, 4),
    ).copyWith(essence: GameLogic.relicCosts[GameLogic.warBannerRelic]);

    final unlocked = GameLogic.unlockRelic(initial, GameLogic.warBannerRelic);

    expect(unlocked.hasRelic(GameLogic.warBannerRelic), isTrue);
    expect(unlocked.essence, 0);
    expect(unlocked.totalAttackBonus, 4);
    expect(GameLogic.relicKeepSummary(unlocked), contains('+4 ATK'));
    expect(GameLogic.relicPerTierPayout(GameLogic.warBannerRelic), '+4 ATK');
  });

  test('ascension is locked until required bosses are cleared', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));

    expect(GameLogic.canAscend(initial), isFalse);
    expect(identical(GameLogic.ascend(initial), initial), isTrue);

    final ready = initial.copyWith(bossVictories: 1);
    expect(GameLogic.canAscend(ready), isTrue);
  });

  test('ascend resets run and keeps meta progress', () {
    final weapon = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 10,
    );
    final ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          gold: 500,
          essence: 12,
          bossVictories: 1,
          attackBonus: 4,
          unlockedRelics: <String>[GameLogic.warBannerRelic],
          equipped: <EquipmentSlot, EquipmentItem>{
            EquipmentSlot.weapon: weapon,
          },
          highestFloorCleared: 3,
        );

    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));

    expect(ascended.ascensionLevel, 1);
    expect(ascended.gold, 0);
    expect(ascended.bossVictories, 0);
    expect(ascended.attackBonus, 0);
    expect(ascended.battleNumber, 1);
    expect(ascended.equipped, isEmpty);
    expect(ascended.unlockedRelics, contains(GameLogic.warBannerRelic));
    expect(
      ascended.essence,
      12 +
          GameLogic.ascendEssenceReward(1) +
          MetaSystems.ascendMilestoneReward(0, 1) +
          (AchievementCatalog.byId('first_ascend')?.essenceReward ?? 0) +
          (AchievementCatalog.byId('full_party')?.essenceReward ?? 0),
    );
    expect(ascended.achievements, contains('first_ascend'));
    expect(ascended.metaDepth.ascendBlessings, 1);
    expect(
      ascended.totalAttackBonus,
      1 + 4 + GameLogic.ascendBlessingAtk,
    ); // AL + war banner + Blessing
    expect(ascended.ascensionGoldBonusPercent, 10);
    expect(
      ascended.ascendBlessingGoldPercent,
      GameLogic.ascendBlessingGoldPct,
    );
    expect(ascended.soulboundFragments, 0);
    expect(ascended.inDungeon, isFalse);
  });

  test('ascend Blessing stacks ATK DEF VIT and gold', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(bossVictories: 1);
    state = GameLogic.ascend(state, now: DateTime(2026, 7, 5));
    expect(state.metaDepth.ascendBlessings, 1);
    expect(state.ascendBlessingAttackBonus, GameLogic.ascendBlessingAtk);
    expect(state.ascendBlessingDefenseBonus, GameLogic.ascendBlessingDef);
    expect(state.ascendBlessingVitalityBonus, GameLogic.ascendBlessingVit);
    expect(state.ascendBlessingGoldPercent, GameLogic.ascendBlessingGoldPct);

    state = state.copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(state.ascensionLevel),
    );
    state = GameLogic.ascend(state, now: DateTime(2026, 7, 6));
    expect(state.metaDepth.ascendBlessings, 2);
    expect(state.ascendBlessingAttackBonus, GameLogic.ascendBlessingAtk * 2);
    expect(state.ascendBlessingDefenseBonus, GameLogic.ascendBlessingDef * 2);
    expect(state.ascendBlessingVitalityBonus, GameLogic.ascendBlessingVit * 2);
    expect(state.ascendBlessingGoldPercent, GameLogic.ascendBlessingGoldPct * 2);

    final withBlessing = GameLogic.applyGoldGain(state, 100);
    final withoutBlessing = GameLogic.applyGoldGain(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(ascendBlessings: 0),
      ),
      100,
    );
    expect(withBlessing, greaterThan(withoutBlessing));
  });

  test('ascendBlessings defaults to 0 on old saves', () {
    final depth = MetaDepthState.fromJson(<String, dynamic>{});
    expect(depth.ascendBlessings, 0);
  });

  test('ascend keeps hero levels and meta, clears run loadouts', () {
    final pet = const Pet(id: 'p_meta', name: 'Cub', attackBonus: 1);
    var ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      bossVictories: 1,
      essence: 20,
      lifetimeGoldEarned: 12000,
      highestDungeonCleared: 1,
      godHandLevel: 3,
      soulboundFragments: 5,
      sanctuaryPowerLevel: 2,
      ownedPets: <Pet>[pet],
      activePet: pet,
      heroes: GameLogic.createInitialState(now: DateTime(2026, 7, 4))
          .heroes
          .map((h) => h.copyWith(level: 12, xp: 40))
          .toList(),
    );
    ready = GameLogic.saveLoadout(ready, id: 'bis', name: 'BIS');
    expect(ready.loadouts, hasLength(1));

    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.lifetimeGoldEarned, 12000);
    expect(ascended.highestDungeonCleared, 1);
    expect(ascended.godHandLevel, 3);
    expect(ascended.soulboundFragments, 5);
    expect(ascended.sanctuaryPowerLevel, 2);
    expect(ascended.activePet?.id, pet.id);
    expect(ascended.loadouts, isEmpty);
    expect(ascended.gearStash, isEmpty);
    final kept = ascended.heroRoster.where(
      (h) => ready.heroRoster.any((r) => r.id == h.id),
    );
    expect(kept, isNotEmpty);
    expect(kept.every((h) => h.level == 12 && h.xp == 40), isTrue);
  });

  test('ascend keeps legacy heirloom and does not grant fragments', () {
    final heirloom = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 10,
    ).copyWith(id: 'soulbound_old', name: 'Soulbound Old');
    var ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      bossVictories: 1,
      highestFloorCleared: 12,
      soulboundFragments: 4,
      soulboundItem: heirloom,
    );
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.soulboundFragments, 4);
    expect(ascended.soulboundItem, isNotNull);
    expect(ascended.soulboundItem!.id, 'soulbound_old');
    expect(ascended.soulboundAttackBonus, greaterThan(0));
  });

  test('ascension gold bonus applies to room rewards', () {
    expect(GameLogic.applyGoldGain(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4))
          .copyWith(ascensionLevel: 2),
      100,
    ), 120);
  });

  test('loot always stashes gear for manual equip', () {
    final weak = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      battleNumber: 1,
    );
    final strong = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.epic,
      battleNumber: 12,
    );

    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(autoSellMaxPower: 0, autoDisassembleMaxIlvl: 0);
    final afterWeak = GameLogic.applyLootDrops(initial, [
      LootDrop(
        name: weak.name,
        amount: 1,
        rarity: weak.rarity,
        equipment: weak,
      ),
    ]);
    expect(afterWeak.state.equipped, isEmpty);
    expect(afterWeak.state.gearStash.map((item) => item.id), contains(weak.id));
    expect(afterWeak.resolved.first.outcome, LootOutcome.stashed);

    final afterStrong = GameLogic.applyLootDrops(afterWeak.state, [
      LootDrop(
        name: strong.name,
        amount: 1,
        rarity: strong.rarity,
        equipment: strong,
      ),
    ]);
    expect(afterStrong.state.equipped, isEmpty);
    expect(
      afterStrong.state.gearStash.map((item) => item.id),
      containsAll(<String>[weak.id, strong.id]),
    );
  });

  test('combinator ignores equipped gear and only merges bag pieces', () {
    final primary = EquipmentItem(
      id: 'w1',
      name: 'Iron Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 4,
      defenseBonus: 0,
      vitalityBonus: 0,
    );
    final secondary = EquipmentItem(
      id: 'w2',
      name: 'Rusty Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 2,
      defenseBonus: 0,
      vitalityBonus: 0,
    );
    final cost = GameLogic.combineCost(primary, secondary);
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          gold: cost,
          gearStash: <EquipmentItem>[secondary],
        );
    final hero0 = state.heroes.first.copyWith(
      equipped: <EquipmentSlot, EquipmentItem>{
        EquipmentSlot.weapon: primary,
      },
    );
    state = state.copyWith(
      heroes: [hero0, ...state.heroes.skip(1)],
    );

    final blocked = GameLogic.combineGear(
      state,
      primaryId: primary.id,
      secondaryId: secondary.id,
    );
    expect(blocked.gold, cost);
    expect(blocked.heroes.first.itemIn(EquipmentSlot.weapon)?.id, primary.id);
    expect(blocked.gearStash.map((g) => g.id), contains(secondary.id));

    // Both in bag → merge succeeds; result lands in stash.
    state = state.copyWith(
      heroes: [
        hero0.copyWith(equipped: const <EquipmentSlot, EquipmentItem>{}),
        ...state.heroes.skip(1),
      ],
      gearStash: <EquipmentItem>[primary, secondary],
    );
    final combined = GameLogic.combineGear(
      state,
      primaryId: primary.id,
      secondaryId: secondary.id,
    );

    expect(combined.gold, 0);
    expect(combined.heroes.first.itemIn(EquipmentSlot.weapon), isNull);
    expect(combined.gearStash, hasLength(1));
    expect(combined.gearStash.first.id, isNot(primary.id));
    expect(combined.gearStash.first.rarity, LootRarity.uncommon);
    expect(
      combined.gearStash.first.attackBonus +
          combined.gearStash.first.strengthBonus,
      greaterThanOrEqualTo(5),
    );
    expect(combined.gearStash.first.slot, EquipmentSlot.weapon);
  });

  test('auto equip prefers class-relevant upgrades', () {
    GameLogic.random = Random(42);
    EquipmentFactory.random = GameLogic.random;
    final tankShield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      attackBonus: 0,
      defenseBonus: 12,
      vitalityBonus: 6,
      armorBonus: 12,
      staminaBonus: 6,
      strengthBonus: 4,
      effectId: GearEffectId.none,
      effectValue: 0,
      affinity: HeroRole.warrior.name,
      offHandKind: OffHandKind.shield,
    );
    final mageStaff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.mage,
    ).copyWith(
      attackBonus: 14,
      defenseBonus: 0,
      vitalityBonus: 1,
      intellectBonus: 14,
      spiritBonus: 0,
      spellPowerBonus: 10,
      attackSpeedBonus: 8,
      critChanceBonus: 0,
      effectId: GearEffectId.none,
      effectValue: 0,
      affinity: HeroRole.mage.name,
      weaponType: WeaponType.staff,
      handed: WeaponHanded.twoHand,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final prot = state.heroes.firstWhere((h) => h.role == HeroRole.warrior);
    final fire = state.heroes.firstWhere((h) => h.role == HeroRole.mage);
    // Budget honesty: shield is a tank piece; Int/SP staff is a caster piece.
    expect(
      GameLogic.specEquipScore(prot, tankShield),
      greaterThan(GameLogic.specEquipScore(fire, tankShield)),
    );
    expect(
      GameLogic.specEquipScore(fire, mageStaff),
      greaterThan(GameLogic.specEquipScore(prot, mageStaff)),
    );

    // Auto Equip: tank-only empty party takes the shield from stash.
    state = state
        .withActiveParty([prot.copyWith(level: 20, clearEquipped: true)])
        .copyWith(gearStash: <EquipmentItem>[tankShield]);
    state = GameLogic.autoEquipBetterGear(state);
    expect(
      state.heroes.single.itemIn(EquipmentSlot.offHand)?.id,
      tankShield.id,
    );

    // Fire-only empty party takes the Int/SP staff.
    state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final mage = state.heroes.firstWhere((h) => h.role == HeroRole.mage);
    state = state
        .withActiveParty([mage.copyWith(level: 20, clearEquipped: true)])
        .copyWith(gearStash: <EquipmentItem>[mageStaff]);
    state = GameLogic.autoEquipBetterGear(state);
    expect(
      state.heroes.single.itemIn(EquipmentSlot.weapon)?.id,
      mageStaff.id,
    );
  });

  test('auto equip skips wrong-role junk on empty slots', () {
    final junkStaff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      battleNumber: 2,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'junk_int_staff',
      attackBonus: 0,
      intellectBonus: 3,
      spellPowerBonus: 2,
      spiritBonus: 2,
      affinity: HeroRole.mage.name,
      weaponType: WeaponType.staff,
      handed: WeaponHanded.twoHand,
      effectId: GearEffectId.none,
      effectValue: 0,
      itemLevel: 4,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Only Prot has an empty weapon; lock others so they cannot claim.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.weapon &&
                    e.key != EquipmentSlot.offHand)
                  e.key: e.value,
            },
          )
        else
          state.heroes[i],
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[junkStaff],
    );
    state = GameLogic.autoEquipBetterGear(state);

    expect(state.heroes[0].itemIn(EquipmentSlot.weapon), isNull);
    expect(state.gearStash.map((e) => e.id), contains(junkStaff.id));
  });

  test('auto equip skips low-ilvl affinity crumbs on empty slots', () {
    final crumb = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'crumb_cloak',
      attackBonus: 0,
      defenseBonus: 0,
      vitalityBonus: 0,
      strengthBonus: 1,
      agilityBonus: 0,
      staminaBonus: 1,
      intellectBonus: 0,
      spiritBonus: 0,
      spellPowerBonus: 0,
      armorBonus: 0,
      mp5Bonus: 0,
      critChanceBonus: 0,
      attackSpeedBonus: 0,
      moveSpeedBonus: 0,
      affinity: HeroRole.warrior.name,
      itemLevel: 5,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: false,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // L20+ party with empty cloaks — affinity alone must not fill with i5 junk.
    final heroes = [
      for (final h in state.heroes)
        h.copyWith(
          level: 22,
          equipped: {
            for (final e in h.equipped.entries)
              if (e.key != EquipmentSlot.cloak) e.key: e.value,
          },
        ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[crumb],
    );
    expect(
      GameLogic.emptySlotWorthFilling(
        state.heroes.first,
        crumb,
        GameLogic.specEquipScore(state.heroes.first, crumb),
      ),
      isFalse,
    );
    state = GameLogic.autoEquipBetterGear(state);
    expect(
      state.heroes.any((h) => h.itemIn(EquipmentSlot.cloak)?.id == crumb.id),
      isFalse,
    );
    expect(state.gearStash.map((e) => e.id), contains(crumb.id));
  });

  test('auto equip ignores tiny worn-slot sidegrades', () {
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'worn_cloak',
      strengthBonus: 12,
      staminaBonus: 10,
      armorBonus: 14,
      affinity: HeroRole.warrior.name,
      itemLevel: 24,
      effectId: GearEffectId.none,
      effectValue: 0,
    );
    final side = worn.copyWith(
      id: 'side_cloak',
      // Same combat stats — only a soft ilvl crumb (+1 score).
      itemLevel: 28,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.cloak) e.key: e.value,
              EquipmentSlot.cloak: worn,
            },
          )
        else
          state.heroes[i].copyWith(
            equipped: {
              ...state.heroes[i].equipped,
              EquipmentSlot.cloak: worn.copyWith(id: 'lock_cloak_$i'),
            },
          ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[side],
    );
    final before = state.heroes[0].itemIn(EquipmentSlot.cloak)!.id;
    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.cloak)?.id, before);
    expect(state.gearStash.map((e) => e.id), contains(side.id));
  });

  test('auto sell junk sells non-upgrades within iLvl and rarity filters', () {
    final weak = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 1,
    ).copyWith(
      attackBonus: 0,
      defenseBonus: 1,
      vitalityBonus: 1,
      itemLevel: 40,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final strongCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 8,
        ).copyWith(
          id: 'cloak_strong_$i',
          attackBonus: 2,
          defenseBonus: 8,
          vitalityBonus: 10,
          itemLevel: 28,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[...strongCloaks, weak],
      autoSellMaxPower: 40,
      autoSellMaxRarity: LootRarity.uncommon.index,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        strongCloaks[i].id,
        heroIndex: i,
      );
    }
    state = state.copyWith(gearStash: <EquipmentItem>[weak]);

    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash, isEmpty);
    expect(sold.gold, greaterThan(state.gold));
  });

  test('sellGear scraps stash only and refuses equipped pieces', () {
    final piece = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 6,
    ).copyWith(id: 'sell_cloak');
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 9)).copyWith(
      gearStash: <EquipmentItem>[piece],
      essence: 0,
    );
    state = GameLogic.equipFromStash(state, piece.id, heroIndex: 0);
    expect(state.heroes[0].itemIn(EquipmentSlot.cloak)?.id, piece.id);

    final blocked = GameLogic.sellGear(state, piece.id);
    expect(blocked.heroes[0].itemIn(EquipmentSlot.cloak)?.id, piece.id);
    expect(blocked.essence, 0);

    state = GameLogic.unequipSlot(state, EquipmentSlot.cloak, heroIndex: 0);
    expect(state.gearStash.any((g) => g.id == piece.id), isTrue);
    final scrapped = GameLogic.sellGear(state, piece.id);
    expect(scrapped.gearStash.any((g) => g.id == piece.id), isFalse);
    expect(scrapped.essence, greaterThan(0));
  });

  test('auto merge junk combines same-slot trash pairs', () {
    GameLogic.random = Random(7);
    EquipmentFactory.random = GameLogic.random;

    EquipmentItem junkCloak(String id, int vit) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.cloak,
        rarity: LootRarity.common,
        battleNumber: 1,
      ).copyWith(
        id: id,
        attackBonus: 0,
        defenseBonus: 1,
        vitalityBonus: vit,
        itemLevel: 1,
        effectId: GearEffectId.none,
        effectValue: 0,
        clearAffinity: true,
      );
    }

    final strongCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 8,
        ).copyWith(
          id: 'cloak_keep_$i',
          attackBonus: 2,
          defenseBonus: 8,
          vitalityBonus: 10,
          itemLevel: 28,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    final junkA = junkCloak('cloak_junk_a', 1);
    final junkB = junkCloak('cloak_junk_b', 1);
    final cost = GameLogic.combineCost(junkA, junkB);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gold: cost * 2,
      gearStash: <EquipmentItem>[...strongCloaks, junkA, junkB],
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        strongCloaks[i].id,
        heroIndex: i,
      );
    }
    state = state.copyWith(gearStash: <EquipmentItem>[junkA, junkB]);

    final result = GameLogic.autoMergeJunk(state);
    expect(result.merges, 1);
    expect(result.state.gearStash, hasLength(1));
    expect(result.state.gold, lessThan(state.gold));
    expect(
      result.state.gearStash.first.id,
      isNot(anyOf(junkA.id, junkB.id)),
    );
  });

  test('auto equip fills ring2 when ring1 is already better', () {
    EquipmentItem ring({
      required String id,
      required int str,
      required int sta,
      required LootRarity rarity,
      required int ilvl,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.ring,
        rarity: rarity,
        battleNumber: 1,
      ).copyWith(
        id: id,
        strengthBonus: str,
        agilityBonus: 0,
        staminaBonus: sta,
        intellectBonus: 0,
        spiritBonus: 0,
        spellPowerBonus: 0,
        armorBonus: 0,
        mp5Bonus: 0,
        attackBonus: 0,
        defenseBonus: 0,
        vitalityBonus: 0,
        critChanceBonus: 0,
        attackSpeedBonus: 0,
        moveSpeedBonus: 0,
        itemLevel: ilvl,
        effectId: GearEffectId.none,
        effectValue: 0,
        affinity: HeroRole.warrior.name,
      );
    }

    final ringA = ring(
      id: 'ring_a',
      str: 8,
      sta: 6,
      rarity: LootRarity.rare,
      ilvl: 20,
    );
    final ringB = ring(
      id: 'ring_b',
      str: 4,
      sta: 3,
      rarity: LootRarity.uncommon,
      ilvl: 12,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Only the warrior has open ring2 room relative to ringB.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i]
        else
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
              EquipmentSlot.ring: ring(
                id: 'locked_r1_$i',
                str: 20,
                sta: 20,
                rarity: LootRarity.epic,
                ilvl: 40,
              ),
              EquipmentSlot.ring2: ring(
                id: 'locked_r2_$i',
                str: 20,
                sta: 20,
                rarity: LootRarity.epic,
                ilvl: 40,
              ),
            },
          ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[ringA, ringB],
    );
    state = GameLogic.equipFromStash(state, ringA.id, heroIndex: 0);
    expect(state.heroes[0].itemIn(EquipmentSlot.ring)?.id, ringA.id);

    // Clear ring2 so ringB is clearly the empty-slot upgrade.
    final w = state.heroes[0];
    final wGear = Map<EquipmentSlot, EquipmentItem>.from(w.equipped)
      ..remove(EquipmentSlot.ring2);
    state = state.copyWith(
      heroes: [
        w.copyWith(equipped: wGear),
        ...state.heroes.skip(1),
      ],
      gearStash: <EquipmentItem>[ringB],
    );

    state = GameLogic.autoEquipBetterGear(state);

    expect(state.heroes[0].itemIn(EquipmentSlot.ring)?.id, ringA.id);
    expect(state.heroes[0].itemIn(EquipmentSlot.ring2)?.id, ringB.id);
    expect(state.gearStash, isEmpty);
  });

  test('auto equip does not swap worn gear for lower iLvl affinity crumb', () {
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'worn_high_ilvl',
      armorType: ArmorType.mail,
      strengthBonus: 14,
      staminaBonus: 12,
      armorBonus: 18,
      itemLevel: 40,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
    );
    // Lower iLvl, affinity-tagged, slightly weaker stats — used to win on
    // affinity (+24) while iLvl only counted ~/4.
    final lower = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'bag_lower_ilvl',
      armorType: ArmorType.mail,
      strengthBonus: 13,
      staminaBonus: 11,
      armorBonus: 16,
      itemLevel: 28,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(
      level: 20,
      equipped: {
        ...heroes[0].equipped,
        EquipmentSlot.chest: worn,
      },
    );
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[lower],
    );

    final cmp = GameLogic.compareForHero(state.heroes[0], lower);
    expect(cmp.isUpgrade, isFalse);
    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.chest)?.id, worn.id);
    expect(state.gearStash.any((g) => g.id == lower.id), isTrue);
  });

  test('same-ilvl affinity alone is not a meaningful upgrade', () {
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 12,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'worn_plain',
      armorType: ArmorType.plate,
      strengthBonus: 14,
      staminaBonus: 12,
      armorBonus: 18,
      itemLevel: 32,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final tagged = worn.copyWith(
      id: 'bag_tagged',
      affinity: 'warrior',
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(
      level: 20,
      equipped: {
        ...heroes[0].equipped,
        EquipmentSlot.chest: worn,
      },
    );
    state = state.copyWith(heroes: heroes, gearStash: <EquipmentItem>[tagged]);

    final cmp = GameLogic.compareForHero(state.heroes[0], tagged);
    expect(cmp.powerDelta, 0);
    expect(cmp.isUpgrade, isFalse);
    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.chest)?.id, worn.id);
  });

  test('atkDelta includes intellect for casters', () {
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'worn_low_int',
      armorType: ArmorType.cloth,
      intellectBonus: 4,
      spellPowerBonus: 2,
      staminaBonus: 6,
      itemLevel: 24,
      clearAffinity: true,
    );
    final better = worn.copyWith(
      id: 'bag_high_int',
      intellectBonus: 18,
      spellPowerBonus: 10,
      staminaBonus: 8,
      itemLevel: 28,
      affinity: 'mage',
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final mageIndex =
        state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.mage);
    expect(mageIndex, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[mageIndex] = heroes[mageIndex].copyWith(
      level: 20,
      equipped: {
        ...heroes[mageIndex].equipped,
        EquipmentSlot.chest: worn,
      },
    );
    state = state.copyWith(heroes: heroes);

    final cmp = GameLogic.compareForHero(state.heroes[mageIndex], better);
    expect(cmp.atkDelta, greaterThan(0));
    final wornAtk = state.heroes[mageIndex].gearSheetAttack;
    final swapped = state.heroes[mageIndex].copyWith(
      equipped: {
        ...state.heroes[mageIndex].equipped,
        EquipmentSlot.chest: better,
      },
    );
    expect(cmp.atkDelta, swapped.gearSheetAttack - wornAtk);
  });

  test('1H plus stash OH can beat worn two-hand on upgrade score', () {
    final twoHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 10,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'worn_2h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.twoHand,
      strengthBonus: 16,
      staminaBonus: 8,
      itemLevel: 30,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
    );
    final oneHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 9,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'bag_1h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.oneHand,
      strengthBonus: 12,
      staminaBonus: 6,
      itemLevel: 28,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
    );
    final shield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 9,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'bag_shield',
      offHandKind: OffHandKind.shield,
      strengthBonus: 6,
      staminaBonus: 14,
      armorBonus: 40,
      itemLevel: 28,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final w = state.heroes.indexWhere(
      (h) => h.spec.roleTag == SpecRoleTag.tank || h.gearAffinity == HeroRole.warrior,
    );
    expect(w, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    heroes[w] = heroes[w].copyWith(
      level: 24,
      equipped: {
        ...heroes[w].equipped,
        EquipmentSlot.weapon: twoHand,
      },
      clearEquipped: false,
    );
    // Ensure no leftover OH under a 2H.
    final eq = Map<EquipmentSlot, EquipmentItem>.from(heroes[w].equipped)
      ..remove(EquipmentSlot.offHand)
      ..[EquipmentSlot.weapon] = twoHand;
    heroes[w] = heroes[w].copyWith(equipped: eq);
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[oneHand, shield],
    );

    final withoutPair = GameLogic.compareForHero(state.heroes[w], oneHand);
    final withPair = GameLogic.compareForHero(
      state.heroes[w],
      oneHand,
      pairingStash: state.gearStash,
    );
    expect(withPair.powerDelta, greaterThan(withoutPair.powerDelta));
    expect(withPair.isUpgrade, isTrue);

    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[w].itemIn(EquipmentSlot.weapon)?.id, oneHand.id);
    expect(state.heroes[w].itemIn(EquipmentSlot.offHand)?.id, shield.id);
  });

  test('auto equip may swap lower iLvl when role stats clearly win', () {
    final wornJunk = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.uncommon,
      battleNumber: 10,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'worn_wrong_stats',
      armorType: ArmorType.cloth,
      strengthBonus: 12,
      staminaBonus: 2,
      armorBonus: 4,
      intellectBonus: 0,
      spellPowerBonus: 0,
      itemLevel: 36,
      affinity: 'warrior',
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final betterLower = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'bag_right_stats',
      armorType: ArmorType.cloth,
      intellectBonus: 22,
      spellPowerBonus: 14,
      staminaBonus: 10,
      armorBonus: 6,
      itemLevel: 28,
      affinity: 'mage',
      effectId: GearEffectId.none,
      effectValue: 0,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final mageIndex =
        state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.mage);
    expect(mageIndex, greaterThanOrEqualTo(0));
    final heroes = [...state.heroes];
    // Fill other chests so BiS does not steal the bag piece for empty slots.
    final filler = betterLower.copyWith(
      id: 'filler_chest',
      intellectBonus: 30,
      spellPowerBonus: 20,
      staminaBonus: 16,
      itemLevel: 40,
    );
    for (var i = 0; i < heroes.length; i++) {
      if (i == mageIndex) {
        heroes[i] = heroes[i].copyWith(
          level: 20,
          equipped: {
            ...heroes[i].equipped,
            EquipmentSlot.chest: wornJunk,
          },
        );
      } else {
        heroes[i] = heroes[i].copyWith(
          level: 20,
          equipped: {
            ...heroes[i].equipped,
            EquipmentSlot.chest: filler.copyWith(id: 'filler_chest_$i'),
          },
        );
      }
    }
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[betterLower],
    );

    final cmp = GameLogic.compareForHero(state.heroes[mageIndex], betterLower);
    expect(cmp.isUpgrade, isTrue);
    state = GameLogic.autoEquipBetterGear(state);
    expect(
      state.heroes[mageIndex].itemIn(EquipmentSlot.chest)?.id,
      betterLower.id,
    );
  });

  test('sell junk drops offhand blocked by two-hand weapon', () {
    final staff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'big_staff',
      weaponType: WeaponType.staff,
      handed: WeaponHanded.twoHand,
      intellectBonus: 10,
      spellPowerBonus: 8,
      clearAffinity: true,
    );
    final weakFrill = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.mage,
    ).copyWith(
      id: 'junk_tome',
      offHandKind: OffHandKind.frill,
      intellectBonus: 1,
      spellPowerBonus: 1,
      itemLevel: 30,
      clearAffinity: true,
    );
    // Strong frills so other heroes do not BiS-keep the junk tome.
    final keepFrills = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.rare,
          battleNumber: 8,
          bias: HeroRole.healer,
        ).copyWith(
          id: 'keep_frill_$i',
          offHandKind: OffHandKind.frill,
          intellectBonus: 12,
          spellPowerBonus: 10,
          itemLevel: 28,
          clearAffinity: true,
        ),
    ];

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final mageIndex =
        state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.mage);
    expect(mageIndex, greaterThanOrEqualTo(0));

    // Strip mage gear then put 2H staff on; give other heroes strong frills.
    final heroes = [...state.heroes];
    heroes[mageIndex] = heroes[mageIndex].copyWith(clearEquipped: true);
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[staff, weakFrill, ...keepFrills],
    );
    state = GameLogic.equipFromStash(state, staff.id, heroIndex: mageIndex);
    expect(
      state.heroes[mageIndex].itemIn(EquipmentSlot.weapon)?.id,
      staff.id,
    );
    var frillHero = 0;
    for (var i = 0; i < state.heroes.length; i++) {
      if (i == mageIndex) continue;
      if (frillHero >= keepFrills.length) break;
      state = GameLogic.equipFromStash(
        state,
        keepFrills[frillHero].id,
        heroIndex: i,
      );
      frillHero++;
    }
    state = state.copyWith(
      gearStash: <EquipmentItem>[weakFrill],
      autoSellMaxPower: 40,
      autoSellMaxRarity: LootRarity.uncommon.index,
    );

    final cmp = GameLogic.compareForHero(
      state.heroes[mageIndex],
      weakFrill,
    );
    expect(cmp.isUpgrade, isFalse);

    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash, isEmpty);
    expect(sold.gold, greaterThan(state.gold));
  });

  test('auto equip puts plate on a warrior from level 1; SELL JUNK keeps rare mail', () {
    final plate = GameLogic.createEquipment(
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      battleNumber: 10,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'plate_chest',
      armorType: ArmorType.plate,
      strengthBonus: 12,
      staminaBonus: 10,
      armorBonus: 20,
      itemLevel: 40,
      clearAffinity: true,
    );
    final mail = plate.copyWith(
      id: 'mail_chest',
      armorType: ArmorType.mail,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.heroes[0].level, lessThan(40));
    state = state.copyWith(gearStash: <EquipmentItem>[plate]);
    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.chest)?.id, plate.id);

    state = state.copyWith(gearStash: <EquipmentItem>[mail]);
    final sold = GameLogic.autoSellJunk(state);
    // Rare+ stays for merge even when the starter party cannot wear mail.
    expect(sold.gearStash.any((g) => g.id == mail.id), isTrue);
  });

  test('SELL JUNK sells rare gear at or below the auto-sell iLvl cap', () {
    final rareUnderCap = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 4,
    ).copyWith(
      id: 'rare_under_cap',
      attackBonus: 1,
      defenseBonus: 3,
      vitalityBonus: 3,
      itemLevel: 12,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final wornCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 10,
        ).copyWith(
          id: 'worn_strong_$i',
          attackBonus: 4,
          defenseBonus: 12,
          vitalityBonus: 14,
          itemLevel: 40,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[...wornCloaks, rareUnderCap],
      autoSellMaxPower: 20,
      autoSellMaxRarity: LootRarity.rare.index,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        wornCloaks[i].id,
        heroIndex: i,
      );
    }
    state = state.copyWith(gearStash: <EquipmentItem>[rareUnderCap]);
    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash.any((g) => g.id == rareUnderCap.id), isFalse);
  });

  test('SELL JUNK sells non-upgrade uncommons but keeps rare gear', () {
    final junk = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 1,
    ).copyWith(
      id: 'junk_cloak',
      attackBonus: 0,
      defenseBonus: 1,
      vitalityBonus: 0,
      itemLevel: 1,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final spareUncommon = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.uncommon,
      battleNumber: 3,
    ).copyWith(
      id: 'spare_uncommon',
      attackBonus: 0,
      defenseBonus: 2,
      vitalityBonus: 1,
      itemLevel: 8,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final rare = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      battleNumber: 6,
    ).copyWith(
      id: 'rare_cloak',
      attackBonus: 1,
      defenseBonus: 4,
      vitalityBonus: 4,
      itemLevel: 18,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final wornCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 8,
        ).copyWith(
          id: 'worn_cloak_$i',
          attackBonus: 2,
          defenseBonus: 8,
          vitalityBonus: 10,
          itemLevel: 28,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[...wornCloaks, junk, spareUncommon, rare],
      // Cap below rare ilvl so rare+ above the gate is kept (matches pickup).
      autoSellMaxPower: 10,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        wornCloaks[i].id,
        heroIndex: i,
      );
    }
    state = state.copyWith(
      gearStash: <EquipmentItem>[junk, spareUncommon, rare],
    );

    final sold = GameLogic.autoSellJunk(state);
    expect(sold.gearStash.any((g) => g.id == junk.id), isFalse);
    expect(sold.gearStash.any((g) => g.id == spareUncommon.id), isFalse);
    expect(sold.gearStash.any((g) => g.id == rare.id), isTrue);
  });

  test('SELL JUNK sells surplus commons beyond BiS empty-slot fills', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final bisSlots = state.heroes.length * 2; // trinket + trinket2
    final fills = [
      for (var i = 0; i < bisSlots + 4; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.trinket,
          rarity: LootRarity.common,
          battleNumber: 1,
        ).copyWith(
          id: 'empty_fill_trinket_$i',
          attackBonus: 1,
          defenseBonus: 0,
          vitalityBonus: 0,
          itemLevel: 1,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes)
          h.copyWith(
            equipped: {
              for (final e in h.equipped.entries)
                if (e.key != EquipmentSlot.trinket &&
                    e.key != EquipmentSlot.trinket2)
                  e.key: e.value,
            },
          ),
      ],
      gearStash: fills,
    );
    final sold = GameLogic.autoSellJunk(state);
    // BiS may keep one per trinket slot; surplus commons must not stick forever.
    expect(sold.gearStash.length, lessThan(fills.length));
    expect(sold.gearStash.length, lessThanOrEqualTo(bisSlots));
  });

  test('SELL JUNK on a full bag also clears non-upgrade rares', () {
    final wornCloaks = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 10,
        ).copyWith(
          id: 'worn_full_$i',
          attackBonus: 4,
          defenseBonus: 12,
          vitalityBonus: 14,
          itemLevel: 30,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: wornCloaks,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(
        state,
        wornCloaks[i].id,
        heroIndex: i,
      );
    }
    final cap = GameLogic.maxGearStashFor(state);
    final weakRares = [
      for (var i = 0; i < cap; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 4,
        ).copyWith(
          id: 'weak_rare_$i',
          attackBonus: 0,
          defenseBonus: 2,
          vitalityBonus: 2,
          itemLevel: 10,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    state = state.copyWith(
      gearStash: weakRares,
      autoSellMaxPower: 40,
      autoSellMaxRarity: LootRarity.rare.index,
    );
    expect(state.gearStash.length, cap);

    final sold = GameLogic.autoSellJunk(state, unstickBag: true);
    expect(sold.gearStash.length, lessThan(cap ~/ 2));
    expect(sold.gold, greaterThan(state.gold));
  });

  test('near-full unstick still keeps epics above FILTERS', () {
    final cap = GameLogic.maxGearStashFor(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
    );
    final epics = [
      for (var i = 0; i < cap; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.epic,
          battleNumber: 12,
        ).copyWith(
          id: 'epic_above_$i',
          armorBonus: 4 + (i % 3),
          staminaBonus: 4,
          itemLevel: 36,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: epics,
      // Uncommon i24 — epics are outside FILTERS.
      autoSellMaxPower: 24,
      autoSellMaxRarity: LootRarity.uncommon.index,
    );
    final sold = GameLogic.autoSellJunk(state, unstickBag: true);
    // Best-per-slot + all other epics above filter remain.
    expect(sold.gearStash.length, cap);
    expect(sold.gold, state.gold);
  });

  test('auto-disassemble scraps matching junk for essence', () {
    final junk = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 1,
    ).copyWith(
      id: 'scrap_cloak',
      attackBonus: 0,
      defenseBonus: 1,
      vitalityBonus: 0,
      itemLevel: 4,
      effectId: GearEffectId.none,
      effectValue: 0,
      clearAffinity: true,
    );
    final worn = [
      for (var i = 0; i < 3; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.rare,
          battleNumber: 10,
        ).copyWith(
          id: 'worn_scrap_$i',
          attackBonus: 4,
          defenseBonus: 12,
          vitalityBonus: 14,
          itemLevel: 40,
          effectId: GearEffectId.none,
          effectValue: 0,
          clearAffinity: true,
        ),
    ];
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[...worn, junk],
      autoSellMaxPower: 0,
      autoDisassembleMaxIlvl: 10,
      autoDisassembleMaxRarity: LootRarity.uncommon.index,
    );
    for (var i = 0; i < 3; i++) {
      state = GameLogic.equipFromStash(state, worn[i].id, heroIndex: i);
    }
    state = state.copyWith(gearStash: <EquipmentItem>[junk]);
    final scraped = GameLogic.autoDisassembleJunk(state);
    expect(scraped.gearStash, isEmpty);
    expect(scraped.essence, greaterThan(state.essence));
    expect(scraped.gold, state.gold);
  });

  test('applyLootDrops registers item names in the codex', () {
    final piece = GameLogic.createEquipment(
      slot: EquipmentSlot.ring,
      rarity: LootRarity.uncommon,
      battleNumber: 3,
    ).copyWith(id: 'codex_ring', name: 'Codex Test Ring');
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(initial.codexItems, isEmpty);
    final after = GameLogic.applyLootDrops(initial, [
      LootDrop(
        name: piece.name,
        amount: 1,
        rarity: piece.rarity,
        equipment: piece,
      ),
    ]);
    expect(after.state.codexItems, contains('Codex Test Ring'));
  });

  test('backfillCodexFromInventory discovers stash and equipped names', () {
    final stashPiece = GameLogic.createEquipment(
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.common,
      battleNumber: 2,
    ).copyWith(id: 'stash_cloak', name: 'Backfill Cloak');
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      gearStash: <EquipmentItem>[stashPiece],
      codexItems: const <String>[],
    );
    state = GameLogic.backfillCodexFromInventory(state);
    expect(state.codexItems, contains('Backfill Cloak'));
  });

  test('awardPartyXp still grants XP to downed heroes', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(currentHp: 0);
    state = state.copyWith(heroes: heroes);
    final xpBefore = state.heroes[0].xp;
    state = GameLogic.awardPartyXp(state, 5);
    expect(state.heroes[0].xp, xpBefore + 5);
    expect(state.heroes[0].isAlive, isFalse);
  });

  test('awardPartyXp catch-up boosts heroes far behind party mean', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [
      state.heroes[0].copyWith(level: 20, xp: 0),
      state.heroes[1].copyWith(level: 20, xp: 0),
      state.heroes[2].copyWith(level: 10, xp: 0),
    ];
    state = state.copyWith(heroes: heroes);
    state = GameLogic.awardPartyXp(state, 10);
    expect(state.heroes[0].xp, 10);
    expect(state.heroes[2].xp, 14); // 1.4× catch-up
  });

  test('unlockSpec seeds new roster heroes near party mean level', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes) h.copyWith(level: 18, xp: 0),
      ],
      heroRoster: [
        for (final h in state.heroRoster) h.copyWith(level: 18, xp: 0),
      ],
      essence: 500,
      ascensionLevel: 5,
      highestDungeonCleared: 6,
    );
    // Combat is usually already present after ascend; pick an unlocked late spec.
    final before = state.heroRoster.length;
    // Force-unlock path via starter-unlocked check bypass: use unlockSpec on a
    // kit that canUnlockSpec may allow at this progress.
    for (final id in HeroSpecId.values) {
      if (state.heroRoster.any((h) => h.specId == id)) continue;
      if (!GameLogic.canUnlockSpec(state, id) &&
          !HeroSpecs.starterUnlocked.contains(id)) {
        continue;
      }
      state = GameLogic.unlockSpec(state, id);
      break;
    }
    expect(state.heroRoster.length, greaterThan(before));
    final newest = state.heroRoster.last;
    expect(newest.level, greaterThanOrEqualTo(15));
    expect(state.metaDepth.pendingHeroReveals, contains(newest.specId.name));
  });

  test('unlockSpec queues pending hero reveal', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    state = state.copyWith(
      ascensionLevel: 1,
      bossVictories: 99,
      highestDungeonCleared: 1,
    );
    expect(state.metaDepth.pendingHeroReveals, isEmpty);
    state = GameLogic.syncSpecUnlocks(state);
    expect(state.metaDepth.pendingHeroReveals, isNotEmpty);
    final cleared = GameLogic.ackPendingHeroReveals(state);
    expect(cleared.metaDepth.pendingHeroReveals, isEmpty);
  });

  test('early-floor gear pressure does not overshoot F3 packs', () {
    final room = DungeonGenerator.generateFloor(
      3,
      dungeonId: 'sandy',
      layoutSeed: 1,
    ).first;
    final fresh = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'sandy',
      gearPressure: 1.0,
    );
    final gear10 = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'sandy',
      gearPressure: 1.93,
    );
    expect(gear10.hp / fresh.hp, lessThan(1.4));
    expect(gear10.attack / fresh.attack, lessThan(1.3));
    expect(
      GameLogic.appliedGearPressure(1.93, level: 3),
      closeTo(1.26, 0.02),
    );
  });

  test('fresh ascend dampens AL threat until gear rebuilds', () {
    final room = DungeonGenerator.generateFloor(2, ascensionLevel: 2).first;
    final geared = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'hell',
      ascensionLevel: 2,
      gearPressure: 1.8,
    );
    final fresh = GameLogic.roomCombatBudget(
      room,
      dungeonId: 'hell',
      ascensionLevel: 2,
      gearPressure: 1.0,
    );
    expect(fresh.hp, lessThan(geared.hp));
    expect(fresh.attack, lessThan(geared.attack));
  });

  test('auto equip fills both empty ring slots from stash (BiS dual)', () {
    EquipmentItem ring({
      required String id,
      required int str,
      required int sta,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.ring,
        rarity: LootRarity.rare,
        battleNumber: 5,
      ).copyWith(
        id: id,
        strengthBonus: str,
        agilityBonus: 0,
        staminaBonus: sta,
        intellectBonus: 0,
        spiritBonus: 0,
        spellPowerBonus: 0,
        armorBonus: 0,
        mp5Bonus: 0,
        attackBonus: 0,
        defenseBonus: 0,
        vitalityBonus: 0,
        critChanceBonus: 0,
        attackSpeedBonus: 0,
        moveSpeedBonus: 0,
        itemLevel: 18,
        effectId: GearEffectId.none,
        effectValue: 0,
        affinity: HeroRole.warrior.name,
      );
    }

    final strong = ring(id: 'dual_r_strong', str: 10, sta: 8);
    final mild = ring(id: 'dual_r_mild', str: 5, sta: 4);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Lock other heroes' rings so only warrior claims these.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == 0)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
            },
          )
        else
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.ring && e.key != EquipmentSlot.ring2)
                  e.key: e.value,
              EquipmentSlot.ring: ring(id: 'lock_r1_$i', str: 30, sta: 30),
              EquipmentSlot.ring2: ring(id: 'lock_r2_$i', str: 30, sta: 30),
            },
          ),
    ];
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[strong, mild],
    );

    state = GameLogic.autoEquipBetterGear(state);
    final ids = {
      state.heroes[0].itemIn(EquipmentSlot.ring)?.id,
      state.heroes[0].itemIn(EquipmentSlot.ring2)?.id,
    };
    expect(ids, containsAll(<String>[strong.id, mild.id]));
    expect(state.gearStash, isEmpty);
  });

  test('auto equip keeps 1H+offhand when 2H net score is worse', () {
    final oneHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_1h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.oneHand,
      strengthBonus: 6,
      staminaBonus: 4,
      attackBonus: 4,
      clearAffinity: true,
    );
    final shield = GameLogic.createEquipment(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_shield',
      offHandKind: OffHandKind.shield,
      defenseBonus: 20,
      armorBonus: 18,
      staminaBonus: 14,
      strengthBonus: 4,
      clearAffinity: true,
    );
    final twoHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 6,
      bias: HeroRole.warrior,
    ).copyWith(
      id: 'net_2h',
      weaponType: WeaponType.sword,
      handed: WeaponHanded.twoHand,
      strengthBonus: 10,
      staminaBonus: 6,
      attackBonus: 8,
      clearAffinity: true,
    );

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    heroes[0] = heroes[0].copyWith(
      equipped: {
        EquipmentSlot.weapon: oneHand,
        EquipmentSlot.offHand: shield,
      },
    );
    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[twoHand],
    );

    final cmp = GameLogic.compareForHero(state.heroes[0], twoHand);
    expect(cmp.isUpgrade, isFalse);

    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[0].itemIn(EquipmentSlot.weapon)?.id, oneHand.id);
    expect(state.heroes[0].itemIn(EquipmentSlot.offHand)?.id, shield.id);
    expect(state.gearStash.any((g) => g.id == twoHand.id), isTrue);
  });

  test('auto equip gives contested item to largest delta hero', () {
    EquipmentItem cloak({
      required String id,
      required int armor,
      required int sta,
    }) {
      return GameLogic.createEquipment(
        slot: EquipmentSlot.cloak,
        rarity: LootRarity.rare,
        battleNumber: 5,
      ).copyWith(
        id: id,
        armorBonus: armor,
        staminaBonus: sta,
        strengthBonus: 2,
        defenseBonus: armor,
        vitalityBonus: sta,
        effectId: GearEffectId.none,
        effectValue: 0,
        clearAffinity: true,
      );
    }

    final prize = cloak(id: 'prize_cloak', armor: 16, sta: 14);
    final runnerUp = cloak(id: 'runner_cloak', armor: 10, sta: 8);

    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final w = state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.warrior);
    final m = state.heroes.indexWhere((h) => h.gearAffinity == HeroRole.mage);
    expect(w, greaterThanOrEqualTo(0));
    expect(m, greaterThanOrEqualTo(0));

    // Empty cloaks on W/M; lock other heroes so they cannot claim.
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        if (i == w || i == m)
          state.heroes[i].copyWith(
            equipped: {
              for (final e in state.heroes[i].equipped.entries)
                if (e.key != EquipmentSlot.cloak) e.key: e.value,
            },
          )
        else
          state.heroes[i].copyWith(
            equipped: {
              ...state.heroes[i].equipped,
              EquipmentSlot.cloak: cloak(
                id: 'lock_$i',
                armor: 40,
                sta: 40,
              ),
            },
          ),
    ];

    state = state.copyWith(
      heroes: heroes,
      gearStash: <EquipmentItem>[prize, runnerUp],
    );

    final deltaW = GameLogic.compareForHero(state.heroes[w], prize).powerDelta;
    final deltaM = GameLogic.compareForHero(state.heroes[m], prize).powerDelta;
    expect(deltaW, greaterThan(deltaM));
    expect(deltaW, greaterThan(0));
    expect(deltaM, greaterThan(0));

    state = GameLogic.autoEquipBetterGear(state);
    expect(state.heroes[w].itemIn(EquipmentSlot.cloak)?.id, prize.id);
    expect(state.heroes[m].itemIn(EquipmentSlot.cloak)?.id, runnerUp.id);
  });


  test('stash overflow salvages oldest piece to essence', () {
    final pieces = List<EquipmentItem>.generate(
      GameLogic.maxGearStash + 1,
      (index) => EquipmentItem(
        id: 'stash_$index',
        name: 'Spare $index',
        slot: EquipmentSlot.cloak,
        rarity: LootRarity.common,
        attackBonus: 0,
        defenseBonus: 1,
        vitalityBonus: 0,
      ),
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final essenceBefore = state.essence;
    for (final piece in pieces) {
      state = GameLogic.stashEquipment(state, piece);
    }

    expect(state.gearStash, hasLength(GameLogic.maxGearStash));
    expect(state.gearStash.first.id, 'stash_1');
    expect(state.essence, greaterThan(essenceBefore));
  });

  test('clearing rooms can stash gear for the party', () {
    final initial = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
      dungeonId: 'sandy',
    );
    final progressed = GameLogic.simulateSpatialOffline(initial, 5 * 60).state;

    expect(progressed.gearStash, isNotEmpty);
  });

  test('tile map multi-room floors are walkable with spawn and exit', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final map = RoomLayouts.forFloor(
      floorNumber: state.currentRoom.floorNumber,
      room: state.currentRoom,
      dungeonId: 'sandy',
    );
    expect(map.cols, greaterThan(13));
    expect(map.roomCenters.length, greaterThanOrEqualTo(1));
    expect(map.isWalkable(map.spawnPoints.first.$1, map.spawnPoints.first.$2),
        isTrue);
    expect(map.isWalkable(map.exitPoint.$1, map.exitPoint.$2), isTrue);
    expect(map.at(0, 0), TileKind.wall);
  });

  test('bossFloor formula is 5 plus ascension', () {
    expect(DungeonGenerator.bossFloorFor(0), 5);
    expect(DungeonGenerator.bossFloorFor(2), 7);
    expect(DungeonCatalog.byId('sandy').layout, DungeonLayoutKind.cave);
    // Hell must not share Sandy's cave layout (different chamber footprint).
    expect(DungeonCatalog.byId('hell').layout, isNot(DungeonLayoutKind.cave));
  });

  test('dungeon zone names are catalog-canonical', () {
    const banned = [
      'Goblin Den',
      'Sandy Crypt',
      'Hell Maw',
      'Dead Marsh',
      "King's Tomb",
    ];
    for (final d in DungeonCatalog.all) {
      expect(d.name, isNotEmpty);
      for (final bad in banned) {
        expect(d.name, isNot(bad));
      }
    }
    expect(DungeonCatalog.byId('sandy').name, 'Sandy Caverns');
    expect(DungeonCatalog.byId('goblin').name, "Goblin's Hideout");
    expect(DungeonCatalog.byId('hell').name, "Hell's Gate");
    expect(DungeonCatalog.byId('dead').name, 'City of Dead');
    for (final hint in HeroSpecs.all.map((s) => s.unlockHint)) {
      for (final bad in banned) {
        expect(hint, isNot(contains(bad)), reason: hint);
      }
    }
    for (final a in AchievementCatalog.all) {
      for (final bad in banned) {
        expect(a.description, isNot(contains(bad)), reason: a.id);
      }
      if (a.id == 'clear_hell') {
        expect(a.description, contains("Hell's Gate"));
      }
    }
  });

  test('sanctuary bonus labels use softcapped totals', () {
    final raw = 40 * 5; // would be 200% without softcap
    final soft = GameLogic.sanctuaryTrackBonusAt('gold', 40);
    expect(soft, lessThan(raw));
    final label = GameLogic.sanctuaryBonusLabel('gold', 40, prestige: 2);
    expect(label, contains('+${soft + 6}%'));
    expect(label, contains('P2'));
    expect(GameLogic.sanctuaryPrestigeKeepShort('gold'), '+3% gold');
    expect(GameLogic.sanctuaryPrestigeKeepShort('power'), '+1 ATK');
    expect(GameLogic.sanctuaryPrestigeKeepShort('vitality'), '+12 HP');
    expect(GameLogic.sanctuaryPrestigeKeepShort('xp'), '+2% XP');
    expect(GameLogic.sanctuaryPrestigeEssenceGain(12), 37);
    expect(GameLogic.sanctuaryTrackBonusAt('power', 1), 1);
    expect(
      GameLogic.sanctuaryTrackBonusAt('vitality', 1),
      GameLogic.sanctuaryVitalityPerLevel,
    );
    expect(
      GameLogic.sanctuaryPrestigeKeepAmount('vitality'),
      GameLogic.sanctuaryVitalityPerLevel,
    );
  });

  test('ascend mission board ignores pre-ascend highestFloorCleared', () {
    final deep = GameLogic.createMissionBoard(
      ascensionLevel: 3,
      highestFloorCleared: 40,
    );
    final fresh = GameLogic.createMissionBoard(
      ascensionLevel: 3,
      highestFloorCleared: 0,
    );
    // Depth score includes floorBand — fresh board must not inherit deep HFC.
    final deepScore = GameLogic.missionDepthScore(
      ascensionLevel: 3,
      highestFloorCleared: 40,
    );
    final freshScore = GameLogic.missionDepthScore(
      ascensionLevel: 3,
      highestFloorCleared: 0,
    );
    expect(freshScore, lessThan(deepScore));
    expect(deep, hasLength(3));
    expect(fresh, hasLength(3));
  });

  test('god hand upgrade spends essence', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4)).copyWith(
      essence: 100,
    );
    final before = state.godHandLevel;
    state = GameLogic.upgradeGodHand(state);
    expect(state.godHandLevel, before + 1);
  });

  test('enter and leave dungeon flags', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.inDungeon, isFalse);
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    expect(state.inDungeon, isTrue);
    expect(state.dungeonId, 'sandy');
    state = GameLogic.leaveDungeon(state);
    expect(state.inDungeon, isFalse);
  });

  test('leaveDungeon clamps over-max HP from fortitude sync', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final hero = state.heroes.first;
    final maxHp = state.effectiveHeroMaxHp(hero);
    state = state.copyWith(
      heroes: [
        hero.copyWith(currentHp: maxHp + 200),
        ...state.heroes.skip(1),
      ],
    );
    state = GameLogic.leaveDungeon(state);
    expect(state.heroes.first.currentHp, maxHp);
  });

  test('mage aura boosts party attack while Ember lives', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final aegis = state.heroes.first;
    final withMage = state.effectiveHeroAttack(aegis);

    final mageDown = state.copyWith(
      heroes: state.heroes
          .map(
            (hero) => hero.gearAffinity == HeroRole.mage
                ? hero.copyWith(currentHp: 0)
                : hero,
          )
          .toList(),
    );
    final withoutMage = mageDown.effectiveHeroAttack(aegis);

    expect(withMage, greaterThan(withoutMage));
    expect(state.casterAuraBonusFor(aegis), greaterThanOrEqualTo(2));
  });

  test('warrior guard and healer mend passives apply', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final warrior = state.heroes.firstWhere(
      (hero) => hero.gearAffinity == HeroRole.warrior,
    );
    expect(state.tankGuardBonusFor(warrior), 2);
    expect(
      state.effectiveHeroDefense(warrior),
      greaterThanOrEqualTo(warrior.defense + state.tankGuardBonusFor(warrior)),
    );
    expect(state.healerMendAmount, 2);

    GameLogic.random = Random(3);
    final floor = DungeonGenerator.generateFloor(1);
    final room = floor.first;
    final enemies = GameLogic.createEnemyGroup(room)
        .map(
          (enemy) => enemy.copyWith(
            currentHp: 500,
            stats: Stats.enemy(
              attack: 12,
              defense: enemy.defense,
              maxHp: 500,
            ),
          ),
        )
        .toList();

    final damaged = state.copyWith(
      inDungeon: true,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: enemies,
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: state.effectiveHeroMaxHp(hero) - 8,
            ),
          )
          .toList(),
    );

    // Spatial heal kits / mend keep living healers relevant mid-fight.
    expect(damaged.hasLivingHealer, isTrue);
    expect(damaged.heroes.every((h) {
      return h.currentHp <= damaged.effectiveHeroMaxHp(h);
    }), isTrue);
  });

  test('mission board starts with three distinct contracts', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    expect(state.missions, hasLength(3));
    expect(state.missions.map((m) => m.type).toSet(), hasLength(3));
    expect(
      state.missions.every((m) => MissionType.values.contains(m.type)),
      isTrue,
    );
  });

  test('clearing rooms progresses and claim pays out missions', () {
    final initial = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    // Force a board with kill + gold so offline clears can progress them.
    final seeded = GameLogic.enterDungeon(
      initial.copyWith(
        missions: [
          GameLogic.createMission(
            type: MissionType.defeatEnemies,
            ascensionLevel: 0,
            random: Random(1),
          ),
          GameLogic.createMission(
            type: MissionType.earnGold,
            ascensionLevel: 0,
            random: Random(2),
          ),
          GameLogic.createMission(
            type: MissionType.clearBosses,
            ascensionLevel: 0,
            random: Random(3),
          ),
        ],
      ),
      dungeonId: 'sandy',
    );
    final progressed = GameLogic.simulateSpatialOffline(seeded, 6 * 60).state;

    final defeat = progressed.missions.firstWhere(
      (m) => m.type == MissionType.defeatEnemies,
    );
    expect(defeat.progress, greaterThan(0));

    final goldMission = progressed.missions.firstWhere(
      (m) => m.type == MissionType.earnGold,
    );
    expect(goldMission.progress, greaterThan(0));

    final ready = progressed.copyWith(
      missions: progressed.missions
          .map(
            (m) => m.id == defeat.id ? m.copyWith(progress: m.target) : m,
          )
          .toList(),
    );
    final claimed = GameLogic.claimMission(ready, defeat.id);
    expect(claimed.gold, ready.gold + defeat.goldReward);
    expect(claimed.essence, ready.essence + defeat.essenceReward);
    final idx = ready.missions.indexWhere((m) => m.id == defeat.id);
    final replacement = claimed.missions[idx];
    expect(replacement.progress, 0);
    expect(replacement.type, isNot(MissionType.defeatEnemies));
  });

  test('ascend refreshes mission board for new depth', () {
    final ready = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          bossVictories: 1,
          highestDungeonCleared: 2,
          missions: GameLogic.createMissionBoard(ascensionLevel: 0)
              .map((m) => m.copyWith(progress: m.target))
              .toList(),
        );
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.ascensionLevel, 1);
    expect(ascended.missions, hasLength(3));
    expect(ascended.missions.every((m) => m.progress == 0), isTrue);
    final kill = ascended.missions.where(
      (m) => m.type == MissionType.defeatEnemies,
    );
    if (kill.isNotEmpty) {
      expect(kill.first.target, greaterThan(8));
    }
  });

  test('deeper accounts get harder kill contracts', () {
    final early = GameLogic.createMission(
      type: MissionType.defeatEnemies,
      ascensionLevel: 0,
      random: Random(7),
    );
    final deep = GameLogic.createMission(
      type: MissionType.defeatEnemies,
      ascensionLevel: 3,
      highestDungeonCleared: 4,
      highestFloorCleared: 20,
      hardmodeLevel: 2,
      random: Random(7),
    );
    expect(deep.target, greaterThan(early.target));
    expect(deep.goldReward, greaterThan(early.goldReward));
  });

  test('farm mode loops the same floor after clear', () {
    final floor = DungeonGenerator.generateFloor(2);
    final room = floor.first;
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.farm,
          inDungeon: true,
          currentRoom: room,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(room)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );

    final after = GameLogic.completeCurrentRoom(
      state,
      goldGain: 20,
      skipLootRoll: true,
    );
    expect(after.currentRoom.floorNumber, 2);
    expect(after.highestFloorCleared, 2);
    expect(after.inDungeon, isTrue);
  });

  test('push mode advances floor and failed wipe retreats', () {
    final floor = DungeonGenerator.generateFloor(2);
    final room = floor.first;
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          dungeonMode: DungeonMode.push,
          inDungeon: true,
          currentRoom: room,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(room)
              .map((e) => e.copyWith(currentHp: 1))
              .toList(),
        );
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 20,
      skipLootRoll: true,
    );
    expect(state.currentRoom.floorNumber, 3);
    expect(state.highestFloorCleared, 2);

    final wiped = state.copyWith(
      heroes: state.heroes.map((h) => h.copyWith(currentHp: 0)).toList(),
    );
    final retreated = GameLogic.retreatFromFailedPush(wiped);
    expect(retreated.currentRoom.floorNumber, 2);
    expect(retreated.dungeonMode, DungeonMode.push);
  });

  test('equip sell and sanctuary persist through ascend', () {
    final stashItem = EquipmentItem(
      id: 'stash_w',
      name: 'Spare Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      attackBonus: 3,
      strengthBonus: 3,
      defenseBonus: 0,
      vitalityBonus: 0,
      weaponType: WeaponType.sword,
      handed: WeaponHanded.oneHand,
      affinity: HeroRole.warrior.name,
    );
    final pet = const Pet(id: 'p1', name: 'Ember Pup', attackBonus: 2);
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
          essence: 100,
          gearStash: <EquipmentItem>[stashItem],
          ownedPets: <Pet>[pet],
          activePet: pet,
          heroes: GameLogic.createInitialState(now: DateTime(2026, 7, 4))
              .heroes
              .map((h) => h.copyWith(clearEquipped: true))
              .toList(),
        );
    state = GameLogic.equipFromStash(state, stashItem.id);
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon)?.id, stashItem.id);
    expect(state.gearStash, isEmpty);

    state = GameLogic.upgradeSanctuary(state, 'gold');
    expect(state.sanctuaryGoldLevel, 1);
    expect(GameLogic.applyGoldGain(state, 100), 105);

    final ready = state.copyWith(bossVictories: 1);
    final ascended = GameLogic.ascend(ready, now: DateTime(2026, 7, 5));
    expect(ascended.equipped, isEmpty);
    // Fresh AL heroes get class starter kits (not previous run's gear).
    expect(ascended.heroes.every((h) => h.equipped.isNotEmpty), isTrue);
    expect(
      ascended.heroes.any(
        (h) => h.itemIn(EquipmentSlot.weapon)?.id == stashItem.id,
      ),
      isFalse,
    );
    expect(ascended.sanctuaryGoldLevel, 1);
    expect(ascended.activePet?.id, pet.id);
    expect(ascended.ownedPets, hasLength(1));
    expect(ascended.highestFloorCleared, 0);
    expect(ascended.dungeonMode, DungeonMode.push);
  });

  test('sanctuary tracks level infinitely past 12', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 3))
        .copyWith(sanctuaryGoldLevel: 12, essence: 5000);
    final beforeBonus = state.sanctuaryGoldBonusPercent;
    state = GameLogic.upgradeSanctuary(state, 'gold');
    expect(state.sanctuaryGoldLevel, 13);
    expect(state.sanctuaryGoldBonusPercent, greaterThanOrEqualTo(beforeBonus));

    // Prestige remains optional compress from Lv12+.
    final prestiged = GameLogic.prestigeSanctuaryTrack(state, 'gold');
    expect(prestiged.sanctuaryGoldLevel, 0);
    expect(prestiged.metaDepth.sanctuaryGoldPrestige, 1);
    expect(
      prestiged.essence,
      state.essence + GameLogic.sanctuaryPrestigeEssenceGain(13),
    );
    expect(prestiged.sanctuaryGoldBonusPercent, 3);
  });

  test('infinity gauntlet unlocks at AL10 and escalates', () {
    final locked = GameLogic.createInitialState(now: DateTime(2026, 8, 3));
    expect(GameLogic.canEnterGauntlet(locked), isFalse);
    expect(GameLogic.enterGauntlet(locked).inGauntlet, isFalse);

    var state = locked.copyWith(
      ascensionLevel: 10,
      highestFloorCleared: 27,
    );
    expect(GameLogic.canEnterGauntlet(state), isTrue);
    state = GameLogic.enterGauntlet(state);
    expect(state.inGauntlet, isTrue);
    expect(state.inDungeon, isTrue);
    expect(state.dungeonId, 'crystal');
    expect(state.dungeonMode, DungeonMode.push);
    expect(state.currentRoom.floorNumber, 1);
    expect(state.achievements, contains('gauntlet_enter'));
    // Gauntlet must not wipe zone highestFloorCleared (Ascend fragments).
    expect(state.highestFloorCleared, 27);

    final f1 = GameLogic.createEnemyGroup(
      state.currentRoom,
      dungeonId: state.dungeonId,
      fromState: state,
    );
    final f10Room = DungeonGenerator.generateFloor(
      10,
      ascensionLevel: state.ascensionLevel,
      dungeonId: 'crystal',
      bossEvery: GameLogic.gauntletBossEvery,
    ).first;
    expect(f10Room.type, RoomType.boss);
    final f10 = GameLogic.createEnemyGroup(
      f10Room,
      dungeonId: 'crystal',
      fromState: state.copyWith(currentRoom: f10Room),
    );
    final f1Hp = f1.fold<int>(0, (s, e) => s + e.maxHp);
    final f10Hp = f10.fold<int>(0, (s, e) => s + e.maxHp);
    expect(f10Hp, greaterThan(f1Hp));
    expect(GameLogic.gauntletEssenceForFloor(10, boss: false), greaterThan(1));
    expect(
      DungeonGenerator.generateFloor(
        15,
        bossEvery: GameLogic.gauntletBossEvery,
      ).first.type,
      RoomType.boss,
    );

    final goldBefore = state.gold;
    final expectedGold = GameLogic.applyGoldGain(
      state,
      (100 * GameLogic.gauntletGoldMul(1)).round(),
    );
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 100,
      skipLootRoll: true,
    );
    expect(state.inGauntlet, isTrue);
    expect(state.currentRoom.floorNumber, 2);
    expect(state.metaDepth.gauntletBestFloor, greaterThanOrEqualTo(1));
    // Gauntlet must NOT bump zone highestFloorCleared (Ascend fragments).
    expect(state.highestFloorCleared, 27);
    expect(state.essence, greaterThan(locked.essence));
    // Single gold mul on clear (F1 → mul 1.0).
    expect(state.gold - goldBefore, expectedGold);

    // Challenge mint suppressed in gauntlet; daily vault counts at AL10+.
    final vaultBefore = state.metaDepth.dailyVaultClears;
    final withChallenges = state.copyWith(
      challengeBossRush: true,
      hardmodeLevel: 3,
      keystoneRunActive: true,
      keystoneRunLevel: 3,
      essence: 0,
    );
    expect(
      MetaSystems.challengeClearEssenceBonus(withChallenges),
      greaterThan(0),
    );
    final afterClear = GameLogic.completeCurrentRoom(
      withChallenges,
      goldGain: 10,
      skipLootRoll: true,
    );
    final hmReward = AchievementCatalog.byId('hm_1')?.essenceReward ?? 0;
    expect(afterClear.achievements, contains('hm_1'));
    // Gauntlet floor essence only + new achievement — no rush/HM clear mint.
    expect(afterClear.essence, 1 + (2 ~/ 2) + hmReward);
    expect(
      afterClear.metaDepth.dailyVaultClears,
      min(GameLogic.dailyVaultClearTarget, vaultBefore + 1),
    );

    final left = GameLogic.leaveDungeon(state);
    expect(left.inGauntlet, isFalse);
    expect(left.inDungeon, isFalse);
    expect(left.metaDepth.gauntletBestFloor, greaterThanOrEqualTo(1));

    // Offline soft-cap: even long AFK clears at most 6 gauntlet floors.
    final afk = GameLogic.enterGauntlet(
      locked.copyWith(ascensionLevel: 10),
    );
    final sim = GameLogic.simulateSpatialOffline(afk, 60 * 60);
    expect(sim.roomsCleared, lessThanOrEqualTo(6));
  });

  test('gauntlet wipe exits to hub healed (live helper + offline)', () {
    final base = GameLogic.createInitialState(
      now: DateTime(2026, 8, 3),
    ).copyWith(ascensionLevel: 10);
    var state = GameLogic.enterGauntlet(base);
    expect(state.inGauntlet, isTrue);
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes) h.copyWith(currentHp: 0),
      ],
    );
    final left = GameLogic.exitToHubHealed(state);
    expect(left.inGauntlet, isFalse);
    expect(left.inDungeon, isFalse);
    expect(
      left.heroes.every((h) => h.currentHp == left.effectiveHeroMaxHp(h)),
      isTrue,
    );

    // Offline sim with a wiped party must not soft-lock in Gauntlet.
    var afk = GameLogic.enterGauntlet(base);
    afk = afk.copyWith(
      heroes: [
        for (final h in afk.heroes) h.copyWith(currentHp: 0),
      ],
    );
    final sim = GameLogic.simulateSpatialOffline(afk, 5);
    expect(sim.state.inDungeon, isFalse);
    expect(sim.state.inGauntlet, isFalse);
    expect(
      sim.state.heroes.every(
        (h) => h.currentHp == sim.state.effectiveHeroMaxHp(h),
      ),
      isTrue,
    );
  });

  test('field bandage heals the lowest living hero about 40%', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 3));
    final bandage = GameLogic.createMarketBandage(salt: 1);
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        state.heroes[i].copyWith(
          currentHp: i == 0
              ? max(1, state.effectiveHeroMaxHp(state.heroes[i]) ~/ 4)
              : state.effectiveHeroMaxHp(state.heroes[i]),
          equipped: {
            for (final e in state.heroes[i].equipped.entries)
              if (e.key != EquipmentSlot.consumable) e.key: e.value,
            if (i == 0) EquipmentSlot.consumable: bandage,
          },
        ),
    ];
    state = state.copyWith(heroes: heroes);
    final before = state.heroes.first.currentHp;
    state = GameLogic.useConsumable(state);
    final after = state.heroes.first.currentHp;
    final maxHp = state.effectiveHeroMaxHp(state.heroes.first);
    expect(after, greaterThan(before));
    expect(after - before, greaterThanOrEqualTo(max(8, (maxHp * 0.35).round())));
    expect(after - before, lessThanOrEqualTo((maxHp * 0.45).round() + 2));
    expect(GameLogic.canUseConsumable(state), isFalse);
  });

  test('offline spatial build uses full threat and afk assist', () {
    final farm = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 3)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );
    final live = SpatialCombat.build(farm);
    expect(live.afkAssist, isFalse);
    final offline = SpatialCombat.build(farm, threatScale: 1.0, afkAssist: true);
    expect(offline.afkAssist, isTrue);
    expect(offline.enemies.first.maxHp, live.enemies.first.maxHp);
    final sim = GameLogic.simulateSpatialOffline(farm, 60);
    expect(sim.state.gold, greaterThanOrEqualTo(farm.gold));
  });

  test('loot: kill has no fillers; clear grants gold pouch as wallet gold', () {
    GameLogic.random = Random(3);
    final kill = GameLogic.rollKillLoot(
      4,
      party: GameLogic.createInitialState(now: DateTime(2026, 8, 3)).heroes,
    );
    expect(kill.any((d) => d.name == 'Gold Pouch'), isFalse);
    expect(kill.any((d) => d.name == 'Boss Sigil'), isFalse);

    final fillers = GameLogic.rollFloorClearLoot(4, roomType: RoomType.normal);
    expect(fillers.any((d) => d.name == 'Gold Pouch'), isTrue);
    final pouch = fillers.firstWhere((d) => d.name == 'Gold Pouch');
    expect(pouch.amount, GameLogic.goldPouchBaseGold(4));

    final before = GameLogic.createInitialState(now: DateTime(2026, 8, 3));
    final applied = GameLogic.applyLootDrops(before, [pouch]);
    expect(applied.resolved.first.outcome, LootOutcome.gold);
    expect(applied.state.gold, greaterThan(before.gold));
    expect(applied.state.essence, before.essence);

    final bossFillers = GameLogic.rollFloorClearLoot(
      10,
      roomType: RoomType.boss,
    );
    expect(bossFillers.any((d) => d.name == 'Boss Sigil'), isTrue);

    // Combat clear applies floor fillers into recentLoot.
    var roomState = before.copyWith(
      inDungeon: true,
      currentRoom: DungeonRoom(
        floorNumber: 4,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 4,
        enemyCount: 3,
      ),
      dungeonFloor: [
        DungeonRoom(
          floorNumber: 4,
          roomIndex: 0,
          type: RoomType.normal,
          enemyLevel: 4,
          enemyCount: 3,
        ),
      ],
    );
    roomState = GameLogic.completeCurrentRoom(
      roomState,
      goldGain: 0,
      skipLootRoll: true,
    );
    expect(roomState.recentLoot.any((d) => d.name == 'Gold Pouch'), isTrue);
  });

  test('Apex gear does not cancel fresh-AL gear pressure ease', () {
    final fresh = GameLogic.createInitialState(now: DateTime(2026, 8, 5))
        .copyWith(ascensionLevel: 3);
    final apex = EquipmentItem(
      id: 'apex_keep',
      name: 'Apex Blade',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.legendary,
      strengthBonus: 30,
      staminaBonus: 20,
      isApex: true,
      itemLevel: 90,
    );
    final withApex = fresh.copyWith(
      heroes: [
        fresh.heroes.first.copyWith(
          equipped: {
            ...fresh.heroes.first.equipped,
            EquipmentSlot.weapon: apex,
          },
        ),
        ...fresh.heroes.skip(1),
      ],
    );
    expect(GameLogic.partyGearPressure(withApex), lessThanOrEqualTo(1.08));
  });

  test('pickup auto-sell keeps BiS candidate not yet in stash', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 5))
        .copyWith(autoSellMaxPower: 80);
    // Empty cloak slots: keep-on-upgrade path cannot fire; BiS probe must.
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes)
          h.copyWith(
            equipped: {
              for (final e in h.equipped.entries)
                if (e.key != EquipmentSlot.cloak) e.key: e.value,
            },
          ),
      ],
    );
    final upgrade = EquipmentItem(
      id: 'bis_cloak_pickup',
      name: 'Better Cloak',
      slot: EquipmentSlot.cloak,
      rarity: LootRarity.rare,
      staminaBonus: 12,
      armorBonus: 18,
      strengthBonus: 8,
      itemLevel: 40,
    );
    final after = GameLogic.applyLootDrops(state, [
      LootDrop(
        name: upgrade.name,
        rarity: upgrade.rarity,
        amount: 1,
        equipment: upgrade,
      ),
    ]);
    expect(
      after.resolved.single.outcome,
      LootOutcome.stashed,
      reason: 'BiS fill must not auto-sell on pickup',
    );
    expect(
      after.state.gearStash.any((g) => g.id == upgrade.id),
      isTrue,
    );
  });
}
